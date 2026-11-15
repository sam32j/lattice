// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Kill Process, embedded as a Settings page: a live, searchable list of
/// every running process with kill, force-kill, kill-all, kill-tree, and
/// restart actions. Its Apps view narrows the list to regular apps, quits
/// them gracefully, and quits all or all but the front app, sparing the
/// person's Keep Running list.
struct KillProcessView: View {
    var inlineOptions = false
    /// The floating Hub and the Dynamic Island are narrow: the PID column
    /// moves into the row's menu, columns and buttons tighten, and the list
    /// sits on the surface's own glass.
    var compact = false
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = KillProcessService.shared
    @Environment(\.controlActiveState) private var controlActiveState
    @AppStorage(DefaultsKey.killProcessOpensInApps) private var opensInApps = true
    @State private var showsOptions = false
    @State private var refreshTimer: Timer?
    @State private var pendingAction: PendingAction?
    @State private var showsApps = true
    @State private var choseScope = false
    @State private var keepRunning: Set<String> = []
    @State private var frontPID: Int32?

    private var strings: KillProcessFeatureStrings { FeatureStrings.killProcess(l10n.language) }
    private var appStrings: KillProcessAppStrings { FeatureStrings.killProcessApps(l10n.language) }

    private enum PendingAction {
        case kill(KillProcessEntry, force: Bool)
        case killAll(name: String, force: Bool)
        case killTree(KillProcessEntry, force: Bool)
        case quit(KillProcessEntry)
        case quitBatch(pids: Set<Int32>, names: [String])
    }

    // Column and button widths, shared by the header and every row so each
    // label sits over its column.
    private var spacing: CGFloat { compact ? 8 : 10 }
    private var iconSize: CGFloat { compact ? 20 : 22 }
    private var cpuWidth: CGFloat { compact ? 44 : 52 }
    private var memoryWidth: CGFloat { compact ? 60 : 72 }
    private var actionWidth: CGFloat { compact ? 40 : 44 }
    private var menuWidth: CGFloat { compact ? 26 : 44 }
    private var pinWidth: CGFloat { compact ? 20 : 22 }
    private var trailingWidth: CGFloat {
        actionWidth + spacing + menuWidth + (showsApps ? pinWidth + spacing : 0)
    }

