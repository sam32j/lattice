// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// Homebrew inside the App Manager's Dynamic Island and floating Hub:
/// - In the Dynamic Island: a focused glance with instant search across
///   installed packages and the online catalog, Update All, and Clean Up.
/// - In the floating Hub: an interactive compact workbench with pinned heading,
///   search + filter, edge-faded scrollable package list with expandable
///   details, and a docked maintenance / live-operation footer.
struct PanelHomebrewView: View {
    @ObservedObject var l10n = L10n.shared
    @ObservedObject var features = FeatureRuntime.shared
    @ObservedObject var homebrew = HomebrewManager.shared
    @ObservedObject var catalog = HomebrewOnlineCatalog.shared
    @Environment(\.notchPresentation) var inNotch
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State var query = ""
    @State var filter: Filter = .all
    @State var expandedPackageID: String?
    @State var armedUninstallID: String?
    @State var armReset: DispatchWorkItem?
    @State var installedSnapshot = InstalledSnapshot()
    @State var cachedFilteredInstalled: [HomebrewPackage] = []
    @FocusState var searchFocused: Bool

    enum Filter: Hashable { case all, cask, formula, outdated, orphans }

    struct InstalledSnapshot {
        var outdated: [HomebrewPackage] = []
        var orphans: [HomebrewPackage] = []
        var orphanIDs: Set<String> = []
        var caskCount: Int = 0
        var formulaCount: Int = 0
    }

    var showHeader: Bool = true
    var onClose: () -> Void = {}

