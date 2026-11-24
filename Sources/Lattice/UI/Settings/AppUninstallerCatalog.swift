// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import Foundation

/// The installed apps the App Uninstaller tab lists, with what each row shows
/// beyond its name: version, size on disk, the Homebrew cask that manages it
/// and whether it is running. The list arrives first; sizes and casks fill in
/// as they are read, off the main thread.
@MainActor
final class AppUninstallerCatalog: ObservableObject {
    static let shared = AppUninstallerCatalog()

    struct Entry: Identifiable, Equatable {
        let id: String
        let name: String
        let bundleID: String?
        let url: URL
        let version: String?
        var size: Int64?
        var cask: String?
        var running: Bool
    }

    enum Scope: String, CaseIterable { case all, homebrew, largest }

    @Published private(set) var entries: [Entry] = []
    @Published private(set) var isLoading = false
    private var loadedAt: Date?
    private var generation = 0

    /// Reloads when the list is older than a minute or asked to.
    func load(force: Bool = false) {
        if !force, let loadedAt, Date().timeIntervalSince(loadedAt) < 60 { refreshRunning(); return }
        generation += 1
        let generation = generation
        isLoading = entries.isEmpty
        let brewPath = HomebrewManager.shared.brewPath ?? HomebrewManager.shared.detectBrewPath()
        Task.detached(priority: .utility) {
            let apps = UninstallerSupport.offeredApplications().filter { !$0.isSystem }
            let running = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleURL?.standardizedFileURL.path })
            let listed = apps.map { app -> Entry in
                let version = Bundle(url: app.url)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                return Entry(id: app.id, name: app.name, bundleID: app.bundleID, url: app.url, version: version,
                             size: nil, cask: nil, running: running.contains(app.url.standardizedFileURL.path))
            }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            await self.publish(listed, generation: generation)

            let casks = brewPath.map(Self.caskOwners(brewPath:)) ?? [:]
            await self.apply(casks: casks, generation: generation)
            for entry in listed {
                let size = Self.allocatedSize(of: entry.url)
                await self.apply(size: size, to: entry.id, generation: generation)
            }
        }
    }

    func filtered(query: String, scope: Scope) -> [Entry] {
        let folded = query.trimmingCharacters(in: .whitespaces).lowercased()
        var list = entries.filter { entry in
            if !folded.isEmpty, !entry.name.lowercased().contains(folded),
               !(entry.bundleID?.lowercased().contains(folded) ?? false) { return false }
            if scope == .homebrew, entry.cask == nil { return false }
            return true
        }
        if scope == .largest { list.sort { ($0.size ?? 0) > ($1.size ?? 0) } }
        return list
    }

    private func publish(_ list: [Entry], generation: Int) {
        guard generation == self.generation else { return }
        // Keep what was already measured for apps still listed.
        let known = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        entries = list.map { entry in
            var entry = entry
            entry.size = known[entry.id]?.size
            entry.cask = known[entry.id]?.cask
            return entry
        }
        isLoading = false
        loadedAt = Date()
    }

    private func apply(casks: [String: String], generation: Int) {
        guard generation == self.generation else { return }
        for index in entries.indices {
            entries[index].cask = casks[entries[index].url.standardizedFileURL.path]
                ?? casks[entries[index].url.lastPathComponent]
        }
    }

    private func apply(size: Int64, to id: String, generation: Int) {
        guard generation == self.generation, let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].size = size
    }

    private func refreshRunning() {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleURL?.standardizedFileURL.path })
        for index in entries.indices {
            entries[index].running = running.contains(entries[index].url.standardizedFileURL.path)
        }
    }

    /// Each installed cask's token, by the app path or file name it installs.
    nonisolated static func caskOwners(brewPath: String) -> [String: String] {
        let command = HomebrewCommandBuilder.installed(brewPath: brewPath)
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return [:] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let records = try? HomebrewParser.parseInstalledCaskRecords(String(decoding: data, as: UTF8.self))
        else { return [:] }
        var owners: [String: String] = [:]
        for record in records {
            for path in record.appPaths { owners[URL(fileURLWithPath: path).standardizedFileURL.path] = record.token }
            for name in record.appFileNames where owners[name] == nil { owners[name] = record.token }
        }
        return owners
    }

    /// The space an app bundle takes on disk.
    nonisolated static func allocatedSize(of url: URL) -> Int64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys,
                                                              options: [], errorHandler: { _, _ in true })
        else { return 0 }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            guard let values = try? file.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? 0)
        }
        return total
    }
}
