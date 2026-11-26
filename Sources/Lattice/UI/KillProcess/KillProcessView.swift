// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// Where the Kill Process list is shown. Only the header and frame differ.
enum KillProcessSurface {
    case settings, hud, island

    var scopeKey: String {
        switch self {
        case .settings: return DefaultsKey.killProcessScopeSettings
        case .hud: return DefaultsKey.killProcessScopeHUD
        case .island: return DefaultsKey.killProcessScopeIsland
        }
    }

    var isCompact: Bool { self != .settings }
}

/// Kill Process: running apps, background apps and macOS processes in
/// sections, with helpers nested under the app that owns them. One list,
/// hosted by the Settings page, the floating HUD and the expanded island.
struct KillProcessView: View {
    let surface: KillProcessSurface

    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = KillProcessService.shared
    @ObservedObject private var activity = KillProcessActivity.shared
    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage private var scopeRaw: String
    @State private var query = ""
    /// Open rows, per section, so a row's ports and its helpers open apart.
    @State private var expanded: Set<String> = []
    @State private var confirmation: KillProcessConfirmation?
    @State private var frontPID: pid_t?
    @State private var refreshTimer: Timer?
    @State private var hoveredPID: pid_t?
    /// Each section's row order last shown, held while the pointer rests on
    /// a row so a live refresh never moves the row under it.
    @State private var displayOrder: [KillProcessScope: [pid_t]] = [:]
    /// Rows a search opened that the user closed again, for this query only.
    @State private var collapsedForQuery: Set<String> = []
    @FocusState private var searchFocused: Bool

    /// `expandedPIDs` opens those rows' helpers, and `expandedPortPIDs` their
    /// ports, from the start.
    init(surface: KillProcessSurface, expandedPIDs: Set<pid_t> = [], expandedPortPIDs: Set<pid_t> = []) {
        self.surface = surface
        _scopeRaw = AppStorage(wrappedValue: KillProcessScope.everything.rawValue, surface.scopeKey)
        _expanded = State(initialValue: Set(expandedPIDs.map { Self.expansionKey(.apps, $0) }
            + expandedPortPIDs.map { Self.expansionKey(.ports, $0) }))
    }

    private var strings: KillProcessListStrings { FeatureStrings.killProcessList(l10n.language) }
    private var scope: KillProcessScope { KillProcessScope(rawValue: scopeRaw) ?? .everything }
    private var compact: Bool { surface.isCompact }

    private var items: [KillProcessItem] { activity.visibleItems(service.items) }