    var strings: HomebrewTabStrings { FeatureStrings.homebrewTab(l10n.language) }
    var s: Strings { l10n.s }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showHeader && !inNotch {
                legacyHeader
            }
            if inNotch {
                islandBody
            } else {
                hubBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            PanelInteractionState.shared.viewKeepsPopoverOpen = true
            if homebrew.installed.isEmpty {
                homebrew.refreshInstalled()
            }
            catalog.checkVersion()
            homebrew.refreshCleanupEstimate()
            rebuildInstalledSnapshot()
            runSearch()
        }
        .onDisappear {
            PanelInteractionState.shared.viewKeepsPopoverOpen = false
            armReset?.cancel()
            armedUninstallID = nil
        }
        .onChange(of: query) { _, _ in
            armedUninstallID = nil
            rebuildFilteredInstalled()
            runSearch()
        }
        .onChange(of: filter) { _, _ in
            armedUninstallID = nil
            rebuildFilteredInstalled()
            runSearch()
        }
        .onChange(of: AppFeature.homebrew.isAvailable) { _, available in
            guard available else { return }
            if homebrew.installed.isEmpty && !homebrew.isLoadingInstalled {
                homebrew.refreshInstalled()
            }
            catalog.checkVersion()
            homebrew.refreshCleanupEstimate()
        }
        .onChange(of: homebrew.installed) { _, _ in
            rebuildInstalledSnapshot()
            if !trimmedQuery.isEmpty { runSearch() }
        }
        .onChange(of: homebrew.outdatedPackagesByID) { _, _ in
            rebuildInstalledSnapshot()
        }
        .onChange(of: searchFocused) { _, focused in
            if focused && inNotch {
                NotchService.shared.takeKeyboardFocus()
            }
        }
        .onChange(of: homebrew.operationStatus?.targetID) { _, _ in
            homebrew.setOperationDetailsExpanded(false)
        }
    }

    // MARK: Derived state

    var outdated: [HomebrewPackage] {
        installedSnapshot.outdated
    }

    var firstLoad: Bool {
        homebrew.isLoadingInstalled && homebrew.installed.isEmpty
    }

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var orphanIDs: Set<String> {
        installedSnapshot.orphanIDs
    }

    var searchesOnline: Bool {
        inNotch || (filter != .outdated && filter != .orphans)
    }

    var activeOrHomebrewStatus: HomebrewOperationStatus? {
        homebrew.operationStatus.flatMap { status in
            (status.isActive || homebrew.operationOwner == .homebrew) ? status : nil
        }
    }

    var filteredInstalled: [HomebrewPackage] {
        cachedFilteredInstalled
    }

    func rebuildInstalledSnapshot() {
        let installed = homebrew.installed
        var outdatedList: [HomebrewPackage] = []
        var caskCount = 0
        var formulaCount = 0
        for package in installed {
            if package.hasUpdateAvailable { outdatedList.append(package) }
            if package.kind == .cask {
                caskCount += 1
            } else {
                formulaCount += 1
            }
        }
        let folded = HomebrewDependencyGraph.fold(installed, installed: installed)
        installedSnapshot = InstalledSnapshot(
            outdated: outdatedList,
            orphans: folded.orphans,
            orphanIDs: Set(folded.orphans.map(\.id)),
            caskCount: caskCount,
            formulaCount: formulaCount
        )
        if !visibleFilters.contains(filter) { filter = .all }
        rebuildFilteredInstalled()
    }

    func rebuildFilteredInstalled() {
        var base = homebrew.installed
        if !inNotch {
            switch activeFilter {
            case .all: break
            case .cask: base = base.filter { $0.kind == .cask }
            case .formula: base = base.filter { $0.kind == .formula }
            case .outdated: base = installedSnapshot.outdated
            case .orphans: base = installedSnapshot.orphans
            }
        }
        let lower = trimmedQuery.lowercased()
        if !lower.isEmpty {
            base = base.filter {
                $0.name.lowercased().contains(lower)
                    || $0.displayName.lowercased().contains(lower)
            }
        }
        cachedFilteredInstalled = HomebrewPackageOrdering.updatesFirst(base)
    }

    var outdatedPreviewLine: String {
        let names = outdated.prefix(3).map(\.displayName)
        guard !names.isEmpty else { return "" }
        let joined = names.joined(separator: ", ")
        let remaining = outdated.count - names.count
        guard remaining > 0 else { return joined }
        return joined + ", " + String(format: strings.moreUpdatesFormat, remaining)
    }

    var showsCleanupButton: Bool {
        if let estimate = homebrew.cleanupEstimate {
            return !estimate.isEmpty
        }
        return !homebrew.isCheckingCleanup
    }

    var cleanupActionTitle: String {
        homebrew.cleanupEstimate?.freedSizeText.map {
            String(format: strings.cleanupCompactFormat, $0)
        } ?? strings.cleanupButton
    }

    // MARK: Actions

    func runSearch() {
        guard searchesOnline else { catalog.clear(); return }
        let kind: HomebrewPackageKind? = (!inNotch && activeFilter == .cask) ? .cask
            : (!inNotch && activeFilter == .formula) ? .formula : nil
        catalog.search(query, kind: kind, installed: Set(homebrew.installed.map { $0.name.lowercased() }))
    }

    func refreshAll() {
        homebrew.refreshInstalled()
        catalog.checkVersion(force: true)
        homebrew.refreshCleanupEstimate(force: true)
    }

    func openHomebrewSettings() {
        SettingsRouter.shared.request(AppFeature.homebrew.settingsDestination)
        (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
    }

    func armOrUninstall(_ package: HomebrewPackage) {
        guard armedUninstallID == package.id else {
            armedUninstallID = package.id
            armReset?.cancel()
            let work = DispatchWorkItem { armedUninstallID = nil }
            armReset = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: work)
            return
        }
        armReset?.cancel()
        armedUninstallID = nil
        homebrew.uninstall(package)
    }

    func activeStatus(for package: HomebrewPackage) -> HomebrewOperationStatus? {
        guard let status = homebrew.operationStatus, status.isActive else { return nil }
        if status.package?.id == package.id { return status }
        if status.action == .upgradeAll, package.hasUpdateAvailable {
            return status
        }
        return nil
    }

    func activeStatus(for id: String) -> HomebrewOperationStatus? {
        guard let status = homebrew.operationStatus, status.isActive else { return nil }
        if status.package?.id == id { return status }
        return nil
    }

    // MARK: Shared Controls

    private var legacyHeader: some View {
        HStack(spacing: 8) {
            Label(s.homebrewName, systemImage: "shippingbox")
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help(s.uninstallerCancel)
        }
    }

    @ViewBuilder
    func searchBar(compactNotch: Bool) -> some View {
        let content = HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11.5))
                .foregroundStyle(compactNotch ? AnyShapeStyle(.white.opacity(0.55)) : AnyShapeStyle(.secondary))
                .accessibilityHidden(true)
            TextField(compactNotch ? strings.searchAll : searchPlaceholder, text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(compactNotch ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .focused($searchFocused)
                .onSubmit { runSearch() }
                .onKeyPress(.escape) {
                    guard !query.isEmpty else { return .ignored }
                    query = ""
                    return .handled
                }
            if catalog.isSearching {
                ProgressView().controlSize(.mini)
            }
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(compactNotch ? AnyShapeStyle(.white.opacity(0.45)) : AnyShapeStyle(.tertiary))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(s.actionClear)
            }
            if !compactNotch {
                HStack(spacing: 7) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.18))
                        .frame(width: 1, height: 13)
                        .accessibilityHidden(true)
                    filterMenu
                        .font(.system(size: 11))
                }
                .fixedSize()
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, compactNotch ? 9 : 0)
        .frame(height: compactNotch ? 30 : 32)

        if compactNotch {
            content
                .modifier(NotchControlSurface(cornerRadius: 10,
                                              selected: searchFocused || !trimmedQuery.isEmpty,
                                              interactive: false))
        } else {
            content
                .background(Color.primary.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
        }
    }

    private var activeFilter: Filter {
        visibleFilters.contains(filter) ? filter : .all
    }

    var visibleFilters: [Filter] {
        [Filter.all, .cask, .formula, .outdated, .orphans].filter {
            $0 == .all || filterCount($0) > 0
        }
    }

    private func filterCount(_ option: Filter) -> Int {
        switch option {
        case .all: return homebrew.installed.count
        case .cask: return installedSnapshot.caskCount
        case .formula: return installedSnapshot.formulaCount
        case .outdated: return installedSnapshot.outdated.count
        case .orphans: return installedSnapshot.orphans.count
        }
    }

    private var searchPlaceholder: String {
        switch activeFilter {
        case .all: return strings.searchAll
        case .cask: return strings.searchCasks
        case .formula: return strings.searchFormulae
        case .outdated: return strings.searchOutdated
        case .orphans: return strings.searchOrphans
        }
    }

    private func filterTitle(_ option: Filter) -> String {
        let count = filterCount(option)
        switch option {
        case .all: return String(format: strings.filterAllFormat, count)
        case .cask: return String(format: strings.filterCasksFormat, count)
        case .formula: return String(format: strings.filterFormulasFormat, count)
        case .outdated: return String(format: strings.filterOutdatedFormat, count)
        case .orphans: return String(format: strings.filterOrphansFormat, count)
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker(s.homebrewAll, selection: $filter) {
                ForEach(visibleFilters, id: \.self) { option in
                    Text(filterTitle(option)).tag(option)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            SearchFilterMenuLabel(title: filterTitle(activeFilter))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    func refreshButton(size: CGFloat) -> some View {
        let spinning = homebrew.isLoadingInstalled || homebrew.isLoadingOutdated
        return Button(action: refreshAll) {
            RefreshArrow(isSpinning: spinning)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(homebrew.isBusy || spinning)
        .help(s.homebrewRefresh)
        .accessibilityLabel(s.homebrewRefresh)
    }

    func kindTile(_ kind: HomebrewPackageKind, size: CGFloat = 26) -> some View {
        AppManagerSymbolTile(symbol: kind == .cask ? "macwindow" : "terminal",
                             tint: kind == .cask ? .purple : .secondary,
                             size: size)
    }

    func busyPill(_ text: String) -> some View {
        HStack(spacing: 4) {
            ProgressView()
                .controlSize(.mini)
                .scaleEffect(0.75)
                .frame(width: 10, height: 10)
            Text(text)
        }
        .font(.system(size: 10.5, weight: .semibold))
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 3.5)
        .foregroundStyle(Color.accentColor)
        .background(Color.accentColor.opacity(0.12), in: Capsule())
    }

    func operationTitle(_ status: HomebrewOperationStatus) -> String {
        let name = status.package?.displayName ?? ""
        switch status.action {
        case .install: return String(format: s.homebrewOperationInstallFormat, name)
        case .uninstall: return String(format: s.homebrewOperationUninstallFormat, name)
        case .upgrade: return String(format: s.homebrewOperationUpgradeFormat, name)
        case .upgradeAll: return s.homebrewOperationUpgradeAll
        case .updateHomebrew: return s.homebrewOperationUpdateHomebrew
        case .cleanup: return strings.operationCleaning
        }
    }

    func failedTargetName(_ status: HomebrewOperationStatus) -> String {
        if let name = status.package?.displayName { return name }
        switch status.action {
        case .updateHomebrew: return s.homebrewName
        case .cleanup: return strings.cleanupTitle
        default: return s.homebrewAllPackages
        }
    }

    func succeededTitle(_ status: HomebrewOperationStatus) -> String {
        let name = status.package?.displayName ?? ""
        switch status.action {
        case .install: return String(format: s.homebrewOperationInstalledFormat, name)
        case .uninstall: return String(format: s.homebrewOperationUninstalledFormat, name)
        case .upgrade: return String(format: s.homebrewOperationUpgradedFormat, name)
        case .upgradeAll: return s.homebrewOperationUpgradedAll
        case .updateHomebrew: return s.homebrewOperationUpdatedHomebrew
        case .cleanup: return strings.operationCleaned
        }
    }

    func succeededDetail(_ status: HomebrewOperationStatus) -> String? {
        guard status.action == .cleanup else { return nil }
        guard let summary = homebrew.lastCleanupSummary else { return nil }
        return summary.freedSizeText.map { String(format: strings.cleanupFreedFormat, $0) }
            ?? strings.cleanupAlreadyClean
    }

    func phaseLabel(_ phase: HomebrewOperationPhase) -> String {
        switch phase {
        case .preparing: return s.homebrewOperationPreparing
        case .downloading: return s.homebrewOperationDownloading
        case .installing: return s.homebrewOperationInstalling
        case .uninstalling: return s.homebrewOperationUninstalling
        case .upgrading: return s.homebrewOperationUpgrading
        case .cleaning: return strings.cleaningPhase
        case .finalizing: return s.homebrewOperationFinalizing
        case .refreshing: return s.homebrewOperationRefreshing
        }
    }
}
