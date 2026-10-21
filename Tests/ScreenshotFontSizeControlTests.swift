// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

enum ScreenshotFontSizeControlTests {
    private static func native<T: NSView>(_ root: NSView, as type: T.Type) -> [T] {
        (root as? T).map { [$0] } ?? root.subviews.flatMap { native($0, as: type) }
    }
    private static func elements(_ root: AnyObject, role: NSAccessibility.Role) -> [AnyObject] {
        var found: [AnyObject] = root.accessibilityRole?() == role ? [root] : []
        for child in root.accessibilityChildren?() ?? [] {
            found += elements(child as AnyObject, role: role)
        }
        return found
    }

    static func run(_ suite: TestSuite) {
        ScreenshotFontSizeDragTests.run(suite)
        _ = NSApplication.shared
        let getter = NSSelectorFromString("accessibilityAttributeValue:")
        let setter = NSSelectorFromString("accessibilitySetValue:forAttribute:")
        let previous = NSApp.perform(getter, with: "AXEnhancedUserInterface")?.takeUnretainedValue() as? NSNumber ?? false
        NSApp.perform(setter, with: true, with: "AXEnhancedUserInterface")
        defer { NSApp.perform(setter, with: previous, with: "AXEnhancedUserInterface") }
        var size = 24
        var tracking: [Bool] = []
        func root() -> some View {
            ScreenshotFontSizeControl(value: Binding(get: { size }, set: { size = $0 }), title: "Font size",
                                      onEditingChanged: { tracking.append($0) }).frame(width: 60, height: 60)
        }
        let host = NSHostingView(rootView: root())
        let panel = NSPanel(contentRect: CGRect(x: -10000, y: -10000, width: 60, height: 60),
                            styleMask: [.titled, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.contentView = host
        panel.orderFront(nil)
        defer { panel.orderOut(nil); panel.contentView = nil; panel.close() }
        func settle() {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
        settle()
        guard let button = elements(host, role: .button).first else {
            suite.expect(false, "font size is opened through an Aa button"); return
        }
        suite.expect(elements(host, role: .slider).isEmpty,
                     "the slim style rail contains no squeezed inline font-size slider")
        suite.expect(button.accessibilityLabel?() == "Font size", "the Aa button identifies its purpose")
        _ = button.accessibilityPerformPress?()
        settle()
        let slider = panel.childWindows?.compactMap(\.contentView)
            .flatMap { elements($0, role: .slider) }.first
            ?? NSApp.windows.filter { $0 !== panel && $0.isVisible }.compactMap(\.contentView)
                .flatMap { elements($0, role: .slider) }.first
        guard let slider else {
            suite.expect(false, "pressing Aa opens a slider in its popup"); return
        }
        let roots = (panel.childWindows ?? []).compactMap(\.contentView)
            + NSApp.windows.filter { $0 !== panel && $0.isVisible }.compactMap(\.contentView)
        let nativeSlider = roots.flatMap { native($0, as: ScreenshotFontSizeSlider.Control.self) }.first
        suite.expect((slider.accessibilityFrame?().width ?? 0) >= 140,
                     "the popup exposes a comfortably wide horizontal font-size slider")
        if let native = nativeSlider {
            suite.expect(native.minValue == 8 && native.maxValue == 96 && native.numberOfTickMarks == 0
                         && native.focusRingType == .none && !native.acceptsFirstResponder,
                         "font-size slider has the requested range, no tick underline and no keyboard focus")
        } else { suite.expect(false, "font size uses a continuous native slider") }
        _ = slider.accessibilityPerformIncrement?()
        settle()
        suite.expect(size == 28, "the popup slider changes font size live in increments of four")
        let field = panel.childWindows?.compactMap(\.contentView)
            .flatMap { elements($0, role: .textField) }.first
            ?? NSApp.windows.filter { $0 !== panel && $0.isVisible }.compactMap(\.contentView)
                .flatMap { elements($0, role: .textField) }.first
        suite.expect(field != nil, "clicking the numeric font size supports direct entry")
        if let native = nativeSlider {
            native.beginTracking()
            native.doubleValue = 35.5
            _ = native.sendAction(native.action, to: native.target)
            host.rootView = root()
            settle()
            suite.expect(size == 36 && native.doubleValue == 35.5,
                         "live document updates snap by four without pulling the thumb away from the pointer")
            native.endTracking()
            suite.expect(native.doubleValue == 36 && tracking.suffix(2) == [true, false],
                         "releasing the slider settles on its value and ends one undo gesture")
            native.window?.makeKey()
            let knob = (native.cell as? NSSliderCell)?.knobRect(flipped: native.isFlipped) ?? native.bounds
            let start = native.convert(CGPoint(x: knob.midX, y: knob.midY), to: nil)
            func pointer(_ type: NSEvent.EventType, _ location: CGPoint) -> NSEvent {
                NSEvent.mouseEvent(with: type, location: location, modifierFlags: [], timestamp: 0,
                    windowNumber: native.window!.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
            }
            let outside = CGPoint(x: start.x, y: start.y + 500)
            NSApp.postEvent(pointer(.leftMouseUp, outside), atStart: true)
            NSApp.postEvent(pointer(.leftMouseDragged, outside), atStart: true)
            native.mouseDown(with: pointer(.leftMouseDown, start))
            suite.expect(size == 36 && !native.isTracking,
                         "dragging vertically outside the font popup retains the horizontal slider value")
        }
        if let input = roots.flatMap({ native($0, as: ScreenshotFontSizeField.Control.self) }).first {
            suite.expect(input.alignment == .center,
                         "the editable font-size number is centered above its underline")
            suite.expect(!input.isBezeled && !input.isBordered && !input.acceptsFirstResponder && input.focusRingType == .none,
                         "the number input is unboxed and does not receive focus before a click")
            input.clicked = true
            _ = input.window?.makeFirstResponder(input)
            if let editor = input.currentEditor() {
                editor.string = "37"
                (editor as? NSTextView)?.didChangeText()
                suite.expect(size == 37, "direct numeric entry preserves exact sizes rather than snapping by four")
                if let native = nativeSlider {
                    _ = native.accessibilityPerformIncrement()
                    suite.expect(size == 41 && input.currentEditor() == nil,
                                 "accessibility stepping commits numeric input then adds exactly four without retaining stale text")
                    _ = input.window?.makeFirstResponder(nil)
                    suite.expect(size == 41, "ending old field focus cannot undo a slider change")
                    input.clicked = true
                    _ = input.window?.makeFirstResponder(input)
                    input.currentEditor()?.string = "35"
                    (input.currentEditor() as? NSTextView)?.didChangeText()
                    native.beginTracking()
                    native.doubleValue = 43
                    _ = native.sendAction(native.action, to: native.target)
                    native.endTracking()
                    _ = input.window?.makeFirstResponder(nil)
                    suite.expect(size == 44 && input.currentEditor() == nil,
                                 "dragging after numeric entry ends field editing and keeps the new slider value")
                }
                _ = input.window?.makeFirstResponder(nil)
                suite.expect(!input.acceptsFirstResponder, "ending number input restores click-only focus")
                input.clicked = true
                _ = input.window?.makeFirstResponder(input)
                input.currentEditor()?.string = "8"
                (input.currentEditor() as? NSTextView)?.didChangeText()
                suite.expect(size == 8 && ScreenshotSupport.sanitizedTextSize(size) == 8,
                             "the minimum typed size remains eight after preference sanitization")
                input.currentEditor()?.string = "999"
                _ = input.window?.makeFirstResponder(nil)
                suite.expect(size == 96 && input.stringValue == "96", "out-of-range numeric input commits at the supported limit")
            } else { suite.expect(false, "the number field becomes editable after being clicked") }
        }
        _ = button.accessibilityPerformPress?()
        settle()
    }
}
