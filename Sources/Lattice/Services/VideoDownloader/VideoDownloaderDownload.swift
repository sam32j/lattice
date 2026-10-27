// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import Combine
import ImageIO

extension VideoDownloader {
    func download() {
        let quality = selectedQuality.height != 0
            ? selectedQuality
            : (info?.qualities.first(where: { $0.height == selectedHeight }) ?? selectedQuality)

        guard let url = inspectedURL,
              let destination, dependencies.ready,
              let ytdlp = dependencies.tools["yt-dlp"],
              let ffmpeg = dependencies.tools["ffmpeg"],
              let ffprobe = dependencies.tools["ffprobe"] else { return }

        let tools = dependencies
        let sessionArguments = inspectedSession?.arguments ?? []
        let videoTitle = info?.title ?? "video"
        let qualityTag = quality.title

        isDownloading = true
        isFetching = false
        output = nil
        error = nil

        perform(VideoDownloaderStrings.downloading) { [weak self] process, id in
            let manager = FileManager.default
            let staging = destination.appendingPathComponent(".lattice-download-\(UUID().uuidString)", isDirectory: true)
            try manager.createDirectory(at: staging, withIntermediateDirectories: false)
            defer { try? manager.removeItem(at: staging) }

            func executeYtdlp(compatibility: VideoDownloadCompatibilityOptions) throws -> VideoDownloadProcess.Output {
                var tracker = VideoDownloadProgressTracker()
                return try process.run(
                    executable: ytdlp,
                    arguments: tools.runtimeArguments + sessionArguments + VideoDownloadRequest.downloadArguments(
                        url: url,
                        quality: quality,
                        staging: staging,
                        ffmpeg: ffmpeg,
                        compatibility: compatibility
                    ),
                    environment: tools.environment,
                    timeout: 6 * 3600,
                    stdoutLimit: 4_000_000
                ) { line in
                    if let parsed = tracker.consume(line) {
                        let finishing = tracker.isFinishing
                        DispatchQueue.main.async {
                            guard self?.generation == id else { return }
                            self?.progress = parsed.fraction
                            self?.downloadProgress = parsed
                            self?.phase = finishing ? VideoDownloaderStrings.finishingVideo : VideoDownloaderStrings.downloading
                        }
                    }
                }
            }

            var didUseRangeFallback = false
            let result: VideoDownloadProcess.Output
            do {
                result = try executeYtdlp(compatibility: .init(bilibiliRangeFallback: false))
            } catch {
                if VideoDownloadRequest.shouldRetryBilibili567(
                    url: url,
                    output: error.localizedDescription,
                    didUseRangeFallback: didUseRangeFallback
                ) {
                    didUseRangeFallback = true
                    #if DEBUG
                    print("[BiliBili] HTTP 567 detected")
                    print("[BiliBili] Retrying with Range: bytes=0-")
                    #endif
                    DispatchQueue.main.async {
                        guard self?.generation == id else { return }
                        self?.progress = nil
                        self?.downloadProgress = nil
                        self?.phase = VideoDownloaderStrings.downloading
                    }
                    result = try executeYtdlp(compatibility: .init(bilibiliRangeFallback: true))
                } else {
                    throw error
                }
            }

            guard let path = String(decoding: result.stdout, as: UTF8.self).split(separator: "\n")
                .last(where: { $0.hasPrefix("LATTICE_FILE:") })
                .map({ String($0.dropFirst("LATTICE_FILE:".count)) }) else {
                throw VideoDownloadError.invalidOutput
            }

            let file = try VideoDownloadRequest.validatedOutput(URL(fileURLWithPath: path), from: staging)
            let probe = try process.run(
                executable: ffprobe,
                arguments: ["-v", "error", "-select_streams", quality.isAudio ? "a:0" : "v:0",
                            "-show_entries", "stream=codec_type,width,height:format=duration",
                            "-of", "json", "-i", file.path],
                environment: tools.environment,
                timeout: 30,
                stdoutLimit: 256_000
            )

            guard VideoDownloadRequest.hasPlayableMedia(probe.stdout, isAudio: quality.isAudio) else {
                throw VideoDownloadError.invalidOutput
            }

            var saved: URL?
            var publishError: Error?
            DispatchQueue.main.sync {
                guard self?.generation == id else { return }
                do {
                    saved = try VideoDownloadRequest.publish(file, from: staging, to: destination)
                    self?.output = saved
                } catch {
                    publishError = error
                }
            }
            if let publishError { throw publishError }
            guard let saved else { throw CancellationError() }

            return { [weak self] in
                self?.isDownloading = false
                self?.output = saved
                self?.phase = VideoDownloaderStrings.downloadComplete
                self?.progress = nil
                self?.downloadProgress = nil
                self?.historyStore.record(fileURL: saved, title: videoTitle, qualityTag: qualityTag)
                self?.completionFeedback()
                if self?.hasCurrentSearchResult == true { self?.startCompletionSustain() }
            }
        }
    }

    static func playCompletionSound() {
        if let sound = NSSound(named: "Glass") {
            sound.play()
        } else if let sound = NSSound(contentsOfFile: "/System/Library/Sounds/Glass.aiff", byReference: false) {
            sound.play()
        }
    }

}
