// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// A single disk image or app dragged onto the island, which it offers to
/// install or uninstall beside the Shelf.
enum NotchAppDrop: Equatable {
    case install(URL)
    case uninstall(URL)

    init?(urls: [URL]) {
        guard urls.count == 1, let url = urls.first, url.isFileURL else { return nil }
        switch url.pathExtension.lowercased() {
        case "dmg" where AppFeature.diskImageInstaller.isAvailable: self = .install(url)
        case "app" where AppFeature.uninstaller.isAvailable: self = .uninstall(url)
        default: return nil
        }
    }

    var isInstall: Bool {
        if case .install = self { return true }
        return false
    }
}
