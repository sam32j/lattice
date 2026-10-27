// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

extension VideoDownloader {
    func websiteSessionChanged(host: String? = nil) {
        guard !busy else { return }
        if let host, !host.isEmpty, VideoWebsiteSessions.host(link) != host {
            return
        }
        let draft = link
        resetDownloadState()
        link = draft
    }
}
