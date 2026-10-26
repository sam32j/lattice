// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum UpdateSettingsPresentationTests {
    static func run(_ expect: (Bool, String) -> Void) {
        let idle = UpdateSettingsPresentation(state: .idle)
        expect(idle.canCheck && idle.reviewVersion == nil,
               "an unchecked app offers a manual check without claiming an available update")
        let available = UpdateSettingsPresentation(state: .available(version: "4.2.0"))
        expect(available.canCheck && available.reviewVersion == "4.2.0",
               "an available update keeps manual checking and offers its version for review")
        for state in [AppUpdateState.checking, .downloading(progress: nil),
                      .downloading(progress: 0.45), .installing] {
            let presentation = UpdateSettingsPresentation(state: state)
            expect(!presentation.canCheck && presentation.reviewVersion == nil,
                   "an active update operation prevents a competing check or preview")
        }
        for state in [AppUpdateState.upToDate, .failed("Network unavailable")] {
            let presentation = UpdateSettingsPresentation(state: state)
            expect(presentation.canCheck && presentation.reviewVersion == nil,
                   "a completed or failed operation can always be checked again")
        }

        let sampleDate = Date(timeIntervalSince1970: 1793032840) // 2026-10-26 16:40:40 UTC
        let pt = TimeZone(identifier: "America/Los_Angeles")!
        let et = TimeZone(identifier: "America/New_York")!
        let enLocale = Locale(identifier: "en_US")
        let formattedPT = UpdateSettingsPresentation.formattedLastChecked(sampleDate, timeZone: pt, locale: enLocale)
        let formattedET = UpdateSettingsPresentation.formattedLastChecked(sampleDate, timeZone: et, locale: enLocale)
        expect(formattedPT.contains("9:40") && formattedPT.contains("AM"),
               "formattedLastChecked reflects the requested Pacific timezone (got: \(formattedPT))")
        expect(formattedET.contains("12:40") && formattedET.contains("PM"),
               "formattedLastChecked reflects the requested Eastern timezone (got: \(formattedET))")
        expect(SystemTimeZone.current.secondsFromGMT() != 0 || TimeZone.current.secondsFromGMT() == 0,
               "SystemTimeZone resolves a valid system timezone")
    }
}
