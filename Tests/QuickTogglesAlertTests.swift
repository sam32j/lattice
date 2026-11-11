// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// Exercises the production Trash dispatch with explicit Island/HUD origins.
/// Source contracts cover the native alert presenter, which cannot be rendered
/// by the headless test target; appearance/key focus still require a Mac.
enum QuickTogglesAlertTests {
    enum Action { case emptyTrash }
    enum RunState { case running }
    class Fixture {
        var available = true
        var states: [Action: RunState] = [:]
        var trashConfirmationPending = false
        var confirmations = 0
        func emptyTrashConfirmed() { confirmations += 1 }
    }
    enum FeatureStrings {
        struct Strings {
            let emptyTrashConfirmTitle = "Empty Trash?"
            let emptyTrashConfirmMessage = "Trash will be cleared. This action cannot be undone."
            let emptyTrashConfirmButton = "Empty Trash"
        }
        static func quickToggles(_ language: Int) -> Strings { Strings() }
    }
    enum L10n {
        struct Strings { let uninstallerCancel = "Cancel" }
        struct Localized { let language = 0; let s = Strings() }
        static let shared = Localized()
    }
    final class NotchService {
        static let shared = NotchService()
        var presentationWindow: NSWindow?
        var confirmationDepth = 0
        func beginIslandConfirmation() { confirmationDepth += 1 }
        func endIslandConfirmation() { confirmationDepth -= 1 }
    }
    final class LatticeHubService {
        static let shared = LatticeHubService()
        var panel: NSPanel?
        var removed = 0
        var installed = 0
        func removeMonitors() { removed += 1 }
        func installMonitors(for panel: NSPanel) { installed += 1 }
    }
    static var confirmCalls: [NSWindow?] = []
    static var response = NSApplication.ModalResponse.alertSecondButtonReturn
    static func confirmDestructiveFixture(title: String, message: String, action: String,
                                          cancel: String, above owner: NSWindow?) -> Bool {
        confirmCalls.append(owner)
        if let owner, owner.isVisible { owner.makeKey() }
        return response == .alertSecondButtonReturn
    }
    final class Window: NSWindow {
        var simulatedVisible = true
        var keyReturns = 0
        override var isVisible: Bool { simulatedVisible }
        override func makeKey() { keyReturns += 1 }
    }
    final class FloatingPanel: NSPanel {
        var simulatedVisible = true
        var keyReturns = 0
        override var isVisible: Bool { simulatedVisible }
        override func makeKey() { keyReturns += 1 }
    }

