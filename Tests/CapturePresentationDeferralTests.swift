// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum CapturePresentationDeferralTests {
    static func run(_ suite: TestSuite) {
        let pending = CapturePresentationDeferral()
        let first = UUID(), latest = UUID()
        var events: [Int] = []
        pending.enqueue(id: first) { events.append(1) }
        pending.enqueue(id: latest) { events.append(2) }
        pending.cancel(id: first)
        suite.expect(events.isEmpty, "captures do not present while Mission Control remains open")
        pending.restore()
        pending.restore()
        suite.expect(events == [2], "only the latest pending capture presents, exactly once after desktop landing")
        pending.enqueue(id: first) { events.append(3) }
        pending.cancel(id: first)
        pending.restore()
        suite.expect(events == [2], "closed pending previews cannot reappear")
        pending.enqueue(id: first) { pending.enqueue(id: latest) { events.append(4) } }
        pending.restore()
        pending.restore()
        suite.expect(events == [2, 4], "restore clears its old callback before invoking a reentrant presentation")
        pending.enqueue(id: first) { events.append(5) }
        pending.finish(restore: false)
        pending.restore()
        suite.expect(events == [2, 4], "quitting discards a deferred preview instead of opening a fallback window")
    }
}
