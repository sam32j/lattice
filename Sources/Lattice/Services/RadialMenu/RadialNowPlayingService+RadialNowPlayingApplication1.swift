// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Foundation
import SwiftUI

/// A session-scoped view of macOS Now Playing. The read itself lives in the
/// bridge below, out of process; a failed run, a timeout and malformed
/// metadata all arrive here as an empty playback session.
/// Nothing here is required for the radial menu itself to work.
enum RadialNowPlayingApplication {
    static var icons: [String: NSImage] = [:]
    static var missingIcons = Set<String>()

    static func runningApplication(for snapshot: RadialNowPlayingSnapshot) -> NSRunningApplication? {
        if let bundleIdentifier = snapshot.appBundleIdentifier,
           let application = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier).first(where: { !$0.isTerminated }) {
            return application
        }
        if let pid = snapshot.appPID {
            return NSRunningApplication(processIdentifier: pid_t(pid))
        }
        return nil
    }

    static func name(for snapshot: RadialNowPlayingSnapshot) -> String? {
        if let name = runningApplication(for: snapshot)?.localizedName, !name.isEmpty { return name }
        guard let identifier = snapshot.appBundleIdentifier else { return nil }
        return identifier.split(separator: ".").last.map(String.init)
    }

    static func icon(for snapshot: RadialNowPlayingSnapshot) -> NSImage? {
        let key = snapshot.appBundleIdentifier ?? snapshot.appPID.map { "pid:\($0)" } ?? ""
        if let icon = icons[key] { return icon }
        if missingIcons.contains(key) { return nil }
        let icon: NSImage?
        if let runningIcon = runningApplication(for: snapshot)?.icon {
            icon = runningIcon
        } else if let identifier = snapshot.appBundleIdentifier,
                  let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            icon = nil
        }
        if let icon {
            icons[key] = icon
        } else {
            missingIcons.insert(key)
        }
        return icon
    }

    /// The island and the radial card are non-activating panels, so Lattice
    /// rarely holds activation when one is clicked. Since macOS 14 a bare
    /// request from an inactive app is refused, and the player stayed behind.
    static func open(_ snapshot: RadialNowPlayingSnapshot) {
        if let application = runningApplication(for: snapshot) {
            // A helper takes no activation; the handoff would leave Lattice in front.
            guard application.activationPolicy == .regular else { return }
            // Read before the unhide below: a hidden player's windows come back with it.
            let showsNoWindow = !application.isHidden && !hasWindowOnScreen(pid: application.processIdentifier)
            if application.isHidden { application.unhide() }
            ActivationHandoff.yield(to: application)
            if !application.activate(from: NSRunningApplication.current, options: [.activateAllWindows]) {
                application.activate(options: [.activateAllWindows])
            }
            // Like a Dock click, a player that keeps playing with its window
            // closed shows one again, the way the App Switcher reopens a
            // windowless app. Activation alone would leave nothing to see.
            if showsNoWindow, let url = application.bundleURL {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = false
                configuration.addsToRecentItems = false
                configuration.promptsUserIfNeeded = false
                NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            }
            return
        }
        guard let identifier = snapshot.appBundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Whether the player has a window on the current Space. One on another
    /// Space reads as none, and the reopen that follows is harmless there.
    static func hasWindowOnScreen(pid: pid_t) -> Bool {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                 kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.contains {
            ($0[kCGWindowOwnerPID as String] as? pid_t) == pid && ($0[kCGWindowLayer as String] as? Int) == 0
        }
    }
}

/// Reads Now Playing through `/usr/bin/perl` loading the adapter library
/// (`Sources/NowPlayingAdapter`). Since macOS 15.4 MediaRemote answers only
/// processes carrying Apple's signature; perl is one, the app is not. A
/// missing script or library, a failed run, a timeout and malformed output
/// all read as an empty playback session.
