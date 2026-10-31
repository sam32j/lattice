// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine

/// Finds junk the Mac accumulates — leftovers of uninstalled apps, orphaned
/// startup items, caches, logs, developer build junk, the Trash, forgotten
/// screenshots — lets the user review every single path with its size, and
/// moves what they confirm to the Trash. Nothing is deleted in place,
/// nothing is touched while the scan runs, and nothing runs at all until the
/// user opens the tool.
///
/// The safety model, in order of importance:
/// 1. Review first. Every item shows its full path and size before anything
///    happens, and uncertain finds start unchecked.
/// 2. Trash, not delete. Every removal is a reversible move to the Trash
///    (the Trash category itself is the one explicit exception).
/// 3. Never guess against a living app. A leftover needs a bundle shaped
///    name whose owner is not installed, not running, not Apple, and not
///    related to any installed identifier (dot boundary family match),
///    or container metadata that names that owner. Shared wrappers and plain
///    names are never treated as proof in this general scan.
/// 4. Scoped roots only. Items come from fixed, well known junk locations,
///    plus the top level of the screenshot folders, where only files macOS
///    itself marked as screen captures are ever considered. The general
///    scan never enters another app's support tree; symbolic links are
///    never followed and each item is bound to its observed file identity.
extension JunkCleaner {

    // MARK: - Installed apps oracle

    /// Every bundle identifier that must be treated as
    /// alive: apps found in the application folders (three levels deep,
    /// covering subfolders and suites), everything currently running, and
    /// login item helpers nested inside those apps.
    static func installedBundleIDs() -> Set<String> {
        var ids = Set<String>()
        let fm = FileManager.default
        let roots = ["/Applications", "/System/Applications",
                     NSHomeDirectory() + "/Applications"]

        func remember(app url: URL) {
            if let id = Bundle(url: url)?.bundleIdentifier {
                ids.insert(id.lowercased())
            }
        }

        func collect(at url: URL, depth: Int) {
            guard depth > 0 else { return }
            let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
            guard let entries = try? fm.contentsOfDirectory(at: url,
                                                            includingPropertiesForKeys: Array(keys),
                                                            options: [.skipsHiddenFiles]) else { return }
            for entry in entries {
                let values = try? entry.resourceValues(forKeys: keys)
                guard values?.isSymbolicLink != true, values?.isDirectory == true else { continue }
                if entry.pathExtension.caseInsensitiveCompare("app") == .orderedSame {
                    remember(app: entry)
                    collect(at: entry.appendingPathComponent("Contents/Library/LoginItems"), depth: 1)
                } else {
                    collect(at: entry, depth: depth - 1)
                }
            }
        }

        for root in roots {
            collect(at: URL(fileURLWithPath: root), depth: 3)
        }
        for app in NSWorkspace.shared.runningApplications {
            if let id = app.bundleIdentifier { ids.insert(id.lowercased()) }
            if let url = app.bundleURL { remember(app: url) }
        }
        return ids
    }

