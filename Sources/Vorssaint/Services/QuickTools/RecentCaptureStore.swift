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
        if recordingPath.hasPrefix("/") {
            return URL(fileURLWithPath: recordingPath)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("io.github.sam32j.lattice", isDirectory: true)
            .appendingPathComponent("RecentCaptures", isDirectory: true)
        return base?.appendingPathComponent(recordingPath)
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
                let hasRootCaptures = files.contains(where: Self.isCaptureFileName)
                let hasDateFolderCaptures = files.contains { item in
                    Self.isDateFolderName(item) &&
                    ((try? manager.contentsOfDirectory(atPath: resolvedDir.appendingPathComponent(item).path)) ?? [])
                        .contains(where: Self.isCaptureFileName)
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

    /// Called on the history queue, so cleanup cannot observe the copied movie
    /// until its index entry is committed. A failed commit leaves the source intact.
    func importRecording(from sourceURL: URL, entry: RecentCaptureEntry) -> Bool {
        guard loadIfNeeded(), entry.kind == .recording,
              let path = entry.recordingPath, Self.isSafeRelativePath(path),
              Self.isRegularFile(sourceURL), let directoryURL else { return false }
        let root = directoryURL.resolvingSymlinksInPath()
        let destination = root.appendingPathComponent(path)
        let parent = destination.deletingLastPathComponent()
        guard parent.resolvingSymlinksInPath().path == parent.path else { return false }
        let previous = entries
        var copied = false
        do {
            try prepareRoot(parent)
            try manager.copyItem(at: sourceURL, to: destination)
            copied = true
            try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
            entries.append(entry)
            entries.sort { $0.createdAt > $1.createdAt }
            guard persist() else { throw CocoaError(.fileWriteUnknown) }
            return true
        } catch {
            entries = previous
            if copied, destination.path.hasPrefix(root.path) {
                try? manager.removeItem(at: destination)
            }
            return false
        }
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
        let referencedRecordings = Set(entries.compactMap { $0.recordingPath })
        let referencedCaptures = referencedScreenshots.union(referencedRecordings)
        let referencedThumbnails = Set(entries.compactMap { $0.thumbnailName })
        let referencedIDs = Set(entries.map { $0.id.uuidString })

        func isReferenced(_ relativePath: String, fileName: String) -> Bool {
            if referencedCaptures.contains(relativePath) || referencedThumbnails.contains(relativePath)
                || referencedThumbnails.contains(fileName) {
                return true
            }
            for id in referencedIDs {
                if fileName.hasPrefix(id) {
                    return true
                }
            }
            return false
        }

        // Both durable captures and derived caches may use dated folders.
        // Never descend into a symlink, including one shaped like a date.
        func sweep(_ directory: URL) {
            for item in contents(of: directory) {
                let name = item.lastPathComponent
                guard let values = try? item.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey]),
                      values.isSymbolicLink != true else { continue }

                if values.isRegularFile == true {
                    if Self.isCaptureFileName(name),
                       !isReferenced(name, fileName: name) {
                        try? manager.removeItem(at: item)
                    }
                } else if values.isDirectory == true, Self.isDateFolderName(name) {
                    for file in contents(of: item) {
                        let fileName = file.lastPathComponent
                        guard Self.isRegularFile(file), Self.isCaptureFileName(fileName),
                              !isReferenced("\(name)/\(fileName)", fileName: fileName) else { continue }
                        try? manager.removeItem(at: file)
                    }
                    if let remaining = try? manager.contentsOfDirectory(atPath: item.path), remaining.isEmpty {
                        try? manager.removeItem(at: item)
                    }
                }
            }
        }
        sweep(resolvedDir)

        guard let thumbDir = thumbnailDirectoryURL?.resolvingSymlinksInPath(), thumbDir != resolvedDir
        else { return }
        sweep(thumbDir)
    }

    private func contents(of directory: URL) -> [URL] {
        (try? manager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles])) ?? []
    }

    static func isRegularFile(_ url: URL) -> Bool {
        var currentURL = url
        currentURL.removeAllCachedResourceValues()
        guard let values = try? currentURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
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

    static func isCaptureFileName(_ name: String) -> Bool {
        guard name == URL(fileURLWithPath: name).lastPathComponent else { return false }
        let lower = name.lowercased()
        if lower.hasSuffix(".latticecapture") {
            return UUID(uuidString: String(name.dropLast(".latticecapture".count))) != nil
        }
        if lower.hasSuffix(".png") {
            return ScreenshotSupport.isRecentCaptureCacheFileName(name)
        }
        if lower.hasSuffix(".mov") || lower.hasSuffix(".mp4") {
            let stem = String(name.dropLast(4))
            return UUID(uuidString: stem) != nil
        }
        if lower.hasSuffix(".json") {
            let stem = String(name.dropLast(5))
            let suffix = "-annotations"
            return stem.hasSuffix(suffix)
                && UUID(uuidString: String(stem.dropLast(suffix.count))) != nil
        }
        return false
    }

    static func isSafeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("..") else { return false }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        if parts.count == 1 {
            let name = String(parts[0])
            return isCaptureFileName(name)
        } else if parts.count == 2 {
            let dir = String(parts[0])
            let name = String(parts[1])
            return isDateFolderName(dir) && isCaptureFileName(name)
        }
        return false
    }
}
