// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// Opens a question above the island without attaching a sheet that moves and
/// reskins its borderless surface. The island gets the keyboard back afterwards.
enum NotchIslandAlert {
    /// The Island and floating Hub are non-activating panels. A confirmation
    /// must keep the native alert key until it has returned, not just raise it
    /// once at presentation time.
    private final class FocusLease {
        var active = true
        var restoreQueued = false
        var initialWindowUpdateHandled = false
    }

    static func run(_ alert: NSAlert, above island: NSWindow?, lockFocus: Bool = false) -> NSApplication.ModalResponse {
        var observers: [NSObjectProtocol] = []
        let focusLease = FocusLease()
        if let island, island.isVisible {
            // AppKit resets the modal level when it activates the app or makes
            // the alert key. Raise it once running and after each reset.
            let level = NSWindow.Level(rawValue: island.level.rawValue + 1)
            let raise: (Notification) -> Void = { _ in alert.window.level = level }
            observers = [NSWindow.didBecomeKeyNotification, NSApplication.didBecomeActiveNotification].map {
                NotificationCenter.default.addObserver(forName: $0, object: nil, queue: .main, using: raise)
            }
            DispatchQueue.main.async { [weak alert, weak focusLease] in
                guard focusLease?.active == true else { return }
                alert?.window.level = level
            }
            if lockFocus {
                // Observe *all* windows becoming key, not only the source
                // panel. The Island can briefly hand key status to an AppKit
                // child or another Lattice window during a deferred alert.
                // Coalesce handoffs and never reclaim after the modal ends.
                let reclaimFocus: () -> Void = { [weak alert, weak focusLease] in
                    guard let lease = focusLease, lease.active,
                          !lease.restoreQueued, let alert,
                          alert.window.isVisible, !alert.window.isKeyWindow else { return }
                    lease.restoreQueued = true
                    DispatchQueue.main.async { [weak alert, weak focusLease] in
                        guard let lease = focusLease else { return }
                        lease.restoreQueued = false
                        guard lease.active, let alert, alert.window.isVisible,
                              !alert.window.isKeyWindow else { return }
                        NSApp.activate(ignoringOtherApps: true)
                        alert.window.makeKeyAndOrderFront(nil)
                    }
                }
                observers.append(NotificationCenter.default.addObserver(
                    forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main
                ) { [weak alert] notification in
                    guard (notification.object as? NSWindow) !== alert?.window else { return }
                    reclaimFocus()
                })
                observers.append(NotificationCenter.default.addObserver(
                    forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
                ) { _ in reclaimFocus() })
                // The first scheduled makeKey can run before NSAlert.runModal()
                // has made its window visible. Retry once when AppKit updates
                // the now-visible alert, rather than losing that initial focus
                // attempt until some unrelated window changes key status.
                observers.append(NotificationCenter.default.addObserver(
                    forName: NSWindow.didUpdateNotification, object: alert.window, queue: .main
                ) { [weak alert, weak focusLease] _ in
                    guard let lease = focusLease, lease.active,
                          !lease.initialWindowUpdateHandled,
                          alert?.window.isVisible == true else { return }
                    lease.initialWindowUpdateHandled = true
                    reclaimFocus()
                })
            }
        }
        // The island is non-activating, so bring the alert's *window* forward
        // once AppKit has entered the modal loop. Do not make the destructive
        // button first responder: AppKit's guarded destructive-button styling
        // can leave that control visually blank until it is clicked. Keeping
        // NSAlert's native responder chain also preserves Return and Escape via
        // the key equivalents assigned by the caller.
        alert.layout()
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { [weak alert, weak focusLease] in
            guard focusLease?.active == true,
                  let alert, alert.window.isVisible else { return }
            NSApp.activate(ignoringOtherApps: true)
            alert.window.makeKeyAndOrderFront(nil)
        }
        let response = alert.runModal()
        // Cancel queued focus reclamations BEFORE restoring the source's key
        // status, otherwise an old callback can steal focus back afterward.
        focusLease.active = false
        observers.forEach(NotificationCenter.default.removeObserver)
        // A collapsed island declines key status, so only an open one takes it.
        if let island, island.isVisible { island.makeKey() }
        return response
    }
}


// MARK: - Native destructive confirmation from the Dynamic Island

extension NotchIslandAlert {
    /// The same native alert for Island and floating Hub destructive actions.
    /// Cancel occupies the default slot and the red destructive action the
    /// second slot, avoiding the invisible default-destructive-button bug.
    /// Return is explicitly routed to Delete while this alert is key.
    static func confirmDestructive(title: String, message: String, action: String,
                                   cancel: String, above owner: NSWindow?) -> Bool {
        if let owner, !owner.isVisible { return false }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message

        // The Cancel button occupies the default slot. The *second* button
        // receives AppKit's real destructive styling (rather than manually
        // tinting a default button, which broke rendering on macOS).
        let cancelButton = alert.addButton(withTitle: cancel)
        cancelButton.keyEquivalent = "\u{1b}"
        let deleteButton = alert.addButton(withTitle: action)
        deleteButton.hasDestructiveAction = true
        deleteButton.keyEquivalent = ""

        // Because the red action is deliberately non-default, handle Return
        // explicitly, but only when this exact native alert is key. Escape
        // follows the standard Cancel action. Both use the real NSAlert buttons.
        let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak alert] event in
            guard let alert, alert.window.isKeyWindow,
                  event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty
            else { return event }
            switch event.keyCode {
            case 36, 76: // Return and keypad Enter
                deleteButton.performClick(nil)
                return nil
            case 53: // Escape
                cancelButton.performClick(nil)
                return nil
            default:
                return event
            }
        }
        defer { if let keyMonitor { NSEvent.removeMonitor(keyMonitor) } }

        // The shared presenter activates and raises this NSAlert above the
        // non-activating Island, then restores focus to the still-visible
        // Island after either response. The caller holds collapse protection.
        return run(alert, above: owner, lockFocus: true) == .alertSecondButtonReturn
    }
}
