// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// Actual history entrypoints, with UI scheduling and window delivery isolated.
enum HistoryPreviewContinuityTests {
    struct RecentCaptureEntry {
        enum Kind { case screenshot, recording }
        let kind: Kind
        var recordingURL: URL? = URL(fileURLWithPath: "/recording.mov")
    }
    enum DispatchQueue {
        static let main = Queue()
        struct Deadline {
            let value: Double
            static func now() -> Self { .init(value: 0) }
            static func + (lhs: Self, rhs: Double) -> Self { .init(value: lhs.value + rhs) }
        }
        final class Queue {
            var delays: [Double] = []
            func async(execute: () -> Void) { execute() }
            func asyncAfter(deadline: Deadline, execute: () -> Void) { delays.append(deadline.value); execute() }
        }
    }
    final class Delegate {
        var collapsed = 0
        func closePopover(preservingNotch: Bool) { if !preservingNotch { collapsed += 1 } }
    }
    static let delegate = Delegate()
    static func appDelegate() -> Delegate? { delegate }
    enum NSSound { static func beep() {} }
    enum RecentCaptureStore { static func isRegularFile(_ url: URL) -> Bool { true } }
    enum ScreenshotService {
        static let shared = Service()
        final class Service {
            var shown = 0
            func restorePreview(_ capture: Int) { shown += 1 }
        }
    }
    enum RecorderQuickPreviewController {
        static let shared = Controller()
        final class Controller {
            var shown = 0
            func show(url: URL, initialThumbnail: CGImage?, inNotch: Bool) { shown += 1 }
        }
    }
    class State {
        let queue = DispatchQueue.Queue()
        func loadScreenshot(_ entry: RecentCaptureEntry) -> Int? { 1 }
        func hideHistoryWindow() {}
        func remove(_ entry: RecentCaptureEntry) {}
        func thumbnail(for entry: RecentCaptureEntry) -> NSImage? { nil }
    }
    static func run(_ suite: TestSuite) {
        for kind in [RecentCaptureEntry.Kind.screenshot, .recording] {
            for inNotch in [true, false] {
                delegate.collapsed = 0
                DispatchQueue.main.delays = []
                ScreenshotService.shared.shown = 0
                RecorderQuickPreviewController.shared.shown = 0
                Service().open(.init(kind: kind), inNotch: inNotch)
                suite.expect(delegate.collapsed == (inNotch ? 0 : 1)
                             && DispatchQueue.main.delays == [inNotch ? 0 : 0.12],
                             "\(kind) history preserves the current Island session only for an Island entrypoint")
                suite.expect(ScreenshotService.shared.shown + RecorderQuickPreviewController.shared.shown == 1,
                             "history presents exactly one matching preview")
            }
        }
    }
}
