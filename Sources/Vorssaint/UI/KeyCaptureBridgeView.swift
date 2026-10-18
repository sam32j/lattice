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
