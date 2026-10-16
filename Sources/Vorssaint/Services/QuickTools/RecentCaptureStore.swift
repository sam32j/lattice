// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct RecentCaptureEntry: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        case screenshot
        case recording
    }

    let id: UUID
    let kind: Kind
    let createdAt: Date
    let screenshotName: String?
    let recordingPath: String?
    let thumbnailName: String?
    let scale: Double?
    let anchorX: Double?
    let anchorY: Double?
    let anchorWidth: Double?
    let anchorHeight: Double?

    var recordingURL: URL? {
        guard let recordingPath else { return nil }
        return URL(fileURLWithPath: recordingPath)
    }
}

/// Queue-confined history storage. Only a readable index permits writes, and
/// only a committed index permits cleanup of the files it no longer references.
final class RecentCaptureStore {
    let directoryURL: URL?
    let thumbnailDirectoryURL: URL?
    var entries: [RecentCaptureEntry] = []
    private var loaded = false
    private var persistedEntries: [RecentCaptureEntry]?
    private let manager = FileManager.default

    init(directoryURL: URL?, thumbnailDirectoryURL: URL? = nil) {
        self.directoryURL = directoryURL
        self.thumbnailDirectoryURL = thumbnailDirectoryURL ?? directoryURL
    }

    func loadIfNeeded() -> Bool {
        if loaded { return true }
        guard let directoryURL else { return false }
        let resolvedDir = directoryURL.resolvingSymlinksInPath()
        let indexURL = resolvedDir.appendingPathComponent("history.json")
        do {
            try prepareRoot(resolvedDir)
            let decoded: [RecentCaptureEntry]
            do {
                let values = try indexURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                decoded = try JSONDecoder().decode([RecentCaptureEntry].self,
                                                    from: Data(contentsOf: indexURL))
                persistedEntries = decoded
            } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
                // A missing index with existing captures is also an unreadable
                // history, not permission to erase those captures on the next save.
                let files = (try? manager.contentsOfDirectory(atPath: resolvedDir.path)) ?? []
                let hasRootCaptures = files.contains(where: ScreenshotSupport.isRecentCaptureCacheFileName)
                let hasDateFolderCaptures = files.contains { item in
                    Self.isDateFolderName(item) &&
                    ((try? manager.contentsOfDirectory(atPath: resolvedDir.appendingPathComponent(item).path)) ?? [])
                        .contains(where: ScreenshotSupport.isRecentCaptureCacheFileName)
                }
                guard !hasRootCaptures && !hasDateFolderCaptures else {
                    return false
                }
                decoded = []
            }
            entries = decoded.sorted { $0.createdAt > $1.createdAt }
            loaded = true
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func persist() -> Bool {
        guard loaded, let directoryURL else { return false }
        let resolvedDir = directoryURL.resolvingSymlinksInPath()
        if entries != persistedEntries {
            do {
                try prepareRoot(resolvedDir)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                try Self.write(encoder.encode(entries),
                                to: resolvedDir.appendingPathComponent("history.json"))
                persistedEntries = entries
            } catch {
                return false
            }
        }
        removeOrphanedFiles()
        return true
    }

    private func prepareRoot(_ root: URL) throws {
        let resolved = root.resolvingSymlinksInPath()
        try manager.createDirectory(at: resolved, withIntermediateDirectories: true,
                                    attributes: [.posixPermissions: 0o700])
        let values = try resolved.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: resolved.path)
    }

    static func write(_ data: Data, to url: URL) throws {
        let manager = FileManager.default
        let parent = url.deletingLastPathComponent().resolvingSymlinksInPath()
        if !manager.fileExists(atPath: parent.path) {
            try manager.createDirectory(at: parent, withIntermediateDirectories: true,
                                        attributes: [.posixPermissions: 0o700])
        }
        if manager.fileExists(atPath: url.path),
           (try url.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink == true {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        try data.write(to: url, options: .atomic)
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func removeOrphanedFiles() {
        guard let directoryURL else { return }
        let resolvedDir = directoryURL.resolvingSymlinksInPath()
        let referencedScreenshots = Set(entries.compactMap { $0.screenshotName })
        let referencedThumbnails = Set(entries.compactMap { $0.thumbnailName })

        // Sweep capture directory (both root legacy files and date subfolders)
        if let items = try? manager.contentsOfDirectory(
            at: resolvedDir,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]) {
            for item in items {
                let name = item.lastPathComponent
                if name == "history.json" { continue }
                guard let values = try? item.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey]),
                      values.isSymbolicLink != true else { continue }

                if values.isRegularFile == true {
                    if ScreenshotSupport.isRecentCaptureCacheFileName(name) {
                        if !referencedScreenshots.contains(name) && !referencedThumbnails.contains(name) {
                            try? manager.removeItem(at: item)
                        }
                    }
                } else if values.isDirectory == true, Self.isDateFolderName(name) {
                    if let dayFiles = try? manager.contentsOfDirectory(
                        at: item,
                        includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                        options: [.skipsHiddenFiles]) {
                        for dayFile in dayFiles {
                            let fileName = dayFile.lastPathComponent
                            let relativePath = "\(name)/\(fileName)"
                            guard Self.isRegularFile(dayFile),
                                  ScreenshotSupport.isRecentCaptureCacheFileName(fileName) else { continue }
                            if !referencedScreenshots.contains(relativePath) {
                                try? manager.removeItem(at: dayFile)
                            }
                        }
                    }
                    if let remaining = try? manager.contentsOfDirectory(atPath: item.path), remaining.isEmpty {
                        try? manager.removeItem(at: item)
                    }
                }
            }
        }

        // Sweep thumbnail directory if separate
        if let thumbDir = thumbnailDirectoryURL?.resolvingSymlinksInPath(), thumbDir != resolvedDir {
            if let thumbFiles = try? manager.contentsOfDirectory(
                at: thumbDir,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]) {
                for file in thumbFiles {
                    let name = file.lastPathComponent
                    guard Self.isRegularFile(file),
                          ScreenshotSupport.isRecentCaptureCacheFileName(name),
                          name.contains("-thumbnail") else { continue }
                    if !referencedThumbnails.contains(name) {
                        try? manager.removeItem(at: file)
                    }
                }
            }
        }
    }

    static func isRegularFile(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        else { return false }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    static func isDateFolderName(_ name: String) -> Bool {
        guard name.count == 10 else { return false }
        let parts = name.split(separator: "-")
        guard parts.count == 3,
              parts[0].count == 4, Int(parts[0]) != nil,
              parts[1].count == 2, let m = Int(parts[1]), (1...12).contains(m),
              parts[2].count == 2, let d = Int(parts[2]), (1...31).contains(d)
        else { return false }
        return true
    }

    static func isSafeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("..") else { return false }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        if parts.count == 1 {
            let name = String(parts[0])
            return ScreenshotSupport.isRecentCaptureCacheFileName(name)
        } else if parts.count == 2 {
            let dir = String(parts[0])
            let name = String(parts[1])
            return isDateFolderName(dir) && ScreenshotSupport.isRecentCaptureCacheFileName(name)
        }
        return false
    }
}
