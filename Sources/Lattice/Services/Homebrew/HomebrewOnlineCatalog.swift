// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// The whole Homebrew catalog from formulae.brew.sh, searched on this Mac:
/// one download of the cask and formula indexes, kept on disk for a day, so
/// typing searches it at once. Without the network it falls back to brew's
/// own search. It also reads which Homebrew is installed and the newest
/// release, for the tab's self-update footer.
@MainActor
final class HomebrewOnlineCatalog: ObservableObject {
    static let shared = HomebrewOnlineCatalog()

    struct Entry: Identifiable, Hashable, Codable {
        let kind: HomebrewPackageKind
        let name: String
        let displayName: String
        let version: String
        let desc: String

        var id: String { "\(kind.rawValue):\(name)" }

        var package: HomebrewPackage {
            HomebrewPackage(kind: kind, name: name, displayName: displayName,
                            desc: desc.isEmpty ? nil : desc, stableVersion: version.isEmpty ? nil : version)
        }
    }

    enum Source { case live, fallback }

    @Published private(set) var results: [Entry] = []
    @Published private(set) var isSearching = false
    @Published private(set) var source: Source?
    @Published private(set) var installedVersion: String?
    @Published private(set) var latestVersion: String?

    private var index: [Entry]?
    private var indexLoad: Task<[Entry]?, Never>?
    private var searchTask: Task<Void, Never>?
    private var versionCheckedAt: Date?

    nonisolated static let cacheLifetime: TimeInterval = 24 * 60 * 60
    nonisolated static let resultLimit = 8

    /// Whether a newer Homebrew than the installed one has been released.
    var selfUpdateAvailable: Bool {
        guard let installedVersion, let latestVersion else { return false }
        return Self.isNewer(latestVersion, than: installedVersion)
    }

