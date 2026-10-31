// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Darwin
import Foundation

/// One row of the live process list: either a single process, or - when
/// grouping is on - a responsible app with every helper process it owns
/// folded into it (`groupedCount > 1`).
extension KillProcessService {

    /// Terminates the app, waits for the real termination notification (not
    /// a fixed delay), then relaunches it - the same sequence
    /// `CommandBarService.restart` uses for its own restart row.
    func restart(_ entry: KillProcessEntry) {
        guard let cancellation = readWork.begin(owner: .killProcess, isAvailable: { $0.isAvailable }) else { return }
        guard !entry.isProtected,
              let url = entry.bundleURL,
              let target = Self.target(for: entry) else { return }
        cancelPendingRestart()
        pendingRestartPID = entry.pid
        pendingRestartURL = url
        restartObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard !cancellation.isCancelled, let terminated = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  terminated.processIdentifier == self?.pendingRestartPID else { return }
            self?.completeRestart(cancellation: cancellation)
        }
        beginProtectedAction(.killProcess)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            defer { self?.endProtectedAction(.killProcess) }
            guard !cancellation.isCancelled else { return }
            let result = Self.attemptDirectKill(target: target, force: false)
            switch result {
            case .failed, .needsAdmin, .stale:
                DispatchQueue.main.async { if !cancellation.isCancelled { self?.cancelPendingRestart() } }
            case .killed, .alreadyGone:
                break
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard !cancellation.isCancelled, self?.pendingRestartPID == entry.pid else { return }
            self?.cancelPendingRestart()
        }
    }

    func completeRestart(cancellation: FeatureWorkCancellation) {
        guard !cancellation.isCancelled, AppFeature.killProcess.isAvailable, let url = pendingRestartURL else {
            cancelPendingRestart()
            return
        }
        cancelPendingRestart()
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, _ in
            guard !cancellation.isCancelled else { return }
            self?.refresh(force: true)
        }
    }

    func cancelPendingRestart() {
        if let restartObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(restartObserver)
        }
        restartObserver = nil
        pendingRestartPID = nil
        pendingRestartURL = nil
    }

    // MARK: - Protected Processes

    static func isProtected(pid: pid_t, name: String = "", path: String = "") -> Bool {
        KillProcessSupport.isProtected(pid: pid, name: name, path: path)
    }

    static func startTime(for pid: pid_t) -> UInt64? {
        currentStartTime(pid: pid)
    }

    static func target(for entry: KillProcessEntry) -> KillTarget? {
        guard let startedAt = entry.startedAt else { return nil }
        return KillTarget(pid: entry.pid, startedAt: startedAt)
    }

    static func currentTarget(pid: pid_t) -> KillTarget? {
        currentStartTime(pid: pid).map { KillTarget(pid: pid, startedAt: $0) }
    }

    static func identityMatches(_ target: KillTarget) -> Bool {
        currentStartTime(pid: target.pid) == target.startedAt
    }

    static func currentStartTime(pid: pid_t,
                                         expectedParent: pid_t? = nil,
                                         expectedPath: String? = nil) -> UInt64? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        if let expectedParent, pid_t(info.pbi_ppid) != expectedParent { return nil }
        if let expectedPath, expectedPath.contains("/") {
            var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
            guard proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count)) > 0,
                  String(cString: pathBuffer) == expectedPath else { return nil }
        }
        return info.pbi_start_tvsec &* 1_000_000 &+ info.pbi_start_tvusec
    }

    static func currentStartDescription(pid: pid_t) -> String? {
        let result = Shell.run("/usr/bin/env", ["LC_ALL=C", "/bin/ps", "-p", String(pid),
                                                "-o", "lstart="])
        guard result.status == 0 else { return nil }
        return KillProcessSupport.normalizedStartDescription(result.output)
    }

    // MARK: - Snapshot

    /// Nil on a failed or clearly-wrong snapshot (a timed-out or non-zero
    /// `ps`, or zero rows parsed - never legitimately true on a running Mac),
    /// so a transient hiccup can be told apart from an actually-empty list.
    static func snapshot(grouped: Bool, cancellation: FeatureWorkCancellation) -> [KillProcessEntry]? {
        let result = FeatureReadProcess.run("/bin/ps", ["-eo", "pid,ppid,pcpu,rss,comm"], cancellation: cancellation)
        guard !cancellation.isCancelled, result.status == 0 else { return nil }
        let rows = parsePS(result.output)
        guard !rows.isEmpty else { return nil }
        return (grouped ? groupedByApp(rows) : rows).sorted { $0.cpuPercent > $1.cpuPercent }
    }

    /// Lines look like "  437     1  12.5  20480 /System/Library/.../WindowServer".
    static func parsePS(_ output: String) -> [KillProcessEntry] {
        var rows: [KillProcessEntry] = []
        for line in output.split(separator: "\n").dropFirst() {
            let columns = line.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
            guard columns.count == 5,
                  let pid = pid_t(columns[0]), pid > 0,
                  let ppid = pid_t(columns[1]),
                  let cpu = Double(columns[2])
            else { continue }
            let rss = Double(columns[3]) ?? 0
            let commandPath = String(columns[4]).trimmingCharacters(in: .whitespaces)
            let shortName = commandPath.contains("/")
                ? (commandPath as NSString).lastPathComponent : commandPath
            let running = NSRunningApplication(processIdentifier: pid)
            let startedAt = currentStartTime(pid: pid,
                                             expectedParent: ppid,
                                             expectedPath: commandPath)
            let isProt = isProtected(pid: pid, name: shortName, path: commandPath)
                || startedAt == nil
            rows.append(KillProcessEntry(
                pid: pid,
                ppid: ppid,
                name: ResponsibleProcess.displayName(pid: pid, fallback: shortName),
                path: commandPath,
                cpuPercent: cpu,
                memoryBytes: rss * 1024,
                isRegularApp: running?.activationPolicy == .regular,
                bundleURL: running?.bundleURL,
                groupedCount: 1,
                isProtected: isProt,
                startedAt: startedAt))
        }
        return rows
    }

    /// Folds helper processes under the app responsible for them, summing
    /// their CPU/memory - the same grouping `ProcessUsageService` applies to
    /// the resource breakdown, reused here via `ResponsibleProcess`.
    static func groupedByApp(_ rows: [KillProcessEntry]) -> [KillProcessEntry] {
        var byOwner: [pid_t: [KillProcessEntry]] = [:]
        for row in rows {
            byOwner[ResponsibleProcess.owner(of: row.pid), default: []].append(row)
        }
        return byOwner.compactMap { owner, members in
            guard let primary = members.first(where: { $0.pid == owner }) else { return nil }
            let running = NSRunningApplication(processIdentifier: owner)
            let isProt = isProtected(pid: owner, name: primary.name, path: primary.path)
                || primary.startedAt == nil
            return KillProcessEntry(
                pid: owner,
                ppid: primary.ppid,
                name: ResponsibleProcess.displayName(pid: owner, fallback: primary.name),
                path: primary.path,
                cpuPercent: members.reduce(0) { $0 + $1.cpuPercent },
                memoryBytes: members.reduce(0) { $0 + $1.memoryBytes },
                isRegularApp: running?.activationPolicy == .regular,
                bundleURL: running?.bundleURL,
                groupedCount: members.count,
                isProtected: isProt,
                startedAt: primary.startedAt)
        }
    }
}
