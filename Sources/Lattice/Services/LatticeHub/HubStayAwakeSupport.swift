// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum HubStayAwakeSupport {
    static func durationEnd(minutes: Int, isTimed: Bool, end: Date?, now: Date) -> Date {
        let base = isTimed ? max(end ?? now, now) : now
        return base.addingTimeInterval(TimeInterval(minutes) * 60)
    }

    static func nextOccurrence(of time: Date, now: Date, calendar: Calendar = .current) -> Date {
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.nextDate(after: now, matching: parts, matchingPolicy: .nextTime,
                                 repeatedTimePolicy: .first)!
    }

    static func compact(end: Date?, now: Date) -> String {
        KeepAwakeTimeFormat.compact(end: end, now: now)
    }
}
