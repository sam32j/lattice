// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum ScreenshotCaptureFocusTests {
    static func run(_ suite: TestSuite) {
        let panel = ScreenshotCapturePanel(screenRect: CGRect(x: -10000, y: -10000, width: 100, height: 100))
        panel.isReleasedWhenClosed = false
        defer { panel.orderOut(nil); panel.close() }
        var foreground = false
        var restored = false
        var completed = false
        var captureOwnedActivation = false
        let focus = ScreenshotCaptureFocusSession(application: .init(isFrontmost: { foreground }, activate: {
            captureOwnedActivation = panel.isMainWindow && panel.isKeyWindow
            foreground = true
        }, restore: {
            restored = true
            foreground = false
            return true
        }))
        focus.acquire(panel)
        suite.expect(captureOwnedActivation && panel.canBecomeMain,
                     "capture owns main and key before requesting system cursor ownership")
        focus.release {
            completed = restored && !foreground && !panel.canBecomeMain
        }
        suite.expect(completed, "capture hands focus back before completing and releases its main-window role")

        var activated = false
        var stoleFocus = false
        foreground = false
        let abandoned = ScreenshotCaptureFocusSession(application: .init(isFrontmost: { foreground }, activate: {
            activated = true
            foreground = true
        }, restore: { stoleFocus = true; return true }))
        abandoned.release { completed = true }
        suite.expect(!activated && !stoleFocus, "cancelling before panels appear leaves application focus untouched")

        foreground = false
        let switched = ScreenshotCaptureFocusSession(application: .init(isFrontmost: { foreground }, activate: {
            foreground = true
        }, restore: { stoleFocus = true; return false }))
        switched.acquire(panel)
        foreground = false // The user selected another app while capture was visible.
        switched.release {}
        suite.expect(!stoleFocus && !panel.canBecomeMain,
                     "capture cancellation respects an intervening user application switch")

        foreground = true
        activated = false
        let alreadyActive = ScreenshotCaptureFocusSession(application: .init(isFrontmost: { foreground }, activate: {
            activated = true
        }, restore: { stoleFocus = true; return false }))
        alreadyActive.acquire(panel)
        alreadyActive.release {}
        suite.expect(!activated && !stoleFocus,
                     "capture started inside Lattice does not activate another application on completion")

        for acceptsRestore in [false, true] {
            foreground = false
            var completions = 0
            let failed = ScreenshotCaptureFocusSession(application: .init(isFrontmost: { foreground }, activate: {
                foreground = true
            }, restore: { acceptsRestore }))
            failed.acquire(panel)
            failed.release { completions += 1 }
            let deadline = Date().addingTimeInterval(0.5)
            while completions == 0 && Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.01))
            }
            suite.expect(completions == 1 && !panel.ownsCaptureFocus && !panel.isMainWindow,
                         "failed or timed-out activation handoff completes once and releases capture ownership")
            panel.orderOut(nil)
        }
    }
}
