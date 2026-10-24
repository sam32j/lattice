// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import Foundation

struct RecentDownloadItem: Identifiable, Codable, Equatable {
    let id: UUID
    let fileURL: URL
    let title: String
    let qualityTag: String
    let fileSize: Int64
    let date: Date

    var formattedSubtitle: String {
        let df = ByteCountFormatter()
        df.countStyle = .file
        let sizeStr = df.string(fromByteCount: fileSize)

        let dateStr: String
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            dateStr = "Today, \(timeFormatter.string(from: date))"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            dateStr = dateFormatter.string(from: date)
        }

        return "\(qualityTag) · \(sizeStr) · \(dateStr)"
    }
}

final class DownloadHistoryStore: ObservableObject {
    static let shared = DownloadHistoryStore()
    @Published private(set) var items: [RecentDownloadItem] = []

    private let storeURL: URL

    init(storeURL: URL? = nil) {
        if let storeURL {
            self.storeURL = storeURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
            self.storeURL = appSupport.appendingPathComponent("Lattice/VideoDownloader/history.json")
        }
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([RecentDownloadItem].self, from: data) else {
            return
        }
        items = decoded
    }

    func record(fileURL: URL, title: String, qualityTag: String) {
        let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap(Int64.init) ?? 0
        let item = RecentDownloadItem(
            id: UUID(),
            fileURL: fileURL,
            title: title,
            qualityTag: qualityTag,
            fileSize: size,
            date: Date()
        )

        // Filter out if file already exists in recent, insert at front, limit to 5
        var current = items.filter { $0.fileURL != fileURL }
        current.insert(item, at: 0)
        if current.count > 5 {
            current = Array(current.prefix(5))
        }
        items = current
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    private func save() {
        let manager = FileManager.default
        let folder = storeURL.deletingLastPathComponent()
        try? manager.createDirectory(at: folder, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: storeURL, options: .atomic)
        }
    }
}
