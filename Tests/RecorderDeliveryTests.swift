// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Uses production delivery methods extracted by generate_sources.py with
/// lightweight file, preview, clipboard and preference doubles.
enum RecorderDeliveryTests {
    enum DefaultsKey {
        static let recorderAddToFileCache = "recorderAddToFileCache"
        static let shelfEnabled = "shelfEnabled"
        static let recorderSaveAutomatically = "recorderSaveAutomatically"
        static let recorderOpenEditor = "recorderOpenEditor"
        static let recorderCopyAfterRecording = "recorderCopyAfterRecording"
    }
    enum AppFeature {
        enum shelf { static let isAvailable = true }
    }
    final class RecorderTakeStore {
        struct Take { let id: UUID; let videoURL: URL; let startedAt: Date = Date() }
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
        var prefersHardLink: [Bool] = []
        func stashRecording(from url: URL, preferHardLink: Bool = false,
                            completion: @escaping (URL?) -> Void) {
            prefersHardLink.append(preferHardLink)
            replies.append(completion)
        }
    }
    final class ShelfService {
        static let shared = ShelfService()
        var copies: [URL] = []
        func shelveRecordingCopy(from source: URL) { copies.append(source) }
    }
    enum RecorderFileCopy {
        static var copies: [(from: URL, to: URL)] = []
        static func save(from: URL, to: URL, replacing: Bool) throws {
            copies.append((from, to))
        }
    }
    enum CaptureSaveLocation {
        static func presentSaveError(_ error: Error) {}
        static func withFolder<T>(_ operation: (URL) throws -> T) throws -> T {
            try operation(URL(fileURLWithPath: "/exports", isDirectory: true))
        }
    }
    enum CaptureSaveNaming {
        enum Media { case recording }
        static func copyFile(from source: URL, in folder: URL, date: Date,
                             media: Media, ext: String) throws -> URL {
            let destination = folder.appendingPathComponent("recording.\(ext)")
            try RecorderFileCopy.save(from: source, to: destination, replacing: false)
            return destination
        }
    }
    final class RecorderQuickPreviewController {
        static let shared = RecorderQuickPreviewController()
        var previews: [URL] = []
        func show(url: URL) { previews.append(url) }
    }
    final class NSPasteboard {
        static let general = NSPasteboard()
        var copied: [NSURL] = []
        func clearContents() { copied = [] }
        func writeObjects(_ urls: [NSURL]) -> Bool { copied = urls; return true }
        func declareLatticeSource() {}
    }
    enum NSSound { static func beep() {} }
    enum QuickToolHUD {
        static var messages = 0
        static func show(icon: String, message: String) { messages += 1 }
    }
    class State {
        struct Editor { let takeID: UUID }
        struct Session { let take: RecorderTakeStore.Take }
        struct Strings {
            let exportFailed = "failed"
            let recordFailed = "failed to save"
            let savedHUDFormat = "Saved in %@"
        }
        let defaults: UserDefaults
        var strings = Strings()
        var editors: [Editor] = []
        var session: Session?
        var pendingDeliveryTakeIDs = Set<UUID>()
        var editorSucceeds = true
        var preserved: URL?

