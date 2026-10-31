// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Darwin
import Foundation

/// One row of the live process list: either a single process, or - when
/// grouping is on - a responsible app with every helper process it owns
/// folded into it (`groupedCount > 1`).
extension KillProcessService {

    var sortedEntries: [KillProcessEntry] {
        let ascending = sortAscending
        return entries.sorted { lhs, rhs in
            switch sortBy {
            case .cpu:
                return KillProcessSupport.numberComesBefore(lhs.cpuPercent, rhs.cpuPercent,
                                                            lhsPID: lhs.pid, rhsPID: rhs.pid,
                                                            ascending: ascending)
            case .memory:
                return KillProcessSupport.numberComesBefore(lhs.memoryBytes, rhs.memoryBytes,
                                                            lhsPID: lhs.pid, rhsPID: rhs.pid,
                                                            ascending: ascending)
            case .name:
                return KillProcessSupport.nameComesBefore(lhs.name, rhs.name,
                                                          lhsPID: lhs.pid, rhsPID: rhs.pid,
                                                          ascending: ascending)
            case .pid:
                return KillProcessSupport.numberComesBefore(Double(lhs.pid), Double(rhs.pid),
                                                            lhsPID: lhs.pid, rhsPID: rhs.pid,
                                                            ascending: ascending)
            }
        }
    }

