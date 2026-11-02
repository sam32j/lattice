import AppKit
import SwiftUI

/// Danger zone dialogs and assistant file panels share owner-relative placement without a backdrop dim.
enum PermissionDialogPresentation {
    /// Inset from the owning window's top frame, matching the placement of system permission request prompts.
    static let topInset: CGFloat = 150

    @discardableResult
    static func run(_ alert: NSAlert, over parent: NSWindow?,
                    runModal: (() -> NSApplication.ModalResponse)? = nil) -> NSApplication.ModalResponse {
        alert.layout()
        return run(alert.window, over: parent, runModal: runModal ?? alert.runModal)
    }

    @discardableResult
    static func run(_ dialog: NSWindow, over parent: NSWindow?,
                    runModal: (() -> NSApplication.ModalResponse)? = nil) -> NSApplication.ModalResponse {
        guard let parent else {
            return (runModal ?? {
                if let panel = dialog as? NSSavePanel { return panel.runModal() }
                return NSApp.runModal(for: dialog)
            })()
        }

        func place() {
            dialog.level = NSWindow.Level(rawValue: max(NSWindow.Level.modalPanel.rawValue, parent.level.rawValue + 1))
            let x = parent.frame.midX - dialog.frame.width / 2
            let y = max(parent.frame.minY + 20, parent.frame.maxY - dialog.frame.height - topInset)
            dialog.setFrameOrigin(NSPoint(x: x, y: y))
        }
        place()
        let notifications = NotificationCenter.default
        // Modal presentation may apply native placement while entering its modal loop.
        // Reapply the owner-relative placement before the newly key window is rendered.
        let observations = [
            (NSWindow.didBecomeKeyNotification, dialog),
            (NSWindow.didResizeNotification, dialog),
            (NSWindow.didMoveNotification, parent),
            (NSWindow.didResizeNotification, parent)
        ].map { name, window in
            notifications.addObserver(forName: name, object: window, queue: .main) { _ in place() }
        }
        defer {
            observations.forEach(notifications.removeObserver)
        }
        if let runModal {
            return runModal()
        } else if let panel = dialog as? NSSavePanel {
            return panel.runModal()
        } else {
            return NSApp.runModal(for: dialog)
        }
    }
}

final class PermissionDialogWindowReference {
    weak var window: NSWindow?
}

/// Tracks the window containing this row rather than guessing from another key panel.
struct PermissionDialogWindowReader: NSViewRepresentable {
    let reference: PermissionDialogWindowReference

    func makeNSView(context: Context) -> Probe { Probe(reference: reference) }
    func updateNSView(_ view: Probe, context: Context) { reference.window = view.window }

    final class Probe: NSView {
        let reference: PermissionDialogWindowReference
        init(reference: PermissionDialogWindowReference) {
            self.reference = reference
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            reference.window = window
        }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
