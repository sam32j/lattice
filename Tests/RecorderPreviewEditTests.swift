// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum RecorderPreviewEditTests {
    // Replace disk copying and window presentation, not the edit action itself.
    final class RecorderTakeStore: @unchecked Sendable {
        struct Take: Sendable { let id = UUID() }
        static let shared = RecorderTakeStore()
        private let lock = NSLock()
        private var failed = false
        private var copiedOnMain = false
        private var started = false
        private var blocked = false
        let continueCopy = DispatchSemaphore(value: 0)
        var deleted = false
        func reset(failing: Bool, blocking: Bool = false) {
            lock.lock(); defer { lock.unlock() }
            failed = failing
            copiedOnMain = false
            deleted = false
            started = false
            blocked = blocking
        }
        func importVideo(at url: URL) -> Take? {
            lock.lock()
            copiedOnMain = Thread.isMainThread
            started = true
            let wait = blocked, fail = failed
            lock.unlock()
            if wait { _ = continueCopy.wait(timeout: .now() + 2) }
            return fail ? nil : Take()
        }
        var copyStarted: Bool { lock.lock(); defer { lock.unlock() }; return started }
        var didCopyOnMain: Bool {
            lock.lock(); defer { lock.unlock() }
            return copiedOnMain
        }
        func delete(_ take: Take) { deleted = true }
    }
    final class ScreenRecorderService {
        static let shared = ScreenRecorderService()
        var accepts = true
        var presented = false
        @discardableResult func openEditor(with take: RecorderTakeStore.Take, preservedRecordingURL: URL) -> Bool {
            presented = true
            return accepts
        }
    }
    enum NSSound {
        static var beeps = 0
        static func beep() { beeps += 1 }
    }
    enum AppFeature {
        struct Availability { var isAvailable = true }
        static var screenRecorder = Availability()
    }
    class State {
        var url: URL? = URL(fileURLWithPath: "/fixture/video.mov")
        var closed = false
        func close() { closed = true; url = nil }
    }
    @MainActor static func run(_ suite: TestSuite) {
        func settle(_ ready: () -> Bool) {
            let deadline = Date().addingTimeInterval(2)
            while !ready(), Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        }
        let store = RecorderTakeStore.shared
        let service = ScreenRecorderService.shared
        store.reset(failing: false)
        service.accepts = false
        service.presented = false
        let rejected = Controller()
        rejected.performEdit()
        settle { service.presented }
        suite.expect(service.presented && !store.didCopyOnMain,
                     "opening a recording copies its master away from the UI thread")
        suite.expect(store.deleted, "a rejected video editor does not orphan the imported take")
        store.reset(failing: true)
        service.presented = false
        NSSound.beeps = 0
        Controller().performEdit()
        settle { NSSound.beeps > 0 }
        suite.expect(NSSound.beeps == 1 && !service.presented,
                     "a failed video import reports failure instead of silently losing the preview action")
        store.reset(failing: false, blocking: true)
        service.presented = false
        Controller().performEdit()
        settle { store.copyStarted }
        AppFeature.screenRecorder.isAvailable = false
        defer { AppFeature.screenRecorder.isAvailable = true }
        store.continueCopy.signal()
        settle { store.deleted || service.presented }
        suite.expect(store.deleted && !service.presented,
                     "disabling recording during import discards the take without reaching the recorder service")
    }
}
