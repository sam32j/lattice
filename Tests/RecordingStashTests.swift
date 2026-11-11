// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum RecordingStashTests {
    typealias CGImage = Int
    class State {
        let queue = DispatchQueue(label: "recording-stash-test")
        let capturesRoot: URL?
        let store: RecentCaptureStore
        var generation = 0
        static var thumbnailStarted: (() -> Void)?
        static let dayFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter
        }()
        init(root: URL) {
            capturesRoot = root
            store = RecentCaptureStore(directoryURL: root)
        }
        func currentClearGeneration() -> Int { generation }
        func publish() {}
        func pruneMissingEntries() {}
        static func recordingThumbnail(at url: URL) async -> CGImage? {
            thumbnailStarted?()
            return nil
        }
        func storeRecording(at url: URL, recordingPath: String, id: UUID, createdAt: Date,
                            thumbnailName: String, thumbnail: CGImage?, generation: Int) {}
    }

    static func wait(until finished: () -> Bool) {
        let deadline = Date().addingTimeInterval(2)
        while !finished(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    static func run(_ suite: TestSuite) {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("RecordingStash-\(UUID())")
        defer {
            State.thumbnailStarted = nil
            try? manager.removeItem(at: root)
        }
        do {
            try manager.createDirectory(at: root, withIntermediateDirectories: true)
            let source = root.appendingPathComponent("original.mov")
            let bytes = Data("recording before thumbnail".utf8)
            try bytes.write(to: source)
            let service = Service(root: root.appendingPathComponent("history"))
            var confirmed: URL?
            var thumbnailChecked = false
            var retainedDuringCleanup = false
            State.thumbnailStarted = {
                service.queue.sync {
                    retainedDuringCleanup = service.store.persist()
                        && service.store.entries.count == 1
                        && confirmed.map { (try? Data(contentsOf: $0)) == bytes } == true
                }
                thumbnailChecked = true
            }
            service.stashRecording(from: source) { confirmed = $0 }
            wait { thumbnailChecked }
            suite.expect(thumbnailChecked && confirmed != nil && retainedDuringCleanup,
                         "cleanup during thumbnail generation cannot delete a committed recording")
            suite.expect((try? Data(contentsOf: source)) == bytes,
                         "history preservation leaves the original take untouched")

            // History is committed regardless of the user's Shelf preference.
            let history = Service(root: root.appendingPathComponent("second-history"))
            var historyURL: URL?
            history.stashRecording(from: source) { historyURL = $0 }
            wait { historyURL != nil }
            suite.expect(historyURL != nil
                         && history.store.loadIfNeeded()
                         && history.store.entries.count == 1
                         && history.store.persist()
                         && historyURL.map { (try? Data(contentsOf: $0)) == bytes } == true,
                         "every finished recording gets a history entry")

            // Low-space stops use a hard link when the private take and cache
            // are on the same volume; deleting the original still preserves it.
            let lowSpaceSource = root.appendingPathComponent("low-space.mov")
            try bytes.write(to: lowSpaceSource)
            let lowSpace = Service(root: root.appendingPathComponent("low-space-history"))
            var lowSpaceURL: URL?
            lowSpace.stashRecording(from: lowSpaceSource,
                                    preferHardLink: true) { lowSpaceURL = $0 }
            wait { lowSpaceURL != nil }
            try manager.removeItem(at: lowSpaceSource)
            suite.expect(lowSpaceURL.map { (try? Data(contentsOf: $0)) == bytes } == true,
                         "low-space preservation survives private take deletion")

            State.thumbnailStarted = nil
            let brokenRoot = root.appendingPathComponent("broken")
            try manager.createDirectory(at: brokenRoot, withIntermediateDirectories: true)
            try Data("broken index".utf8).write(to: brokenRoot.appendingPathComponent("history.json"))
            let broken = Service(root: brokenRoot)
            var replied = false
            var failedURL: URL?
            broken.stashRecording(from: source) { failedURL = $0; replied = true }
            wait { replied }
            suite.expect(replied && failedURL == nil && (try? Data(contentsOf: source)) == bytes,
                         "failed history loading reports no preserved URL and retains the source")
        } catch {
            suite.expect(false, "recording stash fixture: \(error)")
        }
    }
}
