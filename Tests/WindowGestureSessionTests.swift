// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

enum WindowGestureSessionTests {
    static func run(_ suite: TestSuite) {
        var jobs: [() -> Void] = []
        var values: [Int] = []
        var observed = 0
        var session: WindowGestureApplySession<Int>!
        session = WindowGestureApplySession(schedule: { jobs.append($0) }, apply: { value in
            values.append(value)
            if value < 5 { session.enqueue(value + 1) }
        })
        session.enqueue(1)
        jobs.append { observed = values.count }
        while !jobs.isEmpty { jobs.removeFirst()() }
        suite.expect(observed == 1 && values == [1, 2, 3, 4, 5],
                     "continuous frame writes yield to queued live snap updates before release")
    }
}
