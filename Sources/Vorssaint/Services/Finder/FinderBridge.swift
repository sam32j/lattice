// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Shared Finder selection for Shelf and Command Bar. Call off the main thread
/// so a slow Finder cannot block UI. Consent remains attributed to Lattice.
enum FinderBridge {
    private static let finderBundleID = "com.apple.finder"

    static func selectionURLs(requestPermission: Bool = true) -> [URL] {
        let allowed = requestPermission
            ? AppleScriptRunner.consentToAutomate(bundleID: finderBundleID)
            : Permissions.automationStatus(for: .finder) == .granted
        guard allowed else { return [] }
        let script = """
        tell application "Finder"
            set out to ""
            repeat with f in (get selection)
                set out to out & (POSIX path of (f as alias)) & (character id 0)
            end repeat
            return out
        end tell
        """
        let result = AppleScriptRunner.run(script)
        guard result.ok else { return [] }
        return result.output.split(separator: "\0")
            .map { String($0) }
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0) }
    }
}
