// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Runs the production startup and cancellation methods with controlled writer
/// completions. No capture, permissions, windows or recording folders are used.
enum RecorderPreparationTests {
    enum AppFeature {
        case screenRecorder
        static var available = true
        var isAvailable: Bool { Self.available }
    }
    struct UserDefaults {
        static let standard = Self()
        static var immediate = false
        func integer(forKey key: String) -> Int { 30 }
        func bool(forKey key: String) -> Bool { false }
        func object(forKey key: String) -> Any? { Self.immediate }
    }
    struct Permissions {
        static let shared = Self()
        enum Grant { case granted }
        let microphone = Grant.granted
        let screenRecording = true
        let accessibility = true
        func requestScreenRecording() {}
        func requestAccessibility() {}
    }
    enum QuickToolHUD {
        static var messages = 0
        static func show(icon: String, message: String) { messages += 1 }
    }
    final class Indicator {
        var hidden = false
        var onStop: (() -> Void)?
        init(onPause: @escaping () -> Void = {}, onStop: @escaping () -> Void = {},
             onDiscard: (() -> Void)? = nil) {
            self.onStop = onStop
        }
        func hide() { hidden = true }
        func showRegionGuide(for region: RecorderSupport.Region) {}
        func show(on screen: NSScreen?, tooltip: String, pauseTooltip: String,
                  resumeTooltip: String, stopTooltip: String,
                  discardTooltip: String) {}
    }
    typealias RecorderIndicator = Indicator
    struct NSScreen {
        static let screens: [NSScreen] = []
        let displayID: UInt32
    }
    struct RecorderSelectionAudioOptions { var microphone = false }
    final class NSSound {
        init?(contentsOfFile: String, byReference: Bool) {}
        func play() {}
    }
    final class RecorderTakeStore {
        struct Take: Equatable {
            let videoURL: URL
        }
        static let shared = RecorderTakeStore()
        var made: [Take] = []
        var deleted: [Take] = []
        func makeTake() -> Take? {
            let take = Take(videoURL: URL(fileURLWithPath: "/fixture/\(UUID()).mov"))
            made.append(take)
            return take
        }
        func delete(_ take: Take) { deleted.append(take) }
        func freeBytes() -> Int64 { 10_000_000_000 }
    }
    final class RecorderWriter {
        static var replies: [(RecorderWriter?) -> Void] = []
        var cancelled = false
        static func prepare(url: URL, pixelSize: CGSize, frameRate: Int,
                            capturesSystemAudio: Bool, capturesMicrophone: Bool,
                            pauseClock: RecorderPauseClock,
                            completion: @escaping (RecorderWriter?) -> Void) {
            replies.append(completion)
        }
        func cancel() { cancelled = true }
    }
    final class RecorderSession {
        let writer: RecorderWriter
        let take: RecorderTakeStore.Take
        init(take: RecorderTakeStore.Take, region: RecorderSupport.Region,
             writer: RecorderWriter, pauseClock: RecorderPauseClock,
             capturesSystemAudio: Bool, capturesMicrophone: Bool) {
            self.writer = writer
            self.take = take
        }
        func stop() async -> Bool { false }
    }
    class Fixture {
        var session: RecorderSession?
        var indicator: Indicator? = Indicator()
        var isRecording = false
        var isFinishing = false
        var isAwaitingMicrophone = false
        var isPreparingRecording = false
        var countdown: DispatchWorkItem?
        var pendingStartGeneration = 1
        var starts = 0
        var countdownRequests = 0
        let strings = FeatureStrings.recorder(.enUS)
        func startPreparedRecording(_ session: RecorderSession, frameRate: Int,
                                    capturesSystemAudio: Bool, generation: Int) {
            self.session = session
            starts += 1
        }
        func togglePause() {}
        func stopAndDiscard() {}
        func prepareCountdown(for region: RecorderSupport.Region, wantsMicrophone: Bool, generation: Int) {
            countdownRequests += 1
            countdown = DispatchWorkItem {}
        }
        func endRecordingSurfaces() {}
        func deliver(_ take: RecorderTakeStore.Take, reason: String?) {}
        func sweepTakes() {}
        func reportNoSpace() {}
    }

