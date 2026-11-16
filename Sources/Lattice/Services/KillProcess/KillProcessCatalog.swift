// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// The three lists Kill Process shows, plus Everything, which shows all three
/// as consecutive sections.
enum KillProcessScope: String, CaseIterable, Identifiable {
    case apps, background, ports, system, everything

    var id: String { rawValue }

    /// The scopes that own rows, in the order All Processes shows them. Ports
    /// lists processes again by the sockets they listen on.
    static let sectionScopes: [KillProcessScope] = [.apps, .ports, .background, .system]
}

/// What a running process is, which decides its scope, its primary button
/// and its More menu.
enum KillProcessKind: Equatable {
    /// A regular app with a Dock icon.
    case dockApp
    /// A user-installed menu bar or background app, or a user process that
    /// belongs to no listed app.
    case backgroundApp
    /// A user-level process that ships with macOS and belongs to no listed app.
    case macOSAgent
    /// Owned by root or another system user, or vital to the session. View only.
    case system
    /// Lattice's own process. It can never quit itself from its own row.
    case lattice
    /// A process owned by a listed app. Shown nested under that app.
    case helper

    var scope: KillProcessScope {
        switch self {
        case .dockApp, .lattice: return .apps
        case .backgroundApp, .macOSAgent, .helper: return .background
        case .system: return .system
        }
    }
}

/// The facts the catalog reads about one process. Gathered off the main
/// thread from `ps`, `proc_pidinfo` and `NSRunningApplication`, so the
/// classification itself stays free of AppKit and can be tested.
struct KillProcessProbe: Equatable {
    let pid: pid_t
    let ppid: pid_t
    let uid: uid_t
    let name: String
    let path: String
    let cpuPercent: Double
    let memoryBytes: Double
    let startedAt: UInt64?
    let bundleIdentifier: String?
    /// The `.app` bundle this process runs from, when it is an app.
    let bundlePath: String?
    /// `NSApplication.ActivationPolicy.rawValue` for a process LaunchServices
    /// knows as an app; nil for a plain process.
    let activationPolicy: Int?
    /// The process macOS holds responsible for this one. Equal to `pid` when
    /// it answers for itself.
    let responsiblePID: pid_t
    /// Kernel, launchd, WindowServer, loginwindow and other session-critical
    /// processes that must never be signalled.
    let isProtected: Bool
}

/// One row of the list: a top-level process with the helpers it owns.
struct KillProcessItem: Identifiable, Equatable {
    let pid: pid_t
    let name: String
    let path: String
    let kind: KillProcessKind
    /// Own usage plus every helper's, so the row says what quitting frees.
    let cpuPercent: Double
    let memoryBytes: Double
    let ownCPUPercent: Double
    let ownMemoryBytes: Double
    let startedAt: UInt64?
    let bundleIdentifier: String?
    let bundlePath: String?
    let helpers: [KillProcessItem]
    /// Listening sockets of this process and its helpers, lowest port first.
    var ports: [KillProcessPort] = []

    var id: pid_t { pid }
    var lowestPort: Int { ports.first?.port ?? Int.max }
    var scope: KillProcessScope { kind.scope }
    /// Apps come back from the toast's Reopen; agents and helpers do not.
    var isReopenable: Bool {
        (kind == .dockApp || kind == .backgroundApp) && bundlePath != nil && bundleIdentifier != nil
    }
}

/// One section of the visible list.
struct KillProcessSection: Equatable {
    let scope: KillProcessScope
    let items: [KillProcessItem]
    /// Rows whose helpers a search matched, so they open to show the match.
    let expandedByQuery: Set<pid_t>
}

enum KillProcessChip: Equatable {
    case notResponding, thisApp, front, kept
}

enum KillProcessPrimaryAction: Equatable {
    case quit, stop, forceQuit
}

enum KillProcessMenuAction: Equatable {
    case forceQuit, relaunch, keepRunning, showInFinder, copyPID
}

