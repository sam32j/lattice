// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// What the Stay Awake page's session card says about the session: its
/// title, the pill beside it and the line under it. Worked out here, away
/// from the view, so every state can be checked.
struct StayAwakeStatus: Equatable {
    enum Pill: Equatable { case automatic, untilOff }

    enum Caption: Equatable {
        case normalRules
        case endsAt(Date)
        case untilDisabled
        case automatic(Set<KeepAwakeAutomationCondition>)
        case paused
        case restoreFailed
        case activationFailed

        var isError: Bool { self == .restoreFailed || self == .activationFailed }
    }

    /// False reads "Not running"; true reads "Awake".
    var isAwake: Bool
    /// A countdown session's end: the title adds the time left and the ring
    /// shows its share. Nil for a session with no end, or none at all.
    var countdownEnd: Date?
    var pill: Pill?
    var caption: Caption

    static func make(isActive: Bool, automatic: Bool, end: Date?, failed: Bool, paused: Bool,
                     conditions: Set<KeepAwakeAutomationCondition>) -> StayAwakeStatus {
        var status: StayAwakeStatus
        if !isActive {
            status = StayAwakeStatus(isAwake: false, countdownEnd: nil, pill: nil, caption: .normalRules)
        } else if automatic {
            status = StayAwakeStatus(isAwake: true, countdownEnd: nil, pill: .automatic,
                                     caption: paused ? .paused : .automatic(conditions))
        } else if let end {
            status = StayAwakeStatus(isAwake: true, countdownEnd: end, pill: nil,
                                     caption: paused ? .paused : .endsAt(end))
        } else {
            status = StayAwakeStatus(isAwake: true, countdownEnd: nil, pill: .untilOff,
                                     caption: paused ? .paused : .untilDisabled)
        }
        // A failed update keeps the title and says what went wrong in red.
        if failed { status.caption = isActive ? .restoreFailed : .activationFailed }
        return status
    }

    /// How much of a session is left, for its ring: 1 for a session with no
    /// end, 0 with none running. The whole runs from the start to the end,
    /// so extending a session refills the ring by the time added.
    static func ringFraction(isActive: Bool, start: Date?, end: Date?, now: Date) -> Double {
        guard isActive else { return 0 }
        guard let end else { return 1 }
        guard let start, end > start else { return 0 }
        let fraction = end.timeIntervalSince(now) / end.timeIntervalSince(start)
        return min(1, max(0, fraction))
    }
}

/// The line over the session card's start buttons.
enum StayAwakeStartPrompt: Equatable {
    case startSession, addTime, switchToTimed

    /// `isTimed` is a countdown the buttons extend rather than replace.
    static func make(isActive: Bool, isTimed: Bool) -> StayAwakeStartPrompt {
        guard isActive else { return .startSession }
        return isTimed ? .addTime : .switchToTimed
    }
}

/// What the closed-lid row says under its switch.
enum StayAwakeLidCaption: Equatable {
    case configuring, onDuringSession, appliesToSessions, ready, needsPassword

    static func make(inProgress: Bool, preferred: Bool, isActive: Bool, passwordless: Bool) -> StayAwakeLidCaption {
        if inProgress { return .configuring }
        if preferred { return isActive ? .onDuringSession : .appliesToSessions }
        return passwordless ? .ready : .needsPassword
    }
}

/// What the Start automatically card says under its title.
enum StayAwakeAutomationCaption: Equatable {
    case none, one, combined(requireAll: Bool)

    static func make(selectedCount: Int, requireAll: Bool) -> StayAwakeAutomationCaption {
        switch selectedCount {
        case 0: return .none
        case 1: return .one
        default: return .combined(requireAll: requireAll)
        }
    }
}
