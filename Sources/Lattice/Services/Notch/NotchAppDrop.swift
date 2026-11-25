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
        // Only an app the uninstaller accepts: a system app, a helper inside
        // another app or Lattice itself offers no zone at all.
        case "app" where AppFeature.uninstaller.isAvailable && Self.canUninstall(url): self = .uninstall(url)
        default: return nil
        }
    }

    static func canUninstall(_ url: URL) -> Bool {
        if case .success = UninstallerSupport.evaluate(url) { return true }
        return false
    }

    var isInstall: Bool {
        if case .install = self { return true }
        return false
    }
}
