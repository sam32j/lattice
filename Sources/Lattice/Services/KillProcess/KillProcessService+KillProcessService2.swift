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
        guard !entry.isProtected, let url = entry.bundleURL, let startedAt = entry.startedAt else { return }
        restart(pid: entry.pid, startedAt: startedAt, bundleURL: url)
    }

    /// The same restart for a Kill Process row. `completion` reports on the
    /// main thread whether the app came back.
    func restart(pid: pid_t, startedAt: UInt64, bundleURL url: URL, completion: ((Bool) -> Void)? = nil) {
        guard let cancellation = readWork.begin(owner: .killProcess, isAvailable: { $0.isAvailable }),
              !Self.isProtected(pid: pid) else {
            completion?(false)
            return
        }
        let target = KillTarget(pid: pid, startedAt: startedAt)
        cancelPendingRestart(relaunched: false)
        pendingRestartPID = pid
        pendingRestartURL = url
        pendingRestartCompletion = completion
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
                DispatchQueue.main.async { if !cancellation.isCancelled { self?.cancelPendingRestart(relaunched: false) } }
            case .killed, .alreadyGone:
                break
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard !cancellation.isCancelled, self?.pendingRestartPID == pid else { return }
            self?.cancelPendingRestart(relaunched: false)
        }
    }

    func completeRestart(cancellation: FeatureWorkCancellation) {
        guard !cancellation.isCancelled, AppFeature.killProcess.isAvailable, let url = pendingRestartURL else {
            cancelPendingRestart(relaunched: false)
            return
        }
        let completion = pendingRestartCompletion
        pendingRestartCompletion = nil
        cancelPendingRestart()
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { [weak self] app, error in
            DispatchQueue.main.async {
                guard !cancellation.isCancelled else { return }
                completion?(app != nil && error == nil)
                self?.refresh(force: true)
            }
        }
    }

    /// Drops a pending restart. A caller still waiting hears it did not come back.
    func cancelPendingRestart(relaunched: Bool? = nil) {
        if let restartObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(restartObserver)
        }
        restartObserver = nil
        pendingRestartPID = nil
        pendingRestartURL = nil
        let completion = pendingRestartCompletion
        pendingRestartCompletion = nil
        if let relaunched { completion?(relaunched) }
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
                  KillProcessSupport.pathsMatch(reported: expectedPath,
                                                kernel: String(cString: pathBuffer)) else { return nil }
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
    static func snapshot(cancellation: FeatureWorkCancellation) -> (entries: [KillProcessEntry], items: [KillProcessItem])? {
        let result = FeatureReadProcess.run("/bin/ps", ["-eo", "pid,ppid,uid,pcpu,rss,comm"], cancellation: cancellation)
        guard !cancellation.isCancelled, result.status == 0 else { return nil }
        let parsed = parsePS(result.output)
        guard !parsed.isEmpty else { return nil }
        let rows = parsed.map(\.entry)
        // The Command Bar lists each app once, with its helpers folded in.
        let entries = groupedByApp(rows).sorted { $0.cpuPercent > $1.cpuPercent }
        let items = KillProcessCatalog.items(from: parsed.map(\.probe),
                                             ownPID: ProcessInfo.processInfo.processIdentifier,
                                             currentUID: getuid(),
                                             ports: listeningPorts(probes: parsed.map(\.probe),
                                                                   cancellation: cancellation))
        return (entries, items)
    }

    /// Every listening TCP socket. A port may only be acted on when its
    /// process is the same one `ps` just listed; a new or reused PID stays
    /// visible without actions until the next refresh confirms it.
    static func listeningPorts(probes: [KillProcessProbe], cancellation: FeatureWorkCancellation) -> [KillProcessPort] {
        guard !cancellation.isCancelled else { return [] }
        let result = FeatureReadProcess.run("/usr/sbin/lsof", ["-nP", "+c0", "-iTCP", "-sTCP:LISTEN", "-F", "pcnPT"],
                                            cancellation: cancellation)
        // lsof exits 1 when nothing listens; only a timeout (negative) fails.
        guard !cancellation.isCancelled, result.status >= 0 else { return [] }
        let identities = Dictionary(probes.map { ($0.pid, $0.startedAt) }, uniquingKeysWith: { first, _ in first })
        return KillProcessPortSupport.parseLsof(result.output).map { entry in
            let startedAt = identities[entry.pid] ?? nil
            let stable = startedAt != nil && startedAt == currentStartTime(pid: entry.pid)
            // A command line is read only for a generic runtime, once per process.
            let arguments = KillProcessPortServices.isRuntime(entry.processName)
                ? commandLine(pid: entry.pid) : nil
            return KillProcessPort(port: entry.port, protocolName: entry.protocolName, address: entry.address,
                                   pid: entry.pid, processName: entry.processName,
                                   startedAt: stable ? startedAt : nil,
                                   service: KillProcessPortServices.service(processName: entry.processName,
                                                                           port: entry.port, arguments: arguments))
        }
    }

    /// A process's arguments, from `KERN_PROCARGS2`: the argument count, the
    /// executable path, padding, then each argument NUL-terminated. Only the
    /// user's own processes are readable, which is all the Ports section acts on.
    static func commandLine(pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }
        let count = buffer.withUnsafeBytes { Int($0.load(as: Int32.self)) }
        var cursor = MemoryLayout<Int32>.size
        // Skip the executable path and the padding after it.
        while cursor < size, buffer[cursor] != 0 { cursor += 1 }
        while cursor < size, buffer[cursor] == 0 { cursor += 1 }
        var arguments: [String] = []
        while cursor < size, arguments.count < count {
            let start = cursor
            while cursor < size, buffer[cursor] != 0 { cursor += 1 }
            arguments.append(String(decoding: buffer[start..<cursor], as: UTF8.self))
            cursor += 1
        }
        return arguments.isEmpty ? nil : arguments
    }

    /// Lines look like "  437     1    88  12.5  20480 /System/Library/.../WindowServer".
    static func parsePS(_ output: String) -> [(entry: KillProcessEntry, probe: KillProcessProbe)] {
        var rows: [(entry: KillProcessEntry, probe: KillProcessProbe)] = []
        for line in output.split(separator: "\n").dropFirst() {
            let columns = line.split(separator: " ", maxSplits: 5, omittingEmptySubsequences: true)
            guard columns.count == 6,
                  let pid = pid_t(columns[0]), pid > 0,
                  let ppid = pid_t(columns[1]),
                  let uid = uid_t(columns[2]),
                  let cpu = Double(columns[3])
            else { continue }
            let rss = Double(columns[4]) ?? 0
            let commandPath = String(columns[5]).trimmingCharacters(in: .whitespaces)
            let shortName = commandPath.contains("/")
                ? (commandPath as NSString).lastPathComponent : commandPath
            let running = NSRunningApplication(processIdentifier: pid)
            let startedAt = currentStartTime(pid: pid,
                                             expectedParent: ppid,
                                             expectedPath: commandPath)
            let isProt = isProtected(pid: pid, name: shortName, path: commandPath)
                || startedAt == nil
            let name = ResponsibleProcess.displayName(pid: pid, fallback: shortName)
            let entry = KillProcessEntry(
                pid: pid,
                ppid: ppid,
                name: name,
                path: commandPath,
                cpuPercent: cpu,
                memoryBytes: rss * 1024,
                isRegularApp: running?.activationPolicy == .regular,
                bundleURL: running?.bundleURL,
                groupedCount: 1,
                isProtected: isProt,
                startedAt: startedAt)
            let bundlePath = running?.bundleURL.map(\.path).flatMap { $0.hasSuffix(".app") ? $0 : nil }
            let probe = KillProcessProbe(
                pid: pid,
                ppid: ppid,
                uid: uid,
                name: name,
                path: commandPath,
                cpuPercent: cpu,
                memoryBytes: rss * 1024,
                startedAt: startedAt,
                bundleIdentifier: running?.bundleIdentifier,
                bundlePath: bundlePath,
                activationPolicy: running.map { $0.activationPolicy.rawValue },
                responsiblePID: ResponsibleProcess.owner(of: pid),
                // Lattice is its own kind; only the session's vital processes
                // are protected here.
                isProtected: pid != ProcessInfo.processInfo.processIdentifier
                    && isProtected(pid: pid, name: shortName, path: commandPath))
            rows.append((entry, probe))
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
