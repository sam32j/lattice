// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

enum ScreenshotFontTextEditingTests {
    private final class Draft: ObservableObject {
        @Published var text = "Keep editing"
        @Published var size = 24
        var commits = 0
    }
    private struct Fixture: View {
        @ObservedObject var draft: Draft
        var body: some View {
            HStack {
                ScreenshotTextEditorTests.ScreenshotAnnotationTextEditor(text: $draft.text,
                    fontSize: CGFloat(draft.size), textColor: .black, isBounded: true, width: 200,
                    onCommit: { draft.commits += 1 }).frame(width: 200, height: 100)
                ScreenshotFontSizeControl(value: $draft.size, title: "Font size", onEditingChanged: { _ in })
            }
        }
    }
    private static func native<T: NSView>(_ view: NSView, as type: T.Type) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { native($0, as: type) }
    }
    private static func button(_ element: AnyObject) -> AnyObject? {
        if element.accessibilityRole?() == .button && element.accessibilityLabel?() == "Font size" { return element }
        return (element.accessibilityChildren?() ?? []).lazy.compactMap { button($0 as AnyObject) }.first
    }
    static func run(_ suite: TestSuite) {
        let getter = NSSelectorFromString("accessibilityAttributeValue:")
        let setter = NSSelectorFromString("accessibilitySetValue:forAttribute:")
        let previous = NSApp.perform(getter, with: "AXEnhancedUserInterface")?.takeUnretainedValue() as? NSNumber ?? false
        NSApp.perform(setter, with: true, with: "AXEnhancedUserInterface")
        defer { NSApp.perform(setter, with: previous, with: "AXEnhancedUserInterface") }
        let draft = Draft()
        let host = NSHostingView(rootView: Fixture(draft: draft))
        let window = NSWindow(contentRect: CGRect(x: -10000, y: -10000, width: 300, height: 150),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil); window.contentView = nil; window.close() }
        func settle() {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()
        }
        settle()
        guard let text = native(host, as: NSTextView.self).first,
              let trigger = button(host) else { suite.expect(false, "text and font control mount together"); return }
        window.makeFirstResponder(text)
        text.setSelectedRange(NSRange(location: 4, length: 0))
        _ = trigger.accessibilityPerformPress?()
        settle()
        let roots = (window.childWindows ?? []).compactMap(\.contentView)
            + NSApp.windows.filter { $0 !== window && $0.isVisible }.compactMap(\.contentView)
        guard let slider = roots.flatMap({ native($0, as: ScreenshotFontSizeSlider.Control.self) }).first else {
            suite.expect(false, "font adjustment opens alongside native annotation editing"); return
        }
        slider.beginTracking()
        slider.doubleValue = 44
        _ = slider.sendAction(slider.action, to: slider.target)
        settle()
        suite.expect(draft.size == 44 && text.font?.pointSize == 44 && text.string == "Keep editing",
                     "font dragging updates the active native text without losing its draft")
        suite.expect(text.isEditable && !text.isHidden && text.selectedRange() == NSRange(location: 4, length: 0)
                     && window.firstResponder === text && draft.commits == 0,
                     "font dragging leaves the inline editing session and insertion position intact")
        suite.expect(text.shouldDrawInsertionPoint,
                     "the inline insertion caret remains visible while the font popup is being adjusted")
        slider.endTracking()
        if let sliderWindow = slider.window, let cell = slider.cell as? NSSliderCell {
            let frame = sliderWindow.frame
            let knob = cell.knobRect(flipped: slider.isFlipped)
            let start = slider.convert(CGPoint(x: knob.midX, y: knob.midY), to: nil)
            let outside = CGPoint(x: start.x, y: start.y + 500)
            func pointer(_ type: NSEvent.EventType, _ location: CGPoint) -> NSEvent {
                NSEvent.mouseEvent(with: type, location: location, modifierFlags: [], timestamp: 0,
                    windowNumber: sliderWindow.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
            }
            NSApp.postEvent(pointer(.leftMouseUp, outside), atStart: true)
            NSApp.postEvent(pointer(.leftMouseDragged, outside), atStart: true)
            slider.mouseDown(with: pointer(.leftMouseDown, start))
            suite.expect(draft.size == 44 && sliderWindow.isVisible && sliderWindow.frame == frame
                         && window.firstResponder === text && !text.isHidden,
                         "tracking outside the native palette neither jumps to minimum nor dismisses the text edit")
        }
        if let field = roots.flatMap({ native($0, as: ScreenshotFontSizeField.Control.self) }).first {
            field.window?.makeKey()
            field.clicked = true
            field.window?.makeFirstResponder(field)
            field.currentEditor()?.selectAll(nil)
            for character in ["5", "2"] {
                if let keyWindow = field.window,
                   let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                    windowNumber: keyWindow.windowNumber, context: nil, characters: character,
                    charactersIgnoringModifiers: character, isARepeat: false, keyCode: 0) {
                    keyWindow.sendEvent(event)
                }
            }
            settle()
            suite.expect(draft.size == 52 && text.font?.pointSize == 52 && !text.isHidden
                         && text.selectedRange() == NSRange(location: 4, length: 0) && draft.commits == 0
                         && field.window?.firstResponder === field.currentEditor() && draft.text == "Keep editing",
                         "real numeric keystrokes update font size rather than the underlying annotation draft")
            field.window?.makeFirstResponder(nil)
        } else { suite.expect(false, "the font popup exposes direct numeric entry beside the active draft") }
        let paletteWindow = slider.window
        if let paletteWindow, let escape = NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: [], timestamp: 0, windowNumber: paletteWindow.windowNumber, context: nil,
            characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53) {
            NSApp.sendEvent(escape)
        }
        settle()
        suite.expect(paletteWindow?.isVisible == false && draft.commits == 0 && window.firstResponder === text,
                     "Escape closes only the font palette and returns to the still-active annotation")
    }
}