    /// The catalog's sections, then, while the pointer rests on a row, each
    /// section held in the order last shown. The hold goes on after the
    /// section's own sort (Apps by name, Ports by port), or that sort would
    /// move the row under the pointer anyway; new rows go last.
    private var sections: [KillProcessSection] {
        let sorted = KillProcessCatalog.sections(items, scope: scope, query: surface == .island ? "" : query,
                                                 frontPID: frontPID, isKept: activity.isKept, language: l10n.language)
        guard !displayOrder.isEmpty else { return sorted }
        return sorted.map { section in
            guard let order = displayOrder[section.scope] else { return section }
            let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
            let held = section.items.enumerated().sorted { lhs, rhs in
                let left = rank[lhs.element.pid] ?? Int.max, right = rank[rhs.element.pid] ?? Int.max
                return left == right ? lhs.offset < rhs.offset : left < right
            }.map(\.element)
            return KillProcessSection(scope: section.scope, items: held, expandedByQuery: section.expandedByQuery)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if surface == .hud { KillProcessHUDHeader() }
            ScrollView(.vertical) {
                // Rows are direct children of the lazy stack, so only the rows
                // on screen are built, however long Background or System get.
                LazyVStack(alignment: .leading, spacing: 0) {
                    if surface != .island { searchField }
                    content
                }
                .padding(.horizontal, compact ? 10 : 18)
                .padding(.vertical, compact ? HubScrollEdge.inset : 14)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: scopeRaw)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: service.hasLoadedOnce)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: sections.isEmpty)
            }
            .scrollBounceBehavior(.basedOnSize)
            // In the Hub and the island, rows scroll out under soft edges.
            .hubScrollEdgeFade(surface != .settings)
            if let toast = activity.toast {
                KillProcessToastView(toast: toast, compact: compact)
                    .padding(.horizontal, compact ? 10 : 18)
                    .padding(.bottom, 6)
                    .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .alert(confirmationTitle, isPresented: Binding(
            get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }),
               presenting: confirmation) { pending in
            Button(strings.cancel, role: .cancel) {}
            Button(String(format: strings.confirmButtonFormat, pending.targets.count), role: .destructive) {
                activity.quitOthers(pending.targets)
            }
        } message: { pending in
            Text(ListFormatter.localizedString(byJoining: pending.targets.map(\.name)))
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: activity.toast)
        .onAppear {
            frontPID = QuitAppsActions.frontAppPID()
            service.refresh(force: true)
            updateTimer()
        }
        .onDisappear { stopTimer() }
        // Coming back to Lattice, or into one of its panels, shows the current
        // list at once instead of waiting for the next tick.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .merge(with: NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification))) { _ in
            frontPID = QuitAppsActions.frontAppPID()
            service.refresh(force: true)
        }
        .onChange(of: controlActiveState) { _, _ in updateTimer() }
        .onChange(of: service.items) { _, newItems in
            frontPID = QuitAppsActions.frontAppPID()
            activity.reconcile(with: newItems)
            if hoveredPID == nil { displayOrder = [:] }
        }
        .onChange(of: hoveredPID) { _, pid in
            displayOrder = pid == nil
                ? [:]
                : Dictionary(sections.map { ($0.scope, $0.items.map(\.pid)) }, uniquingKeysWith: { first, _ in first })
        }
        .onChange(of: scopeRaw) { _, _ in confirmation = nil }
        .onChange(of: query) { _, _ in
            confirmation = nil
            collapsedForQuery = []
        }
    }

    // MARK: Search

    @ViewBuilder
    private var searchField: some View {
        let field = HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(strings.searchPlaceholder(scope), text: $query)
                .textFieldStyle(.plain)
                .clipped()
                .focused($searchFocused)
                .onKeyPress(.escape) {
                    // The first Escape clears the search; the next one reaches
                    // the HUD or the island, which close.
                    guard !query.isEmpty else { return .ignored }
                    query = ""
                    return .handled
                }
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.primary.opacity(0.18))
                    .frame(width: 1, height: compact ? 12 : 14)
                    .accessibilityHidden(true)
                KillProcessScopeMenu(surface: surface)
                    .font(.system(size: compact ? 10.5 : 11.5))
            }
            .fixedSize()
            .transaction { $0.animation = nil }
        }
        .font(.system(size: compact ? 12 : 13))
        .padding(.leading, 10)
        .frame(minHeight: compact ? 28 : 37)

        Group {
            switch surface {
            case .settings:
                field
                    .background(Color(nsColor: .controlBackgroundColor),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
            case .hud:
                field
                    .background(Color.primary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
            case .island:
                field
                    .modifier(NotchControlSurface(cornerRadius: 10,
                                                  selected: searchFocused || !query.isEmpty,
                                                  interactive: false))
            }
        }
        .padding(.bottom, compact ? 10 : 14)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        let sections = sections
        if !service.hasLoadedOnce && service.items.isEmpty {
            Group {
                if surface == .settings {
                    SettingsCard {
                        AppManagerListSkeleton(rows: 6)
                    }
                } else {
                    AppManagerListSkeleton(rows: surface == .island ? 4 : 6)
                        .padding(.horizontal, 4)
                }
            }
            .transition(reduceMotion ? .identity : .opacity)
        } else if sections.isEmpty {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            emptyStateCard(message: trimmed.isEmpty
                           ? strings.emptyScope
                           : String(format: strings.emptySearchFormat, trimmed))
                .transition(reduceMotion ? .identity : .opacity)
        } else {
            ForEach(Array(sections.enumerated()), id: \.element.scope) { position, section in
                sectionHeader(section)
                    .padding(.top, position == 0 ? 0 : (compact ? 12 : 18))
                    .padding(.bottom, 6)
                // Ids are unique across sections: a process listed in both Apps
                // and Ports must never share a lazily reused row.
                ForEach(section.items.enumerated().map { KillProcessRowSlot(scope: section.scope, index: $0.offset, item: $0.element) }) { slot in
                    let index = slot.index, item = slot.item
                    rowCell(item, scope: section.scope, index: index, count: section.items.count,
                            expandedByQuery: section.expandedByQuery.contains(item.pid))
                }
            }
            .transition(reduceMotion ? .identity : .opacity)
        }
    }

    @ViewBuilder
    private func emptyStateCard(message: String) -> some View {
        switch surface {
        case .settings:
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, minHeight: 140)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .settingsClipsWhileResizing(to: RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .hud:
            Text(message)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 96)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        case .island:
            Text(message)
                .font(.system(size: 11.5))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 96)
                .modifier(NotchControlSurface(cornerRadius: 14, interactive: false))
        }
    }

    private func sectionHeader(_ section: KillProcessSection) -> some View {
        let targets = KillProcessCatalog.quitOthersTargets(section, isKept: activity.isKept)
            .filter { !activity.isRecentlyQuit($0.pid) }
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            (Text(strings.scopeName(section.scope)).fontWeight(.semibold).foregroundColor(.primary)
             + Text(" • " + String(format: strings.sectionRunningFormat, section.items.count))
                .foregroundColor(.secondary))
                .font(.system(size: compact ? 11.5 : 12.5))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if !targets.isEmpty {
                Button(strings.quitOthers) {
                    confirmation = KillProcessConfirmation(scope: section.scope, targets: targets)
                }
                .buttonStyle(.plain)
                .font(.system(size: compact ? 11 : 12))
                .foregroundStyle(.primary)
                .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 2)
    }

    /// One row in its section's grouped container: the first and last rows
    /// round the container's corners, the others draw a hairline above.
    private static func expansionKey(_ scope: KillProcessScope, _ pid: pid_t) -> String { "\(scope.rawValue)-\(pid)" }

    private func rowCell(_ item: KillProcessItem, scope: KillProcessScope, index: Int, count: Int,
                         expandedByQuery: Bool) -> some View {
        let key = Self.expansionKey(scope, item.pid)
        let radius: CGFloat = 12
        let top = index == 0 ? radius : 0, bottom = index == count - 1 ? radius : 0
        let notResponding = activity.notResponding.contains(item.pid)
        let helperPIDs = Set(item.helpers.map(\.pid))
        let portPIDs = Set(item.ports.map(\.pid))
        return VStack(spacing: 0) {
            if index > 0 { Divider().padding(.leading, rowDividerInset) }
            KillProcessRow(
                item: item,
                surface: surface,
                strings: strings,
                chip: KillProcessCatalog.chip(for: item, frontPID: frontPID,
                                              isKept: activity.isKept(item.bundleIdentifier),
                                              isNotResponding: notResponding),
                primary: scope == .ports
                    ? KillProcessCatalog.portPrimaryAction(for: item, ownPID: ProcessInfo.processInfo.processIdentifier)
                    : KillProcessCatalog.primaryAction(for: item, isNotResponding: notResponding),
                progress: scope == .ports
                    ? (portPIDs.isDisjoint(with: activity.inProgress.keys) ? nil : .stop)
                    : activity.inProgress[item.pid],
                menu: KillProcessCatalog.menu(for: item, in: scope),
                isKept: activity.isKept(item.bundleIdentifier),
                isAlwaysKept: activity.isAlwaysKept(item.bundleIdentifier),
                helpersExpanded: expandedByQuery ? !collapsedForQuery.contains(key) : expanded.contains(key),
                helpersInProgress: (scope == .ports ? portPIDs : helperPIDs).intersection(activity.inProgress.keys),
                isRecentlyQuit: activity.isRecentlyQuit(item.pid),
                ports: scope == .ports ? item.ports : nil,
                onToggleHelpers: { toggleExpansion(key, openedBySearch: expandedByQuery) })
                .equatable()
        }
        .background(UnevenRoundedRectangle(topLeadingRadius: top, bottomLeadingRadius: bottom,
                                           bottomTrailingRadius: bottom, topTrailingRadius: top,
                                           style: .continuous)
            .fill(Color.primary.opacity(compact ? 0.05 : 0.04)))
        .onHover { inside in
            if inside { hoveredPID = item.pid } else if hoveredPID == item.pid { hoveredPID = nil }
        }
    }

    private var rowDividerInset: CGFloat {
        KillProcessRowMetrics(compact: compact).dividerInset
    }

    /// A row a search opened closes and reopens for this query only; it
    /// never becomes a manual expansion that outlasts the search.
    private func toggleExpansion(_ key: String, openedBySearch: Bool) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            if openedBySearch {
                if collapsedForQuery.contains(key) { collapsedForQuery.remove(key) } else { collapsedForQuery.insert(key) }
            } else if expanded.contains(key) {
                expanded.remove(key)
            } else {
                expanded.insert(key)
            }
        }
    }

    private var confirmationTitle: String {
        guard let confirmation else { return "" }
        let count = confirmation.targets.count
        return strings.count(count, one: strings.confirmAppsOne, other: strings.confirmAppsOther)
    }

    // MARK: Live refresh

    /// Ticks only while the list is showing. In Settings it also waits for
    /// the window to be active, so a background Settings window never polls.
    private func updateTimer() {
        guard surface != .settings || controlActiveState != .inactive else {
            stopTimer()
            return
        }
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            service.refresh()
        }
    }

    private func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