    /// A process row that is a regular app, with what the quit rules read.
    private struct AppRow {
        let entry: KillProcessEntry
        let bundleIdentifier: String?
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            columnHeader
            Divider()
            list
            if showsApps {
                Divider()
                quitBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if !choseScope {
                choseScope = true
                showsApps = opensInApps
            }
            keepRunning = QuitAppsSupport.keepRunning()
            frontPID = QuitAppsActions.frontAppPID()
            service.refresh(force: true)
            updateTimer(for: controlActiveState)
        }
        .onChange(of: service.entries) { _, _ in
            frontPID = QuitAppsActions.frontAppPID()
        }
        // The Hub and Settings each show this view; a pin changed in one must
        // reach the other's batch quits.
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            let current = QuitAppsSupport.keepRunning()
            if current != keepRunning { keepRunning = current }
        }
        .onDisappear { stopTimer() }
        .onChange(of: controlActiveState) { _, newValue in
            updateTimer(for: newValue)
        }
        .alert(alertTitle,
               isPresented: Binding(get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } }),
               presenting: pendingAction) { action in
            Button(l10n.s.uninstallerCancel, role: .cancel) {}
            Button(confirmButtonTitle(action), role: .destructive) {
                perform(action)
                pendingAction = nil
            }
        } message: { action in
            Text(alertMessage(for: action))
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: compact ? 10 : 16) {
                Picker("", selection: $showsApps) {
                    Text(appStrings.scopeApps).tag(true)
                    Text(appStrings.scopeProcesses).tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(compact ? .small : .regular)
                .fixedSize()
                Spacer()
                Text(showsApps
                     ? String(format: appStrings.appCountFormat, appRows.count)
                     : String(format: strings.processCountFormat, service.filteredEntries.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    service.refresh(force: true)
                } label: {
                    Image(systemName: "arrow.clockwise").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(strings.refreshTooltip)
                if inlineOptions { KillProcessOptionsButton(presented: $showsOptions) }
            }

            HStack(spacing: spacing) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(strings.searchPlaceholder, text: $service.query)
                    .textFieldStyle(.plain)
                if service.isRefreshing {
                    ProgressView().controlSize(.small)
                }
            }
        }
        .padding(compact ? 12 : 16)
    }

    // MARK: Column header

    /// Mirrors `row(_:)`'s HStack widths exactly, so each label sits over its
    /// column: the leading `22`pt gap matches the row icon, and the trailing
    /// `98`pt gap matches the Kill + "..." button cluster.
    private var columnHeader: some View {
        HStack(spacing: spacing) {
            Spacer().frame(width: iconSize)
            columnHeaderButton(strings.columnProcess, column: .name)
                .frame(maxWidth: .infinity, alignment: .leading)
            columnHeaderButton(strings.columnCPU, column: .cpu)
                .frame(width: cpuWidth, alignment: .trailing)
            columnHeaderButton(strings.columnMemory, column: .memory)
                .frame(width: memoryWidth, alignment: .trailing)
            if !compact {
                columnHeaderButton(strings.columnPID, column: .pid)
                    .frame(width: 56, alignment: .trailing)
            }
            // The Apps view's rows add the Keep Running pin and its gap.
            Spacer().frame(width: trailingWidth)
        }
        .padding(.horizontal, compact ? 12 : 16)
        .padding(.vertical, 6)
    }

    private func columnHeaderButton(_ title: String, column: KillProcessService.SortBy) -> some View {
        Button {
            service.toggleSort(column)
        } label: {
            HStack(spacing: 3) {
                Text(title)
                if service.sortBy == column {
                    Image(systemName: service.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 10.5, weight: .semibold))
        .foregroundStyle(.secondary)
    }

    // MARK: List

    @ViewBuilder
    private var list: some View {
        if showsApps {
            appList
        } else if service.filteredEntries.isEmpty {
            // A transient ps hiccup no longer clears `entries` (KillProcessService
            // keeps the last good snapshot), so an empty list here means either
            // the very first load hasn't landed yet, or a search genuinely
            // matched nothing - two different messages, not one.
            if service.hasLoadedOnce {
                emptyState
            } else {
                loadingState
            }
        } else {
            listSurface(List(service.filteredEntries) { entry in row(entry) })
        }
    }

    /// Settings keeps the inset list; the Hub and island show their glass.
    @ViewBuilder
    private func listSurface<Content: View>(_ list: List<Never, Content>) -> some View {
        if compact {
            list.listStyle(.plain).scrollContentBackground(.hidden)
        } else {
            list.listStyle(.inset)
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text(strings.emptyStateTitle).foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView().controlSize(.small)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ entry: KillProcessEntry) -> some View {
        HStack(spacing: spacing) {
            Image(nsImage: ResponsibleProcess.icon(for: entry.pid))
                .resizable().frame(width: iconSize, height: iconSize)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(entry.name).font(.system(size: 12.5)).lineLimit(1).truncationMode(.middle)
                    if entry.groupedCount > 1 {
                        Text(String(format: strings.processCountFormat, entry.groupedCount))
                            .font(.system(size: 10)).foregroundStyle(.tertiary)
                    }
                }
                Text(entry.path)
                    .font(.system(size: 10.5)).foregroundStyle(.tertiary)
                    .lineLimit(1).truncationMode(.head)
            }
            Spacer()
            metrics(entry)
            Button(strings.killButton) {
                pendingAction = .kill(entry, force: false)
            }
            .frame(minWidth: actionWidth)
            .disabled(entry.isProtected)
            Menu {
                if compact { Text(String(format: strings.pidLabelFormat, entry.pid)) }
                Button(strings.forceKillButton) { pendingAction = .kill(entry, force: true) }
                    .disabled(entry.isProtected)
                Button(String(format: strings.killAllFormat, entry.name)) {
                    pendingAction = .killAll(name: entry.name, force: false)
                }
                .disabled(entry.isProtected)
                Button(strings.killTreeButton) { pendingAction = .killTree(entry, force: false) }
                    .disabled(entry.isProtected)
                if service.canRestart(entry) {
                    Button(strings.restartButton) { service.restart(entry) }
                }
                Divider()
                Button(strings.copyPID) { copy(String(entry.pid)) }
                Button(strings.copyPath) { copy(entry.path) }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: menuWidth)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.vertical, 2)
    }

    // MARK: Apps view

    private var appRows: [AppRow] {
        let apps = Dictionary(NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isTerminated }
            .map { ($0.processIdentifier, $0.bundleIdentifier) },
            uniquingKeysWith: { first, _ in first })
        return service.filteredEntries.compactMap { entry in
            apps.index(forKey: entry.pid).map { AppRow(entry: entry, bundleIdentifier: apps.values[$0]) }
        }
    }

    @ViewBuilder
    private var appList: some View {
        let rows = appRows
        if rows.isEmpty {
            if service.hasLoadedOnce {
                VStack {
                    Spacer()
                    Text(appStrings.emptyApps).foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                loadingState
            }
        } else {
            listSurface(List(rows, id: \.entry.id) { row in appRow(row) })
        }
    }

    private func isKept(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return QuitAppsSupport.isAlwaysKept(bundleIdentifier) || keepRunning.contains(bundleIdentifier)
    }

    private func appRow(_ row: AppRow) -> some View {
        let entry = row.entry
        let alwaysKept = QuitAppsSupport.isAlwaysKept(row.bundleIdentifier)
        let kept = isKept(row.bundleIdentifier)
        return HStack(spacing: spacing) {
            Image(nsImage: ResponsibleProcess.icon(for: entry.pid))
                .resizable().frame(width: iconSize, height: iconSize)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(entry.name).font(.system(size: 12.5)).lineLimit(1).truncationMode(.middle)
                    if entry.pid == frontPID { badge(appStrings.frontBadge, tint: .accentColor) }
                    if kept { badge(appStrings.keptBadge, tint: .secondary) }
                }
                Text(entry.path)
                    .font(.system(size: 10.5)).foregroundStyle(.tertiary)
                    .lineLimit(1).truncationMode(.head)
            }
            Spacer()
            metrics(entry)
            keepRunningControl(bundleIdentifier: row.bundleIdentifier, alwaysKept: alwaysKept, kept: kept)
                .frame(width: pinWidth)
            Button(appStrings.quitButton) {
                pendingAction = .quit(entry)
            }
            .frame(minWidth: actionWidth)
            .disabled(entry.isProtected)
            Menu {
                if compact { Text(String(format: strings.pidLabelFormat, entry.pid)) }
                Button(appStrings.forceQuitButton) { pendingAction = .kill(entry, force: true) }
                    .disabled(entry.isProtected)
                if service.canRestart(entry) {
                    Button(strings.restartButton) { service.restart(entry) }
                }
                Divider()
                Button(strings.copyPID) { copy(String(entry.pid)) }
                Button(strings.copyPath) { copy(entry.path) }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: menuWidth)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.vertical, 2)
    }

    /// CPU and memory, plus PID outside compact mode, where the row's menu
    /// shows it instead.
    @ViewBuilder
    private func metrics(_ entry: KillProcessEntry) -> some View {
        Text(String(format: "%.1f%%", locale: MetricFormat.locale, entry.cpuPercent))
            .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            .frame(width: cpuWidth, alignment: .trailing)
        Text(MetricFormat.bytes(UInt64(max(0, entry.memoryBytes))))
            .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            .lineLimit(1).minimumScaleFactor(0.85)
            .frame(width: memoryWidth, alignment: .trailing)
        if !compact {
            Text(String(entry.pid))
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
        }
    }

    private func badge(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(tint.opacity(0.14)))
    }

    @ViewBuilder
    private func keepRunningControl(bundleIdentifier: String?, alwaysKept: Bool, kept: Bool) -> some View {
        if alwaysKept {
            Image(systemName: "lock.fill")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .help(appStrings.alwaysKept)
                .accessibilityLabel(appStrings.alwaysKept)
        } else if let bundleIdentifier {
            let title = kept ? appStrings.stopKeepingRunning : appStrings.keepRunning
            Button {
                QuitAppsSupport.setKeepRunning(!kept, bundleIdentifier: bundleIdentifier)
                keepRunning = QuitAppsSupport.keepRunning()
            } label: {
                Image(systemName: kept ? "pin.fill" : "pin")
                    .font(.system(size: 11))
                    .foregroundStyle(kept ? Color.accentColor : Color.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help(title)
            .accessibilityLabel(title)
        }
    }

    /// Apps a batch quit would ask to quit right now, across every running
    /// app rather than only those the search shows.
    private func batchTargets(keepingFront: Bool) -> [QuitAppsCandidate] {
        QuitAppsSupport.batchQuitTargets(
            QuitAppsActions.runningCandidates(),
            exceptions: QuitAppsSupport.batchExceptions(keepRunning: keepRunning),
            keepingPID: keepingFront ? frontPID : nil)
    }

    private var keptRunningCount: Int {
        NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated && isKept($0.bundleIdentifier)
        }.count
    }

    private var quitBar: some View {
        let others = frontPID == nil ? [] : batchTargets(keepingFront: true)
        let all = batchTargets(keepingFront: false)
        return HStack(spacing: 10) {
            Text(String(format: appStrings.keptCountFormat, keptRunningCount))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(appStrings.quitOthers) {
                // Who is in front now, not when the list last refreshed.
                frontPID = QuitAppsActions.frontAppPID()
                let targets = frontPID == nil ? [] : batchTargets(keepingFront: true)
                guard !targets.isEmpty else { return }
                pendingAction = .quitBatch(pids: Set(targets.map(\.pid)), names: targets.map(\.name))
            }
            .disabled(others.isEmpty)
            Button(appStrings.quitAll) {
                let targets = batchTargets(keepingFront: false)
                guard !targets.isEmpty else { return }
                pendingAction = .quitBatch(pids: Set(targets.map(\.pid)), names: targets.map(\.name))
            }
            .disabled(all.isEmpty)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.horizontal, compact ? 12 : 16)
        .padding(.vertical, compact ? 8 : 10)
    }

    // MARK: Confirmation

    private var alertTitle: String {
        guard let pendingAction else { return "" }
        switch pendingAction {
        case let .kill(entry, force):
            return String(format: force ? strings.confirmForceKillFormat : strings.confirmKillFormat, entry.name)
        case let .killAll(name, _):
            return String(format: strings.confirmKillAllFormat, name)
        case let .killTree(entry, _):
            return String(format: strings.confirmKillTreeFormat, entry.name)
        case let .quit(entry):
            return String(format: appStrings.confirmQuitFormat, entry.name)
        case let .quitBatch(pids, _):
            return String(format: appStrings.confirmBatchFormat, pids.count)
        }
    }

    private func alertMessage(for action: PendingAction) -> String {
        switch action {
        case let .kill(entry, _): return entry.path
        case let .killTree(entry, _): return entry.path
        case .killAll: return ""
        case .quit: return appStrings.confirmQuitMessage
        case let .quitBatch(_, names):
            // Exactly the apps that will be asked to quit.
            return ListFormatter.localizedString(byJoining: names)
        }
    }

    private func confirmButtonTitle(_ action: PendingAction) -> String {
        switch action {
        case let .kill(_, force): return force ? strings.forceKillButton : strings.killButton
        case .killAll: return strings.killButton
        case .killTree: return strings.killTreeButton
        case .quit: return appStrings.quitButton
        case .quitBatch: return appStrings.quitAll
        }
    }

    private func perform(_ action: PendingAction) {
        switch action {
        case let .kill(entry, force): service.kill(entry, force: force)
        case let .killAll(name, force): service.killAll(named: name, force: force)
        case let .killTree(entry, force): service.killTree(entry, force: force)
        case let .quit(entry):
            NSRunningApplication(processIdentifier: entry.pid)?.terminate()
            refreshSoon()
        case let .quitBatch(pids, _):
            // Only the apps the confirmation listed, each checked again.
            QuitAppsActions.quit(confirmed: pids,
                                 exceptions: QuitAppsSupport.batchExceptions(keepRunning: keepRunning))
            refreshSoon()
        }
    }

    /// Apps quit on their own schedule; look again once they have had a moment.
    private func refreshSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { service.refresh(force: true) }
    }

    // MARK: Helpers

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.declareLatticeSource()
        NSPasteboard.general.setString(value, forType: .string)
    }

    /// Ticks only while this page is open AND its window is key, so the
    /// CPU/memory columns read live without polling `ps` in the background -
    /// neither while some other Settings page is showing, nor while this one
    /// is open but not the focused window.
    /// The interval matches the service's own freshness cache exactly, so
    /// every tick does real work instead of a third of them being no-ops.
    private func updateTimer(for state: ControlActiveState) {
        guard state != .inactive else {
            stopTimer()
            return
        }
        guard refreshTimer == nil else { return }
        service.refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            service.refresh()
        }
    }

    private func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
