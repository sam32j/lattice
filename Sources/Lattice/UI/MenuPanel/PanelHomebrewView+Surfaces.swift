// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

extension PanelHomebrewView {
    // MARK: - Dynamic Island

    @ViewBuilder
    var islandBody: some View {
        VStack(spacing: 8) {
            islandTopBar
            if homebrew.brewPath == nil && !homebrew.isLoadingInstalled {
                islandMissingState
            } else if firstLoad {
                islandStateCard {
                    ProgressView().controlSize(.small)
                    Text(s.homebrewLoading)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                }
            } else if let status = activeOrHomebrewStatus {
                islandOperationState(status)
            } else if !trimmedQuery.isEmpty {
                islandSearchResults
            } else {
                islandOverview
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: trimmedQuery.isEmpty)
    }

    private var islandTopBar: some View {
        let refreshing = homebrew.isLoadingInstalled || homebrew.isLoadingOutdated
        return HStack(spacing: 6) {
            searchBar(compactNotch: true)
            islandUtilityButton(label: s.homebrewRefresh,
                                disabled: homebrew.isBusy || refreshing,
                                action: refreshAll) {
                RefreshArrow(isSpinning: refreshing)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
            islandUtilityButton(label: strings.openHomebrew,
                                action: openHomebrewSettings) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    private func islandUtilityButton<Icon: View>(
        label: String,
        disabled: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        Button(action: action) {
            icon()
                .frame(width: 30, height: 30)
                .modifier(NotchControlSurface(cornerRadius: 10, interactive: false))
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 10))
        .disabled(disabled)
        .help(label)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var islandOverview: some View {
        if let tap = homebrew.untrustedTap {
            islandStateCard {
                HomebrewTrustCard(tap: tap, compact: true)
            }
        } else {
            VStack(spacing: 8) {
                islandUpdatesCard
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if showsCleanupButton {
                    islandCleanupCard
                }
                islandNoticeBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: outdated.isEmpty)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: showsCleanupButton)
        }
    }

    private var islandUpdatesCard: some View {
        Group {
            if outdated.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.green)
                    Text(strings.upToDate)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.orange)
                    VStack(spacing: 2) {
                        Text(String(format: strings.packageUpdatesFormat, outdated.count))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        if !outdatedPreviewLine.isEmpty {
                            Text(outdatedPreviewLine)
                                .font(.system(size: 10.5))
                                .foregroundStyle(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    islandPillButton(title: s.homebrewUpgradeAll,
                                     prominent: true,
                                     disabled: homebrew.isBusy,
                                     fullWidth: false) {
                        homebrew.upgradeAll()
                    }
                    .fixedSize()
                    .padding(.top, 4)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .modifier(NotchControlSurface(cornerRadius: 15, interactive: false))
    }

    private var islandCleanupCard: some View {
        let sizeText = homebrew.cleanupEstimate?.freedSizeText
        return HStack(spacing: 8) {
            Text(strings.cleanupTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
            if let sizeText {
                AppManagerChip(text: sizeText, tone: .accent)
            }
            Spacer(minLength: 8)
            islandPillButton(title: strings.cleanupButton,
                             prominent: false,
                             disabled: homebrew.isBusy,
                             fullWidth: false) {
                homebrew.cleanup()
            }
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(NotchControlSurface(cornerRadius: 14, interactive: false))
    }

    @ViewBuilder
    private var islandNoticeBar: some View {
        if !homebrew.isShellConfigured {
            Button {
                homebrew.openShellConfiguration()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "terminal")
                        .font(.system(size: 10, weight: .semibold))
                    Text(s.homebrewShellSetupTitle)
                        .font(.system(size: 10.5, weight: .medium))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(s.homebrewShellSetupButton)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
        } else if let error = homebrew.errorMessage, !error.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                Text(error)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }

    private func islandPillButton(
        title: String,
        symbol: String? = nil,
        prominent: Bool,
        disabled: Bool = false,
        fullWidth: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if let symbol {
                    Label(title, systemImage: symbol)
                } else {
                    Text(title)
                }
            }
            .font(.system(size: 11, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, fullWidth ? 10 : 14)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: 26)
            .background {
                if prominent {
                    Capsule().fill(Color.accentColor)
                } else {
                    Capsule().fill(.white.opacity(0.11))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
                }
            }
            .foregroundStyle(prominent ? Color.white : Color.white.opacity(0.92))
            .contentShape(Capsule())
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 13))
        .disabled(disabled)
    }

    private func islandStateCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(NotchControlSurface(cornerRadius: 16, interactive: false))
    }

    @ViewBuilder
    private var islandSearchResults: some View {
        let installed = filteredInstalled
        let online = catalog.results
        if catalog.isSearching && installed.isEmpty && online.isEmpty {
            islandStateCard {
                ProgressView().controlSize(.small)
                Text(strings.searchingOnline)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.65))
            }
        } else if installed.isEmpty && online.isEmpty {
            islandStateCard {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(.white.opacity(0.45))
                Text(String(format: strings.noOnlineFormat, trimmedQuery))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 5) {
                    if !installed.isEmpty && !online.isEmpty {
                        compactSectionHeader(s.homebrewInstalled, meta: "\(installed.count)")
                    }
                    ForEach(installed) { package in
                        compactSearchInstalledRow(package)
                    }
                    if !online.isEmpty {
                        if !installed.isEmpty {
                            compactSectionHeader(strings.onlineTitle, meta: "\(online.count)")
                                .padding(.top, 4)
                        }
                        ForEach(online) { entry in
                            catalogRow(entry)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentMargins(.vertical, 4, for: .scrollContent)
            .hubScrollEdgeFade()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func islandOperationState(_ status: HomebrewOperationStatus) -> some View {
        islandStateCard {
            if status.isActive {
                HStack(spacing: 7) {
                    Text(operationTitle(status))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    TimelineView(.periodic(from: status.startedAt, by: 1)) { context in
                        Text(elapsedText(startedAt: status.startedAt, finishedAt: status.finishedAt, now: context.date))
                            .font(.system(size: 10.5))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                Group {
                    if let fraction = status.progressFraction {
                        NotchMeter(value: fraction, height: 5, tint: .accentColor)
                    } else {
                        HomebrewIndeterminateProgressBar()
                    }
                }
                .frame(maxWidth: 300)
                Text(status.lastActivity ?? phaseLabel(status.phase))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 320)
                islandPillButton(title: s.homebrewCancelOperation, prominent: false, fullWidth: false) {
                    homebrew.cancelOperation()
                }
                .padding(.top, 2)
            } else if status.result == .needsTerminal {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.orange)
                Text(s.homebrewOperationTerminal)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                HStack(spacing: 8) {
                    if homebrew.terminalFallbackCommand != nil {
                        islandPillButton(title: s.homebrewOpenTerminal, prominent: true, fullWidth: false) {
                            homebrew.openTerminalFallback()
                        }
                    }
                    islandPillButton(title: s.doneButton, prominent: false, fullWidth: false) {
                        homebrew.clearLog()
                    }
                }
            } else if let tap = homebrew.untrustedTap {
                HomebrewTrustCard(tap: tap, compact: true)
                islandPillButton(title: s.doneButton, prominent: false, fullWidth: false) {
                    homebrew.clearUntrustedTap()
                    homebrew.clearLog()
                }
            } else if status.result == .succeeded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.green)
                Text(succeededTitle(status))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let detail = succeededDetail(status) {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
                islandPillButton(title: s.doneButton, prominent: false, fullWidth: false) {
                    homebrew.clearLog()
                }
                .padding(.top, 2)
            } else {
                let failed = status.result == .failed
                Image(systemName: statusIcon(status.result))
                    .font(.system(size: 22))
                    .foregroundStyle(statusColor(status.result))
                Text(failed
                     ? String(format: s.homebrewOperationFailedFormat, failedTargetName(status))
                     : s.homebrewOperationCancelled)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if failed, let err = status.lastActivity ?? homebrew.errorMessage, !err.isEmpty {
                    Text(err)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
                islandPillButton(title: s.doneButton, prominent: false, fullWidth: false) {
                    homebrew.clearLog()
                }
            }
        }
    }

    private var islandMissingState: some View {
        islandStateCard {
            Image(systemName: "shippingbox")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.white.opacity(0.55))
            Text(s.homebrewMissingTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            HStack(spacing: 8) {
                islandPillButton(title: s.homebrewInstallHomebrew, symbol: "terminal", prominent: true, fullWidth: false) {
                    homebrew.openHomebrewInstaller()
                }
                islandPillButton(title: s.homebrewRefresh, prominent: false, fullWidth: false) {
                    homebrew.refreshInstalled()
                }
            }
        }
    }

    // MARK: - Floating Hub

    @ViewBuilder
    var hubBody: some View {
        if homebrew.brewPath == nil && !homebrew.isLoadingInstalled {
            hubMissingState
        } else {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    VStack(alignment: .leading, spacing: 8) {
                        hubHeading
                        searchBar(compactNotch: false)
                    }
                    hubListArea
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                hubFooter
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: activeOrHomebrewStatus?.targetID)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: activeOrHomebrewStatus?.result)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: showsHubIdleFooter)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: homebrew.isOperationDetailsExpanded)
        }
    }

    private var hubHeading: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 6) {
                Text(firstLoad ? s.homebrewLoading
                     : (outdated.isEmpty ? strings.upToDate : String(format: strings.packageUpdatesFormat, outdated.count)))
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                refreshButton(size: 11)
            }
            Spacer(minLength: 8)
            Button(action: openHomebrewSettings) {
                Text(strings.openHomebrew)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var hubListArea: some View {
        if firstLoad {
            AppManagerListSkeleton(rows: 6)
                .padding(.horizontal, 4)
                .padding(.top, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if !homebrew.isShellConfigured {
                        hubShellSetupBanner
                    }
                    if let tap = homebrew.untrustedTap {
                        HomebrewTrustCard(tap: tap, compact: true)
                    }
                    if let error = homebrew.errorMessage, !error.isEmpty, activeOrHomebrewStatus == nil {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 4)
                            Button { homebrew.errorMessage = nil } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    if !trimmedQuery.isEmpty {
                        hubSearchResultsContent
                    } else {
                        hubInstalledContent
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentMargins(.vertical, HubScrollEdge.inset, for: .scrollContent)
            .hubScrollEdgeFade()
        }
    }

    private var hubShellSetupBanner: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(s.homebrewShellSetupTitle)
                    .font(.system(size: 11, weight: .semibold))
                Text(homebrew.didOpenShellConfig ? s.homebrewShellSetupOpened : s.homebrewShellSetupBody)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Button(s.homebrewShellSetupButton) {
                homebrew.openShellConfiguration()
            }
            .buttonStyle(.appManager(compact: true))
        }
        .padding(10)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var hubInstalledContent: some View {
        let packages = filteredInstalled
        if packages.isEmpty {
            Text(homebrew.installed.isEmpty ? s.homebrewNoPackages : strings.noPackagesMatch)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
        } else {
            ForEach(packages) { package in
                hubInstalledRow(package)
            }
        }
    }

    @ViewBuilder
    private var hubSearchResultsContent: some View {
        let installed = filteredInstalled
        let online = catalog.results
        if !installed.isEmpty {
            if searchesOnline {
                compactSectionHeader(s.homebrewInstalled, meta: "\(installed.count)")
            }
            ForEach(installed) { package in
                hubInstalledRow(package)
            }
        }
        if searchesOnline {
            compactSectionHeader(strings.onlineTitle,
                                 meta: catalog.isSearching ? strings.searchingOnline
                                     : String(format: strings.resultsFormat, online.count))
                .padding(.top, installed.isEmpty ? 0 : 4)
            if catalog.isSearching && online.isEmpty {
                AppManagerListSkeleton(rows: 3)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
            } else if online.isEmpty {
                Text(String(format: strings.noOnlineFormat, trimmedQuery))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 70, alignment: .center)
            } else {
                ForEach(online) { entry in
                    catalogRow(entry)
                }
            }
        } else if installed.isEmpty {
            Text(strings.noPackagesMatch)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
        }
    }

    // MARK: Rows

    private func compactSearchInstalledRow(_ package: HomebrewPackage) -> some View {
        let status = activeStatus(for: package)
        return HStack(spacing: 10) {
            kindTile(package.kind, size: 26)
            VStack(alignment: .leading, spacing: 1.5) {
                HStack(spacing: 5) {
                    Text(package.displayName)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if package.hasUpdateAvailable {
                        AppManagerChip(text: strings.updateChip, tone: .orange)
                    }
                }
                Text(packageSubtitle(package))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 6)
            installedTrailing(package, status: status)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .modifier(NotchControlSurface(cornerRadius: 11, interactive: false))
        .contextMenu {
            packageContextMenu(package)
        }
    }

    private func hubInstalledRow(_ package: HomebrewPackage) -> some View {
        let isExpanded = expandedPackageID == package.id
        let status = activeStatus(for: package)
        let armed = armedUninstallID == package.id
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Button {
                    armedUninstallID = nil
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) {
                        expandedPackageID = isExpanded ? nil : package.id
                    }
                } label: {
                    HStack(spacing: 10) {
                        kindTile(package.kind, size: 26)
                        VStack(alignment: .leading, spacing: 1.5) {
                            HStack(spacing: 5) {
                                Text(package.displayName)
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                if package.hasUpdateAvailable {
                                    AppManagerChip(text: strings.updateChip, tone: .orange)
                                }
                                if orphanIDs.contains(package.id) {
                                    AppManagerChip(text: strings.orphanChip)
                                }
                            }
                            HStack(spacing: 4) {
                                Text(packageSubtitle(package))
                                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 7.5, weight: .semibold))
                                    .opacity(0.65)
                            }
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(isExpanded ? s.disclosureExpanded : s.disclosureCollapsed)

                installedTrailing(package, status: status)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ((package.desc.map { Text($0 + " · ") } ?? Text("")).font(.system(size: 10.5))
                        + Text(package.name).font(.system(size: 10, design: .monospaced)))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        if let homepage = package.homepage, let url = URL(string: homepage) {
                            Button {
                                NSWorkspace.shared.open(url)
                            } label: {
                                Label(s.homebrewHomepage, systemImage: "arrow.up.right")
                            }
                            .buttonStyle(.link)
                            .font(.system(size: 10.5))
                        }
                        Spacer(minLength: 4)
                        Button(armed ? strings.confirm : s.homebrewUninstall) {
                            armOrUninstall(package)
                        }
                        .buttonStyle(.appManager(armed ? .destructive : .neutral, compact: true))
                        .disabled(homebrew.isBusy)
                    }
                }
                .padding(.leading, 36)
                .padding(.top, 2)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .modifier(HubHoverRowModifier())
        .contextMenu {
            packageContextMenu(package)
        }
    }

    @ViewBuilder
    private func installedTrailing(_ package: HomebrewPackage, status: HomebrewOperationStatus?) -> some View {
        if let status {
            busyPill(status.action == .uninstall ? strings.uninstalling
                     : status.action == .install ? strings.installing : strings.upgrading)
        } else if package.hasUpdateAvailable {
            Button(s.homebrewUpgrade) {
                homebrew.upgrade(package)
            }
            .buttonStyle(.appManager(compact: true))
            .disabled(homebrew.isBusy)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.green)
                .accessibilityLabel(s.homebrewInstalledBadge)
        }
    }

