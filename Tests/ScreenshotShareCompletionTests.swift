// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Runs the production completion handler with controlled upload and clipboard results.
/// No network request or native preview is created.
enum ScreenshotShareCompletionTests {
    typealias DispatchQueue = NotchScreenRefreshContract.DispatchQueue
    final class Model {
        var deletingShare = false
        var sharing = false
        var sharedRecord: ScreenshotShareRecord?
        var exported = false
        func exportImage() -> Export? { Export() }
        func markExported() { exported = true }
    }

    struct Export {
        let image = 1
        let scale = 1.0
    }

    enum ScreenshotRenderer {
        static var gate: RenderingGate?
        static func pngData(from image: Int, scale: Double) -> Data? {
            gate?.wait()
            return Data([1])
        }
    }

    final class RenderingGate: @unchecked Sendable {
        private let lock = NSLock()
        private var entered = false
        let resume = DispatchSemaphore(value: 0)
        var started: Bool { lock.withLock { entered } }
        func wait() {
            lock.withLock { entered = true }
            _ = resume.wait(timeout: .now() + 5)
        }
    }

    /// Scoped to the hosts, so the production defaults read never reaches
    /// the person's own preferences.
    enum SharingDefaults {
        static let standard = SharingDefaultsState()
    }

    final class SharingDefaultsState {
        var enabled = true
        func bool(forKey: String) -> Bool { enabled }
    }

    struct PreviewCapture {
        let id = UUID()
        let image: Int
    }

    final class QuickLinkMediaIndex {
        static let shared = QuickLinkMediaIndex()
        var screenshotRecords: [UUID: ScreenshotShareRecord] = [:]
        func rememberScreenshot(_ id: UUID, record: ScreenshotShareRecord) {
            screenshotRecords[id] = record
        }
        func latestScreenshot(for id: UUID) -> ScreenshotShareRecord? {
            screenshotRecords[id]
        }
    }

    final class ScreenTextService {
        static let shared = ScreenTextService()
        var copiedImages: [Int] = []
        func copyText(from image: Int) { copiedImages.append(image) }
    }

    /// Holds Copy text back while an after-capture copy is pending.
    final class ScreenshotService {
        static let shared = ScreenshotService()
        var autoCopyPending = false
        var waiting: [() -> Void] = []
        func afterAutoCopy(_ body: @escaping () -> Void) {
            if autoCopyPending { waiting.append(body) } else { body() }
        }
    }

    class EditorState {
        typealias UserDefaults = SharingDefaults
        let model = Model()
        let strings = ScreenshotFeatureStrings.enUS
        var window: Int? = 1
    }

    enum ScreenshotShareError: Error {
        case unavailable, invalidImage, invalidEndpoint, localStorage, invalidResponse, rejected
    }

    /// Runs the real service preflight and records the point at which it
    /// would reach the network. The fake transport always fails locally.
    @MainActor class CreationState {
        typealias UserDefaults = SharingDefaults
        final class Session {
            var uploads = 0
            func upload(for request: URLRequest, from data: Data) async throws -> (Data, URLResponse) {
                uploads += 1
                throw ScreenshotShareError.unavailable
            }
        }
        let session = Session()
        let endpoint = URL(string: "https://example.com")!
        let decoder = JSONDecoder()
        var removedRecordIDs = Set<String>()
        var records: [ScreenshotShareRecord] = []
        var writes = 0
        func loadRecords() throws -> [ScreenshotShareRecord] { [] }
        func saveRecords(_ records: [ScreenshotShareRecord]) throws { writes += 1 }
        func normalizedRecords(_ records: [ScreenshotShareRecord]) -> [ScreenshotShareRecord] { records }
        func deleteRemote(_ record: ScreenshotShareRecord) async throws {}
        func scheduleExpiryRefresh() {}
    }

