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
final class AppUninstaller: ObservableObject {
    static let shared = AppUninstaller()

    enum Phase: Equatable {
        case empty
        case scanning
        case results
        case removing
        case done(freed: Int64, failed: [Leftover])
    }

    struct Target: Equatable {
        let name: String
        let bundleID: String?
        let url: URL
        let icon: NSImage

        static func == (lhs: Target, rhs: Target) -> Bool { lhs.url == rhs.url }
    }

    enum Category: Int, CaseIterable {
        case app, support, caches, preferences, containers, logs, state, other

        var sortRank: Int { rawValue }
    }

    struct Leftover: Identifiable, Equatable {
        let id = UUID()
        let url: URL
        let category: Category
        let size: Int64
        let ownerBundleID: String?
        let ownerGroupID: String?
        let evidenceBundleID: String?
        let confidence: UninstallerSupport.LeftoverMatch
        let fileIdentity: UninstallerSupport.FileIdentity
        var include: Bool = true

        var name: String { url.lastPathComponent }

        static func == (lhs: Leftover, rhs: Leftover) -> Bool {
            lhs.id == rhs.id && lhs.include == rhs.include
        }
    }

    @Published var phase: Phase = .empty
    @Published var target: Target?
    @Published var homebrewPackage: HomebrewPackage?
    /// The app the last selection turned down, so the empty state can say
    /// why instead of springing back in silence (#1582). An accepted
    /// selection or a reset clears it.
    @Published var refusal: UninstallerSupport.RefusedApp?
    @Published var items: [Leftover] = []
    var allowedRemovalPaths = Set<String>()
    var targetFileIdentity: UninstallerSupport.FileIdentity?
    var targetInfoIdentity: UninstallerSupport.FileIdentity?
    var homebrewRemovalSize: Int64 = 0
    var homebrewRemovedApplication = false
    var homebrewRemovalObservation: AnyCancellable?
    var scanCancellation: UninstallerSupport.ScanCancellation?

    struct ScanCandidate {
        let url: URL
        let category: Category
        let ownerBundleID: String?
        let ownerGroupID: String?
        let evidenceBundleID: String?
        let confidence: UninstallerSupport.LeftoverMatch
        var include: Bool
    }

    init() {}

    var selectedSize: Int64 { items.filter(\.include).reduce(0) { $0 + $1.size } }
    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }

    /// What the Homebrew confirmation showed, since the panel, Settings and the
    /// command bar share this uninstaller and can change it while it is open.
    struct HomebrewRemovalConfirmation {
        let package: HomebrewPackage
        let targetURL: URL
        let selectedIDs: Set<UUID>
    }

    static let packageExtensions: Set<String> = [
        "app", "appex", "bundle", "framework", "plugin", "webplugin",
        "prefpane", "qlgenerator", "mdimporter", "service", "saver",
        "colorpicker", "wdgt", "component", "vst", "vst3", "clap", "dpm",
        "aaxplugin", "dictionary", "action", "workflow", "mailbundle",
    ]
}
