// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Foundation

/// Static identity of the app, shared by UI, notifications and tooling.
enum AppInfo {
    static let name = DownstreamIdentity.name
    static let websiteURL = URL(string: "https://github.com/sam32j/lattice")!
    static let repositoryURL = websiteURL
    static let coffeeURL = URL(string: "https://buymeacoffee.com/vorssaint")!

    /// The current Lattice application icon (light/default).
    static var lightIcon: NSImage {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        let devURL = URL(fileURLWithPath: "Resources/Brand/Lattice.icns")
        if let image = NSImage(contentsOf: devURL) {
            return image
        }
        return NSApplication.shared.applicationIconImage
    }

    /// The current Lattice application icon in dark mode.
    static var darkIcon: NSImage {
        if let url = Bundle.main.url(forResource: "AppIcon-Dark", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        let devURL = URL(fileURLWithPath: "Resources/Brand/Lattice-Dark.icns")
        if let image = NSImage(contentsOf: devURL) {
            return image
        }
        return lightIcon
    }

    /// Whether the active appearance is currently dark.
    static var isDark: Bool {
        if let appearance = NSApp.appearance {
            return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        if let style = CFPreferencesCopyAppValue("AppleInterfaceStyle" as CFString, kCFPreferencesAnyApplication) as? String {
            return style.caseInsensitiveCompare("dark") == .orderedSame
        }
        return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    /// The icon for the specified appearance.
    static func icon(isDark: Bool) -> NSImage {
        isDark ? darkIcon : lightIcon
    }

    /// Default icon, dynamically matching the active appearance.
    static var icon: NSImage {
        icon(isDark: isDark)
    }

    /// The bundle version. The fallback only applies to the bare binary
    /// (e.g. `--selftest`), never the shipped app, which reads its Info.plist.
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    /// The upstream release version this downstream build is based upon.
    static var upstreamVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "LatticeUpstreamTag") as? String ?? "3.4.1"
    }

    /// True for the local "Lattice (Developer)" build (bundle id ends in `.dev`).
    /// It is never published and never auto-updates; all work is tested here first.
    static var isDeveloperBuild: Bool {
        (Bundle.main.bundleIdentifier ?? "").hasSuffix(".dev")
    }

    /// True when the current version is a pre-release (e.g. 3.3.4-beta.1 or 3.3.4-rc.1).
    static var isBeta: Bool {
        if isDeveloperBuild && UserDefaults.standard.bool(forKey: DefaultsKey.simulateBetaUI) {
            return true
        }
        let v = version.lowercased()
        return v.contains("-beta") || v.contains("-rc") || v.contains("-alpha")
    }

    /// The git commit a Developer build was compiled from, e.g. "ed2ebba · 2026-06-15 21:30"
    /// (or with a "-dirty" suffix on the SHA for uncommitted changes). build.sh stamps
    /// this into the Developer bundle only, so you can confirm at a glance that the
    /// running dev app matches the source you are about to change. nil in the official app.
    static var buildCommit: String? {
        Bundle.main.object(forInfoDictionaryKey: "LatticeBuildCommit") as? String
    }
}
