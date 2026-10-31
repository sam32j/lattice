// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation
import Darwin
import ImageIO
import UniformTypeIdentifiers
import Vision

extension MediaService {

    func writeImage(_ image: CGImage,
                            properties: [CFString: Any],
                            outputURL: URL,
                            options: MediaImageOptions) throws {
        if options.format == .pdf {
            try writePDF(image: image, outputURL: outputURL,
                         quality: MediaSupport.sanitizedQuality(options.quality))
        } else {
            let type = typeIdentifier(for: options.format)
            guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, type as CFString, 1, nil) else {
                throw MediaFailureBox(.unsupported)
            }
            var outputProperties: [CFString: Any] = [
                kCGImageDestinationLossyCompressionQuality: MediaSupport.sanitizedQuality(options.quality),
            ]
            if !options.stripMetadata {
                outputProperties.merge(sanitizedImageProperties(properties, image: image)) { current, _ in current }
            }
            CGImageDestinationAddImage(destination, image, outputProperties as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { throw MediaFailureBox(.unsupported) }
        }
    }

    func extractTextWork(inputURL: URL, outputURL: URL?, options: MediaTextOptions,
                                 operationID: UUID, token: MediaCancellationToken) throws {
        let started = Date()
        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let sourceSize = MediaSupport.imageDisplaySize(properties: properties) else {
            throw MediaFailureBox(.unsupported)
        }
        guard MediaSupport.imageRenderSizeIsSafe(sourceSize) else {
            throw MediaFailureBox(.imageTooLarge)
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, [
                  kCGImageSourceShouldCacheImmediately: true,
              ] as CFDictionary) else {
            throw MediaFailureBox(.unsupported)
        }
        try checkCancellation(token)
        publish(.running(progress: 0.2, message: "ocr"), operationID: operationID)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = options.accurate ? .accurate : .fast
        request.usesLanguageCorrection = options.languageCorrection
        if let supported = try? request.supportedRecognitionLanguages(), !supported.isEmpty {
            let desired = options.recognitionLanguages.filter { supported.contains($0) }
            if !desired.isEmpty { request.recognitionLanguages = desired }
        }
        try setActiveVisionRequest(request, operationID: operationID, token: token)
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        try checkCancellation(token)
        let text = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
        if let outputURL {
            let stagedOutputURL = try stagedOutput(inputURL: inputURL, outputURL: outputURL)
            defer { MediaSupport.discardStagedOutput(stagedOutputURL) }
            try text.write(to: stagedOutputURL, atomically: true, encoding: .utf8)
            try commit(stagedOutputURL, at: outputURL, operationID: operationID, token: token)
            MediaSupport.makeVisibleIfNeeded(outputURL)
        }
        let result = MediaResult(tool: .textExtractor,
                                 inputURL: inputURL,
                                 outputURL: outputURL,
                                 originalBytes: fileSize(inputURL),
                                 outputBytes: outputURL.map(fileSize) ?? Int64(text.utf8.count),
                                 elapsed: Date().timeIntervalSince(started),
                                 text: text)
        publish(.completed(result), operationID: operationID)
    }

    /// A dropped file that does not fit the selected tool: surface the same
    /// "unsupported" message a failed run would, instead of accepting it.
    func rejectUnsupportedInput() {
        state = .failed(.unsupported)
    }

    func stagedOutput(inputURL: URL, outputURL: URL) throws -> URL {
        guard !MediaSupport.fileURLsReferToSameItem(inputURL, outputURL) else {
            throw MediaFailureBox(.sameOutput)
        }
        return try MediaSupport.temporaryOutputURL(for: outputURL)
    }

    func commit(_ stagedURL: URL,
                        at outputURL: URL,
                        operationID: UUID,
                        token: MediaCancellationToken) throws {
        lock.lock()
        defer { lock.unlock() }
        guard self.operationID == operationID, !token.isCancelled else {
            throw MediaFailureBox(.cancelled)
        }
        try MediaSupport.installStagedOutput(stagedURL, at: outputURL,
                                             replacingExisting: replacesExistingOutputs)
    }

