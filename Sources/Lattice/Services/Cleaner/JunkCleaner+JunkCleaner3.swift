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

    /// Where macOS saves screenshots and, when its screenshot tool is
    /// installed, where this app saves its own.
    static func screenshotFolders() -> [URL] {
        let home = NSHomeDirectory()
        let location = CFPreferencesCopyAppValue("location" as CFString,
                                                 "com.apple.screencapture" as CFString) as? String
        var paths = [CleanerSupport.screenshotFolder(location: location, home: home)]
        if AppFeature.screenshot.isAvailable {
            let stored = UserDefaults.standard.string(forKey: DefaultsKey.screenshotSaveFolder) ?? ""
            paths.append(stored.isEmpty ? home + "/Desktop" : (stored as NSString).expandingTildeInPath)
        }
        var seen = Set<String>()
        return paths
            // The real path: the removal guard refuses anything reached
            // through a symbolic link.
            .map { URL(fileURLWithPath: $0, isDirectory: true).resolvingSymlinksInPath().standardizedFileURL }
            .filter { seen.insert($0.path).inserted }
    }

    static func isScreenshotFolderChild(_ url: URL) -> Bool {
        screenshotFolders().contains { CleanerSupport.isDirectChild(url, of: $0) }
    }

    /// Screenshots nobody touched for `days`: only the top level of the
    /// screenshot folders, only files macOS itself marked as captures, and
    /// only under the dated name they were saved with. Moving or renaming
    /// one is a decision about it, so it never shows up again. Without
    /// access to a folder nothing from it is offered.
    static func scanScreenshots(in folders: [URL], days: Int) -> [Item] {
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey,
                                         .creationDateKey, .contentModificationDateKey]
        let now = Date()
        var found: [Item] = []
        for folder in folders {
            guard let entries = try? fm.contentsOfDirectory(at: folder,
                                                            includingPropertiesForKeys: Array(keys),
                                                            options: [.skipsHiddenFiles]) else { continue }
            for url in entries {
                guard let values = try? url.resourceValues(forKeys: keys),
                      values.isRegularFile == true, values.isSymbolicLink != true,
                      let created = values.creationDate,
                      isScreenCapture(url),
                      CleanerSupport.screenshotKeepsDefaultName(url.lastPathComponent,
                                                                created: created) else { continue }
                let lastUsed = extendedAttribute(CleanerSupport.lastUsedDateAttribute, of: url)
                    .flatMap(CleanerSupport.lastUsedDate(fromAttribute:))
                guard CleanerSupport.isForgottenScreenshot(created: created,
                                                           modified: values.contentModificationDate,
                                                           lastUsed: lastUsed,
                                                           now: now, days: days) else { continue }
                let size = fileSize(url)
                guard size > 0 else { continue }
                found.append(Item(url: url, category: .screenshots, size: size,
                                  detail: DateFormatter.localizedString(from: created,
                                                                        dateStyle: .medium,
                                                                        timeStyle: .none),
                                  recommended: CleanerPolicy.precheckScreenshots))
            }
        }
        return sorted(found)
    }

    static func isScreenCapture(_ url: URL) -> Bool {
        extendedAttribute(CleanerSupport.screenCaptureAttribute, of: url)
            .map(CleanerSupport.isScreenCaptureFlag) ?? false
    }

    static func extendedAttribute(_ name: String, of url: URL) -> Data? {
        url.withUnsafeFileSystemRepresentation { path -> Data? in
            guard let path else { return nil }
            let length = getxattr(path, name, nil, 0, 0, XATTR_NOFOLLOW)
            guard length > 0, length <= 4096 else { return nil }
            var data = Data(count: length)
            let read = data.withUnsafeMutableBytes {
                getxattr(path, name, $0.baseAddress, length, 0, XATTR_NOFOLLOW)
            }
            return read == length ? data : nil
        }
    }

    static func scanTrash() -> [Item] {
        let fm = FileManager.default
        let trash = NSHomeDirectory() + "/.Trash"
        // Only what the user can see in the Trash counts: an "empty" Trash
        // still carries hidden bookkeeping files (.DS_Store), and offering
        // to empty those reads as a lie.
        guard let entries = try? fm.contentsOfDirectory(atPath: trash) else { return [] }
        let visible = entries.filter { !$0.hasPrefix(".") }
        guard !visible.isEmpty else { return [] }
        let url = URL(fileURLWithPath: trash)
        let size = visible.reduce(Int64(0)) {
            $0 + directorySize(of: url.appendingPathComponent($1), fm: fm)
        }
        guard size > 0 else { return [] }
        return [Item(url: url, category: .trash, size: size,
                     detail: "", recommended: false)]
    }

    // MARK: - Helpers

    static func sorted(_ items: [Item]) -> [Item] {
        items.sorted { $0.size > $1.size }
    }

    static func directorySize(of url: URL, fm: FileManager) -> Int64 {
        guard CleanerScanPrivacy.mayInspect(url.lastPathComponent) else { return 0 }
        if UninstallerSupport.isSymbolicLink(url) { return 0 }
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue { return fileSize(url) }
        var total: Int64 = 0
        if let enumerator = fm.enumerator(at: url,
                                          includingPropertiesForKeys: nil,
                                          options: [], errorHandler: nil) {
            for case let item as URL in enumerator {
                guard CleanerScanPrivacy.mayInspect(item.lastPathComponent) else {
                    enumerator.skipDescendants()
                    continue
                }
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