    /// The final say on whether a candidate identifier has a living owner:
    /// the collected set (family match), the vendor namespace rule (suites
    /// and updaters share a namespace with sibling identifiers), and Launch
    /// Services, which knows apps registered anywhere on disk.
    static func hasLivingOwner(_ candidate: String, installed: Set<String>) -> Bool {
        if CleanerSupport.isOwned(candidate: candidate, byInstalled: installed) { return true }
        if CleanerSupport.sharesVendorNamespace(candidate: candidate, withInstalled: installed) { return true }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: candidate) != nil
    }

    static func isDirectLeftoverRootChild(_ url: URL) -> Bool {
        [NSHomeDirectory() + "/Library", "/Library"].contains { library in
            leftoverRoots.contains { root in
                CleanerSupport.isDirectChild(
                    url,
                    of: URL(fileURLWithPath: library + "/" + root.path, isDirectory: true)
                )
            }
        }
    }

    static func scanLeftovers(installed: Set<String>) -> [Item] {
        let fm = FileManager.default
        let libraries = [NSHomeDirectory() + "/Library", "/Library"]
        var found: [Item] = []
        for library in libraries {
            for root in leftoverRoots {
                let dir = library + "/" + root.path
                appendLeftovers(in: dir,
                                usesContainerMetadata: root.usesContainerMetadata,
                                installed: installed,
                                fm: fm,
                                into: &found)
            }
        }
        return sorted(found)
    }

    static func appendLeftovers(in dir: String,
                                        usesContainerMetadata: Bool,
                                        installed: Set<String>,
                                        fm: FileManager,
                                        into found: inout [Item]) {
        let root = URL(fileURLWithPath: dir, isDirectory: true)
        let keys: Set<URLResourceKey> = [.isSymbolicLinkKey]
        guard let entries = try? fm.contentsOfDirectory(at: root,
                                                        includingPropertiesForKeys: nil,
                                                        options: []) else { return }
        for url in entries {
            let entry = url.lastPathComponent
            guard !entry.hasPrefix("."), CleanerScanPrivacy.mayInspect(entry) else { continue }
            let values = try? url.resourceValues(forKeys: keys)
            guard values?.isSymbolicLink != true else { continue }
            if let owner = CleanerOwnership.owner(at: url, usesContainerMetadata: usesContainerMetadata) {
                if CleanerSupport.isProtectedBundleID(owner)
                    || hasLivingOwner(owner, installed: installed) {
                    continue
                }
                guard CleanerScanPrivacy.mayRemoveTree(url, fm: fm) else { continue }
                found.append(Item(url: url, category: .leftovers,
                                  size: directorySize(of: url, fm: fm),
                                  detail: owner,
                                  recommended: CleanerPolicy.precheckLeftovers))
            }
        }
    }

    /// Launch agents and daemons whose every referenced executable is gone
    /// and whose label has no living owner: the classic ghost that keeps a
    /// deleted app listed under Login Items and Extensions.
    static func scanOrphanedLaunchPlists(installed: Set<String>) -> [Item] {
        let fm = FileManager.default
        let roots = [NSHomeDirectory() + "/Library/LaunchAgents",
                     "/Library/LaunchAgents",
                     "/Library/LaunchDaemons"]
        var found: [Item] = []
        for root in roots {
            guard let entries = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for entry in entries where entry.hasSuffix(".plist") {
                let url = URL(fileURLWithPath: root).appendingPathComponent(entry)
                guard !UninstallerSupport.isSymbolicLink(url) else { continue }
                guard let plist = NSDictionary(contentsOfFile: url.path) as? [String: Any] else { continue }
                let label = plist["Label"] as? String
                let executables = CleanerSupport.executablePaths(inLaunchPlist: plist)
                guard CleanerSupport.launchPlistIsRemovableOrphan(
                    label: label,
                    executables: executables,
                    // A missing binary on an external volume is inconclusive
                    // (the volume may just be unmounted), so it counts as
                    // present and the plist is left alone.
                    executableExists: { $0.hasPrefix("/Volumes/") || fm.fileExists(atPath: $0) }) else { continue }
                // Second signal: the label itself must not belong to anything
                // installed either (a moved binary is not an uninstalled app).
                if let label, hasLivingOwner(label, installed: installed) { continue }
                found.append(Item(url: url, category: .loginItems,
                                  size: directorySize(of: url, fm: fm),
                                  detail: label ?? entry,
                                  recommended: CleanerPolicy.precheckLoginItems))
            }
        }
        return sorted(found)
    }

    static func scanCaches(excluding claimed: Set<String>) -> [Item] {
        let fm = FileManager.default
        let dir = NSHomeDirectory() + "/Library/Caches"
        guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { return [] }
        var found: [Item] = []
        for entry in entries where !entry.hasPrefix(".") {
            guard !CleanerPolicy.isExcludedCacheEntry(entry) else { continue }
            let url = URL(fileURLWithPath: dir).appendingPathComponent(entry)
            guard !claimed.contains(url.standardizedFileURL.path) else { continue }
            guard CleanerScanPrivacy.mayRemoveTree(url, fm: fm) else { continue }
            let size = directorySize(of: url, fm: fm)
            guard size > 0 else { continue }
            found.append(Item(url: url, category: .caches, size: size,
                              detail: entry,
                              recommended: CleanerPolicy.precheckCacheEntry(entry)))
        }
        return sorted(found)
    }

    static func scanLogs(excluding claimed: Set<String>) -> [Item] {
        let fm = FileManager.default
        var found: [Item] = []
        let logsDir = NSHomeDirectory() + "/Library/Logs"
        if let entries = try? fm.contentsOfDirectory(atPath: logsDir) {
            for entry in entries where entry != "DiagnosticReports"
                && !entry.hasPrefix(".")
                && !CleanerPolicy.isExcludedCacheEntry(entry) {
                let url = URL(fileURLWithPath: logsDir).appendingPathComponent(entry)
                guard !claimed.contains(url.standardizedFileURL.path),
                      CleanerScanPrivacy.mayRemoveTree(url, fm: fm) else { continue }
                let size = directorySize(of: url, fm: fm)
                guard size > 0 else { continue }
                found.append(Item(url: url, category: .logs, size: size,
                                  detail: entry, recommended: CleanerPolicy.precheckLogs))
            }
        }
        let reports = logsDir + "/DiagnosticReports"
        let reportsURL = URL(fileURLWithPath: reports)
        let reportsSize = CleanerScanPrivacy.mayRemoveTree(reportsURL, fm: fm)
            ? directorySize(of: reportsURL, fm: fm) : 0
        if reportsSize > 0 {
            found.append(Item(url: reportsURL, category: .logs, size: reportsSize,
                              detail: "DiagnosticReports", recommended: CleanerPolicy.precheckLogs))
        }
        return sorted(found)
    }

    static func scanDeveloperJunk() -> [Item] {
        let fm = FileManager.default
        var found: [Item] = []
        for path in CleanerPolicy.developerJunkPaths {
            let url = URL(fileURLWithPath: NSHomeDirectory() + path)
            guard fm.fileExists(atPath: url.path) else { continue }
            let size = directorySize(of: url, fm: fm)
            guard size > 0 else { continue }
            found.append(Item(url: url, category: .developer, size: size,
                              detail: url.lastPathComponent,
                              recommended: CleanerPolicy.precheckDeveloper))
        }
        return sorted(found)
    }

    /// Old iPhone and iPad backups under MobileSync: with caches, the other
    /// classic tenant of the storage macOS files under "Other". They are the
    /// user's safety net, so every find starts unchecked and names the
    /// device and the backup date. Without Full Disk Access the folder is
    /// unreadable and nothing is offered.
    static func scanDeviceBackups() -> [Item] {
        let fm = FileManager.default
        let root = NSHomeDirectory() + "/Library/Application Support/MobileSync/Backup"
        guard let entries = try? fm.contentsOfDirectory(atPath: root) else { return [] }
        var found: [Item] = []
        for entry in entries where !entry.hasPrefix(".") {
            let url = URL(fileURLWithPath: root).appendingPathComponent(entry)
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }
            let size = directorySize(of: url, fm: fm)
            guard size > 0 else { continue }
            let info = NSDictionary(contentsOf: url.appendingPathComponent("Info.plist"))
            let device = info?["Device Name"] as? String
            let date = (info?["Last Backup Date"] as? Date).map {
                DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .none)
            }
            let detail = [device, date].compactMap { $0 }.joined(separator: ", ")
            found.append(Item(url: url, category: .deviceBackups, size: size,
                              detail: detail.isEmpty ? entry : detail,
                              recommended: CleanerPolicy.precheckDeviceBackups))
        }
        return sorted(found)
    }

    /// The folders and age of the forgotten screenshot search, or nil when
    /// the user turned it off.
    static func screenshotSearch() -> (folders: [URL], days: Int)? {
        let days = CleanerPolicy.sanitizedScreenshotAgeDays(
            UserDefaults.standard.integer(forKey: DefaultsKey.cleanerScreenshotAgeDays))
        guard days > 0 else { return nil }
        return (screenshotFolders(), days)
    }
}
