// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// Tracks trackpad touch distances during 2-finger gesture events (NSEvent.EventType.gesture)
/// and translates them into continuous zoom scale factors for pinned screenshots.
final class ScreenshotPinPinchTracker {
    private var lastDistance: CGFloat?

    /// Translates raw 2-finger normalized touch coordinates into an incremental zoom factor.
    func update(p1: CGPoint, p2: CGPoint, active: Bool) -> CGFloat? {
        guard active else {
            lastDistance = nil
            return nil
        }
        let distance = hypot(p1.x - p2.x, p1.y - p2.y)
        guard distance > 0.005 else { return nil }

        defer { lastDistance = distance }

        guard let previous = lastDistance, previous > 0.005 else {
            return nil
        }

        let factor = distance / previous
        // Sanity limit on single-packet delta: ignore extreme jumps (e.g. finger swap)
        guard factor.isFinite, factor > 0.5, factor < 2.0, abs(factor - 1.0) > 0.0005 else {
            return nil
        }
        return factor
    }

    /// Extracts active touches from an NSEvent of type .gesture and computes the zoom factor.
    func process(event: NSEvent) -> CGFloat? {
        guard event.type == .gesture else { return nil }
        let touches = event.allTouches().filter { !$0.isResting && $0.phase != .ended && $0.phase != .cancelled }
        guard touches.count == 2 else {
            lastDistance = nil
            return nil
        }
        let t1 = touches[touches.startIndex]
        let t2 = touches[touches.index(after: touches.startIndex)]
        return update(p1: t1.normalizedPosition, p2: t2.normalizedPosition, active: true)
    }

    func reset() {
        lastDistance = nil
    }
}

/// AppKit can describe one pinch through both raw touches and magnify events.
/// The first stream with a usable delta owns the gesture until it ends.
struct ScreenshotPinGestureSource {
    enum Source { case touches, magnify }
    private var owner: Source?
    private var ended = false

    mutating func begin(_ source: Source) {
        if ended || owner == source {
            owner = nil
            ended = false
        }
    }

    mutating func accepts(_ source: Source) -> Bool {
        guard !ended else { return false }
        if owner == nil { owner = source }
        return owner == source
    }

    mutating func finish(_ source: Source) {
        if owner == source { ended = true }
    }
}
