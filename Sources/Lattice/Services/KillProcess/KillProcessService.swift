// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Darwin
import Foundation

/// One row of the live process list: either a single process, or - when
/// grouping is on - a responsible app with every helper process it owns
/// folded into it (`groupedCount > 1`).
final class KillProcessService: ObservableObject {
    static let shared = KillProcessService()

    enum SortBy: String {
        case cpu, memory, name, pid
    }

    enum DirectKillResult {
        case killed, alreadyGone, needsAdmin, failed, stale
    }

    struct KillTarget {
        let pid: pid_t
        let startedAt: UInt64
    }

    struct AdminKillTarget {
        let target: KillTarget
        let startDescription: String
    }

    @Published var entries: [KillProcessEntry] = []
    @Published var query: String = ""
    @Published var sortBy: SortBy
    @Published var sortAscending: Bool
    @Published var groupRelated: Bool
    @Published var isRefreshing = false
    /// True once a `ps` snapshot has completed successfully at least once, so
    /// the view can tell "still loading for the first time" apart from
    /// "search matched nothing" - both look like an empty `entries` array
    /// otherwise.
    @Published var hasLoadedOnce = false

    @Published var activeActionOwners: [AppFeature: Int] = [:]
    let readWork = FeatureWorkRegistry()
    let cacheLock = NSLock()
    var lastRefresh: TimeInterval = 0
    let cacheFreshSeconds: TimeInterval = 3

    var restartObserver: NSObjectProtocol?
    var pendingRestartPID: pid_t?
    var pendingRestartURL: URL?

    init() {
        sortBy = SortBy(rawValue: UserDefaults.standard.string(forKey: DefaultsKey.killProcessSortBy) ?? "cpu") ?? .cpu
        sortAscending = UserDefaults.standard.bool(forKey: DefaultsKey.killProcessSortAscending)
        groupRelated = UserDefaults.standard.bool(forKey: DefaultsKey.killProcessGroupRelated)
    }
}
