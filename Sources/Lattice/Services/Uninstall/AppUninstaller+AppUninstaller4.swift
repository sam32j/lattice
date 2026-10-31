// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import CoreServices
import Darwin
import Security

/// Finds the files an app leaves around — caches, preferences, logs, support
/// folders, containers, preference panes, plugins — and removes only what you
/// pick. Ordinary files go to the Trash; after an extra confirmation, a
/// package-managed app is delegated to its package manager before the remaining
/// choices go to the Trash.
extension AppUninstaller {

    /// Main app plus owned executable extensions. Resource bundles and
    /// arbitrary nested apps are excluded because their identifiers may be
    /// shared by unrelated products.
    static func signingIdentity(in appURL: URL,
                                        requireValidSignature: Bool)
        -> (teamIDs: Set<String>, groupIDs: Set<String>) {
        if requireValidSignature, !codeSignatureIsValid(at: appURL) {
            return ([], [])
        }
        var result = codeSigningIdentity(at: appURL,
                                         requireValidSignature: requireValidSignature)
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
        guard let enumerator = fm.enumerator(at: appURL,
                                             includingPropertiesForKeys: Array(keys),
                                             options: [.skipsHiddenFiles],
                                             errorHandler: nil) else { return result }
        var inspected = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: keys)
            if values?.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            guard values?.isDirectory == true,
                  ownedEmbeddedCode(url, in: appURL) else { continue }
            inspected += 1
            guard inspected <= 256 else { break }
            let nested = codeSigningIdentity(at: url,
                                             requireValidSignature: requireValidSignature)
            result.teamIDs.formUnion(nested.teamIDs)
            result.groupIDs.formUnion(nested.groupIDs)
        }
        return result
    }

    static func codeSignatureIsValid(at url: URL) -> Bool {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode) == errSecSuccess,
              let staticCode else { return false }
        return SecStaticCodeCheckValidity(staticCode, [], nil) == errSecSuccess
    }

    static func category(for kind: UninstallerSupport.Kind) -> Category {
        switch kind {
        case .support: return .support
        case .caches: return .caches
        case .preferences: return .preferences
        case .containers: return .containers
        case .logs: return .logs
        case .state: return .state
        case .other: return .other
        }
    }

    static func knownApplicationURLs(candidateBundleIDs: Set<String>) -> [URL] {
        var urls = InstalledApps.installedApplications(includeSystemApplications: true).map(\.url)
        urls += NSWorkspace.shared.runningApplications.compactMap(\.bundleURL)
        for id in candidateBundleIDs {
            urls += NSWorkspace.shared.urlsForApplications(withBundleIdentifier: id)
        }
        var seen = Set<String>()
        return urls.compactMap { url in
            let resolved = url.resolvingSymlinksInPath().standardizedFileURL
            guard resolved.pathExtension.caseInsensitiveCompare("app") == .orderedSame,
                  FileManager.default.fileExists(atPath: resolved.path),
                  seen.insert(resolved.path).inserted else { return nil }
            return resolved
        }
    }

    static func exclusiveOwnedBundleIDs(in selectedURL: URL,
                                                candidates: Set<String>,
                                                knownApplicationIDs: [(url: URL, bundleID: String)],
                                                requiresCurrentOwnership: Bool = true) -> Set<String> {
        var eligible = candidates
        if requiresCurrentOwnership {
            let current = allBundleIDs(in: selectedURL, fm: .default)
            eligible = Set(candidates.filter { candidate in
                current.contains(where: {
                    $0.caseInsensitiveCompare(candidate) == .orderedSame
                })
            })
        }
        return UninstallerSupport.exclusiveBundleIDs(eligible,
                                                     selectedURL: selectedURL,
                                                     knownApplications: knownApplicationIDs)
    }

    static func applicationBundleIdentifiers(in applications: [URL])
        -> [(url: URL, bundleID: String)] {
        let fm = FileManager.default
        return applications.flatMap { url in
            allBundleIDs(in: url, fm: fm).map { (url, $0) }
        }
    }

    static func exclusiveGroupIDs(_ candidates: Set<String>,
                                          selectedURL: URL,
                                          knownApplications: [URL]) -> Set<String> {
        guard !candidates.isEmpty else { return [] }
        let selectedPath = selectedURL.resolvingSymlinksInPath().standardizedFileURL.path
        var claimedElsewhere = Set<String>()
        for url in knownApplications {
            let path = url.resolvingSymlinksInPath().standardizedFileURL.path
            guard path != selectedPath, !path.hasPrefix(selectedPath + "/") else { continue }
            let groups = signingIdentity(in: url, requireValidSignature: false).groupIDs
            claimedElsewhere.formUnion(groups.intersection(candidates))
            if claimedElsewhere == candidates { break }
        }
        return candidates.subtracting(claimedElsewhere)
    }

    static func removalIsStillSafe(_ url: URL,
                                           expectedIdentity: UninstallerSupport.FileIdentity,
                                           allowedPaths: Set<String>,
                                           targetURL: URL?) -> Bool {
        let path = url.standardizedFileURL.path
        guard allowedPaths.contains(path), let targetURL,
              UninstallerSupport.fileIdentity(at: url) == expectedIdentity else { return false }
        if path == targetURL.standardizedFileURL.path {
            return !UninstallerSupport.isSymbolicLink(url)
        }
        guard let root = scanRoots(home: NSHomeDirectory()).first(where: {
            path.hasPrefix($0.path + "/")
        }) else { return false }
        return UninstallerSupport.removalPathIsSafe(url, within: root)
    }

    static func allBundleIDs(in appURL: URL, fm: FileManager) -> Set<String> {
        var result = Set<String>()
        if let primary = UninstallerSupport.verifiedBundleID(Bundle(url: appURL)?.bundleIdentifier) {
            result.insert(primary)
        }
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
        guard let enumerator = fm.enumerator(at: appURL,
                                             includingPropertiesForKeys: Array(keys),
                                             options: [.skipsHiddenFiles],
                                             errorHandler: nil) else { return result }
        var inspected = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: keys)
            if values?.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            guard values?.isDirectory == true,
                  ownedEmbeddedCode(url, in: appURL),
                  let id = UninstallerSupport.verifiedBundleID(Bundle(url: url)?.bundleIdentifier)
            else { continue }
            inspected += 1
            guard inspected <= 256 else { break }
            result.insert(id)
        }
        return result
    }

    static func ownedEmbeddedCode(_ url: URL, in appURL: URL) -> Bool {
        switch url.pathExtension.lowercased() {
        case "appex", "xpc":
            return true
        case "app":
            let loginItems = appURL.appendingPathComponent(
                "Contents/Library/LoginItems", isDirectory: true).standardizedFileURL.path
            return url.standardizedFileURL.path.hasPrefix(loginItems + "/")
        default:
            return false
        }
    }

    static func scanRoots(home: String) -> [URL] {
        var roots = [
            URL(fileURLWithPath: home + "/Library", isDirectory: true),
            URL(fileURLWithPath: "/Library", isDirectory: true),
            URL(fileURLWithPath: home + "/.config", isDirectory: true),
            URL(fileURLWithPath: home + "/.cache", isDirectory: true),
            URL(fileURLWithPath: home + "/.local/share", isDirectory: true),
            URL(fileURLWithPath: "/private/var/db/receipts", isDirectory: true),
            URL(fileURLWithPath: "/Users/Shared/Library", isDirectory: true),
        ]
        if let cache = darwinUserDirectory(_CS_DARWIN_USER_CACHE_DIR) { roots.append(cache) }
        if let temp = darwinUserDirectory(_CS_DARWIN_USER_TEMP_DIR) { roots.append(temp) }
        return roots.map(\.standardizedFileURL)
    }

    static func spotlightRoots(home: String) -> [URL] {
        [
            URL(fileURLWithPath: home + "/Library", isDirectory: true),
            URL(fileURLWithPath: "/Library", isDirectory: true),
            URL(fileURLWithPath: "/Users/Shared/Library", isDirectory: true),
        ].map(\.standardizedFileURL)
    }

    static func darwinUserDirectory(_ name: Int32) -> URL? {
        let length = confstr(name, nil, 0)
        guard length > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: length)
        guard confstr(name, &buffer, length) > 0 else { return nil }
        return URL(fileURLWithPath: String(cString: buffer), isDirectory: true).standardizedFileURL
    }

    /// Drops exact duplicates and any path nested inside another already found.
    /// An exact match upgrades a related one already recorded at the same path.
    static func dedupe(_ paths: [ScanCandidate]) -> [ScanCandidate] {
        var seen = Set<String>()
        var roots: [String] = []
        var out: [ScanCandidate] = []
        let exactPaths = paths.filter { $0.confidence == .exact }
            .map { $0.url.standardizedFileURL.path }
        for candidate in paths.sorted(by: { $0.url.path.count < $1.url.path.count }) {
            let path = candidate.url.standardizedFileURL.path
            if candidate.confidence == .related,
               exactPaths.contains(where: { $0.hasPrefix(path + "/") }) {
                continue
            }
            if let index = out.firstIndex(where: { $0.url.standardizedFileURL.path == path }) {
                let include = out[index].include || candidate.include
                if out[index].confidence != .exact, candidate.confidence == .exact {
                    out[index] = candidate
                }
                out[index].include = include
                continue
            }
            if seen.contains(path) { continue }
            if roots.contains(where: { path.hasPrefix($0 + "/") }) { continue }
            seen.insert(path)
            roots.append(path)
            out.append(candidate)
        }
        return out
    }

    static func directorySize(of url: URL, fm: FileManager) -> Int64 {
        if UninstallerSupport.isSymbolicLink(url) { return fileSize(url) }
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue { return fileSize(url) }

        var total: Int64 = 0
        if let enumerator = fm.enumerator(at: url,
                                          includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
                                          options: [], errorHandler: nil) {
            for case let item as URL in enumerator {
                if UninstallerSupport.isSymbolicLink(item) {
                    enumerator.skipDescendants()
                    continue
                }
                total += fileSize(item)
            }
        }
        return total
    }

    static func fileSize(_ url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
        return Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
    }
}
