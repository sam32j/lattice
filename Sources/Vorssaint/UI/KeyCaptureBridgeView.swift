// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

struct KeyCaptureBridgeView: NSViewRepresentable {
    var onKeyDown: (NSEvent) -> Void
    var onFlagsChanged: (NSEvent) -> Void
    var onExit: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onKeyDown: onKeyDown,
                    onFlagsChanged: onFlagsChanged,
                    onExit: onExit)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.install(view: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onKeyDown = onKeyDown
        context.coordinator.onFlagsChanged = onFlagsChanged
        context.coordinator.onExit = onExit
        context.coordinator.install(view: nsView)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.remove()
    }

    @MainActor
    final class Coordinator {
        private static weak var tapOwner: Coordinator?
        var onKeyDown: (NSEvent) -> Void
        var onFlagsChanged: (NSEvent) -> Void
        var onExit: (() -> Void)?
        private var keyMonitor: Any?
        private var clickMonitor: Any?

        init(onKeyDown: @escaping (NSEvent) -> Void,
             onFlagsChanged: @escaping (NSEvent) -> Void,
             onExit: (() -> Void)? = nil) {
            self.onKeyDown = onKeyDown
            self.onFlagsChanged = onFlagsChanged
            self.onExit = onExit
        }

        func install(view: NSView) {
            if keyMonitor == nil {
                if ShortcutRecordingTap.begin({ [weak self, weak view] keyCode, modifiers, rawFlags in
                    guard let self, Self.tapOwner === self,
                          let key = UInt16(exactly: keyCode) else { return }
                    var flags = NSEvent.ModifierFlags(rawValue: UInt(rawFlags.rawValue))
                    if modifiers.contains(.control) { flags.insert(.control) }
                    if modifiers.contains(.option) { flags.insert(.option) }
                    if modifiers.contains(.shift) { flags.insert(.shift) }
                    if modifiers.contains(.command) { flags.insert(.command) }
                    guard let event = NSEvent.keyEvent(
                        with: .keyDown, location: .zero, modifierFlags: flags,
                        timestamp: ProcessInfo.processInfo.systemUptime,
                        windowNumber: view?.window?.windowNumber ?? 0, context: nil,
                        characters: "", charactersIgnoringModifiers: "",
                        isARepeat: false, keyCode: key) else { return }
                    self.onKeyDown(event)
                }) {
                    Self.tapOwner = self
                }
                // Keep local events for modifier previews and as the fallback
                // when Accessibility is unavailable. A live tap swallows keys
                // before they can reach this monitor or other applications.
                keyMonitor = NSEvent.addLocalMonitorForEvents(
                    matching: [.keyDown, .flagsChanged]) { [weak self] event in
                        if event.type == .flagsChanged {
                            self?.onFlagsChanged(event)
                            return nil
                        }
                        if event.type == .keyDown {
                            self?.onKeyDown(event)
                            return nil
                        }
                        return event
                    }
            }
            if clickMonitor == nil, onExit != nil {
                clickMonitor = NSEvent.addLocalMonitorForEvents(
                    matching: [.leftMouseDown, .rightMouseDown]
                ) { [weak self, weak view] event in
                    guard let self, let onExit = self.onExit else { return event }
                    guard let view, let window = view.window else {
                        onExit()
                        return event
                    }
                    if event.window !== window {
                        onExit()
                        return event
                    }
                    let fieldFrame = view.convert(view.bounds, to: nil)
                    if !fieldFrame.contains(event.locationInWindow) { onExit() }
                    return event
                }
            }
        }

        func remove() {
            // SwiftUI can install a replacement before dismantling this view.
            // Only the current owner may release the shared recording tap.
            if Self.tapOwner === self {
                ShortcutRecordingTap.end()
                Self.tapOwner = nil
            }
            if let keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
                self.keyMonitor = nil
            }
            if let clickMonitor {
                NSEvent.removeMonitor(clickMonitor)
                self.clickMonitor = nil
            }
        }
    }
}
