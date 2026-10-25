// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/// Magic Mouse supplies phased scrolls rather than NSTouch contacts. Deltas
/// identify the axis/direction only; macOS decides whether the swipe completes.
struct NotchMusicMouseSwipe {
    private(set) var tracking = false
    private(set) var direction: NotchMusicTrackSwipe.Direction?
    private(set) var progress = 0.0
    private var began = false
    private var trackpadSequence = false
    private var vertical = false
    private var x = 0.0
    private var y = 0.0

    mutating func wheel(x dx: Double, y dy: Double, phase: NSEvent.Phase, precise: Bool,
                        momentum: Bool, enabled: Bool, hasTouches: Bool) -> NotchMusicTrackSwipe.Direction? {
        guard enabled, precise, !momentum, !hasTouches, dx.isFinite, dy.isFinite else { cancel(); return nil }
        if phase.contains(.mayBegin) { cancel(); trackpadSequence = true; return nil }
        if !phase.intersection([.ended, .cancelled]).isEmpty { cancel(); return nil }
        if phase.contains(.began) {
            let trackpad = trackpadSequence
            self = Self(); began = true; trackpadSequence = trackpad
        }
        guard began, !trackpadSequence, !vertical, !tracking,
              !phase.intersection([.began, .changed]).isEmpty else { return nil }
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
        if phase.contains(.ended) {
            let result = direction
            cancel()
            return result
        }
        if complete { cancel() }
        return nil
    }

    mutating func cancel() { self = Self() }
}