    class State {
        typealias UserDefaults = SharingDefaults
        var systemSharing = false
        var previewDragInProgress = false
        var deletingCapture = false
        var confirmingCaptureDeletion = false
        var contextMenuOpen = false
        var pointerInside = false
        var onClose: () -> Void = {}
        var shareHandler: ((ScreenshotShareDuration, @escaping @MainActor (ScreenshotShareRecord?) -> Void) -> Void)?
        var closed = false
        let capture = PreviewCapture(image: 42)
        let model = Model()
        var dismissWork: DispatchWorkItem?
        var baseDismissDuration: TimeInterval? = 12
        var autoDismissDuration: TimeInterval? = 12
        struct Animation {
            static func spring(response: Double, dampingFraction: Double) -> Animation { Animation() }
        }
        func withAnimation(_ animation: Animation, _ body: () -> Void) { body() }
        var completion: (@MainActor (ScreenshotShareRecord?) -> Void)?
        var copies: [ScreenshotShareRecord] = []
        var copySucceeds = true
        var showingLink = false

        func share(_ duration: ScreenshotShareDuration,
                   completion: @escaping @MainActor (ScreenshotShareRecord?) -> Void) {
            self.completion = completion
            shareHandler?(duration, completion)
        }
        func close() { closed = true; onClose() }
        func scheduleAutoDismiss() {
            dismissWork = DispatchWorkItem {}
        }
        @MainActor func copyLinkAndClose(_ record: ScreenshotShareRecord) -> Bool {
            copies.append(record)
            let copied = copySucceeds && ScreenshotShareService.shared.copy(record.url)
            if copied { close() }
            return copied
        }
        func resizePanel(showingLink: Bool) { self.showingLink = showingLink }
    }

    @MainActor final class ScreenshotShareService {
        static let shared = ScreenshotShareService()
        var revoked: [ScreenshotShareRecord] = []
        var records: [ScreenshotShareRecord] = []
        var copies: [URL] = []
        var clipboard = "new capture"
        var copySucceeds = true
        var uploadCompletion: CheckedContinuation<ScreenshotShareRecord, Error>?
        func createLink(pngData: Data, duration: ScreenshotShareDuration) async throws -> ScreenshotShareRecord {
            try await withCheckedThrowingContinuation { uploadCompletion = $0 }
        }
        func copy(_ url: URL) -> Bool {
            copies.append(url)
            if copySucceeds { clipboard = url.absoluteString }
            return copySucceeds
        }
        func delete(_ record: ScreenshotShareRecord) async throws { revoked.append(record) }
    }

    enum AppFeature {
        case screenshot, screenOCR
        static var available = true
        static var ocrAvailable = true
        var isAvailable: Bool { self == .screenOCR ? Self.ocrAvailable : Self.available }
    }

    enum ScreenshotLastCaptureStore {
        static var stored: Int? = 1
        static var isWithheld = false
        static func load() -> Int? { stored }
        static func save(_ capture: Int) { stored = capture; isWithheld = false }
        static func clear() { stored = nil; isWithheld = false }
        static func withhold() { isWithheld = true }
    }

    enum ScreenshotSelectionController {
        typealias Capture = Int
    }

    final class NSWindow {}
    final class ScreenshotEditorController {
        let capture: Int
        var shown = false
        var originatingPin: Any? = nil
        init(capture: Int) { self.capture = capture }
        func show(above owner: NSWindow? = nil) { shown = true }
    }

    enum WindowActivationPolicy {
        static var retained = 0
        static func retain() { retained += 1 }
        static func release() { retained -= 1 }
    }

    enum NSSound {
        static var beeps = 0
        static func beep() { beeps += 1 }
    }

    enum QuickToolHUD {
        static func show(icon: String, message: String) {}
    }

    typealias ScreenshotQuickPreviewController = Controller

    /// Exercise the production last-capture retention and discard methods.
    @MainActor class LatestState {
        let defaultsName = "vorss.tests.screenshot-last-capture.\(UUID().uuidString)"
        let defaults: UserDefaults
        var latestCaptureToken = UUID()
        var autoCopyTask: Task<Void, Never>?

