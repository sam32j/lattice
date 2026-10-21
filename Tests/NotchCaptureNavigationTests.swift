// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum NotchCaptureNavigationTests {
    static func run(_ suite: TestSuite) {
        suite.expect(NotchModule.captures.presentationTitle(.enUS, hasCapturePreview: true) == "Preview",
                     "an active Island capture is titled Preview rather than Recent captures")
        for language in AppLanguage.allCases {
            suite.expect(NotchModule.captures.presentationTitle(language, hasCapturePreview: false)
                         == FeatureStrings.recentCaptures(language).title,
                         "the history page keeps its own localized Recent captures title")
            suite.expect(!NotchModule.captures.presentationTitle(language, hasCapturePreview: true).isEmpty,
                         "the active preview title is localized")
        }
        let service = NotchPresentationRefreshContract.Service()
        let id = UUID()
        service.selected = .captures
        service.expanded = true
        service.captureID = id
        service.captureContent = true
        service.captureActions = true
        service.captureContentHeight = 200
        service.captureHistoryGestureProgress = 0.75
        var closes = 0
        service.captureClose = {
            closes += 1
            // Real previews remove their presentation during close. Detach
            // first so this callback cannot collapse the new history page.
            service.removeCapture(id: id)
        }
        service.showCaptureHistory()
        suite.expect(closes == 1 && service.captureID == nil && service.captureContent == nil
                     && service.captureActions == nil && service.captureContentHeight == nil,
                     "history navigation detaches and closes the prior preview exactly once")
        suite.expect(service.expanded && service.openedPages.last?.module == .captures
                     && service.captureHistoryGestureProgress == 0,
                     "preview cleanup leaves the history page expanded with no stale gesture cue")
        suite.expect(service.capturePageCrossfades == 1,
                     "preview to history requests a content crossfade without closing the Island session")
        let presented = service.presentCapture(id: UUID(), content: true, height: 200,
            takeFocus: true, closeOnCollapse: true, fallback: {}, close: {}, hover: { _ in })
        suite.expect(presented && service.expanded && service.capturePageCrossfades == 2,
                     "history to preview crossfades within the same expanded Island session")
        if let id = service.captureID {
            _ = service.presentCapture(id: id, content: true, height: 220,
                takeFocus: true, closeOnCollapse: true, fallback: {}, close: {}, hover: { _ in })
            suite.expect(service.capturePageCrossfades == 2,
                         "a live preview height update does not restart its page crossfade")
        }
    }
}