    /// Searches after a short pause, so each keystroke does not start one.
    func search(_ query: String, kind: HomebrewPackageKind?, installed: Set<String>) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled, let self else { return }
            if let index = await self.loadIndex() {
                guard !Task.isCancelled else { return }
                self.source = .live
                self.results = Self.matches(trimmed, in: index, kind: kind, excluding: installed)
            } else {
                guard !Task.isCancelled else { return }
                self.source = .fallback
                self.results = await Self.brewSearch(trimmed, kind: kind ?? .cask, excluding: installed)
            }
            self.isSearching = false
        }
    }

    func clear() {
        searchTask?.cancel()
        results = []
        isSearching = false
    }

    // MARK: Matching

    /// Ranked as a person typing a name expects: an exact name, then names
    /// that start with the query, then names containing it, then descriptions.
    nonisolated static func matches(_ query: String, in index: [Entry], kind: HomebrewPackageKind?,
                                    excluding installed: Set<String>) -> [Entry] {
        var scored: [(entry: Entry, score: Int)] = []
        for entry in index where kind == nil || entry.kind == kind {
            let name = entry.name.lowercased()
            guard !installed.contains(name) else { continue }
            let display = entry.displayName.lowercased()
            let score: Int
            if name == query || display == query { score = 100 }
            else if name.hasPrefix(query) || display.hasPrefix(query) { score = 70 }
            else if name.contains(query) || display.contains(query) { score = 40 }
            else if entry.desc.lowercased().contains(query) { score = 10 }
            else { continue }
            scored.append((entry, score))
        }
        return scored.sorted {
            $0.score != $1.score ? $0.score > $1.score : $0.entry.name.count < $1.entry.name.count
        }.prefix(resultLimit).map(\.entry)
    }

    // MARK: Index

    private func loadIndex() async -> [Entry]? {
        if let index { return index }
        if indexLoad == nil {
            indexLoad = Task.detached(priority: .userInitiated) { await Self.fetchIndex() }
        }
        let loaded = await indexLoad?.value
        if loaded == nil { indexLoad = nil } else { index = loaded }
        return loaded
    }

    nonisolated private static var cacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "Lattice", isDirectory: true)
            .appendingPathComponent("homebrew-catalog.json")
    }

    nonisolated private static func fetchIndex() async -> [Entry]? {
        if let url = cacheURL,
           let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
           Date().timeIntervalSince(modified) < cacheLifetime,
           let data = try? Data(contentsOf: url),
           let cached = try? JSONDecoder().decode([Entry].self, from: data), !cached.isEmpty {
            return cached
        }
        let session = URLSession(configuration: .ephemeral)
        async let casks = download("https://formulae.brew.sh/api/cask.json", session: session)
        async let formulae = download("https://formulae.brew.sh/api/formula.json", session: session)
        guard let caskData = await casks, let formulaData = await formulae else { return nil }
        let entries = parseCasks(caskData) + parseFormulae(formulaData)
        guard !entries.isEmpty else { return nil }
        if let url = cacheURL, let data = try? JSONEncoder().encode(entries) {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }
        return entries
    }

    nonisolated private static func download(_ address: String, session: URLSession) async -> Data? {
        guard let url = URL(string: address),
              let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }

    nonisolated static func parseCasks(_ data: Data) -> [Entry] {
        guard let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return list.compactMap { item in
            guard let token = item["token"] as? String else { return nil }
            let display = (item["name"] as? [String])?.first ?? token
            return Entry(kind: .cask, name: token, displayName: display,
                         version: item["version"] as? String ?? "", desc: item["desc"] as? String ?? "")
        }
    }

    nonisolated static func parseFormulae(_ data: Data) -> [Entry] {
        guard let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return list.compactMap { item in
            guard let name = item["name"] as? String else { return nil }
            let version = (item["versions"] as? [String: Any])?["stable"] as? String ?? ""
            return Entry(kind: .formula, name: name, displayName: name,
                         version: version, desc: item["desc"] as? String ?? "")
        }
    }

    // MARK: Fallback

    nonisolated private static func brewSearch(_ query: String, kind: HomebrewPackageKind,
                                               excluding installed: Set<String>) async -> [Entry] {
        guard let brewPath = HomebrewManager.shared.brewPath ?? HomebrewManager.shared.detectBrewPath() else {
            return []
        }
        let command = HomebrewCommandBuilder.search(brewPath: brewPath, kind: kind, query: query)
        let output = run(command.executable, command.arguments)
        let packages = HomebrewParser.parseSearchOutput(output ?? "", kind: kind, installed: [])
        return packages.filter { !installed.contains($0.name.lowercased()) }.prefix(resultLimit).map {
            Entry(kind: $0.kind, name: $0.name, displayName: $0.displayName,
                  version: $0.stableVersion ?? "", desc: $0.desc ?? "")
        }
    }

    // MARK: Homebrew itself

    /// Reads the installed Homebrew version and the newest release, at most
    /// every six hours.
    func checkVersion(force: Bool = false) {
        if HomebrewSimulator.shared.isSimulating { return }
        if !force, let versionCheckedAt, Date().timeIntervalSince(versionCheckedAt) < 6 * 60 * 60 { return }
        versionCheckedAt = Date()
        let brewPath = HomebrewManager.shared.brewPath ?? HomebrewManager.shared.detectBrewPath()
        Task.detached(priority: .utility) { [weak self] in
            let installed = brewPath.flatMap { Self.run($0, ["--version"]) }.flatMap(Self.parseBrewVersion)
            let latest = await Self.latestRelease()
            await MainActor.run { [weak self] in
                guard let self, !HomebrewSimulator.shared.isSimulating else { return }
                self.installedVersion = installed
                self.latestVersion = latest
            }
        }
    }

    func setSimulatedVersion(installed: String?, latest: String?) {
        installedVersion = installed
        latestVersion = latest
    }

    func clearSimulatedVersion() {
        installedVersion = nil
        latestVersion = nil
        versionCheckedAt = nil
    }

    /// "Homebrew 4.4.12" (with a git suffix on development checkouts).
    nonisolated static func parseBrewVersion(_ output: String) -> String? {
        guard let line = output.split(separator: "\n").first, line.hasPrefix("Homebrew ") else { return nil }
        let version = line.dropFirst("Homebrew ".count).split(separator: "-").first.map(String.init)
        return version?.isEmpty == false ? version : nil
    }

    nonisolated private static func latestRelease() async -> String? {
        guard let url = URL(string: "https://api.github.com/repos/Homebrew/brew/releases/latest") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession(configuration: .ephemeral).data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = object["tag_name"] as? String else { return nil }
        return tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    /// Compares dotted versions number by number.
    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(a.count, b.count) {
            let left = index < a.count ? a[index] : 0
            let right = index < b.count ? b[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    nonisolated private static func run(_ executable: String, _ arguments: [String]) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? String(decoding: data, as: UTF8.self) : nil
    }
}