    var filteredEntries: [KillProcessEntry] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return sortedEntries }
        return sortedEntries.filter {
            $0.name.lowercased().contains(needle) || String($0.pid) == needle
        }
    }

    /// Column-header sorting: clicking the active column flips direction,
    /// clicking a different one switches to it at that column's natural
    /// default direction (highest-first for CPU/memory/PID, A-Z for name).
    func toggleSort(_ value: SortBy) {
        if sortBy == value {
            sortAscending.toggle()
        } else {
            sortBy = value
            sortAscending = value == .name
        }
        UserDefaults.standard.set(sortBy.rawValue, forKey: DefaultsKey.killProcessSortBy)
        UserDefaults.standard.set(sortAscending, forKey: DefaultsKey.killProcessSortAscending)
    }

    func setGroupRelated(_ value: Bool) {
        groupRelated = value
        UserDefaults.standard.set(value, forKey: DefaultsKey.killProcessGroupRelated)
        refresh(force: true)
    }

    /// Refreshes the process list off the main thread and republishes on the
    /// main thread. `force` bypasses the freshness cache, so a kill's
    /// reconciling refresh and an explicit tap of the refresh button always
    /// see the current state. `completion` always fires on the main thread,
    /// even when the cache was already fresh, so a caller that needs the
    /// current snapshot (the Command Bar's lazy load) can sequence off it
    /// instead of guessing at a delay.
    func refresh(force: Bool = false, completion: (() -> Void)? = nil) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.refresh(force: force, completion: completion) }
            return
        }

        guard let cancellation = readWork.begin(owner: .killProcess, isAvailable: { $0.isAvailable }) else {
            completion?()
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        cacheLock.lock()
        let fresh = !force && now - lastRefresh < cacheFreshSeconds
        cacheLock.unlock()
        guard !fresh else {
            completion?()
            return
        }

        isRefreshing = true
        let grouped = groupRelated
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let rows = Self.snapshot(grouped: grouped, cancellation: cancellation)
            DispatchQueue.main.async {
                guard let self, !cancellation.isCancelled else {
                    completion?()
                    return
                }
                // A failed or empty `ps` call (transient - a timeout under
                // load, a hiccup) must never wipe a list that was already
                // showing good data; only a genuine snapshot replaces it.
                if let rows {
                    self.entries = rows
                    self.hasLoadedOnce = true
                }
                self.isRefreshing = false
                self.cacheLock.lock()
                self.lastRefresh = ProcessInfo.processInfo.systemUptime
                self.cacheLock.unlock()
                completion?()
            }
        }
    }

    // MARK: - Kill

    func kill(_ entry: KillProcessEntry, force: Bool) {
        guard let cancellation = readWork.begin(owner: .killProcess, isAvailable: { $0.isAvailable }) else { return }
        guard !entry.isProtected, let target = Self.target(for: entry) else { return }
        beginProtectedAction(.killProcess)
        DispatchQueue.global(qos: .userInitiated).async {
            defer { self.endProtectedAction(.killProcess) }
            guard !cancellation.isCancelled else { return }
            let removed = self.killBatch([target], force: force, adminPromptProcessName: entry.name, cancellation: cancellation)
            self.finishKill(removed: removed, cancellation: cancellation)
        }
    }

    /// Kills a process identified by its pid, name, and kernel start time.
    /// This is the shared safe path for rows supplied by another feature.
    func kill(pid: pid_t,
              name: String,
              startedAt: UInt64,
              force: Bool,
              owner: AppFeature = .killProcess,
              completion: (() -> Void)? = nil) {
        guard let cancellation = readWork.begin(owner: owner, isAvailable: { $0.isAvailable && AppFeature.killProcess.isAvailable }) else { return }
        guard !Self.isProtected(pid: pid, name: name) else {
            completion?()
            return
        }
        let target = KillTarget(pid: pid, startedAt: startedAt)
        beginProtectedAction(owner)
        DispatchQueue.global(qos: .userInitiated).async {
            defer { self.endProtectedAction(owner) }
            guard !cancellation.isCancelled else { return }
            let removed = self.killBatch([target], force: force, adminPromptProcessName: name, cancellation: cancellation)
            self.finishKill(removed: removed, cancellation: cancellation, completion: completion)
        }
    }

    /// Kills every currently listed process sharing this exact name.
    func killAll(named name: String, force: Bool) {
        guard let cancellation = readWork.begin(owner: .killProcess, isAvailable: { $0.isAvailable }) else { return }
        let targets = entries.filter { $0.name == name && !$0.isProtected }
            .compactMap(Self.target(for:))
        guard !targets.isEmpty else { return }
        beginProtectedAction(.killProcess)
        DispatchQueue.global(qos: .userInitiated).async {
            defer { self.endProtectedAction(.killProcess) }
            guard !cancellation.isCancelled else { return }
            let removed = self.killBatch(targets, force: force, adminPromptProcessName: name, cancellation: cancellation)
            self.finishKill(removed: removed, cancellation: cancellation)
        }
    }

    /// Kills a process together with every descendant, deepest first, so a
    /// parent never outlives children it might otherwise try to restart.
    func killTree(_ entry: KillProcessEntry, force: Bool) {
        guard let cancellation = readWork.begin(owner: .killProcess, isAvailable: { $0.isAvailable }) else { return }
        guard !entry.isProtected, let root = Self.target(for: entry) else { return }
        beginProtectedAction(.killProcess)
        DispatchQueue.global(qos: .userInitiated).async {
            defer { self.endProtectedAction(.killProcess) }
            guard !cancellation.isCancelled, Self.identityMatches(root) else { return }
            let descendants = Self.descendants(of: entry.pid)
                .filter { !Self.isProtected(pid: $0) }
                .compactMap(Self.currentTarget(pid:))
            let targets = Array(descendants.reversed()) + [root]
            guard !cancellation.isCancelled else { return }
            let removed = self.killBatch(targets, force: force, adminPromptProcessName: entry.name, cancellation: cancellation)
            self.finishKill(removed: removed, cancellation: cancellation)
        }
    }

    /// Sends the direct-kill signal to every pid, then escalates every pid
    /// that came back EPERM through a single `AdminShell` prompt, so killing
    /// several processes owned by another user asks for the password once.
    func killBatch(_ targets: [KillTarget],
                           force: Bool,
                           adminPromptProcessName: String, cancellation: FeatureWorkCancellation) -> Set<pid_t> {
        var removed = Set<pid_t>()
        var needsAdmin: [AdminKillTarget] = []
        for target in targets {
            guard !cancellation.isCancelled else { return removed }
            guard !Self.isProtected(pid: target.pid), Self.identityMatches(target) else { continue }
            switch Self.attemptDirectKill(target: target, force: force) {
            case .killed, .alreadyGone:
                removed.insert(target.pid)
            case .needsAdmin:
                if let description = Self.currentStartDescription(pid: target.pid),
                   Self.identityMatches(target) {
                    needsAdmin.append(AdminKillTarget(target: target,
                                                      startDescription: description))
                }
            case .failed, .stale:
                break
            }
        }
        guard !cancellation.isCancelled, !needsAdmin.isEmpty else { return removed }

        let signalFlag = force ? "-9" : "-15"
        let command = needsAdmin.map { candidate in
            let pid = candidate.target.pid
            return "if [ \"$(LC_ALL=C /bin/ps -p \(pid) -o lstart= | /usr/bin/xargs)\" = '\(candidate.startDescription)' ]; then /bin/kill \(signalFlag) \(pid); fi"
        }.joined(separator: "; ")
        let prompt = String(format: FeatureStrings.killProcess(L10n.shared.language).adminPromptFormat,
                            adminPromptProcessName)
        if AdminShell.runSync(command, prompt: prompt) {
            for candidate in needsAdmin where !Self.identityMatches(candidate.target) {
                removed.insert(candidate.target.pid)
            }
        }
        return removed
    }

    static func attemptDirectKill(target: KillTarget, force: Bool) -> DirectKillResult {
        guard identityMatches(target) else { return .stale }
        let pid = target.pid
        if let running = NSRunningApplication(processIdentifier: pid),
           !running.isTerminated, running.activationPolicy == .regular {
            guard identityMatches(target) else { return .stale }
            return (force ? running.forceTerminate() : running.terminate()) ? .killed : .failed
        }
        let signal = force ? SIGKILL : SIGTERM
        guard identityMatches(target) else { return .stale }
        if Darwin.kill(pid, signal) == 0 { return .killed }
        switch errno {
        case EPERM: return .needsAdmin
        case ESRCH: return .alreadyGone
        default: return .failed
        }
    }

    /// Removes killed rows immediately so the list feels responsive, then
    /// reconciles with a real `ps` snapshot shortly after - long enough for
    /// the kernel to have reaped the process, short enough nobody notices
    /// the wait.
    func finishKill(removed: Set<pid_t>, cancellation: FeatureWorkCancellation, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            guard !cancellation.isCancelled else { return }
            if !removed.isEmpty {
                self.entries.removeAll { removed.contains($0.pid) }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard !cancellation.isCancelled else { return }
            self?.refresh(force: true)
            completion?()
        }
    }

    /// Every descendant of `pid`, walked in memory from a single `ps` parent
    /// table. The BFS used to run `pgrep -P` once per pid it had found, so
    /// tearing down a tree of a few hundred processes forked that many short
    /// lived helpers one after another - seconds of stalling while the list
    /// had already dropped the rows.
    ///
    /// A grandchild forked between this snapshot and the signal is missed;
    /// the per-pid `pgrep` walk raced the same way, and `killBatch` still
    /// re-checks every target's identity before it signals anything.
    static func descendants(of pid: pid_t) -> [pid_t] {
        let listing = Shell.run("/bin/ps", ["-eo", "pid,ppid"])
        guard listing.status == 0 else { return [] }
        let parents: [(pid: pid_t, ppid: pid_t)] = listing.output
            .split(separator: "\n").dropFirst().compactMap { line in
                let columns = line.split(separator: " ", omittingEmptySubsequences: true)
                guard columns.count >= 2, let child = pid_t(columns[0]),
                      let parent = pid_t(columns[1]) else { return nil }
                return (child, parent)
            }
        return KillProcessSupport.descendants(of: pid, parents: parents)
    }

    // MARK: - Restart

    func canRestart(_ entry: KillProcessEntry) -> Bool {
        !entry.isProtected && entry.bundleURL != nil && entry.startedAt != nil
    }
}