    static func run(_ suite: TestSuite) {
        let region = RecorderSupport.Region(displayID: 1, windowID: nil,
            pixelRect: CGRect(x: 0, y: 0, width: 64, height: 64), anchorRect: .zero, scale: 1)
        func reset() {
            AppFeature.available = true
            UserDefaults.immediate = false
            RecorderWriter.replies = []
            RecorderTakeStore.shared.made = []
            RecorderTakeStore.shared.deleted = []
            QuickToolHUD.messages = 0
        }
        defer { reset() }

        let waiting = Service()
        waiting.record(region, audioOptions: RecorderSelectionAudioOptions())
        suite.expect(waiting.hasActiveCapture && !waiting.prepareForSelection(),
                     "a delayed recording reserves capture and rejects a second selection")
        let waitingIndicator = waiting.indicator!
        waitingIndicator.onStop?()
        suite.expect(!waiting.hasActiveCapture && waitingIndicator.hidden && waiting.prepareForSelection(),
                     "Stop cancels delayed recording and releases its indicator and admission")

        let toggled = Service()
        toggled.record(region, audioOptions: RecorderSelectionAudioOptions())
        let toggledIndicator = toggled.indicator!
        suite.expect(toggled.stopOrCancelActiveCapture() && toggledIndicator.hidden && !toggled.hasActiveCapture,
                     "the shared capture toggle cancels a waiting recording")

        let delayed = Service()
        delayed.record(region, audioOptions: RecorderSelectionAudioOptions())
        suite.expect(delayed.countdownRequests == 1,
                     "a confirmed selection starts countdown without a second waiting screen")
        delayed.invalidatePendingStart()
        delayed.record(region, audioOptions: RecorderSelectionAudioOptions())
        delayed.record(region, audioOptions: RecorderSelectionAudioOptions())
        suite.expect(delayed.countdownRequests == 2,
                     "recording admission rejects duplicate Start requests")

        UserDefaults.immediate = true
        let immediate = Service()
        immediate.record(region, audioOptions: RecorderSelectionAudioOptions())
        suite.expect(immediate.countdownRequests == 1 && immediate.hasActiveCapture,
                     "immediate recording still enters countdown directly")

        reset()
        let accepted = Service()
        accepted.beginRecording(region: region, generation: 1)
        suite.expect(accepted.hasActiveCapture && !accepted.prepareForSelection()
                     && accepted.session == nil && accepted.starts == 0,
                     "writer preparation reserves capture without starting it or admitting a second selection")
        let writer = RecorderWriter()
        RecorderWriter.replies.removeFirst()(writer)
        suite.expect(accepted.starts == 1 && accepted.session?.writer === writer
                     && !accepted.isPreparingRecording && RecorderTakeStore.shared.deleted.isEmpty,
                     "an authorized prepared writer starts exactly one recording")

        reset()
        let cancelled = Service()
        let guide = cancelled.indicator!
        cancelled.beginRecording(region: region, generation: 1)
        suite.expect(cancelled.stopOrCancelActiveCapture() && !cancelled.hasActiveCapture
                     && guide.hidden && cancelled.prepareForSelection(),
                     "the capture toggle cancels preparation and releases its guide and admission")
        let abandoned = RecorderWriter()
        RecorderWriter.replies.removeFirst()(abandoned)
        suite.expect(cancelled.starts == 0 && abandoned.cancelled
                     && RecorderTakeStore.shared.deleted == RecorderTakeStore.shared.made,
                     "a writer completed after cancellation is discarded with its take")

        reset()
        let replaced = Service()
        replaced.beginRecording(region: region, generation: 1)
        replaced.invalidatePendingStart()
        replaced.beginRecording(region: region, generation: replaced.pendingStartGeneration)
        let stale = RecorderWriter()
        RecorderWriter.replies.removeFirst()(stale)
        suite.expect(replaced.isPreparingRecording && replaced.starts == 0 && stale.cancelled,
                     "an old completion does not clear the newer preparation")
        RecorderWriter.replies.removeFirst()(RecorderWriter())
        suite.expect(replaced.starts == 1 && RecorderTakeStore.shared.deleted.count == 1,
                     "the newer request still starts after an older writer is discarded")

        reset()
        let disabled = Service()
        disabled.beginRecording(region: region, generation: 1)
        AppFeature.available = false
        let unavailable = RecorderWriter()
        RecorderWriter.replies.removeFirst()(unavailable)
        suite.expect(disabled.starts == 0 && unavailable.cancelled
                     && RecorderTakeStore.shared.deleted.count == 1,
                     "a disabled feature cannot start after encoder preparation completes")

        reset()
        let failed = Service()
        failed.beginRecording(region: region, generation: 1)
        RecorderWriter.replies.removeFirst()(nil)
        suite.expect(!failed.hasActiveCapture && failed.starts == 0 && failed.indicator == nil
                     && RecorderTakeStore.shared.deleted.count == 1 && QuickToolHUD.messages == 1,
                     "failed preparation releases its take and UI and reports failure once")
    }
}
