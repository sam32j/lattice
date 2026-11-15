// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// Native gestures shared by pinned screenshot content and its window tests.
class ScreenshotPinGestureView: NSView {
    private var lastZoomFrame: CGRect?
    private var zoomCenter: CGPoint?
    private var logicalZoomWidth: CGFloat = 0
    var isPositionLocked: Bool { false }
    var pinOpacity: CGFloat {
        get { window?.alphaValue ?? 1 }
        set { window?.alphaValue = newValue }
    }
    func didZoom() {}
    /// Whether this view's pin is the one under the pointer. Overlapping pins
    /// share screen space, so a wheel, pinch or touch AppKit hands to a pin
    /// lower in the stack must not zoom it too.
    var ownsPointer: Bool { true }

    override func scrollWheel(with event: NSEvent) {
        guard let window, !window.ignoresMouseEvents, event.momentumPhase.isEmpty, ownsPointer else { return }
        var delta = event.scrollingDeltaY
        if !event.hasPreciseScrollingDeltas, let native = event.cgEvent {
            delta = ScreenshotSupport.captureLoupeWheelDelta(
                scrollingDelta: delta,
                lineDelta: native.getIntegerValueField(.scrollWheelEventDeltaAxis1),
                fixedPointDelta: native.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1))
        }
        guard delta.isFinite, delta != 0 else { return }
        let preciseDelta = min(24, max(-24, delta))
        if event.modifierFlags.contains(.option) {
            let change = event.hasPreciseScrollingDeltas ? preciseDelta * 0.005 : (delta > 0 ? 0.05 : -0.05)
            let next = min(1, max(0.1, pinOpacity + change))
            if next != pinOpacity { pinOpacity = next }
            return
        }
        let factor = event.hasPreciseScrollingDeltas ? 1 + preciseDelta * 0.014 : (delta > 0 ? 1.03 : 1 / 1.03)
        zoom(by: factor)
    }

    private let pinchTracker = ScreenshotPinPinchTracker()
    private var pinchSource = ScreenshotPinGestureSource()

    override var acceptsTouchEvents: Bool {
        get { true }
        set {}
    }
    override var allowedTouchTypes: NSTouch.TouchTypeMask {
        get { [.indirect, .direct] }
        set {}
    }

    func resetGestureTracking() {
        pinchTracker.reset()
        pinchSource = ScreenshotPinGestureSource()
    }

    func handleGestureEvent(_ event: NSEvent, at point: CGPoint? = nil) {
        guard let window, !window.ignoresMouseEvents, !isPositionLocked else { return }
        guard !event.modifierFlags.contains(.option) else {
            pinchTracker.reset()
            pinchSource = ScreenshotPinGestureSource()
            return
        }
        if event.type == .gesture {
            let touches = event.allTouches()
            let phase: NSEvent.Phase = touches.allSatisfy { $0.phase == .ended || $0.phase == .cancelled }
                ? .ended : touches.contains { $0.phase == .began } ? .began : .changed
            applyPinch(by: pinchTracker.process(event: event) ?? 1, at: point ?? event.locationInWindow,
                       source: .touches, phase: phase)
        } else if event.type == .magnify {
            applyMagnify(event, at: point ?? event.locationInWindow)
        }
    }

    override func touchesBegan(with event: NSEvent) { if ownsPointer { handleGestureEvent(event) } }
    override func touchesMoved(with event: NSEvent) { if ownsPointer { handleGestureEvent(event) } }
    override func touchesEnded(with event: NSEvent) { pinchTracker.reset(); pinchSource.finish(.touches) }
    override func touchesCancelled(with event: NSEvent) { pinchTracker.reset(); pinchSource.finish(.touches) }

    override func magnify(with event: NSEvent) {
        guard ownsPointer else { return }
        applyMagnify(event, at: event.locationInWindow)
    }

    private func applyMagnify(_ event: NSEvent, at point: CGPoint) {
        guard !event.modifierFlags.contains(.option) else {
            pinchTracker.reset()
            pinchSource = ScreenshotPinGestureSource()
            return
        }
        // Some AppKit magnify deliveries have no phase at all. They must be
        // able to begin after a phased gesture has ended.
        if event.phase.isEmpty { pinchSource.begin(.magnify) }
        applyPinch(by: 1 + event.magnification, at: point,
                   source: .magnify, phase: event.phase)
    }

    func applyPinch(by factor: CGFloat, at point: CGPoint,
                    source: ScreenshotPinGestureSource.Source, phase: NSEvent.Phase) {
        guard let window, !window.ignoresMouseEvents, !isPositionLocked else { return }
        let isEnding = phase.contains(.ended) || phase.contains(.cancelled)
        if phase.contains(.began) { pinchSource.begin(source) }
        defer {
            if isEnding { pinchSource.finish(source) }
        }
        guard !isEnding, factor.isFinite, factor > 0, factor != 1, pinchSource.accepts(source) else { return }
        zoom(by: factor)
    }

    /// Zoom keeps the pin's center where it is, so a pin never moved by hand
    /// sits at the same place at every scale and zooming back to 1x returns
    /// it to exactly where it was. The center is kept exactly, not re-read
    /// from AppKit's whole-point frames, so rounding cannot walk it away;
    /// only a move that did not come from zooming takes a new one. `point`
    /// is accepted for older callers and ignored.
    func zoom(by factor: CGFloat, at point: CGPoint? = nil) {
        guard !isPositionLocked, let window, factor.isFinite, factor > 0, factor != 1 else { return }
        let frame = window.frame
        guard frame.width > 0, frame.height > 0 else { return }
        if lastZoomFrame != frame || zoomCenter == nil {
            // First zoom, or the pin was dragged or nudged since the last one.
            zoomCenter = CGPoint(x: frame.midX, y: frame.midY)
            logicalZoomWidth = frame.width
        }
        guard let center = zoomCenter, center.x.isFinite, center.y.isFinite else { return }
        let baseWidth = logicalZoomWidth > 0 ? logicalZoomWidth : frame.width
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) ?? window.screen
        else { return }
        let limits = screen.visibleFrame
        let aspect = window.contentAspectRatio
        guard aspect.width > 0, aspect.height > 0 else { return }
        // Bounds in terms of the logical width; the height always follows
        // the image ratio so small packets cannot accumulate skew.
        let ratio = aspect.height / aspect.width
        let minimumWidth = max(window.minSize.width, window.minSize.height / ratio)
        let maximumWidth = min(limits.width, limits.height / ratio)
        guard maximumWidth > 0 else { return }
        // A very elongated image may not fit both its minimum and the display;
        // keep it reachable on screen in that case.
        let width = min(max(baseWidth * factor, min(minimumWidth, maximumWidth)), maximumWidth)
        let height = min(limits.height, width * ratio)
        // Centered on the kept center; only a pin that would leave the
        // screen is held inside it, without changing the kept center.
        let next = CGRect(x: min(max(center.x - width / 2, limits.minX), limits.maxX - width),
                          y: min(max(center.y - height / 2, limits.minY), limits.maxY - height),
                          width: width, height: height)
        if next != frame { window.setFrame(next, display: true) }
        logicalZoomWidth = width
        lastZoomFrame = window.frame
        if window.frame != frame { didZoom() }
    }
}
