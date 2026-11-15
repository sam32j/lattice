// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit

/// The AppKit side of Quit Apps, shared by Kill Process's Apps view and the
/// Command Bar: who is running, which app is in front, and the quit itself.
enum QuitAppsActions {
    static func runningCandidates() -> [QuitAppsCandidate] {
        NSWorkspace.shared.runningApplications.map { app in
            QuitAppsCandidate(pid: app.processIdentifier,
                              name: app.localizedName ?? app.bundleIdentifier ?? "",
                              bundleIdentifier: app.bundleIdentifier,
                              activationPolicyRawValue: app.activationPolicy.rawValue,
                              isTerminated: app.isTerminated)
        }
    }

    /// The app whose window is frontmost, other than Lattice. While Settings
    /// or the Hub is in front, that is the app the person was working in.
    static func frontAppPID() -> Int32? {
        let own = ProcessInfo.processInfo.processIdentifier
        if let front = NSWorkspace.shared.frontmostApplication,
           front.processIdentifier != own, front.activationPolicy == .regular {
            return front.processIdentifier
        }
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                 kCGNullWindowID) as? [[String: Any]] ?? []
        for window in windows {
            guard (window[kCGWindowLayer as String] as? Int) == 0,
                  let pid = window[kCGWindowOwnerPID as String] as? Int32, pid != own,
                  NSRunningApplication(processIdentifier: pid)?.activationPolicy == .regular
            else { continue }
            return pid
        }
        return nil
    }

    /// Sends a normal quit request, so an app can still ask about unsaved work,
    /// to each confirmed app that is still running and still a target.
    static func quit(confirmed pids: Set<Int32>, exceptions: Set<String>) {
        let still = QuitAppsSupport.batchQuitTargets(
            runningCandidates().filter { pids.contains($0.pid) },
            exceptions: exceptions, keepingPID: nil)
        for target in still {
            NSRunningApplication(processIdentifier: target.pid)?.terminate()
        }
    }
}
