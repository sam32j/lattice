// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

enum NotchMusicMouseSwipeTests {
    static func run(_ suite: TestSuite) {
        for (delta, expected) in [(-8.0, NotchMusicTrackSwipe.Direction.next), (8.0, .previous)] {
            var gesture = NotchMusicMouseSwipe()
            _ = gesture.wheel(x: 0, y: 0, phase: .began, precise: true, momentum: false, enabled: true, hasTouches: false)
            let start = gesture.wheel(x: delta, y: 0, phase: .changed, precise: true, momentum: false, enabled: true, hasTouches: false)
            suite.expect(start == expected && gesture.tracking, "phase-based Magic Mouse swipes keep AppKit's preference-adjusted direction")
            suite.expect(gesture.native(amount: 0.6, phase: .changed, complete: false) == nil && gesture.progress == 0.6,
                         "native progress holds the cue without changing tracks before finger lift")
            suite.expect(gesture.native(amount: 0.6, phase: .ended, complete: false) == expected
                         && gesture.native(amount: 1, phase: .ended, complete: true) == nil,
                         "only the native accepted end changes a track, exactly once")
        }
        var cancelled = NotchMusicMouseSwipe()
        _ = cancelled.wheel(x: 0, y: 0, phase: .began, precise: true, momentum: false, enabled: true, hasTouches: false)
        _ = cancelled.wheel(x: -8, y: 0, phase: .changed, precise: true, momentum: false, enabled: true, hasTouches: false)
        suite.expect(cancelled.native(amount: 0.1, phase: .cancelled, complete: false) == nil && !cancelled.tracking,
                     "native cancellation clears the cue and never skips a track")
        var trackpad = NotchMusicMouseSwipe()
        _ = trackpad.wheel(x: 0, y: 0, phase: .mayBegin, precise: true, momentum: false, enabled: true, hasTouches: false)
        _ = trackpad.wheel(x: 0, y: 0, phase: .began, precise: true, momentum: false, enabled: true, hasTouches: false)
        suite.expect(trackpad.wheel(x: -8, y: 0, phase: .changed, precise: true, momentum: false, enabled: true, hasTouches: false) == nil,
                     "trackpad may-begin sequences stay on the measured physical-contact path")
        for (precise, momentum, enabled, touches) in [(false, false, true, false), (true, true, true, false),
                                                    (true, false, false, false), (true, false, true, true)] {
            var rejected = NotchMusicMouseSwipe()
            _ = rejected.wheel(x: 0, y: 0, phase: .began, precise: precise, momentum: momentum, enabled: enabled, hasTouches: touches)
            suite.expect(rejected.wheel(x: -10, y: 0, phase: .changed, precise: precise, momentum: momentum, enabled: enabled, hasTouches: touches) == nil,
                         "wheels, momentum, unavailable surfaces and physical touch sequences cannot start a mouse skip")
        }
    }
}
