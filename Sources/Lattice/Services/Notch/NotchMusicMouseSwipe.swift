// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/// Magic Mouse supplies phased scrolls rather than NSTouch contacts. Deltas
/// identify the axis/direction. Native tracking supplies completion when enabled;
/// otherwise a scroll-point threshold is used, never a claimed physical distance.
struct NotchMusicMouseSwipe {
    private(set) var tracking = false
    private(set) var direction: NotchMusicTrackSwipe.Direction?
    private(set) var progress = 0.0
    private var began = false
    private var trackpadSequence = false
    var excludesTrackpadSequence: Bool { trackpadSequence }
    private var vertical = false
    private var x = 0.0
    private var y = 0.0

    mutating func wheel(x dx: Double, y dy: Double, phase: NSEvent.Phase, precise: Bool,
                        momentum: Bool, enabled: Bool, hasTouches: Bool) -> NotchMusicTrackSwipe.Direction? {
        guard enabled, precise, !momentum, !hasTouches, dx.isFinite, dy.isFinite else { cancel(); return nil }
        if phase.contains(.mayBegin) { cancel(); trackpadSequence = true; return nil }
        if !phase.isDisjoint(with: [.ended, .cancelled]) { cancel(); return nil }
        if phase.contains(.began) {
            let trackpad = trackpadSequence
            self = Self(); began = true; trackpadSequence = trackpad
        }
        // A Magic Mouse can move into this view while its finger is still down.
        if !began, phase.contains(.changed) { began = true }
        guard began, !trackpadSequence, !vertical, !tracking,
              !phase.isDisjoint(with: [.began, .changed]) else { return nil }
        x += dx; y += dy
        if abs(y) >= 2 && abs(y) > abs(x) { vertical = true; return nil }
        guard x != 0, abs(x) > abs(y) else { return nil }
        // AppKit already applies natural scrolling. Do not invert again.
        direction = x < 0 ? .next : .previous
        tracking = true
        return direction
    }

    mutating func native(amount: Double, phase: NSEvent.Phase, complete: Bool) -> NotchMusicTrackSwipe.Direction? {
        guard tracking else { return nil }
        guard amount.isFinite, !phase.contains(.cancelled) else { cancel(); return nil }
        progress = min(abs(amount), 1)
        // AppKit defines ended as a successful physical swipe. Commit on lift;
        // isComplete is animation teardown, not another navigation decision.
        if phase.contains(.ended) {
            let result = direction
            cancel()
            return result
        }
        if complete { cancel() }
        return nil
    }

    mutating func fallback(x dx: Double, y dy: Double, phase: NSEvent.Phase, precise: Bool,
                          momentum: Bool) -> (handled: Bool, action: NotchMusicTrackSwipe.Direction?) {
        let wasTracking = tracking
        guard precise, !momentum, dx.isFinite, dy.isFinite,
              !phase.isEmpty, !phase.contains(.cancelled) else {
            cancel(); return (wasTracking, nil)
        }
        if phase.contains(.mayBegin) { cancel(); trackpadSequence = true; return (false, nil) }
        if phase.contains(.began) {
            let trackpad = trackpadSequence
            self = Self(); began = true; trackpadSequence = trackpad
        }
        // A Magic Mouse can move into this view while its finger is still down.
        if !began, phase.contains(.changed) { began = true }
        guard began, !trackpadSequence, !vertical else {
            if phase.contains(.ended) { cancel() }
            return (wasTracking, nil)
        }
        x += dx; y += dy
        if abs(y) >= 2 && abs(y) > abs(x) {
            vertical = true; tracking = false; progress = 0
        } else {
            tracking = abs(x) >= 2 && abs(x) > abs(y)
            direction = x == 0 ? nil : (x < 0 ? .next : .previous)
            // Scroll points are preference-adjusted movement, not trackpad inches.
            progress = tracking ? min(abs(x) / 80, 1) : 0
        }
        let handled = wasTracking || tracking
        if phase.contains(.ended) {
            let action = tracking && progress >= 1 ? direction : nil
            cancel()
            return (handled, action)
        }
        return (handled, nil)
    }

    mutating func cancel() { self = Self() }
}
