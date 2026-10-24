// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
import AppKit
import Foundation

/// Dock Preview exclusions describe the owner of a Dock tile, never the app
/// currently in front. A listed app has no hover or pinned preview session.
enum DockPreviewExclusions {
    static func contains(bundleIdentifier: String?,
                         executablePath: @autoclosure () -> String? = nil,
                         in defaults: UserDefaults = .standard) -> Bool {
        let list = Defaults.sanitizedBundleIdentifierList(
            defaults.stringArray(forKey: DefaultsKey.windowPreviewExcludedApps) ?? [])
        if let bundleIdentifier, list.contains(bundleIdentifier) { return true }
        guard list.contains(where: MouseAppExceptionSupport.isExecutablePathIdentity),
              let path = executablePath() else {
            return false
        }
        return MouseAppExceptionSupport.identities(
            bundleID: bundleIdentifier,
            executablePath: path,
            readsPath: true)
            .contains(where: list.contains)
    }

    static func contains(_ app: NSRunningApplication) -> Bool {
        contains(bundleIdentifier: app.bundleIdentifier, executablePath: app.executableURL?.path)
    }

    static func contains(pid: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return false }
        return contains(app)
    }
}