        init() {
            defaults = UserDefaults(suiteName: defaultsName)!
            ScreenshotLastCaptureStore.stored = 1
            ScreenshotLastCaptureStore.isWithheld = false
        }
        deinit {
            UserDefaults(suiteName: defaultsName)?.removePersistentDomain(forName: defaultsName)
        }
    }

    static func run(_ suite: TestSuite) {
        let first = UUID()
        let second = UUID()
        let latestToken = UUID()
        suite.expect(ScreenshotCaptureOwnership.shelfToken(
            for: first, latestHistoryID: first,
            latestToken: latestToken, previewToken: nil) == latestToken,
                     "history deletion finds the original latest screenshot's Shelf token")
        suite.expect(ScreenshotCaptureOwnership.shelfToken(
            for: first, latestHistoryID: second,
            latestToken: latestToken, previewToken: nil) == nil,
                     "deleting an older screenshot never removes a newer capture's Shelf copy")
        suite.expect(ScreenshotCaptureOwnership.ownsPendingCopy(
            historyID: first, activeCopyID: first)
                     && !ScreenshotCaptureOwnership.ownsPendingCopy(
                        historyID: first, activeCopyID: second),
                     "clipboard cancellation is keyed to the screenshot ID, not retention or a preview token")
        let png = Data([137, 80, 78, 71, 13, 10, 26, 10])
        let snapshot = ScreenshotLatestCaptureRecord(id: first, png: png)
        let encoded = try? snapshot.encoded()
        suite.expect(encoded.flatMap(ScreenshotLatestCaptureRecord.decode) == snapshot,
                     "one atomic cache blob restores screenshot bytes and identity together")
        suite.expect(ScreenshotLatestCaptureRecord.decode(png) == nil,
                     "an identity-less PNG is not a valid latest-capture record")
        var finished = false
        Task { @MainActor in
            await checks(suite)
            finished = true
        }
        let deadline = Date().addingTimeInterval(10)
        while !finished && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.005))
        }
        suite.expect(finished, "screenshot sharing completion tests finish")
    }

    @MainActor static func checks(_ suite: TestSuite) async {
        let record = ScreenshotShareRecord(id: "test", endpoint: URL(string: "https://example.com")!,
                                          expiresAt: Date().addingTimeInterval(3_600), deleteToken: "test")
        let service = ScreenshotShareService.shared
        AppFeature.available = true
        SharingDefaults.standard.enabled = true
        service.revoked = []
        ScreenTextService.shared.copiedImages = []
        ScreenshotService.shared.autoCopyPending = true
        ScreenshotService.shared.waiting = []
        let ocr = Controller()
        ocr.copyText()
        ocr.copyText()
        suite.expect(ocr.closed && ScreenTextService.shared.copiedImages.isEmpty
                     && ScreenshotService.shared.waiting.count == 1,
                     "Copy text closes at once and waits for a pending after-capture copy")
        ScreenshotService.shared.autoCopyPending = false
        ScreenshotService.shared.waiting.forEach { $0() }
        ScreenshotService.shared.waiting = []
        suite.expect(ScreenTextService.shared.copiedImages == [ocr.capture.image],
                     "preview OCR closes once and recognizes the full-resolution capture")
        AppFeature.ocrAvailable = false
        let disabledOCR = Controller()
        disabledOCR.copyText()
        suite.expect(!disabledOCR.closed && ScreenTextService.shared.copiedImages.count == 1,
                     "a stale OCR button cannot close the preview or start work after OCR is disabled")
        AppFeature.ocrAvailable = true
        let open = Controller()
        open.performShare(.oneHour)
        open.completion?(record)
        suite.expect(open.copies == [record] && open.closed,
                     "upload completion copies and closes before returning, without a deferred handoff")
        for _ in 0..<20 { await Task.yield() }
        suite.expect(service.revoked.isEmpty, "a delivered link stays active")

        let closingAfterCallback = Controller()
        closingAfterCallback.performShare(.oneHour)
        closingAfterCallback.completion?(record)
        closingAfterCallback.closed = true
        for _ in 0..<20 { await Task.yield() }
        suite.expect(closingAfterCallback.copies == [record] || service.revoked == [record],
                     "closing immediately after the callback cannot leave a link neither delivered nor revoked")
        service.revoked = []

        let closed = Controller()
        closed.performShare(.oneHour)
        closed.closed = true
        closed.completion?(record)
        for _ in 0..<20 { await Task.yield() }
        suite.expect(service.revoked == [record] && closed.copies.isEmpty,
                     "closing before upload completion revokes the link without copying it")

        service.revoked = []
        var released: Controller? = Controller()
        released?.performShare(.oneHour)
        let completion = released?.completion
        released = nil
        completion?(record)
        for _ in 0..<20 { await Task.yield() }
        suite.expect(service.revoked == [record], "releasing the preview also revokes an undelivered link")

        for scenario in ["links off", "feature off"] {
            service.revoked = []
            let preview = Controller()
            preview.performShare(.oneHour)
            if scenario == "links off" { SharingDefaults.standard.enabled = false }
            if scenario == "feature off" { AppFeature.available = false }
            preview.completion?(record)
            for _ in 0..<20 { await Task.yield() }
            suite.expect(service.revoked == [record] && preview.copies.isEmpty && !preview.model.sharing,
                         "preview revokes an undelivered link after \(scenario)")
            SharingDefaults.standard.enabled = true
            AppFeature.available = true
        }

        for scenario in ["open", "closed", "links off", "feature off"] {
            service.revoked = []
            let editor = Editor()
            var completed = false
            var delivered: ScreenshotShareRecord?
            editor.share(duration: .oneHour) { result in
                completed = true
                delivered = result
            }
            let uploadDeadline = Date().addingTimeInterval(2)
            while service.uploadCompletion == nil && Date() < uploadDeadline { await Task.yield() }
            suite.expect(service.uploadCompletion != nil, "editor starts its controlled upload")
            if scenario == "closed" { editor.window = nil }
            if scenario == "links off" { SharingDefaults.standard.enabled = false }
            if scenario == "feature off" { AppFeature.available = false }
            service.uploadCompletion?.resume(returning: record)
            service.uploadCompletion = nil
            let completionDeadline = Date().addingTimeInterval(2)
            while !completed && Date() < completionDeadline { await Task.yield() }
            suite.expect(completed, "editor handles its upload response after \(scenario)")
            if scenario == "open" {
                suite.expect(delivered == record && editor.model.exported && service.revoked.isEmpty,
                             "an open editor delivers its requested export")
            } else {
                suite.expect(delivered == nil && !editor.model.exported && service.revoked == [record],
                             "editor revokes its undelivered export after \(scenario)")
            }
            SharingDefaults.standard.enabled = true
            AppFeature.available = true
        }

        for scenario in ["closed", "links off", "feature off"] {
            let gate = RenderingGate()
            ScreenshotRenderer.gate = gate
            let editor = Editor()
            var completed = false
            var delivered: ScreenshotShareRecord?
            editor.share(duration: .oneHour) { result in completed = true; delivered = result }
            let renderDeadline = Date().addingTimeInterval(2)
            while !gate.started && Date() < renderDeadline { await Task.yield() }
            suite.expect(gate.started, "editor starts rendering before \(scenario)")
            if scenario == "closed" { editor.window = nil }
            if scenario == "links off" { SharingDefaults.standard.enabled = false }
            if scenario == "feature off" { AppFeature.available = false }
            gate.resume.signal()
            let completionDeadline = Date().addingTimeInterval(2)
            while !completed && service.uploadCompletion == nil && Date() < completionDeadline {
                await Task.yield()
            }
            suite.expect(completed && delivered == nil && service.uploadCompletion == nil,
                         "editor does not transmit when \(scenario) during PNG preparation")
            // Settle the fake request on an unfixed candidate too, so the
            // regression fails without leaking a checked continuation.
            if let completion = service.uploadCompletion {
                service.uploadCompletion = nil
                completion.resume(throwing: ScreenshotShareError.unavailable)
                for _ in 0..<20 { await Task.yield() }
            }
            ScreenshotRenderer.gate = nil
            SharingDefaults.standard.enabled = true
            AppFeature.available = true
        }

        for scenario in ["enabled", "links off", "feature off"] {
            let gate = CreationGate()
            SharingDefaults.standard.enabled = scenario != "links off"
            AppFeature.available = scenario != "feature off"
            let png = Data([137, 80, 78, 71, 13, 10, 26, 10])
            _ = try? await gate.createLink(pngData: png, duration: .oneHour)
            suite.expect(gate.session.uploads == (scenario == "enabled" ? 1 : 0)
                         && gate.writes == (scenario == "enabled" ? 1 : 0),
                         "service checks \(scenario) before persistence or any upload")
        }
        SharingDefaults.standard.enabled = true
        AppFeature.available = true

        let failedCopy = Controller()
        failedCopy.copySucceeds = false
        failedCopy.performShare(.oneHour)
        failedCopy.completion?(record)
        suite.expect(!failedCopy.closed && failedCopy.model.sharedRecord == record
                     && failedCopy.showingLink && failedCopy.dismissWork != nil,
                     "clipboard failure retains the existing link and copy controls in the preview")

        let retention = LatestCapture()
        ScreenshotLastCaptureStore.stored = nil
        retention.beginLatestCapture(8)
        retention.syncLatestCapture(with: retention.defaults)
        suite.expect(ScreenshotLastCaptureStore.stored == nil,
                     "without Edit latest screenshot, the original is not retained")
        retention.defaults.set(true, forKey: DefaultsKey.screenshotLastCaptureShortcutEnabled)
        retention.beginLatestCapture(9)
        retention.syncLatestCapture(with: retention.defaults)
        suite.expect(ScreenshotLastCaptureStore.stored == 9,
                     "Edit latest screenshot retains the original")
        let token = retention.latestCaptureToken
        retention.discardLatestCapture(UUID())
        suite.expect(!ScreenshotLastCaptureStore.isWithheld,
                     "discarding another capture does not withhold the latest")
        retention.discardLatestCapture(token)
        suite.expect(ScreenshotLastCaptureStore.isWithheld,
                     "discarding the latest preview withholds its raw original")
        retention.beginLatestCapture(10)
        suite.expect(!ScreenshotLastCaptureStore.isWithheld && ScreenshotLastCaptureStore.stored == 10,
                     "the next capture restores normal Edit latest behavior")
        retention.defaults.set(false, forKey: DefaultsKey.screenshotLastCaptureShortcutEnabled)
        retention.syncLatestCapture(with: retention.defaults)
        suite.expect(ScreenshotLastCaptureStore.stored == nil,
                     "switching Edit latest screenshot off clears the cached original")

        // A preview's Copy text waits for the after-capture copy, so the
        // capture lands first and the text, when there is any, replaces it.
        let copying = LatestCapture()
        var recognitions = 0
        copying.afterAutoCopy { recognitions += 1 }
        suite.expect(recognitions == 1, "with no after-capture copy pending, Copy text starts at once")
        var finishCopy: CheckedContinuation<Void, Never>?
        copying.autoCopyTask = Task { @MainActor in
            await withCheckedContinuation { finishCopy = $0 }
        }
        copying.afterAutoCopy { recognitions += 1 }
        let copyDeadline = Date().addingTimeInterval(2)
        while finishCopy == nil && Date() < copyDeadline { await Task.yield() }
        for _ in 0..<20 { await Task.yield() }
        suite.expect(finishCopy != nil && recognitions == 1,
                     "Copy text waits while the after-capture copy is still being prepared")
        finishCopy?.resume()
        while recognitions == 1 && Date() < copyDeadline { await Task.yield() }
        suite.expect(recognitions == 2, "Copy text starts once the after-capture copy is in")
    }
}
