// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation
import Darwin
import ImageIO
import UniformTypeIdentifiers
import Vision

extension MediaService {

    func makeGIFWork(inputURL: URL, outputURL: URL, options: MediaGIFOptions,
                             operationID: UUID, token: MediaCancellationToken) throws {
        let started = Date()
        let stagedOutputURL = try stagedOutput(inputURL: inputURL, outputURL: outputURL)
        defer { MediaSupport.discardStagedOutput(stagedOutputURL) }
        let asset = AVURLAsset(url: inputURL)
        let targeted = options.sizing == .targetSize
        let metadata = try loadVideoMetadata(from: asset, includeGeometry: targeted, token: token)
        let trim = MediaSupport.sanitizedTrim(start: options.start,
                                              end: options.end,
                                              assetDuration: metadata.duration)
        guard trim.duration > 0 else { throw MediaFailureBox(.unsupported) }

        // A GIF has no bitrate to aim at, so a target size can only be reached
        // by measuring what a pass produced and shrinking what feeds the next
        // one. Aiming starts from the source itself rather than from the width
        // the resolution mode last used, so the result is the largest GIF that
        // fits instead of the one that happened to be configured.
        var width = targeted
            ? MediaSupport.targetGIFStartWidth(sourceWidth: metadata.displaySize.width)
            : options.width
        var fps = targeted
            ? MediaSupport.targetGIFStartFPS(duration: trim.duration)
            : MediaSupport.sanitizedFPS(options.fps, fallback: 12, maxFPS: 30)
        var pass = 0

        while true {
            try writeGIF(asset: asset,
                         stagedOutputURL: stagedOutputURL,
                         trim: trim,
                         width: width,
                         fps: fps,
                         options: options,
                         operationID: operationID,
                         token: token)
            guard targeted, fileSize(stagedOutputURL) > options.targetBytes else { break }
            pass += 1
            guard pass < MediaSupport.maximumTargetGIFPasses,
                  let plan = MediaSupport.gifSizePlan(width: width,
                                                      fps: fps,
                                                      actualBytes: fileSize(stagedOutputURL),
                                                      targetBytes: options.targetBytes)
            else { throw MediaFailureBox(.targetTooSmall) }
            width = plan.width
            fps = plan.fps
        }

        try commit(stagedOutputURL, at: outputURL, operationID: operationID, token: token)
        MediaSupport.makeVisibleIfNeeded(outputURL)
        let result = MediaResult(tool: .gifMaker,
                                 inputURL: inputURL,
                                 outputURL: outputURL,
                                 originalBytes: fileSize(inputURL),
                                 outputBytes: fileSize(outputURL),
                                 elapsed: Date().timeIntervalSince(started),
                                 text: nil)
        publish(.completed(result), operationID: operationID)
    }

    func writeGIF(asset: AVAsset,
                          stagedOutputURL: URL,
                          trim: MediaTrimRange,
                          width: Int,
                          fps: Double,
                          options: MediaGIFOptions,
                          operationID: UUID,
                          token: MediaCancellationToken) throws {
        guard let frameCount = MediaSupport.safeGIFFrameCount(duration: trim.duration, fps: fps) else {
            throw MediaFailureBox(.gifTooLong(maxSeconds: MediaSupport.maximumGIFDuration(fps: fps)))
        }
        let delay = 1 / fps
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let maximumFrameDimension = CGFloat(max(1, width))
        generator.maximumSize = CGSize(width: maximumFrameDimension, height: maximumFrameDimension)

        try? FileManager.default.removeItem(at: stagedOutputURL)
        guard let destination = CGImageDestinationCreateWithURL(stagedOutputURL as CFURL,
                                                               UTType.gif.identifier as CFString,
                                                               frameCount,
                                                               nil) else {
            throw MediaFailureBox(.unsupported)
        }
        if let loopCount = MediaSupport.gifLoopCount(loops: options.loops) {
            CGImageDestinationSetProperties(destination, [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFLoopCount: loopCount,
                ],
            ] as CFDictionary)
        }

