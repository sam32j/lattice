// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

enum ScreenshotFontSizeDragTests {
    private static func slider(in view: NSView) -> ScreenshotFontSizeSlider.Control? {
        (view as? ScreenshotFontSizeSlider.Control) ?? view.subviews.lazy.compactMap { slider(in: $0) }.first
    }

    static func run(_ suite: TestSuite) {
        var size = 8
        var changes: [Int] = []
        var tracking: [Bool] = []
        let host = NSHostingView(rootView: ScreenshotFontSizeSlider(
            value: Binding(get: { size }, set: { size = $0; changes.append($0) }), title: "Font size",
            onEditingChanged: { tracking.append($0) }).frame(width: 200, height: 20))
        let panel = ScreenshotFontSizePalette.Panel(contentRect: CGRect(x: -10000, y: -10000, width: 228, height: 78),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.contentView = host
        panel.orderFront(nil)
        let other = NSPanel(contentRect: CGRect(x: -11000, y: -11000, width: 300, height: 300),
            styleMask: [.borderless], backing: .buffered, defer: false)
        other.isReleasedWhenClosed = false
        defer { panel.orderOut(nil); panel.close(); other.close() }
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        guard let control = slider(in: host), let cell = control.cell as? NSSliderCell else {
            suite.expect(false, "font slider mounts for native pointer tracking"); return
        }
        panel.makeKey()
        func event(_ type: NSEvent.EventType, at point: CGPoint, in window: NSWindow?) -> NSEvent {
            let screen = panel.convertPoint(toScreen: control.convert(point, to: nil))
            return NSEvent.mouseEvent(with: type, location: window?.convertPoint(fromScreen: screen) ?? screen,
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window?.windowNumber ?? 0, context: nil,
                eventNumber: 0, clickCount: 1, pressure: 1)!
        }
        for destination: NSWindow? in [panel, other, nil] {
            size = 8
            control.doubleValue = 8
            changes.removeAll(); tracking.removeAll()
            let knob = cell.knobRect(flipped: control.isFlipped)
            let start = CGPoint(x: cell.barRect(flipped: control.isFlipped).minX + knob.width / 2, y: knob.midY)
            let middle = CGPoint(x: control.bounds.midX, y: knob.midY)
            let outside = CGPoint(x: middle.x, y: middle.y + 500)
            let events = [event(.leftMouseDragged, at: middle, in: panel),
                          event(.leftMouseDragged, at: outside, in: destination),
                          event(.leftMouseUp, at: outside, in: destination)]
            for event in events.reversed() { NSApp.postEvent(event, atStart: true) }
            control.mouseDown(with: event(.leftMouseDown, at: start, in: panel))
            suite.expect(size == 52 && changes.contains(52) && changes.last == 52,
                         "outside font dragging preserves the new value (size \(size), changes \(changes))")
            suite.expect(tracking == [true, false] && !control.isTracking,
                         "outside mouse-up ends exactly one font gesture without leaving tracking stuck")
        }
        size = 8; control.doubleValue = 8; changes.removeAll(); tracking.removeAll()
        let knob = cell.knobRect(flipped: control.isFlipped)
        let middle = CGPoint(x: control.bounds.midX, y: knob.midY)
        let farRight = CGPoint(x: control.bounds.maxX + 500, y: knob.midY + 500)
        let farLeft = CGPoint(x: control.bounds.minX - 500, y: knob.midY - 500)
        let returnPath = [event(.leftMouseDragged, at: farRight, in: other),
                          event(.leftMouseDragged, at: farLeft, in: nil),
                          event(.leftMouseDragged, at: middle, in: panel),
                          event(.leftMouseUp, at: middle, in: panel)]
        for event in returnPath.reversed() { NSApp.postEvent(event, atStart: true) }
        control.mouseDown(with: event(.leftMouseDown,
            at: CGPoint(x: cell.barRect(flipped: control.isFlipped).minX + knob.width / 2, y: knob.midY), in: panel))
        suite.expect(changes == [96, 8, 52, 52] && size == 52,
                     "horizontal overshoot clamps and re-entry follows the pointer (changes \(changes))")

        size = 44; control.doubleValue = 44; changes.removeAll(); tracking.removeAll()
        let activeKnob = cell.knobRect(flipped: control.isFlipped)
        let bar = cell.barRect(flipped: control.isFlipped)
        // 44 is 36/88 of the way along the supported 8...96 range.
        let grab = CGPoint(x: bar.minX + activeKnob.width
            + (bar.width - activeKnob.width) * (36.0 / 88.0) - 1, y: activeKnob.midY)
        let above = CGPoint(x: grab.x, y: grab.y + 500)
        for queued in [event(.leftMouseUp, at: above, in: other), event(.leftMouseDragged, at: above, in: other)] {
            NSApp.postEvent(queued, atStart: true)
        }
        control.mouseDown(with: event(.leftMouseDown, at: grab, in: panel))
        suite.expect(size == 44 && changes.allSatisfy { $0 == 44 },
                     "grabbing the thumb edge preserves its value (size \(size), changes \(changes))")

        var closedDuringTracking = false
        let escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                closedDuringTracking = control.isTracking
                panel.orderOut(nil)
                return nil
            }
            return event
        }
        defer { if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) } }
        let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: panel.windowNumber, context: nil, characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53)!
        // Backup mouse-up keeps a broken implementation from hanging the test.
        NSApp.postEvent(event(.leftMouseUp, at: middle, in: panel), atStart: true)
        NSApp.postEvent(escape, atStart: true)
        control.mouseDown(with: event(.leftMouseDown, at: middle, in: panel))
        suite.expect(closedDuringTracking && !panel.isVisible && !control.isTracking,
                     "Escape dismisses the palette during tracking without waiting for mouse-up")
        _ = NSApp.nextEvent(matching: [.leftMouseUp, .keyDown], until: Date(), inMode: .default, dequeue: true)
    }
}