/// One More menu item and whether it applies to this row. Every row lists
/// the same items in the same order; the ones that do not apply are disabled.
struct KillProcessMenuEntry: Equatable {
    let action: KillProcessMenuAction
    let isEnabled: Bool
}

/// Pure rules for the Kill Process list: classification, nesting, search,
/// sections, chips, primary actions, More menus and Quit Others targets.
enum KillProcessCatalog {
    /// CPU at or above this share shows in the warning color.
    static let highCPUThreshold: Double = 20

    /// Paths only macOS installs into. A user-owned process running from one
    /// of them, with no app to answer for it, is a macOS agent.
    static func isSystemPath(_ path: String) -> Bool {
        let prefixes = ["/System/", "/usr/libexec/", "/usr/sbin/", "/usr/bin/", "/sbin/", "/bin/",
                        "/Library/Apple/", "/Applications/Utilities/"]
        // Homebrew and other local installs live under /usr/local, which is
        // not part of macOS.
        if path.hasPrefix("/usr/local/") { return false }
        return prefixes.contains { path.hasPrefix($0) }
    }

    /// Whether a process ships with macOS: it runs from a macOS path, carries
    /// an Apple bundle identifier, or hides its path the way system daemons do.
    static func isMacOSProcess(_ probe: KillProcessProbe) -> Bool {
        isSystemPath(probe.path)
            || probe.bundleIdentifier?.hasPrefix("com.apple.") == true
            || !probe.path.hasPrefix("/")
    }

    /// Classifies every process, nests helpers under the app that owns them,
    /// and sorts rows and helpers by CPU, highest first. Zombies, which have
    /// already exited and only wait to be reaped, are left out.
    static func items(from allProbes: [KillProcessProbe], ownPID: pid_t, currentUID: uid_t,
                      ports: [KillProcessPort] = []) -> [KillProcessItem] {
        let probes = allProbes.filter { $0.path != "<defunct>" }
        var kinds: [pid_t: KillProcessKind] = [:]
        let byPID = Dictionary(probes.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })

        // Pass 1: Lattice, Dock apps and system processes, which no parent claims.
        for probe in probes {
            if probe.pid == ownPID {
                kinds[probe.pid] = .lattice
            } else if probe.uid != currentUID || probe.isProtected || probe.pid <= 1 {
                kinds[probe.pid] = .system
            } else if probe.activationPolicy == 0 {
                kinds[probe.pid] = .dockApp
            }
        }

        // Pass 2: user-installed background apps that are not part of an app
        // already listed (a login item inside another app's bundle is a helper).
        let pass1Bundles = probes.compactMap { probe -> (pid_t, String)? in
            guard let kind = kinds[probe.pid], kind == .dockApp || kind == .lattice,
                  let bundle = probe.bundlePath else { return nil }
            return (probe.pid, bundle)
        }
        for probe in probes where kinds[probe.pid] == nil {
            guard let policy = probe.activationPolicy, policy != 0,
                  let bundle = probe.bundlePath, !isSystemPath(bundle), !isMacOSProcess(probe) else { continue }
            let insideAnotherApp = pass1Bundles.contains { isInside(bundle, $0.1) }
            let ownedByAnotherApp = probe.responsiblePID != probe.pid
                && pass1Bundles.contains { $0.0 == probe.responsiblePID }
            if !insideAnotherApp && !ownedByAnotherApp {
                kinds[probe.pid] = .backgroundApp
            }
        }

        // Pass 3: helpers, owned by a listed app either through macOS's
        // responsible-process link or by living inside its bundle.
        let apps = probes.compactMap { probe -> (pid: pid_t, bundle: String?)? in
            guard let kind = kinds[probe.pid],
                  kind == .dockApp || kind == .lattice || kind == .backgroundApp else { return nil }
            return (probe.pid, probe.bundlePath)
        }
        let appPIDs = Set(apps.map(\.pid))
        var parentOf: [pid_t: pid_t] = [:]
        for probe in probes where kinds[probe.pid] == nil {
            if probe.responsiblePID != probe.pid, appPIDs.contains(probe.responsiblePID) {
                parentOf[probe.pid] = probe.responsiblePID
            } else if let owner = apps.first(where: { $0.bundle.map { isInside(probe.path, $0) } ?? false }) {
                parentOf[probe.pid] = owner.pid
            } else if let owner = ancestorApp(of: probe, byPID: byPID, appPIDs: appPIDs) {
                parentOf[probe.pid] = owner
            }
            if parentOf[probe.pid] != nil { kinds[probe.pid] = .helper }
        }

