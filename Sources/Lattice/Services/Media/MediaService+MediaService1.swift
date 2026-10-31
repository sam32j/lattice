// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation
import Darwin
import ImageIO
import UniformTypeIdentifiers
import Vision

extension MediaService {

    func reset() {
        cancel()
        publish(.idle)
    }

    func cancel(immediately: Bool = false) {
        lock.lock()
        token?.cancel()
        if let activeProcess, activeProcess.isRunning {
            if immediately { kill(activeProcess.processIdentifier, SIGKILL) }
            else { activeProcess.terminate() }
        }
        activeVisionRequest?.cancel()
        operationID = nil
        activeProcess = nil
        activeVisionRequest = nil
        lock.unlock()
        publish(.cancelled)
    }

    func compressVideo(inputURL: URL, outputURL: URL, options: MediaVideoOptions) {
        run(.videoCompressor) { [weak self] id, token in
            try self?.compressVideoWork(inputURL: inputURL, outputURL: outputURL, options: options,
                                        operationID: id, token: token)
        }
    }

    func makeGIF(inputURL: URL, outputURL: URL, options: MediaGIFOptions) {
        run(.gifMaker) { [weak self] id, token in
            try self?.makeGIFWork(inputURL: inputURL, outputURL: outputURL, options: options,
                                  operationID: id, token: token)
        }
    }

    func compressImage(inputURL: URL, outputURL: URL, options: MediaImageOptions) {
        run(.imageCompressor) { [weak self] id, token in
            try self?.processImagesWork(inputURLs: [inputURL],
                                        outputDirectory: outputURL.deletingLastPathComponent(),
                                        explicitOutputURL: outputURL,
                                        options: options,
                                        operationID: id,
                                        token: token)
        }
    }

    func processImages(inputURLs: [URL], outputDirectory: URL, options: MediaImageOptions) {
        run(.imageCompressor) { [weak self] id, token in
            try self?.processImagesWork(inputURLs: inputURLs,
                                        outputDirectory: outputDirectory,
                                        explicitOutputURL: nil,
                                        options: options,
                                        operationID: id,
                                        token: token)
        }
    }

    func extractText(inputURL: URL, outputURL: URL?, options: MediaTextOptions) {
        run(.textExtractor) { [weak self] id, token in
            try self?.extractTextWork(inputURL: inputURL, outputURL: outputURL, options: options,
                                      operationID: id, token: token)
        }
    }

    func run(_ tool: MediaTool,
                     _ work: @escaping (UUID, MediaCancellationToken) throws -> Void) {
        guard AppFeature.mediaTools.isAvailable else { return }
        let id = UUID()
        let token = MediaCancellationToken()
        lock.lock()
        self.token?.cancel()
        self.activeProcess?.terminate()
        self.activeVisionRequest?.cancel()
        self.operationID = id
        self.token = token
        self.activeProcess = nil
        self.activeVisionRequest = nil
        lock.unlock()
        publish(.running(progress: 0, message: tool.rawValue), operationID: id)

        queue.async { [weak self] in
            do {
                try work(id, token)
            } catch let failure as MediaFailureBox {
                self?.publish(.failed(failure.failure), operationID: id)
            } catch {
                if token.isCancelled {
                    self?.publish(.cancelled, operationID: id)
                } else {
                    self?.publish(.failed(.failed(error.localizedDescription)), operationID: id)
                }
            }
        }
    }

    func compressVideoWork(inputURL: URL, outputURL: URL, options: MediaVideoOptions,
                                   operationID: UUID, token: MediaCancellationToken) throws {
        let started = Date()
        let stagedOutputURL = try stagedOutput(inputURL: inputURL, outputURL: outputURL)
        defer { MediaSupport.discardStagedOutput(stagedOutputURL) }
        let asset = AVURLAsset(url: inputURL)
        let metadata = try loadVideoMetadata(from: asset, includeGeometry: true, token: token)
        let trim = MediaSupport.sanitizedTrim(start: options.start,
                                              end: options.end,
                                              assetDuration: metadata.duration)
        guard trim.duration > 0 else { throw MediaFailureBox(.unsupported) }

        switch options.sizing {
        case .resolution:
            try convertVideo(inputURL: inputURL,
                             stagedOutputURL: stagedOutputURL,
                             trim: trim,
                             options: options,
                             displaySize: metadata.displaySize,
                             started: started,
                             operationID: operationID,
                             token: token)
        case .targetSize:
            try encodeVideoToTargetSize(asset: asset,
                                        geometry: metadata.geometry,
                                        stagedOutputURL: stagedOutputURL,
                                        trim: trim,
                                        targetBytes: options.targetBytes,
                                        operationID: operationID,
                                        token: token)
        }

        try commit(stagedOutputURL, at: outputURL, operationID: operationID, token: token)
        MediaSupport.makeVisibleIfNeeded(outputURL)
        publish(.running(progress: 1, message: "video"), operationID: operationID)
        let result = MediaResult(tool: .videoCompressor,
                                 inputURL: inputURL,
                                 outputURL: outputURL,
                                 originalBytes: fileSize(inputURL),
                                 outputBytes: fileSize(outputURL),
                                 elapsed: Date().timeIntervalSince(started),
                                 text: nil)
        publish(.completed(result), operationID: operationID)
    }

