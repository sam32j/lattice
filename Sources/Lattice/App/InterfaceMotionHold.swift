// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// A motion drawn frame by frame against the clock, such as the Stay Awake
/// countdown sliding in, holds deferred background syncs until it has
/// finished. Its position comes from the time elapsed, so a sync that blocks
/// the main thread mid-motion freezes it and then lands it in one jump. Main
/// thread only.
enum InterfaceMotionHold {
    private static var heldUntil = Date.distantPast

    /// Holds deferred syncs for the next `duration` seconds.
    static func hold(for duration: TimeInterval) {
        heldUntil = max(heldUntil, Date().addingTimeInterval(duration))
    }

    /// Seconds left before held syncs may run; 0 once no motion holds them.
    static var remaining: TimeInterval {
        max(0, heldUntil.timeIntervalSinceNow)
    }
}
