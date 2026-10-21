// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum ScreenshotMissionControlDeferralTests {
    static func run(_ suite: TestSuite) {
        let service = NotchPresentationRefreshContract.Service()
        var presentations: [String] = []
        let first = UUID(), latest = UUID()
        service.windowHost?.concealedForMissionControl = true
        suite.expect(service.deferCaptureUntilMissionControlRestores(id: first) { presentations.append("old") },
                     "a Mission Control capture defers before opening any floating panel")
        _ = service.deferCaptureUntilMissionControlRestores(id: latest) {
            presentations.append(service.acceptsSystemFeedback ? "island" : "floating")
        }
        service.cancelDeferredCapturePresentation(id: first)
        suite.expect(presentations.isEmpty, "no visual preview or dismissal timer starts before desktop landing")
        service.windowHost?.concealedForMissionControl = false
        service.missionControlDidRestore()
        service.missionControlDidRestore()
        suite.expect(presentations == ["island"], "the latest capture expands the settled island exactly once")
        service.windowHost?.concealedForMissionControl = true
        _ = service.deferCaptureUntilMissionControlRestores(id: UUID()) {
            presentations.append(service.acceptsSystemFeedback ? "island" : "floating")
        }
        service.hiddenInFullscreen = true
        service.windowHost?.concealedForMissionControl = false
        service.missionControlDidRestore()
        suite.expect(presentations == ["island", "floating"],
                     "a settled fullscreen Space with a hidden island can use the standalone fallback")
        suite.expect(!service.deferCaptureUntilMissionControlRestores(id: UUID()) {},
                     "a hidden fullscreen island does not defer indefinitely when Mission Control is already closed")
        service.hiddenInFullscreen = false
        service.windowHost?.concealedForMissionControl = true
        _ = service.deferCaptureUntilMissionControlRestores(id: UUID()) { presentations.append("resumed") }
        service.suspended = true
        service.windowHost?.concealedForMissionControl = false
        service.missionControlDidRestore()
        suite.expect(!presentations.contains("resumed"), "a locked session cannot present a queued screenshot")
        service.suspended = false
        service.resumeDeferredCaptureIfReady()
        suite.expect(presentations.last == "resumed", "resuming after island rebuild consumes the waiting preview")
    }
}
