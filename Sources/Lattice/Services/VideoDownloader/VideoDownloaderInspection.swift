// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import Combine
import ImageIO

extension VideoDownloader {
    func fetchInfo() {
        guard !busy else { return }
        do {
            let url = try VideoDownloadRequest.validatedURL(link)
            refreshDependencies()
            guard dependencies.ready, let ytdlp = dependencies.tools["yt-dlp"] else {
                throw VideoDownloadError.missingTools
            }
            let tools = dependencies
            info = nil
            inspectedURL = nil
            thumbnailImage = nil
            output = nil
            error = nil
            isFetching = true
            isDownloading = false
            perform(VideoDownloaderStrings.fetchingDetails) { [weak self] process, id in
                let result = try process.run(
                    executable: ytdlp,
                    arguments: tools.runtimeArguments + VideoDownloadRequest.metadataArguments(url: url),
                    environment: tools.environment,
                    timeout: 90
                )
                let details = try VideoDownloadInfo.decode(result.stdout)
                return { [weak self] in
                    guard let self else { return }
                    self.isFetching = false
                    self.info = details
                    self.inspectedURL = url
                    self.selectedQuality = .best
                    self.selectedHeight = details.qualities.first?.height ?? 0
                    self.phase = ""
                    self.loadThumbnail(details.thumbnailURL, id: id)
                }
            }
        } catch {
            self.isFetching = false
            self.error = VideoDownloaderStrings.fetchFailedNotice
        }
    }

    func loadThumbnail(_ url: URL?, id: UUID) {
        guard let url else { return }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let data = try? Data(contentsOf: url),
                  let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 600
            ]
            guard let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return }
            let image = NSImage(cgImage: cgThumb, size: NSSize(width: 300, height: 169))
            DispatchQueue.main.async {
                guard self?.generation == id else { return }
                self?.thumbnailImage = image
            }
        }
    }

}
