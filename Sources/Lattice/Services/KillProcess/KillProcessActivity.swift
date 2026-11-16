// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import ApplicationServices
import Darwin
import Foundation
import SwiftUI

/// A short result line shown above the list's footer, with Reopen for apps
/// that were just quit.
struct KillProcessToast: Identifiable, Equatable {
    let id = UUID()
    let message: String
}

/// The live state Kill Process's list shares across Settings, the floating
/// HUD and the Dynamic Island: rows in progress, hung apps, the Keep Running
/// list and the latest toast. Every action a row offers runs through here.
final class KillProcessActivity: ObservableObject {
    static let shared = KillProcessActivity()

    /// Rows waiting to exit, with the action that is ending them.
    @Published private(set) var inProgress: [pid_t: KillProcessPrimaryAction] = [:]
    @Published private(set) var notResponding: Set<pid_t> = []
    /// Rows that exited and leave the list before the next snapshot lands.
    @Published private(set) var departed: Set<pid_t> = []
    @Published private(set) var keepRunning: Set<String> = QuitAppsSupport.keepRunning()
    @Published private(set) var toast: KillProcessToast?
    /// Apps that just quit. They stay in place, greyed out with Reopen,
    /// until `reopenLifetime` runs out.
    @Published private(set) var recentlyQuit: [pid_t: KillProcessItem] = [:]

    /// How long a quit may take before the row reads Not responding.
    static let quitTimeout: TimeInterval = 4
    private static let pollInterval: TimeInterval = 0.25
    private static let toastLifetime: TimeInterval = 5
    static let reopenLifetime: TimeInterval = 5

    private let service = KillProcessService.shared
    private var toastDismissal: DispatchWorkItem?

    private var strings: KillProcessListStrings { FeatureStrings.killProcessList(L10n.shared.language) }

