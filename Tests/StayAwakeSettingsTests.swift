// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// The Stay Awake page's status, ring, prompt, lid caption and automation
/// caption, worked out away from its views.
enum StayAwakeSettingsTests {
    static func run(_ suite: TestSuite) {
        let now = Date()
        let end = now.addingTimeInterval(600)

        let idle = StayAwakeStatus.make(isActive: false, automatic: false, end: nil, failed: false, paused: false,
                                        conditions: [])
        suite.expect(!idle.isAwake && idle.pill == nil && idle.caption == .normalRules && idle.countdownEnd == nil,
                     "nothing running reads Not running under the normal sleep rules")
        let timed = StayAwakeStatus.make(isActive: true, automatic: false, end: end, failed: false, paused: false,
                                         conditions: [])
        suite.expect(timed.isAwake && timed.countdownEnd == end && timed.caption == .endsAt(end) && timed.pill == nil,
                     "a timed session counts down and says when it ends")
        let open = StayAwakeStatus.make(isActive: true, automatic: false, end: nil, failed: false, paused: false,
                                        conditions: [])
        suite.expect(open.pill == .untilOff && open.caption == .untilDisabled && open.countdownEnd == nil,
                     "a session with no end carries the Until turned off pill")
        let automatic = StayAwakeStatus.make(isActive: true, automatic: true, end: nil, failed: false, paused: false,
                                             conditions: [.power])
        suite.expect(automatic.pill == .automatic && automatic.caption == .automatic([.power]),
                     "an automatic session names the condition that started it")
        let paused = StayAwakeStatus.make(isActive: true, automatic: false, end: end, failed: false, paused: true,
                                          conditions: [])
        suite.expect(paused.countdownEnd == end && paused.caption == .paused,
                     "a session paused by the lock keeps its time left and says it is paused")
        let failedStart = StayAwakeStatus.make(isActive: false, automatic: false, end: nil, failed: true,
                                               paused: false, conditions: [])
        let failedStop = StayAwakeStatus.make(isActive: true, automatic: false, end: end, failed: true,
                                              paused: false, conditions: [])
        suite.expect(failedStart.caption == .activationFailed && failedStart.caption.isError
                        && failedStop.caption == .restoreFailed && failedStop.countdownEnd == end,
                     "a failed update keeps the title and says what failed")

        let start = now.addingTimeInterval(-600)
        suite.expect(StayAwakeStatus.ringFraction(isActive: false, start: start, end: end, now: now) == 0
                        && StayAwakeStatus.ringFraction(isActive: true, start: start, end: nil, now: now) == 1,
                     "the ring is empty with nothing running and full for a session with no end")
        suite.expect(abs(StayAwakeStatus.ringFraction(isActive: true, start: start, end: end, now: now) - 0.5) < 0.001,
                     "the ring shows the share of the session left")
        let extended = end.addingTimeInterval(1200)
        suite.expect(abs(StayAwakeStatus.ringFraction(isActive: true, start: start, end: extended, now: now) - 0.75) < 0.001,
                     "extending a session refills the ring by the time added")
        suite.expect(StayAwakeStatus.ringFraction(isActive: true, start: start, end: start.addingTimeInterval(-1), now: now) == 0,
                     "an end before the start reads as nothing left")

        suite.expect(StayAwakeStartPrompt.make(isActive: false, isTimed: false) == .startSession
                        && StayAwakeStartPrompt.make(isActive: true, isTimed: true) == .addTime
                        && StayAwakeStartPrompt.make(isActive: true, isTimed: false) == .switchToTimed,
                     "the start buttons start, extend a countdown, or switch an open or automatic session")

        suite.expect(StayAwakeLidCaption.make(inProgress: true, preferred: true, isActive: true, passwordless: true) == .configuring
                        && StayAwakeLidCaption.make(inProgress: false, preferred: true, isActive: true, passwordless: true) == .onDuringSession
                        && StayAwakeLidCaption.make(inProgress: false, preferred: true, isActive: false, passwordless: true) == .appliesToSessions
                        && StayAwakeLidCaption.make(inProgress: false, preferred: false, isActive: true, passwordless: true) == .ready
                        && StayAwakeLidCaption.make(inProgress: false, preferred: false, isActive: false, passwordless: false) == .needsPassword,
                     "the lid caption says whether setup runs, it is in effect, it waits for a session, or it needs the password")

        suite.expect(StayAwakeAutomationCaption.make(selectedCount: 0, requireAll: true) == .none
                        && StayAwakeAutomationCaption.make(selectedCount: 1, requireAll: true) == .one
                        && StayAwakeAutomationCaption.make(selectedCount: 2, requireAll: true) == .combined(requireAll: true),
                     "the automation caption follows how many conditions are chosen and the match mode")

        for language in AppLanguage.allCases {
            let strings = FeatureStrings.stayAwakeSettings(language)
            for count in [1, 2, 5, 11, 21] {
                let summary = strings.appsSummary(count: count, names: "Zoom", language)
                suite.expect(summary.contains("\(count)") && summary.contains("Zoom"),
                             "\(language.rawValue): the apps summary names \(count) apps and lists them")
            }
            suite.expect(String(format: strings.batteryBelowFormat, 15).contains("15"),
                         "\(language.rawValue): the battery menu names its percent")
        }
    }
}
