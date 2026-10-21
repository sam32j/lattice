// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// A key nonactivating panel receives shortcuts, but does not necessarily own
/// the system cursor. Claim both main and key before activating so AppKit has
/// no reason to raise an unrelated editor. Never activate all windows.
final class ScreenshotCaptureFocusSession {
    struct ApplicationFocus {
        var isFrontmost: () -> Bool
        var activate: () -> Void
        var restore: () -> Bool

        static func current() -> Self {
            let previous = NSWorkspace.shared.frontmostApplication
            let ownPID = ProcessInfo.processInfo.processIdentifier
            return Self(isFrontmost: {
                NSWorkspace.shared.frontmostApplication?.processIdentifier == ownPID
            }, activate: {
                NSApp.activate(ignoringOtherApps: true)
            }, restore: {
                guard let previous, previous.processIdentifier != ownPID,
                      !previous.isTerminated else { return false }
                ActivationHandoff.yield(to: previous)
                return previous.activate(from: .current, options: [])
            })
        }
    }

    private let application: ApplicationFocus
    private let startedInApplication: Bool
    private weak var previousMain: NSWindow?
    private weak var previousKey: NSWindow?
    private weak var panel: ScreenshotCapturePanel?
    private var released = false

    init(application: ApplicationFocus = .current()) {
        self.application = application
        startedInApplication = application.isFrontmost()
        previousMain = NSApp.mainWindow
        previousKey = NSApp.keyWindow
    }

    func acquire(_ panel: ScreenshotCapturePanel) {
        guard !released else { return }
        self.panel?.ownsCaptureFocus = false
        self.panel = panel
        panel.ownsCaptureFocus = true
        panel.makeMain()
        panel.makeKeyAndOrderFront(nil)
        if !application.isFrontmost() { application.activate() }
    }

    /// Keep the inert capture surface up during handoff. Calling the outcome
    /// only afterwards prevents a late focus restore from stealing a new editor.
    func release(completion: @escaping () -> Void) {
        guard !released else { completion(); return }
        released = true
        guard panel != nil else { completion(); return }
        if !startedInApplication && application.isFrontmost() {
            if application.restore() {
                awaitRestoration(until: ProcessInfo.processInfo.systemUptime + 0.3,
                                 completion: completion)
                return
            }
            NSLog("Capture focus: original application could not accept activation")
        }
        finishRestoration(completion: completion)
    }

    private func awaitRestoration(until deadline: TimeInterval, completion: @escaping () -> Void) {
        guard application.isFrontmost(), ProcessInfo.processInfo.systemUptime < deadline else {
            if application.isFrontmost() {
                NSLog("Capture focus: application handoff timed out")
            }
            finishRestoration(completion: completion)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [self] in
            awaitRestoration(until: deadline, completion: completion)
        }
    }

    private func finishRestoration(completion: () -> Void) {
        panel?.resignMain()
        panel?.ownsCaptureFocus = false
        // Do not raise editors if activation failed or the previous app died.
        if startedInApplication || !application.isFrontmost() {
            previousMain?.makeMain()
            if startedInApplication && application.isFrontmost() { previousKey?.makeKey() }
        }
        completion()
    }
}
