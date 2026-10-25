// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

#if LATTICE_DEVELOPMENT
import AppKit

/// Exercises the real canvas and native text view, rather than model-only edits.
enum CaptureEditorTextInteractionProbe {
    static func run(model: ScreenshotEditorModel, window: NSWindow, host: NSView) -> [String] {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        var failures: [String] = []
        func settle() {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            host.layoutSubtreeIfNeeded()
        }
        func textView(_ view: NSView) -> NSTextView? {
            if let text = view as? NSTextView, !text.isFieldEditor { return text }
            return view.subviews.lazy.compactMap(textView).first
        }
        func click(_ point: CGPoint, count: Int = 1) {
            func event(_ type: NSEvent.EventType) -> NSEvent? {
                NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, eventNumber: 0, clickCount: count, pressure: 1)
            }
            guard let down = event(.leftMouseDown), let up = event(.leftMouseUp) else { return }
            // Native text selection consumes mouse-up inside mouseDown's tracking loop.
            let selectingText = host.hitTest(host.convert(point, from: nil)) is NSTextView
            if selectingText { NSApp.postEvent(up, atStart: true) }
            window.sendEvent(down)
            if !selectingText { window.sendEvent(up) }
            settle()
        }
        guard let mark = model.annotations.first(where: { $0.tool == .text }) else { return ["no text fixture"] }
        model.editText(at: CGPoint(x: mark.rect.midX, y: mark.rect.midY))
        settle()
        guard let initial = textView(host) else { return ["no initial native editor"] }
        let inside = initial.convert(CGPoint(x: 8, y: 8), to: nil)
        let outside = CGPoint(x: inside.x, y: inside.y - 100)
        for attempt in 0..<3 {
            click(outside)
            if model.editingTextID != nil { failures.append("outside canvas click did not dismiss text immediately (\(attempt))") }
            click(inside)
            click(inside, count: 2)
            let current = textView(host)
            if model.editingTextID != mark.id || current?.isEditable != true || current?.isHidden != false
                || current?.string != mark.text {
                failures.append("rapid canvas double-click failed to reopen visible text (\(attempt))")
            }
        }
        if let index = model.annotations.firstIndex(where: { $0.id == mark.id }) {
            let area = CGRect(x: 100, y: 100, width: 200, height: 300)
            model.annotations[index].isBounded = true
            model.annotations[index].rect = area
            for size in [96, 8, 32] {
                model.textSize = size
                settle()
                let view = textView(host)
                let height = view?.enclosingScrollView?.frame.height ?? 0
                if model.annotations[index].rect != area || abs(height - 300 * model.currentDisplayZoom) > 0.1 {
                    failures.append("font size \(size) changed the bounded native text area")
                }
            }
            model.selectedID = nil
            model.textSize = mark.textSize
            model.annotations[index] = mark
        }
        model.editingTextID = nil
        settle()
        model.selectedID = mark.id
        let shift = CGPoint(x: 20 * model.currentDisplayZoom, y: 10 * model.currentDisplayZoom)
        let destination = CGPoint(x: inside.x + shift.x, y: inside.y - shift.y)
        for (type, location) in [(NSEvent.EventType.leftMouseDown, inside), (.leftMouseDragged, destination), (.leftMouseUp, destination)] {
            if let event = NSEvent.mouseEvent(with: type, location: location, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1) { window.sendEvent(event) }
        }
        settle()
        if let moved = model.annotations.first(where: { $0.id == mark.id }),
           abs(moved.rect.minX - mark.rect.minX - 20) > 0.1 || abs(moved.rect.minY - mark.rect.minY - 10) > 0.1 {
            failures.append("native canvas dragging did not move the selected text by the pointer distance")
        }
        model.annotations = model.annotations.map { $0.id == mark.id ? mark : $0 }
        return failures
    }
}
#endif
