// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit

/// The capture history's Clear confirmation, from the floating Hub and the
/// Island, when its owner closes while the confirmation is still pending.
/// Scenario adopted from upstream v3.4.3 (#3394); Lattice keeps its own native
/// deferred alert, so only the production presentation methods run here.
enum RecentCaptureClearConfirmationTests {
    final class Panel: NSPanel {
        var simulatedVisible = true
        override var isVisible: Bool { simulatedVisible }
        override func makeKey() {}
    }
    final class LatticeHubService {
        static let shared = LatticeHubService()
        var panel: NSPanel?
        var removed = 0, installed = 0
        func removeMonitors() { removed += 1 }
        func installMonitors(for panel: NSPanel) { installed += 1 }
    }
    final class NotchService {
        static let shared = NotchService()
        var presentationWindow: NSWindow?
        var confirmationDepth = 0
        func beginIslandConfirmation() { confirmationDepth += 1 }
        func endIslandConfirmation() { confirmationDepth -= 1 }
    }
    final class RecentCaptureService {
        struct CaptureDeletionResult { var succeeded = true }
        static let shared = RecentCaptureService()
        var entries = [1]
        var clears = 0
        func clearAndDeleteCaptureFiles(completion: @escaping (CaptureDeletionResult) -> Void) {
            clears += 1
            completion(CaptureDeletionResult())
        }
    }
    struct CaptureInterfaceStrings {
        let deleteRecentTitle = "Delete", deleteAll = "Delete All"
        let deleteRecentFailureTitle = "Failed", deleteRecentFailureBody = "Failed"
        static func localized(_ language: Int) -> CaptureInterfaceStrings { .init() }
    }
    enum L10n {
        struct Strings { let uninstallerCancel = "Cancel" }
        struct Localized { let language = 0; let s = Strings() }
        static let shared = Localized()
    }
    static var confirmations: [NSWindow] = []
    enum NotchIslandAlert {
        static func confirmDestructive(title: String, message: String, action: String,
                                       cancel: String, above owner: NSWindow) -> Bool {
            confirmations.append(owner)
            return true
        }
    }

    static func run(_ suite: TestSuite) {
        _ = NSApplication.shared
        func panel() -> Panel {
            let panel = Panel(contentRect: CGRect(x: -4000, y: -4000, width: 200, height: 120),
                              styleMask: [.borderless], backing: .buffered, defer: true)
            panel.isReleasedWhenClosed = false
            return panel
        }
        func drain() {
            let until = Date().addingTimeInterval(0.05)
            while Date() < until { RunLoop.main.run(mode: .default, before: until) }
        }
        let hub = LatticeHubService.shared, notch = NotchService.shared, captures = RecentCaptureService.shared

        let floating = panel()
        hub.panel = floating
        confirmations = []; captures.clears = 0; hub.removed = 0; hub.installed = 0
        Host.confirmClearAboveFloatingHUD()
        floating.simulatedVisible = false
        drain()
        suite.expect(confirmations.isEmpty && captures.clears == 0,
                     "a Hub that closes while Clear is pending takes the confirmation with it")
        suite.expect(hub.removed == 1 && hub.installed == 0,
                     "a closed Hub does not get its dismissal monitors back")

        floating.simulatedVisible = true
        confirmations = []; hub.removed = 0; hub.installed = 0
        Host.confirmClearAboveFloatingHUD()
        drain()
        suite.expect(confirmations.count == 1 && confirmations[0] === floating && captures.clears == 1
                     && hub.installed == 1,
                     "an open Hub still confirms above itself and restores its monitors")

        let island = panel()
        notch.presentationWindow = island
        confirmations = []; captures.clears = 0
        Host.confirmClearAboveIsland()
        island.simulatedVisible = false
        drain()
        suite.expect(confirmations.isEmpty && captures.clears == 0 && notch.confirmationDepth == 0,
                     "an Island that hides while Clear is pending drops it and releases its focus lease")
        island.simulatedVisible = true
        Host.confirmClearAboveIsland()
        drain()
        suite.expect(confirmations.count == 1 && confirmations[0] === island && notch.confirmationDepth == 0,
                     "a visible Island confirms once and releases its focus lease after")

        hub.panel = nil
        notch.presentationWindow = nil
        floating.simulatedVisible = false; island.simulatedVisible = false
        floating.close(); island.close()
    }
}
