// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum AppUpdatePresentationTests {
    struct AppFeature {
        static let appUpdates = AppFeature()
        var isAvailable: Bool { true }
    }
    final class Updates {
        var isChecking = false
        var items: [Int] = []
        var checkedAppsCount = 0
        var totalAppsCount = 0
        var lastError: String?
        var hasCheckedThisSession = false
    }
    class State {
        let updates = Updates()
        var allSourcesOff = false
        var coveragePartial = false
        let text = AppUpdateStrings.enUS
        var lastCheckRelativeText = "yesterday"
    }
    static func run(_ suite: TestSuite) {
        let view = Presentation()
        view.updates.isChecking = true
        suite.expect(view.statusDetail == view.text.checking,
                     "scan details remain indeterminate instead of inventing checked app counts")
        view.updates.totalAppsCount = 8
        suite.expect(view.statusDetail == view.text.checking,
                     "knowing the discovered total does not turn source-level work into app progress")
        view.updates.isChecking = false
        suite.expect(view.statusHeadline == view.text.neverChecked && !view.statusDetail.contains("8"),
                     "an uncompleted first scan cannot claim the apps are current or checked")
        view.updates.hasCheckedThisSession = true
        suite.expect(view.successfulEmptyCheck,
                     "a completed empty check can display success")
        view.updates.lastError = "Source failed"
        suite.expect(!view.successfulEmptyCheck && view.statusHeadline == view.text.checkFailed,
                     "a failed repeat check replaces prior success instead of claiming no updates")
    }
}