    func convertVideo(inputURL: URL,
                              stagedOutputURL: URL,
                              trim: MediaTrimRange,
                              options: MediaVideoOptions,
                              displaySize: CGSize,
                              started: Date,
                              operationID: UUID,
                              token: MediaCancellationToken) throws {
        let outSize = MediaSupport.scaledVideoSize(source: displaySize,
                                                   maxDimension: options.maxDimension)
        let preset = avconvertPreset(codec: options.codec,
                                     maxDimension: max(Int(outSize.width), Int(outSize.height)),
                                     quality: options.quality)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/avconvert")
        process.arguments = [
            "--source", inputURL.path,
            "--preset", preset,
            "--output", stagedOutputURL.path,
            "--replace",
            "--progress",
            // Deliberately not the reader's region: these are arguments for
            // a tool that reads a decimal point, and a comma would break the
            // trim in every country that writes numbers that way.
            "--start", String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), trim.start),
            "--duration", String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), trim.duration),
        ]
        if options.quality >= 0.82 {
            process.arguments?.append("--multiPass")
        }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        var log = ""
        let logLock = NSLock()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            logLock.lock()
            log.append(chunk)
            if log.count > 8_000 { log.removeFirst(log.count - 8_000) }
            logLock.unlock()
        }
        defer {
            pipe.fileHandleForReading.readabilityHandler = nil
            if process.isRunning { process.terminate() }
        }
        try launch(process: process, operationID: operationID, token: token)
        while process.isRunning {
            try checkCancellation(token)
            let elapsed = Date().timeIntervalSince(started)
            let estimate = max(1, trim.duration * 0.75)
            publish(.running(progress: min(0.95, elapsed / estimate), message: "video"), operationID: operationID)
            Thread.sleep(forTimeInterval: 0.08)
        }
        if token.isCancelled {
            throw MediaFailureBox(.cancelled)
        }
        guard process.terminationStatus == 0 else {
            logLock.lock()
            let message = log.trimmingCharacters(in: .whitespacesAndNewlines)
            logLock.unlock()
            throw MediaFailureBox(.failed(message.isEmpty ? "avconvert failed." : message))
        }
    }

    func encodeVideoToTargetSize(asset: AVAsset,
                                         geometry: VideoGeometry?,
                                         stagedOutputURL: URL,
                                         trim: MediaTrimRange,
                                         targetBytes: Int64,
                                         operationID: UUID,
                                         token: MediaCancellationToken) throws {
        guard let geometry else { throw MediaFailureBox(.noVideoTrack) }
        let source = MediaVideoTargetEncoder.Source(asset: asset,
                                                    videoTrack: geometry.videoTrack,
                                                    audioTracks: geometry.audioTracks,
                                                    naturalSize: geometry.naturalSize,
                                                    preferredTransform: geometry.preferredTransform,
                                                    frameRate: geometry.frameRate)
        var publishedPercent = -1
        do {
            _ = try MediaVideoTargetEncoder.encode(
                source: source,
                trim: trim,
                targetBytes: targetBytes,
                destination: stagedOutputURL,
                isCancelled: { token.isCancelled },
                progress: { value in
                    // The encoder reports every frame, which would put thousands
                    // of hops on the main queue for one conversion.
                    let percent = Int(value * 100)
                    guard percent != publishedPercent else { return }
                    publishedPercent = percent
                    self.publish(.running(progress: value, message: "video"),
                                 operationID: operationID)
                })
        } catch let error as MediaVideoTargetEncoder.EncodeError {
            throw MediaFailureBox(mediaFailure(for: error))
        }
    }

    func mediaFailure(for error: MediaVideoTargetEncoder.EncodeError) -> MediaFailure {
        switch error {
        case .unsupported: return .unsupported
        case .targetTooSmall: return .targetTooSmall
        case .cancelled: return .cancelled
        case let .failed(message): return .failed(message)
        }
    }
}