/// The scope button: the current scope's name and a chevron, opening a menu
/// of Apps, Background and System with their counts, then Everything.
struct KillProcessScopeMenu: View {
    let surface: KillProcessSurface
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = KillProcessService.shared
    @ObservedObject private var activity = KillProcessActivity.shared
    @AppStorage private var scopeRaw: String

    init(surface: KillProcessSurface) {
        self.surface = surface
        _scopeRaw = AppStorage(wrappedValue: KillProcessScope.everything.rawValue, surface.scopeKey)
    }

    private var strings: KillProcessListStrings { FeatureStrings.killProcessList(l10n.language) }
    private var scope: KillProcessScope { KillProcessScope(rawValue: scopeRaw) ?? .everything }

    var body: some View {
        let items = activity.visibleItems(service.items)
        Menu {
            Picker(strings.scopeLabel, selection: $scopeRaw) {
                Text(strings.scopeName(.everything))
                    .badge(KillProcessCatalog.count(items, in: .everything))
                    .tag(KillProcessScope.everything.rawValue)
            }
            .pickerStyle(.inline)
            .labelsHidden()
            Divider()
            Picker(strings.scopeLabel, selection: $scopeRaw) {
                ForEach(KillProcessScope.sectionScopes) { option in
                    Text(strings.scopeName(option))
                        .badge(KillProcessCatalog.count(items, in: option))
                        .tag(option.rawValue)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            // One text run, so the menu label keeps the chevron after the name.
            // The Island is narrow: All Processes reads just "All" on the button.
            let name = surface == .island && scope == .everything
                ? strings.scopeEverythingShort : strings.scopeName(scope)
            SearchFilterMenuLabel(title: name,
                                  color: surface == .island ? Color.white.opacity(0.6) : Color.secondary,
                                  fillsField: surface != .island)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .controlSize(.small)
        .accessibilityLabel(strings.scopeLabel)
        .accessibilityValue(strings.scopeName(scope))
    }
}

/// An inline Quit Others confirmation waiting under its section's header.
struct KillProcessConfirmation: Equatable {
    let scope: KillProcessScope
    let targets: [KillProcessItem]
}

/// One row's place in the list. Its id joins the section and the PID, so a
/// process shown in both Apps and Ports gets two distinct rows.
private struct KillProcessRowSlot: Identifiable {
    let scope: KillProcessScope
    let index: Int
    let item: KillProcessItem
    var id: String { "\(scope.rawValue)-\(item.pid)" }
}