        for index in 0..<frameCount {
            try checkCancellation(token)
            let second = min(trim.end, trim.start + Double(index) / fps)
            let image = try generateCGImage(from: generator, at: seconds(second), token: token)
            let resized = resize(image, maxDimension: width) ?? image
            CGImageDestinationAddImage(destination, resized, [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: delay,
                ],
                kCGImageDestinationLossyCompressionQuality: MediaSupport.sanitizedQuality(options.quality),
            ] as CFDictionary)
            publish(.running(progress: Double(index + 1) / Double(frameCount), message: "gif"),
                    operationID: operationID)
        }

        guard CGImageDestinationFinalize(destination) else { throw MediaFailureBox(.unsupported) }
    }

    func processImagesWork(inputURLs: [URL],
                                   outputDirectory: URL,
                                   explicitOutputURL: URL?,
                                   options: MediaImageOptions,
                                   operationID: UUID,
                                   token: MediaCancellationToken) throws {
        let started = Date()
        let inputs = inputURLs.filter { !$0.path.isEmpty }
        guard !inputs.isEmpty else { throw MediaFailureBox(.noInput) }
        if explicitOutputURL == nil {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        }

        var itemResults: [MediaImageBatchItemResult] = []
        var outputURLs: [URL] = []
        var reservedOutputPaths = Set<String>()
        var originalBytes: Int64 = 0
        var outputBytes: Int64 = 0
        let watermarkLogo: CGImage?
        if options.watermark.usesLogo {
            guard let logo = MediaSupport.watermarkLogo(atPath: options.watermark.logoPath) else {
                throw MediaFailureBox(.watermarkUnavailable)
            }
            watermarkLogo = logo
        } else {
            watermarkLogo = nil
        }

        for (offset, inputURL) in inputs.enumerated() {
            try checkCancellation(token)
            let inputBytes = fileSize(inputURL)
            do {
                let prepared = try makeProcessedImage(inputURL: inputURL,
                                                      options: options,
                                                      watermarkLogo: watermarkLogo,
                                                      token: token)
                let outputURL = explicitOutputURL ?? MediaSupport.imageOutputURL(for: inputURL,
                                                                                 outputDirectory: outputDirectory,
                                                                                 options: options,
                                                                                 index: offset + 1,
                                                                                 outputSize: prepared.size,
                                                                                 reservedPaths: reservedOutputPaths)
                reservedOutputPaths.insert(outputURL.standardizedFileURL.path)
                let stagedOutputURL = try stagedOutput(inputURL: inputURL, outputURL: outputURL)
                defer { MediaSupport.discardStagedOutput(stagedOutputURL) }
                try writeImage(prepared.image,
                               properties: prepared.properties,
                               outputURL: stagedOutputURL,
                               options: options)
                try commit(stagedOutputURL, at: outputURL, operationID: operationID, token: token)
                MediaSupport.makeVisibleIfNeeded(outputURL)
                preserveModificationDateIfNeeded(from: inputURL, to: outputURL, options: options)
                let itemOutputBytes = fileSize(outputURL)
                originalBytes += inputBytes
                outputBytes += itemOutputBytes
                outputURLs.append(outputURL)
                itemResults.append(MediaImageBatchItemResult(inputURL: inputURL,
                                                             outputURL: outputURL,
                                                             originalBytes: inputBytes,
                                                             outputBytes: itemOutputBytes,
                                                             failure: nil))
            } catch let failure as MediaFailureBox {
                if inputs.count == 1 { throw failure }
                itemResults.append(MediaImageBatchItemResult(inputURL: inputURL,
                                                             outputURL: nil,
                                                             originalBytes: inputBytes,
                                                             outputBytes: 0,
                                                             failure: failure.failure))
            } catch {
                if inputs.count == 1 { throw error }
                itemResults.append(MediaImageBatchItemResult(inputURL: inputURL,
                                                             outputURL: nil,
                                                             originalBytes: inputBytes,
                                                             outputBytes: 0,
                                                             failure: .failed(error.localizedDescription)))
            }
            publish(.running(progress: Double(offset + 1) / Double(inputs.count), message: "image"),
                    operationID: operationID)
        }

        guard !outputURLs.isEmpty else {
            throw MediaFailureBox(itemResults.compactMap(\.failure).first ?? .unsupported)
        }

        let result = MediaResult(tool: .imageCompressor,
                                 inputURL: inputs[0],
                                 outputURL: outputURLs.first,
                                 outputURLs: outputURLs,
                                 originalBytes: originalBytes,
                                 outputBytes: outputBytes,
                                 elapsed: Date().timeIntervalSince(started),
                                 text: nil,
                                 imageBatchItems: itemResults)
        publish(.completed(result), operationID: operationID)
    }

    func makeProcessedImage(inputURL: URL,
                                    options: MediaImageOptions,
                                    watermarkLogo: CGImage?,
                                    token: MediaCancellationToken) throws -> PreparedImage {
        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            throw MediaFailureBox(.unsupported)
        }
        try checkCancellation(token)
        guard let sourceSize = MediaSupport.imageDisplaySize(properties: properties) else {
            throw MediaFailureBox(.unsupported)
        }
        let expectedSize = options.resizeMode.targetSize(for: sourceSize)
        guard MediaSupport.imageRenderSizeIsSafe(expectedSize) else {
            throw MediaFailureBox(.imageTooLarge)
        }
        guard let maxPixel = MediaSupport.imageDecodeMaxPixel(sourceSize: sourceSize,
                                                              targetSize: expectedSize,
                                                              resizeMode: options.resizeMode) else {
            throw MediaFailureBox(.imageTooLarge)
        }
        let imageOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let sourceImage = CGImageSourceCreateThumbnailAtIndex(source, 0, imageOptions as CFDictionary) else {
            throw MediaFailureBox(.unsupported)
        }
        let targetSize = options.resizeMode.targetSize(
            for: CGSize(width: sourceImage.width, height: sourceImage.height)
        )
        guard MediaSupport.imageRenderSizeIsSafe(targetSize) else {
            throw MediaFailureBox(.imageTooLarge)
        }
        guard let image = renderImage(sourceImage,
                                      targetSize: targetSize,
                                      resizeMode: options.resizeMode,
                                      watermark: options.watermark,
                                      watermarkLogo: watermarkLogo,
                                      background: options.background,
                                      forceOpaque: options.format == .jpeg || options.format == .pdf) else {
            throw MediaFailureBox(.unsupported)
        }
        return PreparedImage(image: image,
                             properties: properties,
                             size: CGSize(width: image.width, height: image.height))
    }
}
