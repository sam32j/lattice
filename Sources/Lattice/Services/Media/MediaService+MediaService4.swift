// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation
import Darwin
import ImageIO
import UniformTypeIdentifiers
import Vision

extension MediaService {

    func watermarkOrigin(position: MediaImageWatermarkPosition,
                                 contentSize: NSSize,
                                 canvasSize: NSSize,
                                 margin: CGFloat) -> NSPoint {
        let maxX = max(margin, canvasSize.width - contentSize.width - margin)
        let maxY = max(margin, canvasSize.height - contentSize.height - margin)
        switch position {
        case .topLeft:
            return NSPoint(x: margin, y: maxY)
        case .topRight:
            return NSPoint(x: maxX, y: maxY)
        case .center:
            return NSPoint(x: max(margin, (canvasSize.width - contentSize.width) / 2),
                           y: max(margin, (canvasSize.height - contentSize.height) / 2))
        case .bottomLeft:
            return NSPoint(x: margin, y: margin)
        case .bottomRight:
            return NSPoint(x: maxX, y: margin)
        }
    }

    func avconvertPreset(codec: MediaVideoCodec, maxDimension: Int, quality: Double) -> String {
        let quality = MediaSupport.sanitizedQuality(quality)
        if quality < 0.4 {
            return "PresetLowQuality"
        }
        if codec == .hevc {
            if quality >= 0.82 { return "PresetHEVCHighestQuality" }
            if maxDimension <= 1920 { return "PresetHEVC1920x1080" }
            if maxDimension <= 3840 { return "PresetHEVC3840x2160" }
            return "PresetHEVCHighestQuality"
        }
        if quality >= 0.82 { return "PresetHighestQuality" }
        if quality < 0.58 { return "PresetMediumQuality" }
        if maxDimension <= 640 { return "Preset640x480" }
        if maxDimension <= 960 { return "Preset960x540" }
        if maxDimension <= 1280 { return "Preset1280x720" }
        if maxDimension <= 1920 { return "Preset1920x1080" }
        return "PresetHighestQuality"
    }

    func seconds(_ value: Double) -> CMTime {
        CMTime(seconds: value, preferredTimescale: 600)
    }

    func loadVideoMetadata(from asset: AVAsset,
                                   includeGeometry: Bool,
                                   token: MediaCancellationToken) throws -> VideoMetadata {
        try runAsync(token: token) {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let track = tracks.first else { throw MediaFailureBox(.noVideoTrack) }

            let duration = try await asset.load(.duration).seconds
            guard includeGeometry else {
                return VideoMetadata(duration: duration, displaySize: .zero, geometry: nil)
            }

            let naturalSize = try await track.load(.naturalSize)
            let preferredTransform = try await track.load(.preferredTransform)
            let frameRate = Double(try await track.load(.nominalFrameRate))
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            let transformed = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
            let displaySize = CGSize(width: abs(transformed.width), height: abs(transformed.height))
            return VideoMetadata(duration: duration,
                                 displaySize: displaySize,
                                 geometry: VideoGeometry(videoTrack: track,
                                                         audioTracks: audioTracks,
                                                         naturalSize: naturalSize,
                                                         preferredTransform: preferredTransform,
                                                         frameRate: frameRate))
        }
    }

    func generateCGImage(from generator: AVAssetImageGenerator,
                                 at time: CMTime,
                                 token: MediaCancellationToken) throws -> CGImage {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<CGImage, Error>?

        generator.generateCGImageAsynchronously(for: time) { image, _, error in
            if let image {
                result = .success(image)
            } else {
                result = .failure(error ?? MediaFailureBox(.failed("Video frame unavailable.")))
            }
            semaphore.signal()
        }

        while semaphore.wait(timeout: .now() + .milliseconds(50)) == .timedOut {
            if token.isCancelled {
                generator.cancelAllCGImageGeneration()
                throw MediaFailureBox(.cancelled)
            }
        }
        try checkCancellation(token)
        guard let result else {
            throw MediaFailureBox(.failed("Video frame unavailable."))
        }
        return try result.get()
    }

    func runAsync<T>(token: MediaCancellationToken,
                             _ operation: @escaping () async throws -> T) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        let resultBox = AsyncResultBox<T>()

        let task = Task {
            do {
                resultBox.set(.success(try await operation()))
            } catch {
                resultBox.set(.failure(error))
            }
            semaphore.signal()
        }

