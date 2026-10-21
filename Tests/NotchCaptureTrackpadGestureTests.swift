// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum NotchCaptureTrackpadGestureTests {
    static func run(_ suite: TestSuite) {
        func contacts(_ y: CGFloat, second: CGFloat? = nil) -> [NotchCaptureTrackpadGesture.Contact] {
            [.init(id: 1, position: CGPoint(x: 20, y: y)), .init(id: 2, position: CGPoint(x: 40, y: second ?? y))]
        }
        var gesture = NotchCaptureTrackpadGesture()
        _ = gesture.update(contacts(0), enabled: true)
        suite.expect(!gesture.update(contacts(16), enabled: true) && gesture.progress < 0.25,
                     "the old short scroll distance no longer opens capture history")
        suite.expect(!gesture.update(contacts(71.99), enabled: true), "less than one physical inch cannot navigate")
        suite.expect(!gesture.update(contacts(80, second: 60), enabled: true), "both fingers must travel at least one inch")
        suite.expect(gesture.update(contacts(72), enabled: true) && gesture.progress == 1,
                     "one inch of upward travel by both fingers navigates once")
        suite.expect(!gesture.update(contacts(100), enabled: true), "one touch sequence never navigates twice")
        _ = gesture.update([], enabled: true)
        _ = gesture.update(contacts(0), enabled: true)
        suite.expect(!gesture.update(contacts(100), enabled: false) && gesture.progress == 0,
                     "disabled gestures never navigate or retain a feedback cue")
        _ = gesture.update(contacts(0), enabled: true)
        _ = gesture.update([.init(id: 3, position: .zero)], enabled: true)
        suite.expect(!gesture.update(contacts(100), enabled: true), "replaced fingers cannot finish a previous swipe")
        _ = gesture.update([], enabled: true)
        _ = gesture.update(contacts(100), enabled: true)
        suite.expect(!gesture.update(contacts(0), enabled: true) && gesture.progress == 0,
                     "a downward swipe never opens history")
    }
}