    @ViewBuilder
    private func catalogRow(_ entry: HomebrewOnlineCatalog.Entry) -> some View {
        let busy = activeStatus(for: entry.package.id) != nil
        let row = HStack(spacing: 10) {
            kindTile(entry.kind, size: 26)
            VStack(alignment: .leading, spacing: 1.5) {
                HStack(spacing: 5) {
                    Text(entry.displayName)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(inNotch ? AnyShapeStyle(.white.opacity(0.92)) : AnyShapeStyle(.primary))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    AppManagerChip(text: entry.kind == .cask ? strings.cask : strings.formula)
                }
                Text([entry.version.isEmpty ? nil : "v\(entry.version)", entry.desc.isEmpty ? entry.name : entry.desc]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 9.5))
                    .foregroundStyle(inNotch ? AnyShapeStyle(.white.opacity(0.55)) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 6)
            if busy {
                busyPill(strings.installing)
            } else {
                Button(s.homebrewInstall) {
                    homebrew.install(entry.package)
                }
                .buttonStyle(.appManager(compact: true))
                .disabled(homebrew.isBusy)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)

        if inNotch {
            row.modifier(NotchControlSurface(cornerRadius: 11, interactive: false))
        } else {
            row
                .modifier(HubHoverRowModifier())
        }
    }

    @ViewBuilder
    private func packageContextMenu(_ package: HomebrewPackage) -> some View {
        let busy = homebrew.isBusy || activeStatus(for: package.id) != nil
        if package.hasUpdateAvailable {
            Button {
                homebrew.upgrade(package)
            } label: {
                Label(s.homebrewUpgrade, systemImage: "arrow.up.circle")
            }
            .disabled(busy)
        }
        if let homepage = package.homepage, let url = URL(string: homepage) {
            Button {
                NSWorkspace.shared.open(url)
            } label: {
                Label(s.homebrewHomepage, systemImage: "safari")
            }
        }
        if package.isInstalled {
            Button(role: .destructive) {
                homebrew.uninstall(package)
            } label: {
                Label(s.homebrewUninstall, systemImage: "trash")
            }
            .disabled(busy)
        }
    }

    // MARK: Floating Hub Footer

    private var showsHubIdleFooter: Bool {
        showsCleanupButton || !outdated.isEmpty || (catalog.selfUpdateAvailable && catalog.latestVersion != nil)
    }

    @ViewBuilder
    private var hubFooter: some View {
        if let status = activeOrHomebrewStatus {
            VStack(spacing: 0) {
                ZStack(alignment: .leading) {
                    Divider()
                    if status.isActive, let progress = status.progressFraction {
                        GeometryReader { proxy in
                            Rectangle().fill(Color.accentColor)
                                .frame(width: proxy.size.width * min(max(progress, 0), 1), height: 2)
                                .animation(.easeOut(duration: 0.3), value: progress)
                        }
                        .frame(height: 2)
                    }
                }
                HomebrewCompactOperationFooter(status: status)
                    .padding(.top, 8)
            }
            .clipped()
            .transition(.opacity)
        } else if showsHubIdleFooter {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 8) {
                    if showsCleanupButton {
                        Button(cleanupActionTitle) {
                            homebrew.cleanup()
                        }
                        .buttonStyle(.appManager(.neutral, compact: true))
                        .disabled(homebrew.isBusy)
                    }
                    Spacer(minLength: 6)
                    if catalog.selfUpdateAvailable, let latest = catalog.latestVersion {
                        Button(s.homebrewUpdateHomebrew) {
                            homebrew.updateHomebrew()
                        }
                        .buttonStyle(.appManager(.neutral, compact: true))
                        .disabled(homebrew.isBusy)
                        .help(String(format: strings.footerAvailableFormat, latest))
                    }
                    if !outdated.isEmpty {
                        Button(s.homebrewUpgradeAll) {
                            homebrew.upgradeAll()
                        }
                        .buttonStyle(.appManager(compact: true))
                        .disabled(homebrew.isBusy)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private var hubMissingState: some View {
        VStack(spacing: 10) {
            Image(systemName: "shippingbox")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
            Text(s.homebrewMissingTitle)
                .font(.system(size: 13, weight: .semibold))
            Text(s.homebrewMissingBody)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button {
                    homebrew.openHomebrewInstaller()
                } label: {
                    Label(s.homebrewInstallHomebrew, systemImage: "terminal")
                }
                .buttonStyle(.appManager(compact: true))
                Button(s.homebrewRefresh) {
                    homebrew.refreshInstalled()
                }
                .buttonStyle(.appManager(.neutral, compact: true))
            }
            Text(homebrew.didOpenInstaller ? s.homebrewInstallHomebrewOpened : s.homebrewInstallHomebrewCaption)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Small Helpers

    private func compactSectionHeader(_ title: String, meta: String) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(inNotch ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.primary))
            Text("· \(meta)")
                .font(.system(size: 10))
                .foregroundStyle(inNotch ? AnyShapeStyle(.white.opacity(0.5)) : AnyShapeStyle(.secondary))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    private func packageSubtitle(_ package: HomebrewPackage) -> String {
        if let update = package.update {
            return "\(package.installedVersion ?? "") → \(update.currentVersion)"
        }
        var parts: [String] = []
        if let version = package.versionText { parts.append("v\(version)") }
        parts.append(package.kind == .cask ? strings.cask : strings.formula)
        return parts.joined(separator: " · ")
    }

    private func elapsedText(startedAt: Date, finishedAt: Date?, now: Date) -> String {
        let end = finishedAt ?? now
        let seconds = max(Int(end.timeIntervalSince(startedAt)), 0)
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)min" }
        return "\(minutes / 60)h \(minutes % 60)min"
    }

    private func statusIcon(_ result: HomebrewOperationResult) -> String {
        switch result {
        case .running: return "hourglass"
        case .succeeded: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .cancelled: return "xmark.octagon.fill"
        case .needsTerminal: return "terminal.fill"
        }
    }

    private func statusColor(_ result: HomebrewOperationResult) -> Color {
        switch result {
        case .running: return .accentColor
        case .succeeded: return .green
        case .failed, .needsTerminal: return .orange
        case .cancelled: return .red
        }
    }
}

private struct HubHoverRowModifier: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(isHovered ? 0.065 : 0.035))
            )
            .onHover { isHovered = $0 }
    }
}
