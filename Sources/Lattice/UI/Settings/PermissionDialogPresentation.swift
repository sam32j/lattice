import AppKit
import SwiftUI

/// Danger zone dialogs share owner-relative placement without a backdrop dim.
enum PermissionDialogPresentation {
    static func run(_ alert: NSAlert, over parent: NSWindow?,
                    runModal: (() -> NSApplication.ModalResponse)? = nil) -> NSApplication.ModalResponse {
        guard let parent else { return (runModal ?? alert.runModal)() }
        alert.layout()
        let dialog = alert.window

        func center() {
            dialog.level = NSWindow.Level(rawValue: max(NSWindow.Level.modalPanel.rawValue, parent.level.rawValue + 1))
            dialog.setFrameOrigin(NSPoint(x: parent.frame.midX - dialog.frame.width / 2,
                                          y: parent.frame.midY - dialog.frame.height / 2))
        }
        center()
        let notifications = NotificationCenter.default
        // NSAlert may apply native placement while entering its modal loop.
        // Reapply the same center before the newly key window is rendered.
        let observations = [
            (NSWindow.didBecomeKeyNotification, dialog),
            (NSWindow.didResizeNotification, dialog),
            (NSWindow.didMoveNotification, parent),
            (NSWindow.didResizeNotification, parent)
        ].map { name, window in
            notifications.addObserver(forName: name, object: window, queue: .main) { _ in center() }
        }
        defer {
            observations.forEach(notifications.removeObserver)
        }
        return (runModal ?? alert.runModal)()
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