        init() {
            defaults = UserDefaults(suiteName: "io.github.sam32j.lattice.tests.recorder.delivery.\(UUID())")!
        }
        class func saveDestination(strings: Strings, fileExtension: String) -> URL {
            URL(fileURLWithPath: "/exports/recording.\(fileExtension)")
        }
        func openEditor(with take: RecorderTakeStore.Take, preservedRecordingURL: URL?) -> Bool {
            if editorSucceeds { editors.append(Editor(takeID: take.id)); preserved = preservedRecordingURL }
            return editorSucceeds
        }
    }
    static func run(_ suite: TestSuite) {
        let stash = RecentCaptureService.shared
        let preview = RecorderQuickPreviewController.shared
        defer {
            stash.replies = []
            ShelfService.shared.copies = []
            stash.prefersHardLink = []
            preview.previews = []
            RecorderFileCopy.copies = []
            NSPasteboard.general.clearContents()
            QuickToolHUD.messages = 0
        }
        let take = RecorderTakeStore.Take(id: UUID(), videoURL: URL(fileURLWithPath: "/take.mov"))
        let preserved = URL(fileURLWithPath: "/history/preserved.mov")
        let service = Service()
        service.deliver(take, reason: nil)
        suite.expect(service.pendingDeliveryTakeIDs.contains(take.id)
                     && stash.replies.count == 1 && service.editors.isEmpty,
                     "delivery owns its take throughout asynchronous preservation")
        RecorderTakeStore.shared.reset()
        service.sweepTakes()
        RecordingStashTests.wait { RecorderTakeStore.shared.result() != nil }
        suite.expect(RecorderTakeStore.shared.result()?.contains(take.id) == true,
                     "orphan cleanup keeps a take while its preservation callback is pending")
        stash.replies.removeFirst()(preserved)
        suite.expect(service.pendingDeliveryTakeIDs.isEmpty && service.editors.first?.takeID == take.id
                     && service.preserved == preserved && preview.previews.isEmpty,
                     "cache delivery opens editor without unwanted quick preview")
        RecorderTakeStore.shared.reset()
        service.sweepTakes()
        RecordingStashTests.wait { RecorderTakeStore.shared.result() != nil }
        suite.expect(RecorderTakeStore.shared.result()?.contains(take.id) == true,
                     "editor retains the take after asynchronous delivery completes")

        let lowSpace = Service()
        lowSpace.deliver(take, reason: "disk full")
        suite.expect(stash.replies.count == 1 && stash.prefersHardLink.last == true
                     && lowSpace.pendingDeliveryTakeIDs.contains(take.id),
                     "low-space stops preserve a take without allocating another movie")
        stash.replies.removeFirst()(preserved)
        suite.expect(RecorderFileCopy.copies.isEmpty && lowSpace.editors.count == 1
                     && lowSpace.pendingDeliveryTakeIDs.isEmpty,
                     "low-space completion presents editor after private preservation")

        let failedEditor = Service()
        failedEditor.editorSucceeds = false
        failedEditor.deliver(take, reason: nil)
        stash.replies.removeFirst()(nil)
        suite.expect(RecorderFileCopy.copies.isEmpty && failedEditor.pendingDeliveryTakeIDs.isEmpty
                     && preview.previews.last == take.videoURL,
                     "failed history preservation or editor opening falls back to the take preview")

        preview.previews = []
        let directPreview = Service()
        directPreview.defaults.set(false, forKey: DefaultsKey.recorderOpenEditor)
        directPreview.defaults.set(false, forKey: DefaultsKey.recorderAddToFileCache)
        directPreview.deliver(take, reason: nil)
        suite.expect(stash.replies.count == 1,
                     "File Cache off never skips Recent Captures preservation")
        stash.replies.removeFirst()(preserved)
        suite.expect(RecorderFileCopy.copies.isEmpty && preview.previews == [preserved]
                     && ShelfService.shared.copies.isEmpty,
                     "without File Cache, the history copy remains and no Shelf copy is created")

        preview.previews = []
        let saved = Service()
        saved.defaults.set(false, forKey: DefaultsKey.recorderOpenEditor)
        saved.defaults.set(false, forKey: DefaultsKey.recorderAddToFileCache)
        saved.defaults.set(true, forKey: DefaultsKey.recorderSaveAutomatically)
        saved.defaults.set(true, forKey: DefaultsKey.recorderCopyAfterRecording)
        saved.deliver(take, reason: nil)
        suite.expect(stash.replies.count == 1,
                     "automatic export never prevents the private recording copy")
        stash.replies.removeFirst()(preserved)
        let destination = URL(fileURLWithPath: "/exports/recording.mov")
        suite.expect(RecorderFileCopy.copies.count == 1
                     && RecorderFileCopy.copies[0].from == take.videoURL
                     && RecorderFileCopy.copies[0].to == destination
                     && preview.previews == [preserved]
                     && NSPasteboard.general.copied.first == (preserved as NSURL)
                     && ShelfService.shared.copies.isEmpty,
                     "auto export and clipboard are independent; File Cache remains disabled")

        let cached = Service()
        cached.defaults.set(false, forKey: DefaultsKey.recorderOpenEditor)
        cached.defaults.set(true, forKey: DefaultsKey.recorderAddToFileCache)
        cached.defaults.set(true, forKey: DefaultsKey.shelfEnabled)
        cached.deliver(take, reason: nil)
        suite.expect(stash.replies.count == 1,
                     "File Cache on still creates the Recent Captures entry")
        stash.replies.removeFirst()(preserved)
        suite.expect(ShelfService.shared.copies == [preserved],
                     "File Cache on adds exactly one Shelf-owned recording copy")

        ShelfService.shared.copies.removeAll()
        let disabledShelf = Service()
        disabledShelf.defaults.set(false, forKey: DefaultsKey.recorderOpenEditor)
        disabledShelf.defaults.set(true, forKey: DefaultsKey.recorderAddToFileCache)
        disabledShelf.defaults.set(false, forKey: DefaultsKey.shelfEnabled)
        disabledShelf.deliver(take, reason: nil)
        stash.replies.removeFirst()(preserved)
        suite.expect(ShelfService.shared.copies.isEmpty,
                     "globally disabled File Cache does not receive hidden new files")
    }
}
