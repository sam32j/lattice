// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Foundation

/// Expiring media-to-link association index. The deletion tokens remain in the
/// existing share services' private Application Support stores. This small
/// index lives beside RecentCaptures thumbnails in Caches and is disposable.
@MainActor
final class QuickLinkMediaIndex {
    static let shared = QuickLinkMediaIndex()

    private struct Entry: Codable, Equatable {
        let mediaKey: String
        let linkID: String
        let expiresAt: Date
        let createdAt: Date
    }

    private var entries: [Entry] = []
    private var nextCleanup: DispatchWorkItem?

    private static var fileURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("io.github.sam32j.lattice", isDirectory: true)
            .appendingPathComponent("RecentCaptures", isDirectory: true)
            .appendingPathComponent("quick-links.json", isDirectory: false)
    }

    private init() {
        if let url = Self.fileURL,
           RecentCaptureStore.isRegularFile(url),
           let data = try? Data(contentsOf: url),
           let restored = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = restored
        }
        cleanup()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.cleanup() }
        }
    }

    func latestScreenshot(for captureID: UUID) -> ScreenshotShareRecord? {
        cleanup()
        let key = "screenshot:\(captureID.uuidString)"
        guard let id = entries.last(where: { $0.mediaKey == key })?.linkID else { return nil }
        return ScreenshotShareService.shared.records.first(where: { $0.id == id })
    }

    func latestRecording(for source: URL) -> RecordingShareRecord? {
        cleanup()
        let key = Self.recordingKey(source)
        guard let id = entries.last(where: { $0.mediaKey == key })?.linkID else { return nil }
        return RecordingShareService.shared.records.first(where: { $0.id == id })
    }

    func rememberScreenshot(_ captureID: UUID, record: ScreenshotShareRecord) {
        remember(mediaKey: "screenshot:\(captureID.uuidString)",
                 linkID: record.id, expiresAt: record.expiresAt)
    }

    func rememberRecording(_ source: URL, record: RecordingShareRecord) {
        remember(mediaKey: Self.recordingKey(source),
                 linkID: record.id, expiresAt: record.expiresAt)
    }

    func forget(linkID: String) {
        let previous = entries.count
        entries.removeAll { $0.linkID == linkID }
        if entries.count != previous { save() }
        scheduleCleanup()
    }

    private static func recordingKey(_ source: URL) -> String {
        "recording:\(source.standardizedFileURL.path)"
    }

    private func remember(mediaKey: String, linkID: String, expiresAt: Date) {
        // Every generated link is retained; the newest valid one wins.
        entries.removeAll { $0.linkID == linkID }
        entries.append(Entry(mediaKey: mediaKey, linkID: linkID,
                             expiresAt: expiresAt, createdAt: Date()))
        cleanup()
    }

    private func cleanup() {
        let now = Date()
        ScreenshotShareService.shared.refresh(now: now)
        RecordingShareService.shared.refresh(now: now)
        let screenshotIDs = Set(ScreenshotShareService.shared.records.map(\.id))
        let recordingIDs = Set(RecordingShareService.shared.records.map(\.id))
        let before = entries
        entries = entries.filter { entry in
            guard entry.expiresAt > now else { return false }
            if entry.mediaKey.hasPrefix("screenshot:") {
                return screenshotIDs.contains(entry.linkID)
            }
            guard entry.mediaKey.hasPrefix("recording:") else { return false }
            let path = String(entry.mediaKey.dropFirst("recording:".count))
            return recordingIDs.contains(entry.linkID)
                && FileManager.default.fileExists(atPath: path)
        }
        // Bounded even under frequent regenerate actions; expired or deleted
        // records are removed at launch, on wake, on access, and at expiry.
        if entries.count > 1_000 { entries.removeFirst(entries.count - 1_000) }
        if entries != before { save() }
        scheduleCleanup()
    }

    private func scheduleCleanup() {
        nextCleanup?.cancel()
        nextCleanup = nil
        guard let expiry = entries.map(\.expiresAt).min() else { return }
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in self?.cleanup() }
        }
        nextCleanup = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + max(0.1, expiry.timeIntervalSinceNow + 0.1),
            execute: work)
    }

    private func save() {
        guard let url = Self.fileURL,
              let data = try? JSONEncoder().encode(entries) else { return }
        try? RecentCaptureStore.write(data, to: url)
    }
}
