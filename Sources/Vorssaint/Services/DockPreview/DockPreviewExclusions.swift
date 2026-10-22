// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
import AppKit
import Foundation

/// Dock Preview exclusions describe the owner of a Dock tile, never the app
/// currently in front. A listed app has no hover or pinned preview session.
enum DockPreviewExclusions {
    static func contains(bundleIdentifier: String?, in defaults: UserDefaults = .standard) -> Bool {
        guard let bundleIdentifier else { return false }
        return Defaults.sanitizedBundleIdentifierList(
            defaults.stringArray(forKey: DefaultsKey.windowPreviewExcludedApps) ?? [])
            .contains(bundleIdentifier)
    }

    static func contains(_ app: NSRunningApplication) -> Bool {
        contains(bundleIdentifier: app.bundleIdentifier)
    }

    static func contains(pid: pid_t) -> Bool {
        contains(bundleIdentifier: NSRunningApplication(processIdentifier: pid)?.bundleIdentifier)
    }
}