        // Pass 4: everything else stands alone. Prefer Background over System
        // when unsure, so the person can still act on it.
        for probe in probes where kinds[probe.pid] == nil {
            kinds[probe.pid] = isMacOSProcess(probe) ? .macOSAgent : .backgroundApp
        }

        var helpersByParent: [pid_t: [KillProcessItem]] = [:]
        for probe in probes {
            guard kinds[probe.pid] == .helper, let parent = parentOf[probe.pid] else { continue }
            helpersByParent[parent, default: []].append(item(probe, kind: .helper, helpers: []))
        }
        let portsByPID = Dictionary(grouping: ports, by: \.pid)
        return probes.compactMap { probe -> KillProcessItem? in
            guard let kind = kinds[probe.pid], kind != .helper else { return nil }
            let helpers = (helpersByParent[probe.pid] ?? []).sorted(by: comesBefore)
            var row = item(probe, kind: kind, helpers: helpers)
            // A port a helper opened belongs to the app the helper serves.
            let owned: [pid_t] = [probe.pid] + helpers.map(\.pid)
            var rowPorts: [KillProcessPort] = []
            for pid in owned { rowPorts += portsByPID[pid] ?? [] }
            row.ports = rowPorts.sorted(by: portComesBefore)
            return row
        }
        .sorted(by: comesBefore)
    }

    static func portComesBefore(_ lhs: KillProcessPort, _ rhs: KillProcessPort) -> Bool {
        lhs.port == rhs.port ? lhs.pid < rhs.pid : lhs.port < rhs.port
    }

    /// Whether `path` sits inside `bundle` (and is not the bundle itself).
    static func isInside(_ path: String, _ bundle: String) -> Bool {
        let root = bundle.hasSuffix("/") ? bundle : bundle + "/"
        return path.hasPrefix(root)
    }

    /// The nearest listed app up the parent chain, for a child process an
    /// app spawned that macOS does not hold the app responsible for.
    private static func ancestorApp(of probe: KillProcessProbe,
                                    byPID: [pid_t: KillProcessProbe],
                                    appPIDs: Set<pid_t>) -> pid_t? {
        var cursor = probe.ppid
        var seen: Set<pid_t> = [probe.pid]
        while cursor > 1, seen.insert(cursor).inserted {
            if appPIDs.contains(cursor) { return cursor }
            guard let next = byPID[cursor] else { return nil }
            cursor = next.ppid
        }
        return nil
    }

    private static func item(_ probe: KillProcessProbe, kind: KillProcessKind,
                             helpers: [KillProcessItem]) -> KillProcessItem {
        KillProcessItem(
            pid: probe.pid,
            name: probe.name,
            path: probe.path,
            kind: kind,
            cpuPercent: probe.cpuPercent + helpers.reduce(0) { $0 + $1.cpuPercent },
            memoryBytes: probe.memoryBytes + helpers.reduce(0) { $0 + $1.memoryBytes },
            ownCPUPercent: probe.cpuPercent,
            ownMemoryBytes: probe.memoryBytes,
            startedAt: probe.startedAt,
            bundleIdentifier: probe.bundleIdentifier,
            bundlePath: probe.bundlePath,
            helpers: helpers)
    }

    /// CPU, highest first; ties fall back to the lower PID so rows hold still.
    static func comesBefore(_ lhs: KillProcessItem, _ rhs: KillProcessItem) -> Bool {
        if lhs.cpuPercent == rhs.cpuPercent { return lhs.pid < rhs.pid }
        return lhs.cpuPercent > rhs.cpuPercent
    }

    // MARK: Sections and search

    /// Names and port services match anywhere; numbers match from the start,
    /// so typing a PID or port narrows the list as each digit arrives. A
    /// leading colon searches ports only. Services match in English and in
    /// `language`.
    static func matches(_ item: KillProcessItem, needle: String, language: AppLanguage = .enUS) -> Bool {
        if needle.hasPrefix(":") {
            let port = String(needle.dropFirst())
            return !port.isEmpty && item.ports.contains { String($0.port).hasPrefix(port) }
        }
        if item.name.lowercased().contains(needle) { return true }
        let strings = [KillProcessListStrings.enUS, FeatureStrings.killProcessList(language)]
        if item.ports.contains(where: { port in
            guard let service = port.service else { return false }
            return strings.contains { $0.serviceName(service).lowercased().contains(needle) }
        }) { return true }
        guard needle.allSatisfy(\.isASCIIDigit) else { return false }
        return String(item.pid).hasPrefix(needle) || item.ports.contains { String($0.port).hasPrefix(needle) }
    }

    /// Whether a row belongs in a section: its own scope, or Ports when it listens.
    static func belongs(_ item: KillProcessItem, to scope: KillProcessScope) -> Bool {
        scope == .ports ? !item.ports.isEmpty : item.scope == scope
    }

    /// The sections to show. A search looks through every scope, whatever is
    /// selected, and a match on a helper shows its parent opened. Apps reads
    /// This app, Front, Kept, then the rest, each group by name; the other
    /// sections stay sorted by CPU.
    static func sections(_ items: [KillProcessItem], scope: KillProcessScope, query: String,
                         frontPID: pid_t? = nil,
                         isKept: (String?) -> Bool = { _ in false },
                         language: AppLanguage = .enUS) -> [KillProcessSection] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let scopes = needle.isEmpty && scope != .everything ? [scope] : KillProcessScope.sectionScopes
        return scopes.compactMap { sectionScope in
            var expanded: Set<pid_t> = []
            let rows = items.filter { belongs($0, to: sectionScope) }.compactMap { item -> KillProcessItem? in
                guard !needle.isEmpty else { return item }
                if matches(item, needle: needle, language: language) { return item }
                if item.helpers.contains(where: { matches($0, needle: needle, language: language) }) {
                    expanded.insert(item.pid)
                    return item
                }
                return nil
            }
            guard !rows.isEmpty else { return nil }
            let ordered: [KillProcessItem]
            switch sectionScope {
            case .apps: ordered = orderedApps(rows, frontPID: frontPID, isKept: isKept)
            case .ports: ordered = rows.sorted { $0.lowestPort == $1.lowestPort ? $0.pid < $1.pid : $0.lowestPort < $1.lowestPort }
            default: ordered = rows
            }
            return KillProcessSection(scope: sectionScope, items: ordered, expandedByQuery: expanded)
        }
    }

    /// This app, then Front, then Kept, then everything else, each by name.
    static func orderedApps(_ items: [KillProcessItem], frontPID: pid_t?,
                            isKept: (String?) -> Bool) -> [KillProcessItem] {
        func group(_ item: KillProcessItem) -> Int {
            if item.kind == .lattice { return 0 }
            if item.kind == .dockApp, item.pid == frontPID { return 1 }
            if item.kind == .dockApp, isKept(item.bundleIdentifier) { return 2 }
            return 3
        }
        return items.sorted { lhs, rhs in
            let left = group(lhs), right = group(rhs)
            if left != right { return left < right }
            let byName = lhs.name.localizedStandardCompare(rhs.name)
            return byName == .orderedSame ? lhs.pid < rhs.pid : byName == .orderedAscending
        }
    }

    /// Count of top-level rows in one scope, for the scope menu.
    static func count(_ items: [KillProcessItem], in scope: KillProcessScope) -> Int {
        scope == .everything ? items.count : items.filter { belongs($0, to: scope) }.count
    }

    // MARK: Row content

    static func chip(for item: KillProcessItem, frontPID: pid_t?, isKept: Bool,
                     isNotResponding: Bool) -> KillProcessChip? {
        if isNotResponding { return .notResponding }
        if item.kind == .lattice { return .thisApp }
        if item.pid == frontPID, item.kind == .dockApp { return .front }
        if isKept, item.kind == .dockApp { return .kept }
        return nil
    }

    static func primaryAction(for item: KillProcessItem, isNotResponding: Bool) -> KillProcessPrimaryAction? {
        switch item.kind {
        case .lattice, .system: return nil
        case _ where isNotResponding: return .forceQuit
        case .dockApp: return .quit
        case .backgroundApp, .macOSAgent, .helper: return .stop
        }
    }

    /// The Ports section's button: Stop, which ends only the processes holding
    /// this row's ports (an app keeps running when a helper holds the port).
    /// System processes and Lattice offer none, nor do ports whose process
    /// could not be verified.
    static func portPrimaryAction(for item: KillProcessItem, ownPID: pid_t) -> KillProcessPrimaryAction? {
        guard item.kind != .system, item.kind != .lattice else { return nil }
        return stoppablePorts(item.ports, ownPID: ownPID).isEmpty ? nil : .stop
    }

    /// Ports whose process may be stopped: verified, and never Lattice itself.
    static func stoppablePorts(_ ports: [KillProcessPort], ownPID: pid_t) -> [KillProcessPort] {
        ports.filter { $0.startedAt != nil && $0.pid != ownPID }
    }

    /// The More menu for a row: Force Quit, Relaunch, Show in Finder and Copy
    /// PID, with Skip Quit All first in the Apps section. The row draws
    /// separators after Skip Quit All and after Relaunch.
    static func menu(for item: KillProcessItem, in scope: KillProcessScope) -> [KillProcessMenuEntry] {
        let actionable = item.startedAt != nil
        let canSignal = actionable && item.kind != .system && item.kind != .lattice
        let canRelaunch: Bool = {
            switch item.kind {
            case .dockApp, .backgroundApp: return canSignal && item.bundlePath != nil
            // launchd starts a macOS agent again once it stops.
            case .macOSAgent: return canSignal
            case .system, .lattice, .helper: return false
            }
        }()
        let actions = [
            KillProcessMenuEntry(action: .forceQuit, isEnabled: canSignal),
            KillProcessMenuEntry(action: .relaunch, isEnabled: canRelaunch),
            KillProcessMenuEntry(action: .showInFinder, isEnabled: (item.bundlePath ?? item.path).hasPrefix("/")),
            KillProcessMenuEntry(action: .copyPID, isEnabled: true),
        ]
        // Skip Quit All only means something where Quit all apps acts, so it
        // leads the Apps menu and is absent everywhere else.
        guard scope == .apps else { return actions }
        let canKeep = item.kind == .dockApp && item.bundleIdentifier != nil
        return [KillProcessMenuEntry(action: .keepRunning, isEnabled: canKeep)] + actions
    }

    /// Whether a row gets the info icon with its What Is This? description.
    /// Only when Lattice can say what the process does; the generic "part of
    /// macOS" line adds nothing the row does not already show.
    static func hasDescription(_ item: KillProcessItem, language: AppLanguage) -> Bool {
        (item.kind == .macOSAgent || item.kind == .system)
            && KillProcessDescriptions.specificDescription(for: item.name, language: language) != nil
    }

    // MARK: Quit Others

    /// What a section's Quit all apps asks to quit: the Dock apps in Apps,
    /// skipping kept apps and Lattice. Background and System never offer it.
    static func quitOthersTargets(_ section: KillProcessSection,
                                  isKept: (String?) -> Bool) -> [KillProcessItem] {
        guard section.scope == .apps else { return [] }
        return section.items.filter { item in
            item.kind == .dockApp && item.bundleIdentifier != nil && !isKept(item.bundleIdentifier)
        }
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
