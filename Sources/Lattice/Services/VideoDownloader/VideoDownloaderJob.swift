// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import Combine
import ImageIO

extension VideoDownloader {
    func perform(_ title: String,
                         work: @escaping (VideoDownloadProcess, UUID) throws -> () -> Void) {
        guard !busy else { return }
        cancelCompletionSustain()
        let process = VideoDownloadProcess()
        let id = UUID()
        generation = id
        job = process
        busy = true
        isPaused = false
        error = nil
        output = nil
        progress = nil
        downloadProgress = nil
        phase = title

        queue.async { [weak self] in
            do {
                let finish = try work(process, id)
                DispatchQueue.main.async {
                    self?.terminatingJobs.removeAll { $0 === process }
                    guard self?.generation == id else { return }
                    self?.busy = false
                    self?.isFetching = false
                    self?.isDownloading = false
                    self?.isPaused = false
                    self?.job = nil
                    finish()
                }
            } catch {
                DispatchQueue.main.async {
                    self?.terminatingJobs.removeAll { $0 === process }
                    guard self?.generation == id else { return }
                    let wasFetching = self?.isFetching == true
                    self?.busy = false
                    self?.isFetching = false
                    self?.isDownloading = false
                    self?.isPaused = false
                    self?.job = nil
                    self?.progress = nil
                    self?.downloadProgress = nil
                    self?.phase = ""
                    if self?.inspectedURL == nil {
                        self?.info = nil
                        self?.thumbnailImage = nil
                    }
                    if error is CancellationError {
                        self?.error = nil
                    } else if wasFetching {
                        self?.error = VideoDownloaderStrings.fetchFailedNotice
                    } else {
                        self?.error = error.localizedDescription
                    }
                    if let self { self.dependencies = self.discover() }
                }
            }
        }
    }
}
