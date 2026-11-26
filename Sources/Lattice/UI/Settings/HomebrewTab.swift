// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// The App Manager's Homebrew tab: what is out of date, one search over the
/// installed packages and the online catalog, the installed list with each
/// package's details and dependencies a click away, and a footer docked under
/// the list for a running operation or a newer Homebrew.
struct HomebrewTab: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var homebrew = HomebrewManager.shared
    @ObservedObject private var catalog = HomebrewOnlineCatalog.shared
    @AppStorage(DefaultsKey.homebrewGroupDependencies) private var groupDependencies = true
    @State private var query = ""
    @State private var filter = Filter.all
    @State private var expanded: Set<String> = []
    @State private var armedUninstall: String?

    enum Filter: Hashable { case all, cask, formula, outdated, orphans }

    private var strings: HomebrewTabStrings { FeatureStrings.homebrewTab(l10n.language) }
    private var s: Strings { l10n.s }

    var body: some View {
        Group {
            if homebrew.brewPath == nil && !homebrew.isLoadingInstalled {
                missing
            } else {
                AppManagerPage {
                    statusCard
                    if !homebrew.isShellConfigured {
                        AppManagerBanner(title: s.homebrewShellSetupTitle, detail: s.homebrewShellSetupBody) {
                            Button(s.homebrewShellSetupButton) { homebrew.openShellConfiguration() }
                                .buttonStyle(.appManager())
                        }
                    }
                    if let tap = homebrew.untrustedTap { HomebrewTrustCard(tap: tap) }
                    if let error = homebrew.errorMessage, !error.isEmpty, activeOrHomebrewStatus == nil {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    searchBar
                    // What is installed comes first; when an online-capable search
                    // finds nothing installed locally, hide the empty local box and
                    // surface the online catalog directly. Outdated and orphan
                    // filters have no online search, so they keep their empty state.
                    if !hidesEmptyInstalledSection {
                        installedSection
                    }
                    if searchesOnline, !trimmedQuery.isEmpty { onlineSection }
                } footer: {
                    footer
                }
            }
        }
        .onAppear {
            if !HomebrewSimulator.shared.isSimulating {
                if homebrew.installed.isEmpty { homebrew.refreshInstalled() }
                catalog.checkVersion()
                homebrew.refreshCleanupEstimate()
            }
            if !visibleFilters.contains(filter) { filter = .all }
        }
        .onChange(of: AppFeature.homebrew.isAvailable) { _, available in
            guard available, !HomebrewSimulator.shared.isSimulating else { return }
            if homebrew.installed.isEmpty && !homebrew.isLoadingInstalled {
                homebrew.refreshInstalled()
            }
            catalog.checkVersion()
            homebrew.refreshCleanupEstimate()
        }
        .onChange(of: query) { _, _ in runSearch() }
        .onChange(of: filter) { _, _ in runSearch() }
        .onChange(of: homebrew.installed) { _, _ in
            if !visibleFilters.contains(filter) { filter = .all }
        }
        .onChange(of: homebrew.outdatedPackagesByID) { _, _ in
            if !visibleFilters.contains(filter) { filter = .all }
        }
        .onChange(of: homebrew.operationStatus?.targetID) { _, _ in
            homebrew.setOperationDetailsExpanded(false)
        }
        .animation(.easeInOut(duration: 0.2), value: activeFilter)
        .animation(.easeInOut(duration: 0.2), value: activeOrHomebrewStatus?.targetID)
        .animation(.easeInOut(duration: 0.2), value: activeOrHomebrewStatus?.result)
        .animation(.easeInOut(duration: 0.2), value: showsCleanupButton)
        .animation(.easeInOut(duration: 0.2), value: showsCheckingButton)
        .animation(.easeInOut(duration: 0.2), value: showsCheckNowButton)
        .animation(.easeInOut(duration: 0.2), value: catalog.selfUpdateAvailable)
        .animation(.easeInOut(duration: 0.22), value: homebrew.isOperationDetailsExpanded)
    }

    // MARK: Header

    private var outdated: [HomebrewPackage] { homebrew.installed.filter(\.hasUpdateAvailable) }
    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hidesEmptyInstalledSection: Bool {
        !trimmedQuery.isEmpty && searchesOnline && installedRows.isEmpty && !firstLoad
    }

    private var activeOrHomebrewStatus: HomebrewOperationStatus? {
        homebrew.operationStatus.flatMap { status in
            (status.isActive || homebrew.operationOwner == .homebrew) ? status : nil
        }
    }

    private var showsCleanupButton: Bool {
        if let estimate = homebrew.cleanupEstimate {
            return !estimate.isEmpty
        }
        return !homebrew.isCheckingCleanup
    }

    private var isCheckingStatus: Bool {
        homebrew.isLoadingInstalled || homebrew.isLoadingOutdated || homebrew.isCheckingCleanup
    }

    private var showsCheckingButton: Bool {
        outdated.isEmpty && !showsCleanupButton && isCheckingStatus
    }

    private var showsCheckNowButton: Bool {
        outdated.isEmpty && !isCheckingStatus && homebrew.cleanupEstimate?.isEmpty == true
    }

    private func refreshAll() {
        if HomebrewSimulator.shared.isSimulating {
            HomebrewSimulator.shared.refreshCurrent()
        } else {
            homebrew.refreshInstalled()
            catalog.checkVersion(force: true)
            homebrew.refreshCleanupEstimate(force: true)
        }
    }

    /// How many updates and Homebrew version on the left, with Clean Up /
    /// Update All (or Check Now when up to date and cache is clean) on the right.
    @ViewBuilder
    private var statusCard: some View {
        let refreshing = homebrew.isLoadingInstalled
        if firstLoad {
            statusSkeleton
        } else {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(outdated.isEmpty ? strings.upToDate : String(format: strings.packageUpdatesFormat, outdated.count))
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        if !showsCheckNowButton && !isCheckingStatus {
                            Button {
                                refreshAll()
                            } label: {
                                RefreshArrow(isSpinning: refreshing)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 16, height: 14)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(homebrew.isBusy || refreshing)
                            .help(s.homebrewRefresh)
                            .accessibilityLabel(s.homebrewRefresh)
                        }
                    }
                    if let version = catalog.installedVersion {
                        Text(String(format: strings.versionFormat, version))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                if showsCleanupButton || showsCheckingButton || showsCheckNowButton || !outdated.isEmpty {
                    HStack(spacing: 8) {
                        if showsCleanupButton {
                            cleanupButton
                                .fixedSize()
                        } else if showsCheckingButton {
                            Button {} label: {
                                AnimatedEllipsisText(base: FeatureStrings.appUpdates(l10n.language).checking)
                            }
                            .buttonStyle(.appManager(.neutral))
                            .disabled(true)
                            .fixedSize()
                        } else if showsCheckNowButton {
                            Button(FeatureStrings.appUpdates(l10n.language).checkNow) {
                                refreshAll()
                            }
                            .buttonStyle(.appManager(.neutral))
                            .disabled(homebrew.isBusy || refreshing)
                            .fixedSize()
                        }
                        if !outdated.isEmpty {
                            Button(s.homebrewUpgradeAll) { homebrew.upgradeAll() }
                                .buttonStyle(.appManager())
                                .disabled(homebrew.isBusy)
                                .fixedSize()
                        }
                    }
                }
            }
            // The same size as the other tabs' drop strip, filled rather than dashed.
            .padding(14)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    /// Nothing is known before the first read: the title, the version and
    /// the button are placeholders rather than "All up to date".
    private var firstLoad: Bool { homebrew.isLoadingInstalled && homebrew.installed.isEmpty }

    private var statusSkeleton: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                RoundedRectangle(cornerRadius: 3).frame(width: 190, height: 12)
                RoundedRectangle(cornerRadius: 3).frame(width: 96, height: 9)
            }
            Spacer(minLength: 8)
            Capsule().frame(width: 86, height: 26)
        }
        .foregroundStyle(Color.primary.opacity(0.08))
        .padding(.vertical, 3)
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityHidden(true)
    }

    /// Cleans cached downloads, temporary files, historical versions and
    /// unneeded dependencies via `brew cleanup --prune=all -s`.
    private var cleanupActionTitle: String {
        homebrew.cleanupEstimate?.freedSizeText.map {
            String(format: strings.cleanupCompactFormat, $0)
        } ?? strings.cleanupButton
    }

    private var cleanupButton: some View {
        Button(cleanupActionTitle) {
            homebrew.cleanup()
        }
        .buttonStyle(.appManager(.neutral))
        .disabled(homebrew.isBusy)
        .help(cleanupDetail)
    }

    private var cleanupDetail: String {
        if let summary = homebrew.lastCleanupSummary {
            return summary.freedSizeText.map { String(format: strings.cleanupFreedFormat, $0) }
                ?? strings.cleanupAlreadyClean
        }
        if homebrew.isCheckingCleanup {
            return strings.cleanupChecking
        }
        if let estimate = homebrew.cleanupEstimate {
            if estimate.isEmpty {
                return strings.cleanupClean
            }
            return estimate.freedSizeText.map { String(format: strings.cleanupReclaimableFormat, $0) }
                ?? strings.cleanupDescription
        }
        return strings.cleanupDescription
    }

    /// The search field with its filter inside it, as Process Manager's.
    private var searchBar: some View {
        AppManagerSearchField(placeholder: searchPlaceholder, text: $query, busy: catalog.isSearching) { filterMenu }
    }

    private var activeFilter: Filter {
        visibleFilters.contains(filter) ? filter : .all
    }

    private var visibleFilters: [Filter] {
        [Filter.all, .cask, .formula, .outdated, .orphans].filter {
            $0 == .all || filterCount($0) > 0
        }
    }

    private func filterCount(_ option: Filter) -> Int {
        switch option {
        case .all: return homebrew.installed.count
        case .cask: return homebrew.installed.filter { $0.kind == .cask }.count
        case .formula: return homebrew.installed.filter { $0.kind == .formula }.count
        case .outdated: return outdated.count
        case .orphans: return folded.orphans.count
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

    /// Outdated and orphaned are about what is installed; the catalog has
    /// nothing to add to them.
    private var searchesOnline: Bool { activeFilter == .all || activeFilter == .cask || activeFilter == .formula }

    private func runSearch() {
        guard searchesOnline else { catalog.clear(); return }
        let kind: HomebrewPackageKind? = activeFilter == .cask ? .cask : activeFilter == .formula ? .formula : nil
        catalog.search(query, kind: kind, installed: Set(homebrew.installed.map { $0.name.lowercased() }))
    }

    // MARK: Online catalog

    private var onlineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppManagerSectionHeader(title: strings.onlineTitle,
                                    meta: catalog.isSearching ? strings.searchingOnline
                                        : String(format: strings.resultsFormat, catalog.results.count))
            if catalog.isSearching {
                AppManagerSkeletonRow()
            } else if catalog.results.isEmpty {
                Text(String(format: strings.noOnlineFormat, trimmedQuery))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 70)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .settingsClipsWhileResizing(to: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                SettingsCard {
                    ForEach(Array(catalog.results.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 { Divider().padding(.leading, 42) }
                        catalogRow(entry)
                    }
                }
            }
        }
    }

    private func catalogRow(_ entry: HomebrewOnlineCatalog.Entry) -> some View {
        let busy = activeStatus(for: entry.package.id) != nil
        return HStack(spacing: 12) {
            kindTile(entry.kind)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.displayName).font(.system(size: 13, weight: .medium)).lineLimit(1)
                    AppManagerChip(text: entry.kind == .cask ? strings.cask : strings.formula)
                }
                Text([entry.version.isEmpty ? nil : "v\(entry.version)", entry.desc.isEmpty ? entry.name : entry.desc]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if busy {
                busyPill(strings.installing)
            } else {
                Button(s.homebrewInstall) { homebrew.install(entry.package) }
                    .buttonStyle(.appManager())
                    .disabled(homebrew.isBusy)
            }
        }
    }

    // MARK: Installed

    private var folded: (rows: [HomebrewPackage], dependencies: [String: [HomebrewPackage]], orphans: [HomebrewPackage]) {
        HomebrewDependencyGraph.fold(homebrew.installed, installed: homebrew.installed)
    }

    private var installedRows: [HomebrewPackage] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        let graph = folded
        let orphanIDs = Set(graph.orphans.map(\.id))
        var base: [HomebrewPackage]
        switch activeFilter {
        case .orphans: base = graph.orphans
        case .outdated: base = outdated
        case .cask, .formula, .all:
            base = groupDependencies ? graph.rows + graph.orphans.filter { orphan in !graph.rows.contains(orphan) }
                                     : homebrew.installed
            if activeFilter == .cask { base = base.filter { $0.kind == .cask } }
            if activeFilter == .formula { base = base.filter { $0.kind == .formula } }
        }
        if !trimmed.isEmpty {
            base = base.filter { $0.name.lowercased().contains(trimmed) || $0.displayName.lowercased().contains(trimmed) }
        }
        _ = orphanIDs
        return HomebrewPackageOrdering.updatesFirst(base)
    }

    private var installedSection: some View {
        let rows = installedRows
        let graph = folded
        let orphanIDs = Set(graph.orphans.map(\.id))
        return VStack(alignment: .leading, spacing: 8) {
            AppManagerSectionHeader(title: s.homebrewInstalled,
                                    meta: firstLoad ? nil : String(format: strings.packagesFormat, rows.count)) {
                if firstLoad {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 120, height: 10)
                        .accessibilityHidden(true)
                } else {
                    Toggle(s.homebrewGroupDependencies, isOn: $groupDependencies)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
            }
            SettingsCard {
                if homebrew.isLoadingInstalled && homebrew.installed.isEmpty {
                    AppManagerListSkeleton()
                } else if rows.isEmpty {
                    Text(strings.noPackagesMatch)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, package in
                            if index > 0 { Divider().padding(.leading, 42).padding(.vertical, 6) }
                            packageRow(package, dependencies: groupDependencies ? (graph.dependencies[package.id] ?? []) : [],
                                       orphan: orphanIDs.contains(package.id))
                        }
                    }
                }
            }
        }
    }

    private func packageRow(_ package: HomebrewPackage, dependencies: [HomebrewPackage], orphan: Bool) -> some View {
        let isExpanded = expanded.contains(package.id)
        let status = activeStatus(for: package.id)
            ?? (homebrew.operationStatus?.isActive == true && homebrew.operationStatus?.action == .upgradeAll
                && package.hasUpdateAvailable ? homebrew.operationStatus : nil)
        let armed = armedUninstall == package.id
        let dependencyUpdates = dependencies.filter(\.hasUpdateAvailable).count
        var meta: [String] = []
        if let update = package.update {
            meta.append("\(package.installedVersion ?? "") → \(update.currentVersion)")
        } else if let version = package.versionText {
            meta.append("v\(version)")
        }
        meta.append(package.kind == .cask ? strings.cask : strings.formula)
        if !dependencies.isEmpty {
            var deps = String(format: strings.depsFormat, dependencies.count)
            if dependencyUpdates > 0 { deps += " (" + String(format: strings.depUpdatesFormat, dependencyUpdates) + ")" }
            meta.append(deps)
        }
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                armedUninstall = nil
                if isExpanded { expanded.remove(package.id) } else { expanded.insert(package.id) }
            } label: {
                HStack(spacing: 12) {
                    kindTile(package.kind)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(package.displayName).font(.system(size: 13, weight: .medium)).lineLimit(1)
                            if package.hasUpdateAvailable { AppManagerChip(text: strings.updateChip, tone: .orange) }
                            if orphan { AppManagerChip(text: strings.orphanChip) }
                        }
                        HStack(spacing: 4) {
                            Text(meta.joined(separator: " · "))
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                                .opacity(0.7)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    trailing(package, status: status, armed: armed)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(status != nil ? 0.85 : 1)
            .accessibilityValue(isExpanded ? s.disclosureExpanded : s.disclosureCollapsed)
            if isExpanded {
                details(package, dependencies: dependencies, armed: armed)
                    .padding(.leading, 42)
                    .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private func trailing(_ package: HomebrewPackage, status: HomebrewOperationStatus?, armed: Bool) -> some View {
        if let status {
            busyPill(status.action == .uninstall ? strings.uninstalling
                     : status.action == .install ? strings.installing : strings.upgrading)
        } else if package.hasUpdateAvailable {
            Button(s.homebrewUpgrade) { homebrew.upgrade(package) }
                .buttonStyle(.appManager())
                .disabled(homebrew.isBusy)
        } else {
            uninstallButton(package, armed: armed, label: armed ? strings.confirm : s.homebrewUninstall)
        }
    }

    private func uninstallButton(_ package: HomebrewPackage, armed: Bool, label: String) -> some View {
        Button(label) {
            guard armed else { armedUninstall = package.id; return }
            armedUninstall = nil
            homebrew.uninstall(package)
        }
        .buttonStyle(.appManager(armed ? .destructive : .neutral))
        .disabled(homebrew.isBusy)
    }

    private func details(_ package: HomebrewPackage, dependencies: [HomebrewPackage], armed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // One run of text, so a long description wraps with the name
            // after it instead of leaving it stranded in a column.
            ((package.desc.map { Text($0 + " · ") } ?? Text("")).font(.caption)
                + Text(package.name).font(.system(size: 10.5, design: .monospaced)))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(dependencies) { dependency in
                HStack(spacing: 6) {
                    Text(dependency.displayName).font(.system(size: 11.5))
                    if dependency.hasUpdateAvailable { AppManagerChip(text: strings.updateChip, tone: .orange) }
                    Spacer()
                    Text(dependency.versionText.map { "v\($0)" } ?? "")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
            HStack(spacing: 8) {
                if let homepage = package.homepage, let url = URL(string: homepage) {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label(s.homebrewHomepage, systemImage: "arrow.up.right")
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 11))
                }
                Spacer()
                if package.hasUpdateAvailable {
                    uninstallButton(package, armed: armed, label: armed ? strings.confirmUninstall : s.homebrewUninstall)
                }
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func kindTile(_ kind: HomebrewPackageKind) -> some View {
        AppManagerSymbolTile(symbol: kind == .cask ? "macwindow" : "terminal",
                             tint: kind == .cask ? .purple : .secondary)
    }

    private func busyPill(_ text: String) -> some View {
        HStack(spacing: 5) {
            ProgressView()
                .controlSize(.mini)
                .scaleEffect(0.85)
                .frame(width: 11, height: 11)
            Text(text)
        }
        .font(.system(size: 11.5, weight: .semibold))
        .lineLimit(1)
        .padding(.horizontal, 14)
        .padding(.vertical, 5.5)
        .foregroundStyle(Color.accentColor)
        .background(Color.accentColor.opacity(0.12), in: Capsule())
    }

    private func activeStatus(for id: String) -> HomebrewOperationStatus? {
        guard let status = homebrew.operationStatus, status.isActive, status.package?.id == id else { return nil }
        return status
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        if let status = activeOrHomebrewStatus {
            AppManagerDockedFooter(progress: status.isActive ? status.progressFraction : nil) {
                HomebrewCompactOperationFooter(status: status)
            }
        } else if catalog.selfUpdateAvailable, let latest = catalog.latestVersion {
            AppManagerDockedFooter {
                Circle().fill(Color.accentColor).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(format: strings.footerAvailableFormat, latest))
                        .font(.system(size: 12.5, weight: .semibold))
                    Text(String(format: strings.footerDetailFormat, catalog.installedVersion ?? ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button(s.homebrewUpdateHomebrew) { homebrew.updateHomebrew() }
                    .buttonStyle(.appManager())
                    .disabled(homebrew.isBusy)
            }
        }
    }

    // MARK: Missing

    private var missing: some View {
        SettingsFeatureEmptyState(title: s.homebrewMissingTitle, symbol: "shippingbox",
                                  description: s.homebrewMissingBody) {
            VStack(spacing: 8) {
                Button {
                    homebrew.openHomebrewInstaller()
                } label: {
                    Label(s.homebrewInstallHomebrew, systemImage: "terminal")
                }
                .buttonStyle(.borderedProminent)
                Text(homebrew.didOpenInstaller ? s.homebrewInstallHomebrewOpened : s.homebrewInstallHomebrewCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                Button {
                    homebrew.refreshInstalled()
                } label: {
                    Label(s.homebrewRefresh, systemImage: "arrow.clockwise")
                }
            }
        }
    }
}

extension HomebrewPackageKind: Codable {}
