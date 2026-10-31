// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import CoreServices

/// Finds which of the installed apps have a newer version waiting, in one
/// list, and updates the ones the person picks.
///
/// Managed apps can be updated in place or handed to the store. Other apps
/// are compared conservatively with a public online catalog and only opened,
/// leaving their own updater in control.
///
/// Nothing runs at rest. The scan happens when the person opens the list or
/// asks for it, and the background check only exists while its schedule is on.
final class AppUpdatesService: ObservableObject {
    static let shared = AppUpdatesService()

    @Published var items: [AppUpdatesSupport.Item] = []
    @Published var rules: [AppUpdatesSupport.UpdateRule] = []
    /// Latest scan, including skipped versions, so removing a rule needs no network work.
    var allItems: [AppUpdatesSupport.Item] = []
    @Published var isChecking = false
    @Published var lastCheck: Date?
    @Published var nextCheck: Date?
    /// Rows the person ticked. New findings arrive ticked, so the common
    /// case is one click.
    @Published var selection: Set<String> = []
    /// False means package-managed apps cannot be updated from this list.
    @Published var packageManagerAvailable = false
    /// False means the online source failed, so an empty list is incomplete.
    @Published var onlineCatalogAvailable = true
    @Published var appStoreAvailable = true
    @Published var uncheckedAppNames: [String] = []
    /// Apps the catalog knows whose own version cannot be compared with it.
    /// They are named instead of listed, so nothing claims an update for them
    /// or implies they are current.
    @Published var uncomparableAppNames: [String] = []
    /// A check finished in THIS process. The time of the last check survives
    /// relaunches, but its findings do not, so nothing may claim the Mac is
    /// up to date until a scan has actually run here.
    @Published var hasCheckedThisSession = false
    @Published var lastError: String?

    let workQueue = DispatchQueue(label: "io.github.sam32j.lattice.appupdates", qos: .utility)
    lazy var lookupSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 20
        return URLSession(configuration: configuration)
    }()
    lazy var catalogSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 20
        return URLSession(configuration: configuration)
    }()
    var timer: Timer?
    var wakeObserver: NSObjectProtocol?
    var scanGeneration = 0
    var checkCancellation: AppUpdateCheckCancellation?
    var sourceRefreshPending = false
    var automaticCheckPending = false
    var knownIDs = Set<String>()
    /// The person was sent elsewhere to finish an update, so the list is
    /// about to be wrong until it is read again.
    var pendingUpdateHandoffs = Set<UUID>()
    var updateHandoffPending: Bool {
        !pendingUpdateHandoffs.isEmpty
    }
    var onlineCatalogCache: (loadedAt: Date, entries: [AppUpdatesSupport.CatalogEntry])?
    /// Alive only while an upgrade this service started is running, so the
    /// list refreshes itself even when no window is on screen to notice.
    var upgradeObserver: AnyCancellable?

    private init() {
        let stamp = UserDefaults.standard.double(forKey: DefaultsKey.appUpdatesLastCheck)
        lastCheck = stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
        rules = AppUpdatesSupport.decodedRules(
            UserDefaults.standard.string(forKey: DefaultsKey.appUpdatesRules))
    }

}
