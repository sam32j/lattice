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

    func items(in category: CleanerSupport.Category) -> [Item] {
        items.filter { $0.category == category }
    }

    func setInclude(_ include: Bool, for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].include = include
    }

    func setInclude(_ include: Bool, forCategory category: CleanerSupport.Category) {
        for index in items.indices where items[index].category == category {
            items[index].include = include
        }
    }

    func reset() {
        scanToken = UUID()
        scanCancellation?.cancel()
        scanCancellation = nil
        items = []
        scanningCategory = nil
        phase = .idle
    }

    // MARK: - Scan

    /// `attended: false` is a pass nobody watches: it skips the screenshot
    /// search, which reads the user's own folders and can ask for access.
    func scan(attended: Bool) {
        guard AppFeature.cleaner.isAvailable else { return }
        guard phase != .scanning else { return }
        let token = UUID()
        scanToken = token
        scanCancellation?.cancel()
        let cancellation = CleanerSupport.ScanCancellation()
        scanCancellation = cancellation
        items = []
        phase = .scanning
        let screenshots = attended ? Self.screenshotSearch() : nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard !cancellation.isCancelled else { return }
            let installed = Self.installedBundleIDs()
            // A path claimed by the leftover scan must not reappear under
            // caches or logs: one path, one row, one decision.
            var claimed = Set<String>()
            let categories: [(CleanerSupport.Category, () -> [Item])] = [
                (.leftovers, {
                    let found = Self.scanLeftovers(installed: installed)
                    claimed.formUnion(found.map { $0.url.standardizedFileURL.path })
                    return found
                }),
                (.loginItems, { Self.scanOrphanedLaunchPlists(installed: installed) }),
                (.caches, { Self.scanCaches(excluding: claimed) }),
                (.logs, { Self.scanLogs(excluding: claimed) }),
                (.developer, { Self.scanDeveloperJunk() }),
                (.trash, { Self.scanTrash() }),
                (.deviceBackups, { Self.scanDeviceBackups() }),
            ] + (screenshots.map { search in
                [(.screenshots, { Self.scanScreenshots(in: search.folders, days: search.days) })]
            } ?? [])
            for (category, run) in categories {
                guard !cancellation.isCancelled else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.scanToken == token else { return }
                    self.scanningCategory = category
                }
                let found = run()
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.scanToken == token else { return }
                    self.items.append(contentsOf: found)
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.scanToken == token else { return }
                self.scanCancellation = nil
                self.scanningCategory = nil
                self.phase = .results
            }
        }
    }

    // MARK: - Clean

    /// `escalate: false` leaves whatever the Trash move refused in place
    /// instead of handing it to Finder, which is an administrator password
    /// prompt. No default: each caller says whether someone is there to answer.
    func cleanSelected(escalate: Bool) {
        guard AppFeature.cleaner.isAvailable else { return }
        let chosen = items.filter(\.include)
        guard !chosen.isEmpty else { return }
        phase = .cleaning

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fm = FileManager.default
            // One installed-apps oracle for the whole pass, and only when the
            // selection can ask for it: building it walks the application
            // folders, and `mayRemove` reads it under `.leftovers` alone, so a
            // clean without leftover rows must not pay for the walk. Nothing
            // can install an app mid-clean that this pass would have to
            // respect. `stubborn` is a subset of `chosen`, so the second and
            // third passes are covered by the same test.
            let installed = chosen.contains { $0.category == .leftovers }
                ? Self.installedBundleIDs() : []
            var freed: Int64 = 0
            var failed = 0
            var stubborn: [Item] = []

            // Emptying the Trash MUST come first: the row means the Trash as
            // it was scanned. Running it after the moves would silently wipe
            // the very items this clean just made recoverable, which reads
            // as "nothing ever went to the Trash".
            for item in chosen where item.category == .trash {
                if Self.emptyTrash() { freed += item.size } else { failed += 1 }
            }

            for item in chosen where item.category != .trash {
                guard Self.mayRemove(item, installed: installed) else {
                    failed += 1
                    continue
                }
                if item.category == .loginItems {
                    // Retire the job first so nothing keeps running from a
                    // plist that is about to leave; then the regular move.
                    Self.bootoutUserAgent(item.url)
                    guard Self.mayRemove(item, installed: installed) else {
                        failed += 1
                        continue
                    }
                }
                do {
                    try fm.trashItem(at: item.url, resultingItemURL: nil)
                    freed += item.size
                } catch {
                    stubborn.append(item)
                }
            }

            // Root owned files (system LaunchDaemons and friends) go through
            // Finder, which shows the standard administrator prompt and moves
            // them to the Trash exactly like a drag would. One batch, one
            // prompt; a cancel leaves them in place and they count as failed.
            if !escalate {
                // Unattended pass: nobody can answer the prompt, so they
                // stay put and count as failed.
                failed += stubborn.count
            } else if !stubborn.isEmpty {
                let stillSafe = stubborn.filter { Self.mayRemove($0, installed: installed) }
                failed += stubborn.count - stillSafe.count
                Self.trashViaFinder(stillSafe.map(\.url))
                for item in stillSafe {
                    if fm.fileExists(atPath: item.url.path) {
                        failed += 1
                    } else {
                        freed += item.size
                    }
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self, self.phase == .cleaning else { return }
                self.items = []
                self.phase = .done(freed: freed, failed: failed)
            }
        }
    }

    /// Exact match guard against ever removing a critical root, even if a
    /// scanner bug produced one. Items are already scoped by construction;
    /// this is the last line of defense.
    static func mayRemove(_ item: Item, installed: Set<String>) -> Bool {
        let url = item.url
        let path = url.standardizedFileURL.path
        let home = NSHomeDirectory()
        let critical: Set<String> = [
            "/", "/Applications", "/Library", "/System", "/Users", "/usr",
            "/bin", "/sbin", "/etc", "/var", "/private", "/opt",
            home, home + "/Library", home + "/Documents", home + "/Desktop",
            home + "/Downloads", home + "/Pictures", home + "/Music", home + "/Movies",
        ]
        guard !critical.contains(path),
              !url.lastPathComponent.lowercased().hasSuffix(".localized"),
              let expectedIdentity = item.fileIdentity,
              UninstallerSupport.fileIdentity(at: url) == expectedIdentity,
              !UninstallerSupport.isSymbolicLink(url),
              url.resolvingSymlinksInPath().standardizedFileURL.path == path else { return false }
        guard CleanerScanPrivacy.mayRemoveTree(url, fm: .default) else { return false }
        if item.category == .leftovers {
            guard isDirectLeftoverRootChild(url),
                  CleanerSupport.isAttributableBundleID(item.detail),
                  !CleanerSupport.isProtectedBundleID(item.detail),
                  !hasLivingOwner(item.detail, installed: installed) else { return false }
        }
        if item.category == .screenshots {
            guard isScreenshotFolderChild(url), isScreenCapture(url) else { return false }
        }
        // Depth guard: anything this shallow is a root of some kind, never junk.
        return url.pathComponents.count >= 4
    }

    static func trashViaFinder(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        guard AppleScriptRunner.consentToAutomate(bundleID: "com.apple.finder") else { return }
        let targets = urls
            .map { "set end of targets to POSIX file \(AppleScriptRunner.literal($0.path))" }
            .joined(separator: "\n")
        let source = """
        set targets to {}
        \(targets)
        tell application "Finder" to delete targets
        """
        _ = AppleScriptRunner.run(source)
    }

    /// Emptying the Trash is the one permanent action here, clearly labeled
    /// in the interface. Finder owns it, exactly like the menu command.
    static func emptyTrash() -> Bool {
        guard AppleScriptRunner.consentToAutomate(bundleID: "com.apple.finder") else { return false }
        return AppleScriptRunner.run("tell application \"Finder\" to empty trash").ok
    }

    /// Unloads a user launch agent before its plist is trashed, so the job
    /// does not keep running until logout. Best effort: a plist that was
    /// never loaded simply makes launchctl exit nonzero, which is fine.
    static func bootoutUserAgent(_ plistURL: URL) {
        guard plistURL.path.hasPrefix(NSHomeDirectory() + "/Library/LaunchAgents/") else { return }
        guard let plist = NSDictionary(contentsOf: plistURL) as? [String: Any],
              let label = plist["Label"] as? String, !label.isEmpty,
              !label.contains("/"), !label.contains("..") else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["bootout", "gui/\(getuid())/\(label)"]
        // A plist that was never loaded makes launchctl complain; that is
        // expected and not worth a line in anyone's console.
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}
