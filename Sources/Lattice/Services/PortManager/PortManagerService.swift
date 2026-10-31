// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Darwin
import Foundation

final class PortManagerService: ObservableObject {
    static let shared = PortManagerService()
    @Published var entries: [PortManagerEntry] = []
    @Published var query = ""
    @Published var isRefreshing = false
    @Published var hasLoadedOnce = false
    @Published var refreshFailed = false

    var filteredEntries: [PortManagerEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return entries }
        return entries.filter { "\($0.port) \($0.processName) \($0.pid) \($0.address)".lowercased().contains(q) }
    }

    let readWork = FeatureWorkRegistry()

    func refresh() {
        guard let cancellation = readWork.begin(owner: .portManager, isAvailable: { $0.isAvailable }), !isRefreshing else { return }
        isRefreshing = true
        refreshFailed = false
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Self.snapshot(cancellation: cancellation)
            DispatchQueue.main.async {
                guard !cancellation.isCancelled else { return }
                if let result {
                    self.entries = result
                    self.hasLoadedOnce = true
                }
                self.refreshFailed = result == nil
                self.isRefreshing = false
            }
        }
    }

    func terminate(_ entry: PortManagerEntry, force: Bool) {
        guard AppFeature.portManager.isAvailable, AppFeature.killProcess.isAvailable, let startedAt = entry.startedAt else { return }
        KillProcessService.shared.kill(pid: entry.pid,
                                       name: entry.processName,
                                       startedAt: startedAt,
                                       force: force, owner: .portManager) { [weak self] in
            self?.refresh()
        }
    }

    private static func startTimes() -> [pid_t: UInt64] {
        let estimatedCount = max(1, Int(proc_listallpids(nil, 0)))
        var pids = [pid_t](repeating: 0, count: estimatedCount + 32)
        let count = pids.withUnsafeMutableBytes { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count))
        }
        guard count > 0 else { return [:] }
        var identities: [pid_t: UInt64] = [:]
        for pid in pids.prefix(min(Int(count), pids.count)) where pid > 0 {
            identities[pid] = KillProcessService.startTime(for: pid)
        }
        return identities
    }

    private static func snapshot(cancellation: FeatureWorkCancellation = FeatureWorkCancellation()) -> [PortManagerEntry]? {
        guard !cancellation.isCancelled else { return nil }
        let identities = startTimes()
        let result = FeatureReadProcess.run("/usr/sbin/lsof", ["-nP", "+c0", "-iTCP", "-sTCP:LISTEN", "-F", "pcnPT"], cancellation: cancellation)
        // Negative status means Shell.run hit its own timeout — always bail.
        guard !cancellation.isCancelled, result.status >= 0 else { return nil }
        let parsed = PortManagerSupport.parseLsof(result.output).map { entry in
            // Only the same process observed across the entire listing may
            // be terminated. New or reused PIDs remain visible without actions
            // until a subsequent refresh can establish their identity.
            let startedAt = identities[entry.pid]
            let stable = startedAt != nil && startedAt == KillProcessService.startTime(for: entry.pid)
            return PortManagerEntry(port: entry.port,
                             protocolName: entry.protocolName,
                             address: entry.address,
                             pid: entry.pid,
                             processName: entry.processName,
                             startedAt: stable ? startedAt : nil)
        }
        // lsof exits 1 when no listening sockets are found or when it prints a
        // warning. Both cases yield a clean result: an empty list or the parsed rows.
        // A negative status code above (timeout) is the only infrastructure failure.
        return parsed
    }
}
