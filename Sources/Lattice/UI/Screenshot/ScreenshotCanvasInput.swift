// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Keep canvas input separate from NSTextView's native selection gestures.
/// A click outside the inline editor reaches this surface immediately, without
/// waiting for SwiftUI's competing single/double-click recognizers.
struct ScreenshotCanvasInput: NSViewRepresentable {
    let began: (CGPoint, NSEvent.ModifierFlags) -> Void
    let moved: (CGPoint, NSEvent.ModifierFlags) -> Void
    let ended: (CGPoint, NSEvent.ModifierFlags, Int) -> Void
    let hovered: (CGPoint?) -> Void

    func makeNSView(context: Context) -> InputView { InputView(input: self) }
    func updateNSView(_ view: InputView, context: Context) { view.input = self }

    final class InputView: NSView {
        var input: ScreenshotCanvasInput
        private var tracking: NSTrackingArea?
        init(input: ScreenshotCanvasInput) { self.input = input; super.init(frame: .zero) }
        required init?(coder: NSCoder) { nil }
        override var isFlipped: Bool { true }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) {
            input.began(convert(event.locationInWindow, from: nil), event.modifierFlags)
        }
        override func mouseDragged(with event: NSEvent) {
            input.moved(convert(event.locationInWindow, from: nil), event.modifierFlags)
        }
        override func mouseUp(with event: NSEvent) {
            input.ended(convert(event.locationInWindow, from: nil), event.modifierFlags, event.clickCount)
        }
        override func updateTrackingAreas() {
            if let tracking { removeTrackingArea(tracking) }
            let area = NSTrackingArea(rect: bounds,
                options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
                owner: self, userInfo: nil)
            addTrackingArea(area)
            tracking = area
            super.updateTrackingAreas()
        }
        override func mouseMoved(with event: NSEvent) {
            // Tracking areas overlap; the native text view owns its I-beam
            // even though the canvas underneath also receives mouse movement.
            if let content = window?.contentView,
               let text = content.hitTest(content.convert(event.locationInWindow, from: nil)) as? NSTextView,
               text.isEditable { return }
            input.hovered(convert(event.locationInWindow, from: nil))
        }
        override func mouseEntered(with event: NSEvent) { mouseMoved(with: event) }
        override func mouseExited(with event: NSEvent) {
            // A late exit from the editor must not override the crosshair of
            // a newly presented nonactivating capture panel.
            guard window?.isKeyWindow == true else { return }
            input.hovered(nil)
        }
    }
}
