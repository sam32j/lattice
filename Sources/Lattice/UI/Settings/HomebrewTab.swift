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
    @ObservedObject private var homebrew = HomebrewManager.shared
    @ObservedObject private var catalog = HomebrewOnlineCatalog.shared
    @AppStorage(DefaultsKey.homebrewGroupDependencies) private var groupDependencies = true
    @State private var query = ""
    @State private var filter = Filter.all
    @State private var expanded: Set<String> = []
    @State private var armedUninstall: String?
    @State private var showDetails = false

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
                    if let error = homebrew.errorMessage, !error.isEmpty, homebrew.operationStatus?.isActive != true {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    searchBar
                    // What is installed comes first; the catalog follows, and
                    // only for the filters it can answer.
                    installedSection
                    if searchesOnline, !query.trimmingCharacters(in: .whitespaces).isEmpty { onlineSection }
                    if let status = homebrew.operationStatus, !status.isActive, status.result != .running {
                        HomebrewOperationStatusView(status: status, log: homebrew.log,
                                                    terminalFallbackCommand: homebrew.terminalFallbackCommand,
                                                    compact: false, showDetails: $showDetails,
                                                    onCancel: homebrew.cancelOperation, onClear: homebrew.clearLog,
                                                    onOpenTerminal: homebrew.openTerminalFallback)
                    }
                } footer: {
                    footer
                }
            }
        }
        .onAppear {
            if homebrew.installed.isEmpty { homebrew.refreshInstalled() }
            catalog.checkVersion()
        }
        .onChange(of: query) { _, _ in runSearch() }
        .onChange(of: filter) { _, _ in runSearch() }
        .animation(.easeInOut(duration: 0.2), value: homebrew.operationStatus?.isActive == true)
        .animation(.easeInOut(duration: 0.2), value: catalog.selfUpdateAvailable)
    }

    // MARK: Header

    private var outdated: [HomebrewPackage] { homebrew.installed.filter(\.hasUpdateAvailable) }

    /// How many updates, with the refresh arrow right beside it (turning
    /// while Homebrew is read), and Upgrade All when there is something to
    /// upgrade.
    private var statusCard: some View {
        let casks = homebrew.installed.filter { $0.kind == .cask }.count
        let formulae = homebrew.installed.count - casks
        var detail = String(format: strings.summaryFormat, homebrew.installed.count, casks, formulae)
        if let version = catalog.installedVersion { detail += " · " + String(format: strings.versionFormat, version) }
        let refreshing = homebrew.isLoadingInstalled
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(outdated.isEmpty ? strings.upToDate : String(format: strings.packageUpdatesFormat, outdated.count))
                        .font(.system(size: 13, weight: .semibold))
                    Button {
                        homebrew.refreshInstalled()
                        catalog.checkVersion(force: true)
                    } label: {
                        RefreshArrow(isSpinning: refreshing)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(homebrew.isBusy || refreshing)
                    .help(s.homebrewRefresh)
                    .accessibilityLabel(s.homebrewRefresh)
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if !outdated.isEmpty {
                Button(s.homebrewUpgradeAll) { homebrew.upgradeAll() }
                    .buttonStyle(.appManager())
                    .disabled(homebrew.isBusy)
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// The search field with its filter inside it, as Process Manager's.
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(searchPlaceholder, text: $query)
                .textFieldStyle(.plain)
            if catalog.isSearching {
                ProgressView().controlSize(.small)
            }
            Rectangle()
                .fill(Color.primary.opacity(0.18))
                .frame(width: 1, height: 14)
                .accessibilityHidden(true)
            filterMenu
                .font(.system(size: 11.5))
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
    }

    private var searchPlaceholder: String {
        switch filter {
        case .all: return strings.searchAll
        case .cask: return strings.searchCasks
        case .formula: return strings.searchFormulae
        case .outdated: return strings.searchOutdated
        case .orphans: return strings.searchOrphans
        }
    }

    private func filterTitle(_ option: Filter) -> String {
        switch option {
        case .all: return String(format: strings.filterAllFormat, homebrew.installed.count)
        case .cask: return String(format: strings.filterCasksFormat, homebrew.installed.filter { $0.kind == .cask }.count)
        case .formula:
            return String(format: strings.filterFormulasFormat, homebrew.installed.filter { $0.kind == .formula }.count)
        case .outdated: return String(format: strings.filterOutdatedFormat, outdated.count)
        case .orphans: return String(format: strings.filterOrphansFormat, folded.orphans.count)
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker(s.homebrewAll, selection: $filter) {
                ForEach([Filter.all, .cask, .formula, .outdated, .orphans], id: \.self) { option in
                    Text(filterTitle(option)).tag(option)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            // One text run, so the menu label keeps the chevron after the name.
            (Text(filterTitle(filter) + " ")
             + Text(Image(systemName: "chevron.down")).font(.system(size: 8, weight: .bold)))
            .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    /// Outdated and orphaned are about what is installed; the catalog has
    /// nothing to add to them.
    private var searchesOnline: Bool { filter == .all || filter == .cask || filter == .formula }

    private func runSearch() {
        guard searchesOnline else { catalog.clear(); return }
        let kind: HomebrewPackageKind? = filter == .cask ? .cask : filter == .formula ? .formula : nil
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
                SettingsCard {
                    Text(String(format: strings.noOnlineFormat, query.trimmingCharacters(in: .whitespaces)))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
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
        switch filter {
        case .orphans: base = graph.orphans
        case .outdated: base = outdated
        case .cask, .formula, .all:
            base = groupDependencies ? graph.rows + graph.orphans.filter { orphan in !graph.rows.contains(orphan) }
                                     : homebrew.installed
            if filter == .cask { base = base.filter { $0.kind == .cask } }
            if filter == .formula { base = base.filter { $0.kind == .formula } }
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
            AppManagerSectionHeader(title: s.homebrewInstalled, meta: String(format: strings.packagesFormat, rows.count)) {
                Toggle(s.homebrewGroupDependencies, isOn: $groupDependencies)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            SettingsCard {
                if homebrew.isLoadingInstalled && homebrew.installed.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(s.homebrewLoading).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
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
            ProgressView().controlSize(.mini)
            Text(text)
        }
        .font(.system(size: 11.5, weight: .medium))
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(Color.accentColor.opacity(0.12), in: Capsule())
    }

    private func activeStatus(for id: String) -> HomebrewOperationStatus? {
        guard let status = homebrew.operationStatus, status.isActive, status.package?.id == id else { return nil }
        return status
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        if let status = homebrew.operationStatus, status.isActive {
            AppManagerDockedFooter(progress: status.progressFraction) {
                ProgressView().controlSize(.small)
                VStack(alignment: .leading, spacing: 1) {
                    Text(operationTitle(status))
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(1)
                    Text("$ " + command(for: status))
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button(s.homebrewCancelOperation) { homebrew.cancelOperation() }
                    .buttonStyle(.appManager(.neutral))
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

    private func operationTitle(_ status: HomebrewOperationStatus) -> String {
        let name = status.package?.displayName ?? ""
        switch status.action {
        case .install: return String(format: s.homebrewOperationInstallFormat, name)
        case .uninstall: return String(format: s.homebrewOperationUninstallFormat, name)
        case .upgrade: return String(format: s.homebrewOperationUpgradeFormat, name)
        case .upgradeAll: return s.homebrewOperationUpgradeAll
        case .updateHomebrew: return s.homebrewOperationUpdateHomebrew
        }
    }

    private func command(for status: HomebrewOperationStatus) -> String {
        let cask = status.package?.kind == .cask ? "--cask " : ""
        let name = status.package?.name ?? ""
        switch status.action {
        case .install: return "brew install \(cask)\(name)"
        case .uninstall: return "brew uninstall \(cask)\(name)"
        case .upgrade: return "brew upgrade \(cask)\(name)"
        case .upgradeAll: return "brew upgrade"
        case .updateHomebrew: return "brew update"
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
