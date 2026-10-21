// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum ScreenshotCanvasInputTests {
    static func run(_ suite: TestSuite) {
        var hovers = 0, exits = 0
        var began: CGPoint?, moved: CGPoint?, ended: CGPoint?
        var modifiers = NSEvent.ModifierFlags(), clicks = 0
        let input = ScreenshotCanvasInput.InputView(input: ScreenshotCanvasInput(
            began: { began = $0; modifiers = $1 }, moved: { moved = $0; modifiers = $1 },
            ended: { ended = $0; modifiers = $1; clicks = $2 },
            hovered: { if $0 != nil { hovers += 1 } else { exits += 1 } }))
        let root = NSView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        input.frame = root.bounds
        root.addSubview(input)
        let text = NSTextView(frame: CGRect(x: 20, y: 20, width: 100, height: 40))
        text.string = "Editing"
        root.addSubview(text)
        let window = NSWindow(contentRect: root.bounds, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = root
        defer { window.contentView = nil; window.close() }
        func event(_ type: NSEvent.EventType, at point: CGPoint, flags: NSEvent.ModifierFlags = []) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: point, modifierFlags: flags,
                timestamp: 0, windowNumber: window.windowNumber, context: nil,
                eventNumber: 0, clickCount: 2, pressure: 1)!
        }
        input.mouseMoved(with: event(.mouseMoved, at: CGPoint(x: 30, y: 30)))
        suite.expect(hovers == 0, "native text owns its cursor without canvas hover overriding the I-beam")
        input.mouseMoved(with: event(.mouseMoved, at: CGPoint(x: 200, y: 100)))
        suite.expect(hovers == 1, "the nonediting canvas still receives hover for selection and resize cursors")
        input.mouseExited(with: event(.mouseMoved, at: CGPoint(x: 200, y: 100)))
        suite.expect(exits == 0,
                     "an editor without key ownership cannot reset the cursor after capture takes focus")
        input.mouseDown(with: event(.leftMouseDown, at: CGPoint(x: 200, y: 100), flags: .command))
        suite.expect(began == CGPoint(x: 200, y: 100) && modifiers.contains(.command),
                     "canvas mouse-down forwards image-oriented coordinates and additive-selection modifiers immediately")
        input.mouseDragged(with: event(.leftMouseDragged, at: CGPoint(x: 230, y: 80), flags: .shift))
        input.mouseUp(with: event(.leftMouseUp, at: CGPoint(x: 230, y: 80), flags: .shift))
        suite.expect(moved == CGPoint(x: 230, y: 120) && ended == moved && modifiers.contains(.shift) && clicks == 2,
                     "canvas dragging and mouse-up retain the constraint modifier, flipped coordinates and double-click count")
    }
}
