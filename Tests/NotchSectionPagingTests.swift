// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum NotchSectionPagingTests {
    static func run(_ suite: TestSuite) {
        routing(suite)
    }

    // The generated Service uses the current production handleScroll verbatim.
    // Section paging math remains independently covered above; actual scroll
    // dispatch now forwards to the generic gesture handler.
    struct NSEvent {}

    class State {
        var gestureCalls = 0
        var gestureHandled = false
        func handleGesture(_ event: NSEvent) -> Bool {
            gestureCalls += 1
            return gestureHandled
        }
    }

    private static func routing(_ suite: TestSuite) {
        let service = Service()
        let event = NSEvent()
        suite.expect(!service.handleScroll(event) && service.gestureCalls == 1,
                     "scroll events reach the current gesture handler even when not consumed")
        service.gestureHandled = true
        suite.expect(service.handleScroll(event) && service.gestureCalls == 2,
                     "scroll events propagate the gesture handler's consumed result")
    }
}