    init() {
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            let current = QuitAppsSupport.keepRunning()
            if current != self.keepRunning { self.keepRunning = current }
        }
    }

    // MARK: State queries

    func isKept(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return QuitAppsSupport.isAlwaysKept(bundleIdentifier) || keepRunning.contains(bundleIdentifier)
    }

    func isAlwaysKept(_ bundleIdentifier: String?) -> Bool {
        QuitAppsSupport.isAlwaysKept(bundleIdentifier)
    }

    /// The service's rows, minus those that already exited, plus apps that
    /// just quit and can still be reopened from their row.
    func visibleItems(_ items: [KillProcessItem]) -> [KillProcessItem] {
        guard !departed.isEmpty || !recentlyQuit.isEmpty else { return items }
        var live = items.compactMap { item -> KillProcessItem? in
            guard !departed.contains(item.pid) else { return nil }
            let helpers = item.helpers.filter { !departed.contains($0.pid) }
            guard helpers.count != item.helpers.count else { return item }
            return KillProcessItem(pid: item.pid, name: item.name, path: item.path, kind: item.kind,
                                   cpuPercent: item.cpuPercent, memoryBytes: item.memoryBytes,
                                   ownCPUPercent: item.ownCPUPercent, ownMemoryBytes: item.ownMemoryBytes,
                                   startedAt: item.startedAt, bundleIdentifier: item.bundleIdentifier,
                                   bundlePath: item.bundlePath, helpers: helpers,
                                   ports: item.ports.filter { !departed.contains($0.pid) })
        }
        guard !recentlyQuit.isEmpty else { return live }
        let shown = Set(live.map(\.pid))
        live += recentlyQuit.values.filter { !shown.contains($0.pid) }
        return live.sorted(by: KillProcessCatalog.comesBefore)
    }

    func isRecentlyQuit(_ pid: pid_t) -> Bool { recentlyQuit[pid] != nil }

    /// Reopens an app from its greyed-out row.
    func reopen(_ item: KillProcessItem) {
        recentlyQuit[item.pid] = nil
        guard let path = item.bundlePath else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: configuration) { _, _ in }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.service.refresh(force: true) }
    }

    /// A fresh snapshot is the truth: forget departures and hung marks for
    /// processes it no longer lists.
    func reconcile(with items: [KillProcessItem]) {
        var alive: Set<pid_t> = []
        for item in items {
            alive.insert(item.pid)
            for helper in item.helpers { alive.insert(helper.pid) }
        }
        let departedNow = departed.intersection(alive)
        if departedNow != departed { departed = departedNow }
        let hungNow = notResponding.intersection(alive)
        if hungNow != notResponding { notResponding = hungNow }
    }

    // MARK: Row actions

    func perform(_ action: KillProcessPrimaryAction, on item: KillProcessItem) {
        dismissToast()
        switch action {
        case .quit: quit([item], toastWhenDone: true)
        case .stop: stop(item, announces: item.isReopenable)
        case .forceQuit: forceQuit(item)
        }
    }

    /// Stops every process holding these ports, once each. The row's app
    /// keeps running unless it holds one of the ports itself.
    func stopPorts(_ ports: [KillProcessPort], of owner: KillProcessItem) {
        dismissToast()
        let own = ProcessInfo.processInfo.processIdentifier
        var seen = Set<pid_t>()
        for port in KillProcessCatalog.stoppablePorts(ports, ownPID: own) where seen.insert(port.pid).inserted {
            stop(process(holding: port, of: owner), announces: false)
        }
    }

    /// The listed process behind a port: the row itself, one of its helpers,
    /// or, for a process the list has not caught up with, one built from the port.
    private func process(holding port: KillProcessPort, of owner: KillProcessItem) -> KillProcessItem {
        if port.pid == owner.pid { return owner }
        if let helper = owner.helpers.first(where: { $0.pid == port.pid }) { return helper }
        return KillProcessItem(pid: port.pid, name: port.processName, path: "", kind: .helper,
                               cpuPercent: 0, memoryBytes: 0, ownCPUPercent: 0, ownMemoryBytes: 0,
                               startedAt: port.startedAt, bundleIdentifier: nil, bundlePath: nil, helpers: [])
    }

    func stopHelper(_ helper: KillProcessItem) {
        dismissToast()
        stop(helper, announces: false)
    }

    func forceQuit(_ item: KillProcessItem) {
        dismissToast()
        guard let target = target(for: item) else { return }
        inProgress[item.pid] = .forceQuit
        signal([target], force: true, name: item.name) { [weak self] removed in
            guard let self else { return }
            if removed.contains(item.pid) {
                self.waitForExit([item]) { exited, _ in
                    self.finish(exited: exited, remaining: [], announce: item.isReopenable)
                }
            } else {
                self.inProgress[item.pid] = nil
                self.show(String(format: self.strings.toastCouldNotStopFormat, item.name))
            }
        }
    }

    /// Quit, wait for the exit, and open the same bundle again.
    func relaunch(_ item: KillProcessItem) {
        dismissToast()
        guard let startedAt = item.startedAt, let path = item.bundlePath else { return }
        inProgress[item.pid] = item.kind == .dockApp ? .quit : .stop
        service.restart(pid: item.pid, startedAt: startedAt, bundleURL: URL(fileURLWithPath: path)) { [weak self] relaunched in
            guard let self else { return }
            self.inProgress[item.pid] = nil
            if relaunched { self.departed.insert(item.pid) }
            let format = relaunched ? self.strings.toastRelaunchedFormat : self.strings.toastNotRelaunchedFormat
            self.show(String(format: format, item.name))
        }
    }

    /// A macOS agent's Restart: launchd starts it again once it stops.
    func restartAgent(_ item: KillProcessItem) {
        stop(item, announces: false)
    }

    /// Asks every listed app to quit together, then reports once.
    func quitOthers(_ items: [KillProcessItem]) {
        dismissToast()
        let apps = items.filter { $0.kind == .dockApp }
        let background = items.filter { $0.kind != .dockApp }
        var pending = Set(items.map(\.pid))
        var exited: [KillProcessItem] = []
        var remaining: [KillProcessItem] = []
        let done: ([KillProcessItem], [KillProcessItem]) -> Void = { [weak self] gone, left in
            exited += gone
            remaining += left
            for item in gone + left { pending.remove(item.pid) }
            if pending.isEmpty { self?.finish(exited: exited, remaining: remaining, announce: true) }
        }
        if !apps.isEmpty { quit(apps, toastWhenDone: false, completion: done) }
        for item in background {
            stop(item, announces: false) { gone in done(gone ? [item] : [], gone ? [] : [item]) }
        }
    }

    func setKeepRunning(_ keep: Bool, for item: KillProcessItem) {
        guard let bundleIdentifier = item.bundleIdentifier else { return }
        QuitAppsSupport.setKeepRunning(keep, bundleIdentifier: bundleIdentifier)
        keepRunning = QuitAppsSupport.keepRunning()
    }

    func copyPID(_ pid: pid_t) {
        GeneralPasteboardAccess.shared.async({
            NSPasteboard.general.clearContents()
            NSPasteboard.general.declareLatticeSource()
            return NSPasteboard.general.setString(String(pid), forType: .string)
        }, then: { [weak self] copied in
            guard let self else { return }
            if copied { self.show(String(format: self.strings.toastCopiedPIDFormat, Int(pid))) } else { NSSound.beep() }
        })
    }

    func showInFinder(_ item: KillProcessItem) {
        let path = item.bundlePath ?? item.path
        guard path.hasPrefix("/") else { NSSound.beep(); return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    // MARK: Toasts

    func show(_ message: String) {
        toastDismissal?.cancel()
        let toast = KillProcessToast(message: message)
        self.toast = toast
        AccessibilityNotification.Announcement(message).post()
        let dismissal = DispatchWorkItem { [weak self] in
            if self?.toast?.id == toast.id { self?.toast = nil }
        }
        toastDismissal = dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.toastLifetime, execute: dismissal)
    }

    func dismissToast() {
        toastDismissal?.cancel()
        toastDismissal = nil
        if toast != nil { toast = nil }
    }

    // MARK: Quit and stop

    /// Graceful quit through `terminate()`, so an app can save. An app that
    /// is still running when the timeout ends is either hung, and reads Not
    /// responding, or showing a save dialog, and comes forward.
    private func quit(_ items: [KillProcessItem], toastWhenDone: Bool,
                      completion: (([KillProcessItem], [KillProcessItem]) -> Void)? = nil) {
        var asked: [KillProcessItem] = []
        for item in items {
            guard let target = target(for: item), KillProcessService.identityMatches(target),
                  let app = NSRunningApplication(processIdentifier: item.pid), !app.isTerminated else { continue }
            inProgress[item.pid] = .quit
            if app.terminate() { asked.append(item) } else { inProgress[item.pid] = nil }
        }
        let skipped = items.filter { item in !asked.contains { $0.pid == item.pid } }
        guard !asked.isEmpty else {
            completion?([], skipped)
            return
        }
        waitForExit(asked) { [weak self] exited, remaining in
            guard let self else { return }
            self.handleUnfinishedQuits(remaining)
            if let completion {
                for item in exited { self.inProgress[item.pid] = nil }
                self.markDeparted(exited)
                completion(exited, remaining + skipped)
            } else {
                self.finish(exited: exited, remaining: remaining, announce: toastWhenDone)
            }
        }
    }

    /// SIGTERM to one process, then wait for it to go.
    private func stop(_ item: KillProcessItem, announces: Bool, completion: ((Bool) -> Void)? = nil) {
        guard let target = target(for: item) else {
            completion?(false)
            return
        }
        inProgress[item.pid] = .stop
        signal([target], force: false, name: item.name) { [weak self] removed in
            guard let self else { return }
            guard removed.contains(item.pid) else {
                self.inProgress[item.pid] = nil
                self.show(String(format: self.strings.toastCouldNotStopFormat, item.name))
                completion?(false)
                return
            }
            self.waitForExit([item]) { exited, remaining in
                if let completion {
                    for gone in exited { self.inProgress[gone.pid] = nil }
                    self.markDeparted(exited)
                    self.handleUnfinishedQuits(remaining)
                    completion(!exited.isEmpty)
                } else {
                    self.handleUnfinishedQuits(remaining)
                    self.finish(exited: exited, remaining: remaining, announce: announces)
                }
            }
        }
    }

    private func signal(_ targets: [KillProcessService.KillTarget], force: Bool, name: String,
                        completion: @escaping (Set<pid_t>) -> Void) {
        guard let cancellation = service.readWork.begin(owner: .killProcess, isAvailable: { $0.isAvailable }) else {
            completion([])
            return
        }
        service.beginProtectedAction(.killProcess)
        DispatchQueue.global(qos: .userInitiated).async { [service] in
            defer { service.endProtectedAction(.killProcess) }
            let removed = cancellation.isCancelled
                ? []
                : service.killBatch(targets, force: force, adminPromptProcessName: name, cancellation: cancellation)
            DispatchQueue.main.async { completion(removed) }
        }
    }

    /// Polls until every process has exited or the timeout passes.
    private func waitForExit(_ items: [KillProcessItem],
                             completion: @escaping (_ exited: [KillProcessItem], _ remaining: [KillProcessItem]) -> Void) {
        let deadline = ProcessInfo.processInfo.systemUptime + Self.quitTimeout
        func check() {
            let remaining = items.filter { item in
                target(for: item).map(KillProcessService.identityMatches) ?? false
            }
            if remaining.isEmpty || ProcessInfo.processInfo.systemUptime >= deadline {
                let exited = items.filter { item in !remaining.contains { $0.pid == item.pid } }
                completion(exited, remaining)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.pollInterval, execute: check)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.pollInterval, execute: check)
    }

    private func finish(exited: [KillProcessItem], remaining: [KillProcessItem], announce: Bool) {
        for item in exited + remaining { inProgress[item.pid] = nil }
        markDeparted(exited)
        if announce { holdForReopen(exited.filter(\.isReopenable)) }
        service.refresh(force: true)
    }

    /// Keeps quit apps in the list, greyed out with Reopen, for a few seconds.
    private func holdForReopen(_ items: [KillProcessItem]) {
        guard !items.isEmpty else { return }
        for item in items { recentlyQuit[item.pid] = item }
        let message = items.count == 1
            ? String(format: strings.toastQuitFormat, items[0].name)
            : strings.count(items.count, one: strings.toastAppsQuitOne, other: strings.toastAppsQuitOther)
        AccessibilityNotification.Announcement(message).post()
        let pids = items.map(\.pid)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.reopenLifetime) { [weak self] in
            guard let self else { return }
            for pid in pids { self.recentlyQuit[pid] = nil }
        }
    }

    /// A row and its helpers leave the list at once; the next snapshot confirms.
    private func markDeparted(_ items: [KillProcessItem]) {
        for item in items {
            departed.insert(item.pid)
            for helper in item.helpers { departed.insert(helper.pid) }
        }
    }

    /// Still running after the timeout: hung apps read Not responding; an app
    /// waiting on a save dialog comes forward with its row restored.
    private func handleUnfinishedQuits(_ items: [KillProcessItem]) {
        for item in items { inProgress[item.pid] = nil }
        let apps = items.filter { $0.kind == .dockApp || $0.kind == .backgroundApp }
        guard !apps.isEmpty else { return }
        let trusted = AXIsProcessTrusted()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let hung = Set(apps.filter { !trusted || Self.isHung(pid: $0.pid) }.map(\.pid))
            DispatchQueue.main.async {
                guard let self else { return }
                self.notResponding.formUnion(hung)
                for item in apps where !hung.contains(item.pid) {
                    NSRunningApplication(processIdentifier: item.pid)?.activate()
                }
            }
        }
    }

    // MARK: Hang detection

    /// Whether an app is processing events: a cheap Accessibility question
    /// with a short timeout that a hung app cannot answer. Asked only after a
    /// quit runs out of time, never on every refresh.
    static func isHung(pid: pid_t) -> Bool {
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, 0.5)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &value)
        return result == .cannotComplete
    }

    private func target(for item: KillProcessItem) -> KillProcessService.KillTarget? {
        item.startedAt.map { KillProcessService.KillTarget(pid: item.pid, startedAt: $0) }
    }
}
