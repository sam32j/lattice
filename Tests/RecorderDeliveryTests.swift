// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

enum RecorderDeliveryTests {
    final class RecorderTakeStore {
        struct Take { let id: UUID; let videoURL: URL }
        static let shared = RecorderTakeStore()
        private let lock = NSLock()
        private var owned: Set<UUID>?
        func sweep(keeping ids: Set<UUID>) { lock.lock(); owned = ids; lock.unlock() }
        func result() -> Set<UUID>? { lock.lock(); defer { lock.unlock() }; return owned }
        func reset() { lock.lock(); owned = nil; lock.unlock() }
    }
    final class RecentCaptureService {
        static let shared = RecentCaptureService()
        var replies: [(URL?) -> Void] = []
        func stashRecording(from url: URL, completion: @escaping (URL?) -> Void) { replies.append(completion) }
    }
    enum QuickToolHUD {
        static var messages = 0
        static func show(icon: String, message: String) { messages += 1 }
    }
    class State {
        struct Editor { let takeID: UUID }
        struct Session { let take: RecorderTakeStore.Take }
        struct Strings { let exportFailed = "failed" }
        var strings = Strings()
        var editors: [Editor] = []
        var session: Session?
        var pendingDeliveryTakeIDs = Set<UUID>()
        var opensEditor = true, editorSucceeds = true
        var saves = 0
        var preserved: URL?
        func openEditor(with take: RecorderTakeStore.Take, preservedRecordingURL: URL?) -> Bool {
            if editorSucceeds { editors.append(Editor(takeID: take.id)); preserved = preservedRecordingURL }
            return editorSucceeds
        }
        func saveDirect(_ take: RecorderTakeStore.Take, reason: String?) { saves += 1 }
    }
    static func run(_ suite: TestSuite) {
        defer { RecentCaptureService.shared.replies = []; QuickToolHUD.messages = 0 }
        let take = RecorderTakeStore.Take(id: UUID(), videoURL: URL(fileURLWithPath: "/take.mov"))
        let service = Service()
        service.deliver(take, reason: nil)
        suite.expect(service.pendingDeliveryTakeIDs.contains(take.id)
                     && RecentCaptureService.shared.replies.count == 1 && service.editors.isEmpty,
                     "delivery owns its take throughout asynchronous preservation")
        RecorderTakeStore.shared.reset()
        service.sweepTakes()
        RecordingStashTests.wait { RecorderTakeStore.shared.result() != nil }
        suite.expect(RecorderTakeStore.shared.result()?.contains(take.id) == true,
                     "orphan cleanup keeps a take while its preservation callback is pending")
        let url = URL(fileURLWithPath: "/history/preserved.mov")
        RecentCaptureService.shared.replies.removeFirst()(url)
        suite.expect(service.pendingDeliveryTakeIDs.isEmpty && service.editors.first?.takeID == take.id
                     && service.preserved == url, "preservation callback transfers ownership into the editor")
        RecorderTakeStore.shared.reset()
        service.sweepTakes()
        RecordingStashTests.wait { RecorderTakeStore.shared.result() != nil }
        suite.expect(RecorderTakeStore.shared.result()?.contains(take.id) == true,
                     "editor retains the take after asynchronous delivery completes")
        let lowSpace = Service()
        lowSpace.deliver(take, reason: "disk full")
        suite.expect(lowSpace.saves == 1 && lowSpace.pendingDeliveryTakeIDs.isEmpty
                     && RecentCaptureService.shared.replies.isEmpty,
                     "low-space stops save directly without a redundant full-sized history copy")
        let failedEditor = Service()
        failedEditor.editorSucceeds = false
        failedEditor.deliver(take, reason: nil)
        RecentCaptureService.shared.replies.removeFirst()(nil)
        suite.expect(failedEditor.saves == 1 && failedEditor.pendingDeliveryTakeIDs.isEmpty,
                     "failed preservation and editor delivery save directly then release pending ownership")
    }
}