    static func run(_ suite: TestSuite) {
        _ = NSApplication.shared
        let island = Window(contentRect: CGRect(x: -4000, y: -4000, width: 200, height: 80),
                            styleMask: [.borderless], backing: .buffered, defer: true)
        let floating = FloatingPanel(contentRect: CGRect(x: -4000, y: -4000, width: 280, height: 180),
                                     styleMask: [.borderless], backing: .buffered, defer: true)
        island.isReleasedWhenClosed = false
        floating.isReleasedWhenClosed = false
        let notch = NotchService.shared
        let hub = LatticeHubService.shared
        notch.presentationWindow = island
        hub.panel = floating
        defer {
            notch.presentationWindow = nil
            hub.panel = nil
            island.simulatedVisible = false
            floating.simulatedVisible = false
            island.close()
            floating.close()
        }

        for answer in [NSApplication.ModalResponse.alertSecondButtonReturn, .alertFirstButtonReturn, .abort] {
            response = answer
            hub.removed = 0
            hub.installed = 0
            confirmCalls = []
            let fromNotch = Host()
            fromNotch.emptyTrash(fromNotch: true)
            suite.expect(confirmCalls.isEmpty && notch.confirmationDepth == 1
                         && fromNotch.trashConfirmationPending,
                         "Island confirmation protects the panel before the click handler returns")
            // A rapid second click cannot queue a second destructive prompt.
            fromNotch.emptyTrash(fromNotch: true)
            let islandDeadline = Date().addingTimeInterval(0.3)
            while confirmCalls.isEmpty && Date() < islandDeadline {
                RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
            }
            suite.expect(confirmCalls.count == 1 && confirmCalls[0] === island,
                         "Empty Trash presents one native dialog on the NEXT main-loop turn")
            suite.expect(notch.confirmationDepth == 0 && island.keyReturns > 0
                         && !fromNotch.trashConfirmationPending,
                         "Island focus and collapse protection end on every modal response")
            suite.expect(hub.removed == 0 && hub.installed == 0,
                         "an Island confirmation does not modify floating-HUD monitors")
            suite.expect(fromNotch.confirmations == (answer == .alertSecondButtonReturn ? 1 : 0),
                         "only the native destructive second button performs Empty Trash")

            confirmCalls = []
            let fromHUD = Host()
            fromHUD.emptyTrash(fromNotch: false)
            suite.expect(confirmCalls.isEmpty && hub.removed > 0 && fromHUD.trashConfirmationPending,
                         "the floating HUD is protected before showing the native modal")
            let hudDeadline = Date().addingTimeInterval(0.3)
            while confirmCalls.isEmpty && Date() < hudDeadline {
                RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
            }
            suite.expect(confirmCalls.count == 1 && confirmCalls[0] === floating,
                         "Empty Trash from the HUD uses the same deferred native presenter")
            suite.expect(hub.removed == hub.installed && floating.keyReturns > 0
                         && !fromHUD.trashConfirmationPending,
                         "floating HUD retains visibility and restores monitors after the modal")
            suite.expect(fromHUD.confirmations == (answer == .alertSecondButtonReturn ? 1 : 0),
                         "Cancel or alert abort never empties Trash from the floating HUD")
        }
        let confirmationSource = (try? String(contentsOfFile:
            "Sources/Lattice/UI/Notch/NotchIslandAlert.swift", encoding: .utf8)) ?? ""
        let trashSource = (try? String(contentsOfFile:
            "Sources/Lattice/Services/QuickTools/QuickTogglesService.swift", encoding: .utf8)) ?? ""
        let recentSource = (try? String(contentsOfFile:
            "Sources/Lattice/UI/MenuPanel/PanelRecentCapturesView.swift", encoding: .utf8)) ?? ""
        let notchSource = (try? String(contentsOfFile:
            "Sources/Lattice/Services/Notch/NotchService.swift", encoding: .utf8)) ?? ""
        let panelSource = (try? String(contentsOfFile:
            "Sources/Lattice/Services/Notch/NotchWindowHost.swift", encoding: .utf8)) ?? ""
        suite.expect(confirmationSource.contains("let alert = NSAlert()")
                     && confirmationSource.contains("let cancelButton = alert.addButton(withTitle: cancel)")
                     && confirmationSource.contains("let deleteButton = alert.addButton(withTitle: action)")
                     && confirmationSource.contains("deleteButton.hasDestructiveAction = true")
                     && confirmationSource.contains("deleteButton.performClick(nil)")
                     && confirmationSource.contains("cancelButton.performClick(nil)")
                     && confirmationSource.contains("run(alert, above: owner, lockFocus: true)"),
                     "both destructive actions use the same native Cancel-first red action and Return/Esc routing")
        suite.expect(confirmationSource.contains("focusLease.active = false")
                     && confirmationSource.contains("forName: NSWindow.didBecomeKeyNotification, object: nil")
                     && confirmationSource.contains("restoreQueued")
                     && confirmationSource.contains("NSWindow.didUpdateNotification")
                     && notchSource.contains("guard self.islandConfirmationDepth == 0 else { return event }")
                     && notchSource.contains("guard self.islandConfirmationDepth == 0 else { return }")
                     && notchSource.contains("guard islandConfirmationDepth == 0 else { return false }")
                     && panelSource.contains("acceptsKeyFocus && !blocksKeyDuringConfirmation")
                     && notchSource.contains("panel?.blocksKeyDuringConfirmation = true")
                     && notchSource.contains("panel?.blocksKeyDuringConfirmation = false")
                     && recentSource.contains("above: island")
                     && recentSource.contains("islandClearConfirmationPending"),
                     "Island cannot reclaim native modal focus through touches, scroll or frame updates; the history modal retains its owner")
        suite.expect(!trashSource.contains("destructive.bezelColor")
                     && !recentSource.contains("delete.bezelColor")
                     && recentSource.contains("confirmDestructiveAboveFloatingHUD(")
                     && recentSource.contains("hub.removeMonitors()\n        DispatchQueue.main.async")
                     && recentSource.contains("NotchIslandAlert.confirmDestructive(")
                     && trashSource.contains("trashConfirmationPending = true\n        DispatchQueue.main.async"),
                     "no manual red button bezel remains; both Island and floating-HUD confirmations share the presenter")
        let unavailable = Host()
        unavailable.available = false
        confirmCalls = []
        unavailable.emptyTrash(fromNotch: true)
        suite.expect(confirmCalls.isEmpty && unavailable.confirmations == 0,
                     "feature gating still prevents Empty Trash when unavailable")
    }
}