        while semaphore.wait(timeout: .now() + .milliseconds(50)) == .timedOut {
            if token.isCancelled {
                task.cancel()
                throw MediaFailureBox(.cancelled)
            }
        }
        try checkCancellation(token)
        guard let result = resultBox.get() else {
            throw MediaFailureBox(.failed("Video metadata unavailable."))
        }
        return try result.get()
    }

    func sanitizedImageProperties(_ properties: [CFString: Any], image: CGImage) -> [CFString: Any] {
        var clean = properties
        clean.removeValue(forKey: kCGImagePropertyOrientation)
        clean[kCGImagePropertyPixelWidth] = image.width
        clean[kCGImagePropertyPixelHeight] = image.height
        return clean
    }

    /// CGImageDestination accepts com.adobe.pdf but ignores the lossy quality,
    /// embedding the bitmap losslessly. Re-encoding as JPEG at the chosen
    /// quality and drawing that image into a PDF context makes Quartz embed
    /// the JPEG stream as-is, so the quality slider keeps working for PDF.
    func writePDF(image: CGImage, outputURL: URL, quality: Double) throws {
        let jpegData = NSMutableData()
        guard let encoder = CGImageDestinationCreateWithData(jpegData, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw MediaFailureBox(.unsupported)
        }
        CGImageDestinationAddImage(encoder, image, [
            kCGImageDestinationLossyCompressionQuality: quality,
        ] as CFDictionary)
        guard CGImageDestinationFinalize(encoder),
              let encodedSource = CGImageSourceCreateWithData(jpegData, nil),
              let encoded = CGImageSourceCreateImageAtIndex(encodedSource, 0, nil) else {
            throw MediaFailureBox(.unsupported)
        }
        var mediaBox = CGRect(x: 0, y: 0, width: CGFloat(encoded.width), height: CGFloat(encoded.height))
        guard let pdf = CGContext(outputURL as CFURL, mediaBox: &mediaBox, nil) else {
            throw MediaFailureBox(.unsupported)
        }
        pdf.beginPDFPage(nil)
        pdf.draw(encoded, in: mediaBox)
        pdf.endPDFPage()
        pdf.closePDF()
    }

    func typeIdentifier(for format: MediaImageFormat) -> String {
        switch format {
        case .jpeg: return UTType.jpeg.identifier
        case .heic: return UTType.heic.identifier
        case .png: return UTType.png.identifier
        case .pdf: return UTType.pdf.identifier
        }
    }

    func fileSize(_ url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    func preserveModificationDateIfNeeded(from inputURL: URL,
                                                  to outputURL: URL,
                                                  options: MediaImageOptions) {
        guard options.preserveModificationDate,
              let date = try? inputURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        else { return }
        try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: outputURL.path)
    }

    func checkCancellation(_ token: MediaCancellationToken) throws {
        if token.isCancelled { throw MediaFailureBox(.cancelled) }
    }

    /// Launch and cancellation share one lock, so a process either starts and
    /// becomes cancellable before the lock is released, or never starts after
    /// its operation was replaced or cancelled.
    func launch(process: Process,
                        operationID: UUID,
                        token: MediaCancellationToken) throws {
        lock.lock()
        defer { lock.unlock() }
        guard self.operationID == operationID, !token.isCancelled else {
            throw MediaFailureBox(.cancelled)
        }
        try process.run()
        activeProcess = process
    }

    func setActiveVisionRequest(_ request: VNRequest,
                                        operationID: UUID,
                                        token: MediaCancellationToken) throws {
        lock.lock()
        defer { lock.unlock() }
        guard self.operationID == operationID, !token.isCancelled else {
            throw MediaFailureBox(.cancelled)
        }
        activeVisionRequest = request
    }

    func clearOperation(_ id: UUID) {
        lock.lock()
        if operationID == id {
            operationID = nil
            token = nil
            activeProcess = nil
            activeVisionRequest = nil
        }
        lock.unlock()
    }

    func publish(_ state: MediaServiceState, operationID: UUID? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let operationID {
                self.lock.lock()
                let isCurrent = self.operationID == operationID
                self.lock.unlock()
                guard isCurrent else { return }
            }
            self.state = state
            if let operationID, state.isTerminal {
                self.clearOperation(operationID)
            }
        }
    }
}
