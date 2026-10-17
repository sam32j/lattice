// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum RecordingImportTests {
    private static func entry(day: String = "2026-10-17") -> RecentCaptureEntry {
        let id = UUID()
        return RecentCaptureEntry(
            id: id, kind: .recording, createdAt: Date(timeIntervalSince1970: 1),
            screenshotName: nil, recordingPath: "\(day)/\(id.uuidString).mov", thumbnailName: nil,
            scale: nil, anchorX: nil, anchorY: nil, anchorWidth: nil, anchorHeight: nil)
    }

    static func run(_ suite: TestSuite) {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("RecordingImport-\(UUID())")
        defer { try? manager.removeItem(at: root) }
        do {
            try manager.createDirectory(at: root, withIntermediateDirectories: true)
            let source = root.appendingPathComponent("original.mov")
            let bytes = Data("original recording".utf8)
            try bytes.write(to: source)
            let history = root.appendingPathComponent("history")
            let store = RecentCaptureStore(directoryURL: history)
            let id = UUID()
            let path = "2026-10-17/\(id.uuidString).mov"
            let entry = RecentCaptureEntry(
                id: id, kind: .recording, createdAt: Date(timeIntervalSince1970: 1),
                screenshotName: nil, recordingPath: path, thumbnailName: nil, scale: nil,
                anchorX: nil, anchorY: nil, anchorWidth: nil, anchorHeight: nil)
            suite.expect(store.importRecording(from: source, entry: entry),
                         "the first recording creates and commits its history before reporting success")
            let reloaded = RecentCaptureStore(directoryURL: history)
            suite.expect(reloaded.loadIfNeeded() && reloaded.entries == [entry] && reloaded.persist()
                         && (try? Data(contentsOf: history.appendingPathComponent(path))) == bytes
                         && (try? Data(contentsOf: source)) == bytes,
                         "a committed recording survives reload and cleanup without changing its source")
            suite.expect(!store.importRecording(from: source, entry: entry)
                         && (try? Data(contentsOf: history.appendingPathComponent(path))) == bytes
                         && store.entries == [entry],
                         "a destination collision never replaces a committed movie or its index entry")

            let failed = Self.entry()
            let index = history.appendingPathComponent("history.json")
            try manager.removeItem(at: index)
            try manager.createDirectory(at: index, withIntermediateDirectories: false)
            suite.expect(!store.importRecording(from: source, entry: failed)
                         && store.entries == [entry]
                         && !manager.fileExists(atPath: history.appendingPathComponent(failed.recordingPath!).path)
                         && (try? Data(contentsOf: source)) == bytes,
                         "an index write failure rolls back the copy and entry while preserving the original")
            try manager.removeItem(at: index)
            suite.expect(store.importRecording(from: source, entry: failed)
                         && Set(store.entries.map(\.id)) == Set([entry.id, failed.id]),
                         "a failed import can retry once the index is writable")
            let saved = history.appendingPathComponent(failed.recordingPath!)
            let mode = try manager.attributesOfItem(atPath: saved.path)[.posixPermissions] as? Int
            suite.expect(mode == 0o600, "imported recordings remain private to their owner")

            let escaped = Self.entry(day: "2026-10-18")
            let outside = root.appendingPathComponent("outside")
            try manager.createDirectory(at: outside, withIntermediateDirectories: true)
            try manager.createSymbolicLink(at: history.appendingPathComponent("2026-10-18"),
                                           withDestinationURL: outside)
            suite.expect(!store.importRecording(from: source, entry: escaped)
                         && (try? manager.contentsOfDirectory(atPath: outside.path))?.isEmpty == true,
                         "a dated-folder symlink never redirects a recording outside history storage")
        } catch {
            suite.expect(false, "recording import fixture: \(error)")
        }
    }
}
