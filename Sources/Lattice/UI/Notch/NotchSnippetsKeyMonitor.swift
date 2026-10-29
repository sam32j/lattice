// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// Intercepts arrow keys, Return, and ⌘1–9 before field editors consume them.
struct SnippetKeyMonitor: NSViewRepresentable {
    var handleKey: (UInt16, String, NSEvent.ModifierFlags, Bool, Bool) -> Bool
    var composed: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.install(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.handleKey = handleKey
        context.coordinator.composed = composed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(handleKey: handleKey, composed: composed)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator {
        var handleKey: (UInt16, String, NSEvent.ModifierFlags, Bool, Bool) -> Bool
        var composed: () -> Void
        private var monitor: Any?

        init(handleKey: @escaping (UInt16, String, NSEvent.ModifierFlags, Bool, Bool) -> Bool,
             composed: @escaping () -> Void) {
            self.handleKey = handleKey
            self.composed = composed
        }

        func install(for view: NSView) {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak view] event in
                guard let self, let window = view?.window, event.window === window else { return event }
                let editor = (window.firstResponder as? NSTextView).flatMap { $0.isFieldEditor ? $0 : nil }
                if editor == nil, window.firstResponder is NSTextView { return event }
                let composing = editor?.hasMarkedText() == true
                if self.handleKey(event.keyCode, event.characters ?? "", event.modifierFlags, composing, editor != nil) {
                    return nil
                }
                if let editor, !composing {
                    DispatchQueue.main.async { [weak self, weak editor] in
                        if editor?.hasMarkedText() == true { self?.composed() }
                    }
                }
                return event
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }
}
