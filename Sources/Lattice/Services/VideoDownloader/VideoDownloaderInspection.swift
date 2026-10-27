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
            let session = websiteSessions.session(for: url)
            info = nil
            inspectedURL = nil
            inspectedSession = nil
            thumbnailImage = nil
            output = nil
            error = nil
            isFetching = true
            isDownloading = false
            perform(VideoDownloaderStrings.fetchingDetails) { [weak self] process, id in
                let result = try process.run(
                    executable: ytdlp,
                    arguments: tools.runtimeArguments + (session?.arguments ?? []) + VideoDownloadRequest.metadataArguments(url: url),
                    environment: tools.environment,
                    timeout: 90
                )
                let details = try VideoDownloadInfo.decode(result.stdout)
                return { [weak self] in
                    guard let self else { return }
                    self.isFetching = false
                    self.info = details
                    self.inspectedURL = url
                    self.inspectedSession = session
                    self.selectedQuality = .best
                    self.selectedHeight = details.qualities.first?.height ?? 0
                    self.phase = ""
                    self.loadThumbnail(details.thumbnailURL, id: id)
                }
            }
        } catch {
            self.isFetching = false
            self.websiteFailure = nil
            self.error = VideoDownloaderStrings.fetchFailedNotice
        }
    }

    func loadThumbnail(_ url: URL?, id: UUID) {
        guard let url else { return }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var targetURL = url
            if targetURL.scheme == "http", let httpsURL = URL(string: "https://" + targetURL.absoluteString.dropFirst("http://".count)) {
                targetURL = httpsURL
            }
            var request = URLRequest(url: targetURL)
            request.timeoutInterval = 15
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            if let host = targetURL.host?.lowercased(), host.contains("bilibili") || host.contains("hdslb") {
                request.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")
            }
            let task = URLSession.shared.dataTask(with: request) { data, _, _ in
                guard let data, let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }
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
            task.resume()
        }
    }

}
