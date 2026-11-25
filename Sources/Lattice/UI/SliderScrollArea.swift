// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Enabled level controls receive the wheel before an enclosing horizontal strip.
protocol SliderScrollTarget: AnyObject {
    var acceptsSliderScroll: Bool { get }
}

extension SliderScroll {
    mutating func handle(_ event: NSEvent, current: Double, range: ClosedRange<Double>) -> Outcome {
        let phase: Phase
        if !event.momentumPhase.isEmpty { phase = .momentum }
        else if event.phase.contains(.began) { phase = .began }
        else if !event.phase.intersection([.changed, .stationary]).isEmpty { phase = .changed }
        else if event.phase.isEmpty { phase = .none }
        else { phase = .ended }
        return handle(phase, dx: Double(event.scrollingDeltaX), dy: Double(event.scrollingDeltaY),
                      precise: event.hasPreciseScrollingDeltas, inverted: event.isDirectionInvertedFromDevice,
                      timestamp: event.timestamp, current: current, range: range)
    }

    /// A scroll the bar does not take goes on to the list around it.
    static func pass(_ event: NSEvent, from view: NSView) {
        if let scroll = view.enclosingScrollView { scroll.scrollWheel(with: event) }
        else { view.nextResponder?.scrollWheel(with: event) }
    }
}

/// Laid over a SwiftUI slider, it takes only scroll events; clicks and drags
/// reach the slider underneath.
struct SliderScrollArea: NSViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>
    /// A control with coarse steps, such as an on/off level, moves at least
    /// one step per wheel notch; a smaller notch would round back to where
    /// it was. Trackpad gestures keep accumulating finely.
    var step: Double = 0
    /// Told when a wheel or trackpad change begins and ends, as a native
    /// slider drag would be, so a control can keep what it held before.
    var onEditingChanged: ((Bool) -> Void)? = nil
    /// Sideways scrolling only, so a list of sliders scrolls past them.
    var horizontalOnly = false

    func makeNSView(context: Context) -> AreaView { AreaView() }

    func updateNSView(_ view: AreaView, context: Context) {
        view.area = self
        view.horizontalOnly = horizontalOnly
        view.isEnabled = context.environment.isEnabled
        if !view.isEnabled { view.endEditing() }
    }

    static func dismantleNSView(_ view: AreaView, coordinator: ()) {
        view.endEditing()
    }

    final class AreaView: NSView, SliderScrollTarget {
        var area: SliderScrollArea?
        var isEnabled = true
        var acceptsSliderScroll: Bool { isEnabled && area != nil }
        private var scroll = SliderScroll()
        private var editing = false
        var horizontalOnly = false { didSet { scroll.horizontalOnly = horizontalOnly } }

        /// Balanced: every begin gets one end, including on removal.
        func endEditing() { setEditing(false) }

        private func setEditing(_ on: Bool) {
            guard editing != on else { return }
            editing = on
            area?.onEditingChanged?(on)
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            if newWindow == nil { endEditing() }
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard NSApp.currentEvent?.type == .scrollWheel else { return nil }
            return super.hitTest(point)
        }

        override func scrollWheel(with event: NSEvent) {
            guard let area, isEnabled else {
                endEditing()
                return SliderScroll.pass(event, from: self)
            }
            let finishes = event.phase.contains(.ended) || event.phase.contains(.cancelled)
            switch scroll.handle(event, current: area.value, range: area.range) {
            case .pass:
                endEditing()
                SliderScroll.pass(event, from: self)
            case .hold:
                if finishes { endEditing() }
            case .move(let value):
                // A wheel notch is a whole edit; a trackpad gesture stays one
                // edit from its first change to its lift.
                setEditing(true)
                area.value = SliderScroll.wheelValue(value, from: area.value, step: area.step,
                                                     precise: event.hasPreciseScrollingDeltas, range: area.range)
                if !event.hasPreciseScrollingDeltas || finishes { endEditing() }
            }
        }
    }
}
