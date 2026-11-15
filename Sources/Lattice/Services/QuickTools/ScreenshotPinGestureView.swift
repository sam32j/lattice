// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// Native gestures shared by pinned screenshot content and its window tests.
class ScreenshotPinGestureView: NSView {
    private var lastZoomFrame: CGRect?
    private var zoomCenter: CGPoint?
    private var logicalZoomWidth: CGFloat = 0
    /// The width relative zoom builds on. Past a size limit it runs a little
    /// beyond the limit, so the small reversals a trackpad pinch reports
    /// while held there are absorbed instead of nudging the pin off the
    /// limit and back.
    private var requestedZoomWidth: CGFloat = 0
    private static let limitSlack: CGFloat = 0.04
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
    /// A trackpad scroll stays with the pin it began on until the fingers
    /// lift, even after the pin shrinks out from under the pointer.
    func ownsScroll(_ event: NSEvent) -> Bool { ownsPointer }

    override func scrollWheel(with event: NSEvent) {
        guard let window, !window.ignoresMouseEvents, event.momentumPhase.isEmpty, ownsScroll(event) else { return }
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
        guard factor.isFinite, factor > 0, factor != 1, let baseWidth = prepareZoom() else { return }
        setZoomTarget(width: baseWidth * factor, relative: true)
    }

    /// An absolute size, such as a fixed Zoom menu choice. It is measured
    /// against nothing in flight, so a glide toward another size cannot skew it.
    func zoom(toWidth width: CGFloat) {
        guard width.isFinite, width > 0, prepareZoom() != nil else { return }
        setZoomTarget(width: width, relative: false)
    }

    /// The logical width zoom builds on, after taking a new center when the
    /// pin was moved by anything but zooming.
    private func prepareZoom() -> CGFloat? {
        guard !isPositionLocked, let window else { return nil }
        let frame = window.frame
        guard frame.width > 0, frame.height > 0 else { return nil }
        if lastZoomFrame != frame || zoomCenter == nil {
            // First zoom, or the pin was dragged or nudged since the last one.
            stopZoomGlide()
            zoomCenter = CGPoint(x: frame.midX, y: frame.midY)
            logicalZoomWidth = frame.width
            requestedZoomWidth = frame.width
            lastZoomFrame = frame
        }
        return requestedZoomWidth > 0 ? requestedZoomWidth : frame.width
    }

    private func setZoomTarget(width requested: CGFloat, relative: Bool) {
        guard let window, let geometry = zoomGeometry(for: window) else { return }
        let frame = window.frame
        // A very elongated image may not fit both its minimum and the display;
        // keep it reachable on screen in that case.
        let lower = min(geometry.minimumWidth, geometry.maximumWidth)
        let upper = geometry.maximumWidth
        let target = min(max(requested, lower), upper)
        requestedZoomWidth = relative
            ? min(max(requested, lower / (1 + Self.limitSlack)), upper * (1 + Self.limitSlack))
            : target
        // Held at a limit, nothing changes until the request comes back inside.
        guard target != logicalZoomWidth || zoomGlideTimer != nil || frame.width != target else { return }
        logicalZoomWidth = target
        guard glidesZoom else {
            applyZoom(width: target, in: window)
            return
        }
        // Each packet moves the target; the drawn size eases toward it frame by
        // frame, so a wheel notch or a burst of pinch packets reads as one
        // continuous resize rather than a series of jumps.
        if zoomGlideTimer == nil {
            presentedZoomWidth = frame.width
            lastZoomGlideFrame = ProcessInfo.processInfo.systemUptime
            let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in self?.advanceZoomGlide() }
            RunLoop.main.add(timer, forMode: .common)
            zoomGlideTimer = timer
        }
    }

    /// Production pins glide; the unit harness checks each packet directly.
    var glidesZoom: Bool { false }
    private var zoomGlideTimer: Timer?
    private var presentedZoomWidth: CGFloat = 0
    private var lastZoomGlideFrame: TimeInterval = 0
    private static let zoomGlideTimeConstant: TimeInterval = 0.05

    private func advanceZoomGlide() {
        guard let window, !isPositionLocked, window.frame == lastZoomFrame || lastZoomFrame == nil else {
            // Something else moved or resized the pin, or it was locked; it
            // owns the frame now.
            stopZoomGlide()
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = max(0, now - lastZoomGlideFrame)
        lastZoomGlideFrame = now
        let target = logicalZoomWidth
        var next = presentedZoomWidth + (target - presentedZoomWidth)
            * CGFloat(1 - exp(-elapsed / Self.zoomGlideTimeConstant))
        let settled = abs(target - next) < 0.25
        if settled { next = target }
        presentedZoomWidth = next
        applyZoom(width: next, in: window)
        if settled { stopZoomGlide() }
    }

    private func stopZoomGlide() {
        zoomGlideTimer?.invalidate()
        zoomGlideTimer = nil
    }

    // The run loop retains a repeating timer; every release path stops it.
    deinit { zoomGlideTimer?.invalidate() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { stopZoomGlide() }
    }

    private func zoomGeometry(for window: NSWindow)
        -> (limits: CGRect, ratio: CGFloat, minimumWidth: CGFloat, maximumWidth: CGFloat)? {
        guard let center = zoomCenter, center.x.isFinite, center.y.isFinite,
              let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) ?? window.screen
        else { return nil }
        let limits = screen.visibleFrame
        let aspect = window.contentAspectRatio
        guard aspect.width > 0, aspect.height > 0 else { return nil }
        // Bounds in terms of the logical width; the height always follows
        // the image ratio so small packets cannot accumulate skew.
        let ratio = aspect.height / aspect.width
        let minimumWidth = max(window.minSize.width, window.minSize.height / ratio)
        let maximumWidth = min(limits.width, limits.height / ratio)
        guard maximumWidth > 0 else { return nil }
        return (limits, ratio, minimumWidth, maximumWidth)
    }

    /// Lays the pin out at `width` around the kept center on whole pixels:
    /// the center sits on a pixel and each side grows by the same whole
    /// number of pixels, so neither edge takes the rounding alone and the
    /// image cannot wobble from side to side as it scales.
    private func applyZoom(width rawWidth: CGFloat, in window: NSWindow) {
        guard let center = zoomCenter, let geometry = zoomGeometry(for: window) else { return }
        let frame = window.frame
        let scale = max(1, window.backingScaleFactor)
        func pixels(_ value: CGFloat) -> CGFloat { (value * scale).rounded() / scale }
        func halfPixels(_ value: CGFloat) -> CGFloat { (value * scale / 2).rounded() / scale }
        let halfWidth = halfPixels(min(rawWidth, geometry.limits.width))
        let halfHeight = halfPixels(min(geometry.limits.height, rawWidth * geometry.ratio))
        let cx = pixels(center.x), cy = pixels(center.y)
        let limits = geometry.limits
        // Only a pin that would leave the screen is held inside it, without
        // changing the kept center.
        let next = CGRect(x: min(max(cx - halfWidth, limits.minX), limits.maxX - halfWidth * 2),
                          y: min(max(cy - halfHeight, limits.minY), limits.maxY - halfHeight * 2),
                          width: halfWidth * 2, height: halfHeight * 2)
        if next != frame { window.setFrame(next, display: true) }
        lastZoomFrame = window.frame
        if window.frame != frame { didZoom() }
    }
}
