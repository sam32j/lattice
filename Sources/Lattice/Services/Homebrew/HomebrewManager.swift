// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Darwin
import Foundation

final class HomebrewManager: ObservableObject {
    static let shared = HomebrewManager()

    @Published var brewPath: String?
    @Published var installed: [HomebrewPackage] = []
    @Published var searchResults: [HomebrewPackage] = []
    @Published var selectedPackage: HomebrewPackage?
    @Published var isLoadingInstalled = false
    @Published var isLoadingOutdated = false
    @Published var isSearching = false
    @Published var isLoadingPopularity = false
    @Published var isLoadingDetails = false
    @Published var operation: HomebrewOperation?
    @Published var operationStatus: HomebrewOperationStatus?
    @Published var log = ""
    @Published var errorMessage: String?
    @Published var terminalFallbackCommand: String?
    /// A third-party tap Homebrew refused to load until the user trusts it,
    /// with the interrupted work retried right after the one-click trust.
    @Published var untrustedTap: String?
    @Published var isTrustingTap = false
    var untrustedTapRetry: (() -> Void)?
    @Published var didOpenInstaller = false
    @Published var isShellConfigured = true
    @Published var shellConfigProfilePath: String?
    @Published var didOpenShellConfig = false
    @Published var outdatedPackagesByID: [String: HomebrewPackageUpdate] = [:]

    let readWork = FeatureWorkRegistry()
    var installedRead: (id: UUID, owner: AppFeature)?
    var outdatedRead: (id: UUID, owner: AppFeature)?
    var trustRead: UUID?
    var operationOwner: AppFeature?
    let workQueue = DispatchQueue(label: "io.github.sam32j.lattice.homebrew", qos: .userInitiated)
    var searchGeneration = 0
    var detailsGeneration = 0
    var outdatedGeneration = 0
    var currentSearchKind: HomebrewPackageKind?
    var popularityCache: [HomebrewPackageKind: PopularityCacheEntry] = [:]
    var popularityLoads: Set<HomebrewPackageKind> = []
    var activeProcess: Process?
    var cancelRequested = false
    var installedCaskRecords: [HomebrewCaskRecord] = []
    var installedCaskRecordsFetchedAt: Date?
    var ownershipLoads: [String: [(HomebrewPackage?) -> Void]] = [:]
    var completedOperationCleanup: DispatchWorkItem?
    lazy var analyticsSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 6
        configuration.timeoutIntervalForResource = 8
        return URLSession(configuration: configuration)
    }()

    init() {
        brewPath = detectBrewPath()
    }

    /// Timeout for read-only Homebrew commands (info, search, outdated).
    /// These are normally fast, but a hung NFS share or locked database can
    /// make them stall indefinitely.
    static let brewReadTimeout: TimeInterval = 30
    /// Install/upgrade/uninstall run on the same serial queue as every read, so a
    /// hung one must end eventually. A big download, a source build and a copy into
    /// Applications are all slow but never silent, so the bound is on silence: a cap
    /// on total time would end work that was still going.
    static let brewSilenceTimeout: TimeInterval = 15 * 60
    static let processTerminationGrace: TimeInterval = 2
}
