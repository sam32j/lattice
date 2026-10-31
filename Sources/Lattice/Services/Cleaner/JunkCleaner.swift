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
final class JunkCleaner: ObservableObject {
    static let shared = JunkCleaner()

    enum Phase: Equatable {
        case idle
        case scanning
        case results
        case cleaning
        case done(freed: Int64, failed: Int)
    }

    struct Item: Identifiable, Equatable {
        let id = UUID()
        let url: URL
        let category: CleanerSupport.Category
        let size: Int64
        /// A short secondary line: the owning bundle identifier or label.
        let detail: String
        let fileIdentity: UninstallerSupport.FileIdentity?
        /// Whether this find is safe enough to clean without a second look.
        /// Recommended items start selected and live in the safe section of
        /// the interface; the rest wait unchecked under optional.
        let recommended: Bool
        var include: Bool

        var name: String { url.lastPathComponent }

        init(url: URL, category: CleanerSupport.Category, size: Int64,
             detail: String, recommended: Bool) {
            self.url = url
            self.category = category
            self.size = size
            self.detail = detail
            self.fileIdentity = UninstallerSupport.fileIdentity(at: url)
            self.recommended = recommended
            self.include = recommended
        }

        static func == (lhs: Item, rhs: Item) -> Bool {
            lhs.id == rhs.id && lhs.include == rhs.include
        }
    }

    @Published var phase: Phase = .idle
    @Published var items: [Item] = []
    /// The category currently being scanned, for the progress line.
    @Published var scanningCategory: CleanerSupport.Category?

    init() {}

    /// Serializes scans so a re-scan started while one runs is ignored.
    var scanToken = UUID()
    /// Lets the running scan's background loop see a cancel; the token only
    /// guards what reaches the main thread.
    var scanCancellation: CleanerSupport.ScanCancellation?

    var selectedSize: Int64 { items.filter(\.include).reduce(0) { $0 + $1.size } }
    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    var selectedCount: Int { items.filter(\.include).count }

    // MARK: - Category scanners

    /// Library locations where uninstalled apps leave data behind. Only direct
    /// children are eligible. A selected app's Uninstaller can prove deeper
    /// ownership; the general Cleaner cannot safely infer it.
    static let leftoverRoots: [(path: String, usesContainerMetadata: Bool)] = [
        ("Application Support", false),
        ("Caches", false),
        ("Preferences", false),
        ("Preferences/ByHost", false),
        ("Saved Application State", false),
        ("HTTPStorages", false),
        ("WebKit", false),
        ("Logs", false),
        ("Containers", true),
        ("Cookies", false),
        ("PreferencePanes", false),
        ("Internet Plug-Ins", false),
        ("Services", false),
        ("QuickLook", false),
        ("Spotlight", false),
        ("Input Methods", false),
        ("Screen Savers", false),
        ("ColorPickers", false),
        ("Widgets", false),
        ("Address Book Plug-Ins", false),
        ("Contextual Menu Items", false),
        ("Safari/Extensions", false),
        ("Automator", false),
        ("CoreImage", false),
        ("Dictionaries", false),
        ("Components", false),
        ("Audio/Plug-Ins", false),
    ]
}