    func resize(_ image: CGImage, maxDimension: Int) -> CGImage? {
        let size = MediaSupport.scaledEvenSize(source: CGSize(width: image.width, height: image.height),
                                               maxDimension: maxDimension)
        guard Int(size.width) != image.width || Int(size.height) != image.height else { return image }
        guard let context = CGContext(data: nil,
                                      width: Int(size.width),
                                      height: Int(size.height),
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return context.makeImage()
    }

    func renderImage(_ image: CGImage,
                             targetSize: CGSize,
                             resizeMode: MediaImageResizeMode,
                             watermark: MediaImageWatermark,
                             watermarkLogo: CGImage?,
                             background: MediaImageBackground,
                             forceOpaque: Bool) -> CGImage? {
        let width = max(1, Int(targetSize.width.rounded()))
        let height = max(1, Int(targetSize.height.rounded()))
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: width,
                                         pixelsHigh: height,
                                         bitsPerSample: 8,
                                         samplesPerPixel: 4,
                                         hasAlpha: true,
                                         isPlanar: false,
                                         colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0,
                                         bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: rep) else {
            return nil
        }

        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        let size = NSSize(width: CGFloat(width), height: CGFloat(height))
        let rect = NSRect(origin: .zero, size: size)
        if let fill = backgroundColor(background, forceOpaque: forceOpaque) {
            fill.setFill()
            rect.fill()
        }
        let drawRect = imageDrawRect(sourceSize: CGSize(width: image.width, height: image.height),
                                     canvasSize: size,
                                     resizeMode: resizeMode)
        NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)).draw(in: drawRect,
                                                 from: .zero,
                                                 operation: .sourceOver,
                                                 fraction: 1,
                                                 respectFlipped: false,
                                                 hints: [.interpolation: NSImageInterpolation.high.rawValue])
        drawWatermark(watermark, logo: watermarkLogo, canvasSize: size)
        NSGraphicsContext.current = previous
        return rep.cgImage
    }

    func imageDrawRect(sourceSize: CGSize,
                               canvasSize: NSSize,
                               resizeMode: MediaImageResizeMode) -> NSRect {
        let canvasRect = NSRect(origin: .zero, size: canvasSize)
        guard resizeMode.kind == .exact, resizeMode.exactMode != .stretch else { return canvasRect }
        let sourceWidth = max(1, sourceSize.width)
        let sourceHeight = max(1, sourceSize.height)
        let scale: CGFloat
        switch resizeMode.exactMode {
        case .stretch:
            return canvasRect
        case .fit:
            scale = min(canvasSize.width / sourceWidth, canvasSize.height / sourceHeight)
        case .fill:
            scale = max(canvasSize.width / sourceWidth, canvasSize.height / sourceHeight)
        }
        let width = sourceWidth * scale
        let height = sourceHeight * scale
        return NSRect(x: (canvasSize.width - width) / 2,
                      y: (canvasSize.height - height) / 2,
                      width: width,
                      height: height)
    }

    func backgroundColor(_ background: MediaImageBackground, forceOpaque: Bool) -> NSColor? {
        switch background {
        case .transparent:
            return forceOpaque ? .white : nil
        case .white:
            return .white
        case .black:
            return .black
        }
    }

    func drawWatermark(_ watermark: MediaImageWatermark,
                               logo: CGImage?,
                               canvasSize: NSSize) {
        guard watermark.isEnabled, NSGraphicsContext.current != nil else { return }
        let opacity = CGFloat(MediaSupport.sanitizedOpacity(watermark.opacity))
        let side = max(1, min(canvasSize.width, canvasSize.height))
        let margin = CGFloat(watermark.margin)
        let gap = max(6, side * 0.015)
        var logoImage: NSImage?
        var logoSize = NSSize.zero
        if watermark.usesLogo, let logo {
            let image = NSImage(cgImage: logo,
                                size: NSSize(width: logo.width, height: logo.height))
            let maxLogoSide = max(12, side * CGFloat(watermark.scale))
            let scale = min(maxLogoSide / image.size.width, maxLogoSide / image.size.height)
            logoImage = image
            logoSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        }

        let text = watermark.usesText ? watermark.text.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        var attributedText: NSAttributedString?
        var textSize = NSSize.zero
        if !text.isEmpty {
            let fontSize = max(12, min(96, side * 0.045))
            let shadow = NSShadow()
            shadow.shadowBlurRadius = max(2, fontSize * 0.14)
            shadow.shadowOffset = NSSize(width: 0, height: -1)
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.45 * opacity)
            attributedText = NSAttributedString(string: text, attributes: [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: NSColor.white.withAlphaComponent(opacity),
                .shadow: shadow,
            ])
            textSize = attributedText?.size() ?? .zero
        }

        guard logoImage != nil || attributedText != nil else { return }
        let maxContentWidth = max(1, canvasSize.width - margin * 2)
        let rawContentWidth = logoSize.width + (logoImage != nil && attributedText != nil ? gap : 0) + textSize.width
        let shrink = rawContentWidth > maxContentWidth ? maxContentWidth / rawContentWidth : 1
        var resolvedText = attributedText
        if shrink < 1 {
            logoSize = NSSize(width: logoSize.width * shrink, height: logoSize.height * shrink)
            if let attributedText {
                let fontSize = max(8, (attributedText.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize ?? 12)
                let shadow = NSShadow()
                shadow.shadowBlurRadius = max(1, fontSize * shrink * 0.14)
                shadow.shadowOffset = NSSize(width: 0, height: -1)
                shadow.shadowColor = NSColor.black.withAlphaComponent(0.45 * opacity)
                let scaled = NSAttributedString(string: attributedText.string, attributes: [
                    .font: NSFont.systemFont(ofSize: max(8, fontSize * shrink), weight: .semibold),
                    .foregroundColor: NSColor.white.withAlphaComponent(opacity),
                    .shadow: shadow,
                ])
                resolvedText = scaled
            }
        }
        textSize = resolvedText?.size() ?? .zero
        let contentWidth = logoSize.width + (logoImage != nil && resolvedText != nil ? gap : 0) + textSize.width
        let contentHeight = max(logoSize.height, textSize.height)
        let origin = watermarkOrigin(position: watermark.position,
                                     contentSize: NSSize(width: contentWidth, height: contentHeight),
                                     canvasSize: canvasSize,
                                     margin: margin)

        var cursorX = origin.x
        if let logoImage {
            let y = origin.y + (contentHeight - logoSize.height) / 2
            logoImage.draw(in: NSRect(x: cursorX, y: y, width: logoSize.width, height: logoSize.height),
                           from: .zero,
                           operation: .sourceOver,
                           fraction: opacity)
            cursorX += logoSize.width + (resolvedText != nil ? gap : 0)
        }
        if let attributedText = resolvedText {
            let y = origin.y + (contentHeight - textSize.height) / 2
            attributedText.draw(at: NSPoint(x: cursorX, y: y))
        }
    }
}
