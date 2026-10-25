// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Keep thumb tracking independent of the snapped document value and palette bounds.
struct ScreenshotFontSizeSlider: NSViewRepresentable {
    @Binding var value: Int
    let title: String
    let onEditingChanged: (Bool) -> Void
    @Environment(\.isEnabled) private var isEnabled

    static func stepped(_ value: Double) -> Int {
        guard value.isFinite else { return ScreenshotSupport.defaultTextSize }
        return min(96, max(8, Int((min(96, max(8, value)) / 4).rounded()) * 4))
    }

    func makeNSView(context: Context) -> Control {
        let control = Control(value: Double(value), minValue: 8, maxValue: 96,
                              target: context.coordinator, action: #selector(Coordinator.changed(_:)))
        control.isContinuous = true
        control.numberOfTickMarks = 0
        control.focusRingType = .none
        control.refusesFirstResponder = true
        control.setAccessibilityLabel(title)
        control.onTrackingChanged = { [weak coordinator = context.coordinator, weak control] tracking in
            guard let coordinator else { return }
            coordinator.parent.onEditingChanged(tracking)
            if !tracking { control?.doubleValue = Double(coordinator.parent.value) }
        }
        control.onStep = { [weak coordinator = context.coordinator, weak control] direction in
            guard let coordinator, let control else { return }
            control.window?.makeFirstResponder(nil)
            coordinator.parent.value = min(96, max(8, coordinator.parent.value + direction * 4))
            control.doubleValue = Double(coordinator.parent.value)
        }
        return control
    }

    func updateNSView(_ control: Control, context: Context) {
        context.coordinator.parent = self
        control.isEnabled = isEnabled
        if !control.isTracking { control.doubleValue = Double(value) }
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject {
        var parent: ScreenshotFontSizeSlider
        init(_ parent: ScreenshotFontSizeSlider) { self.parent = parent }
        @objc func changed(_ sender: NSSlider) {
            if (sender as? Control)?.isTracking != true { sender.window?.makeFirstResponder(nil) }
            parent.value = ScreenshotFontSizeSlider.stepped(sender.doubleValue)
        }
    }
    final class Control: NSSlider {
        private(set) var isTracking = false
        var onTrackingChanged: ((Bool) -> Void)?
        var onStep: ((Int) -> Void)?
        override var acceptsFirstResponder: Bool { false }
        override var needsPanelToBecomeKey: Bool { false }
        func beginTracking() {
            window?.makeFirstResponder(nil)
            isTracking = true
            onTrackingChanged?(true)
        }
        func endTracking() { isTracking = false; onTrackingChanged?(false) }
        override func mouseDown(with event: NSEvent) {
            guard isEnabled, let trackingWindow = window, let cell = cell as? NSSliderCell else { return }
            beginTracking()
            defer { endTracking() }
            // NSSliderCell's tracking can cancel/reset outside its tracking area.
            // Own the gesture until mouse-up, in screen coordinates, so crossing
            // another window cannot reinterpret that window's local X as ours.
            let bar = cell.barRect(flipped: isFlipped)
            var knob = cell.knobRect(flipped: isFlipped)
            let lower = bar.minX + knob.width / 2
            let travel = bar.width - knob.width
            guard travel > 0 else { return }
            func point(_ event: NSEvent) -> CGPoint {
                let screen = event.window?.convertPoint(toScreen: event.locationInWindow) ?? event.locationInWindow
                return convert(trackingWindow.convertPoint(fromScreen: screen), from: nil)
            }
            let start = point(event)
            let center = lower + (doubleValue - minValue) / (maxValue - minValue) * travel
            // AppKit may report the previous frame's knob position after a
            // live value change. Use its native size, not that stale origin.
            knob.origin.x = center - knob.width / 2
            let offset = knob.contains(start) ? start.x - center : 0
            func update(_ event: NSEvent) {
                let fraction = min(1, max(0, (point(event).x - offset - lower) / travel))
                doubleValue = minValue + fraction * (maxValue - minValue)
                _ = sendAction(action, to: target)
            }
            if !knob.contains(start) { update(event) }
            while window === trackingWindow && trackingWindow.isVisible && isEnabled {
                guard let next = NSApp.nextEvent(matching: [.leftMouseDragged, .leftMouseUp, .keyDown, .appKitDefined],
                    until: Date().addingTimeInterval(0.1), inMode: .eventTracking, dequeue: true) else { continue }
                guard window === trackingWindow && trackingWindow.isVisible && isEnabled else { break }
                if next.type == .appKitDefined || next.type == .keyDown { NSApp.sendEvent(next); continue }
                update(next)
                if next.type == .leftMouseUp { break }
            }
        }
        override func accessibilityPerformIncrement() -> Bool {
            guard isEnabled else { return false }
            onStep?(1); return true
        }
        override func accessibilityPerformDecrement() -> Bool {
            guard isEnabled else { return false }
            onStep?(-1); return true
        }
    }
}
