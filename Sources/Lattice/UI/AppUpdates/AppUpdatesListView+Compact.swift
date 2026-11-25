// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers


extension AppUpdatesListView {
    /// The Hub and island's updates: one loader while a check runs, then
    /// the heading, fixed, over a list as tall as its rows up to five in the
    /// island and eight in the floating Hub, scrolling past that.
    var compactBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            if updates.isChecking {
                compactLoader
            } else {
                compactHeader
                if allSourcesOff {
                    compactNoSourcesState
                } else if updates.items.isEmpty {
                    compactEmptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        compactList
                    }
                    .contentMargins(.vertical, HubScrollEdge.inset, for: .scrollContent)
                    .hubScrollEdgeFade()
                    .frame(height: Self.compactListViewport(rowCount: updates.items.count,
                                                            maxRows: inNotch ? 5 : 8))
                }
                if versionsUncompared {
                    uncomparableVersions
                        .panelCard()
                }
                if let status = appUpdatesOperationStatus {
                    HomebrewOperationStatusView(status: status,
                                                log: homebrew.log,
                                                terminalFallbackCommand: homebrew.terminalFallbackCommand,
                                                compact: true,
                                                showDetails: $showOperationDetails,
                                                onCancel: homebrew.cancelOperation,
                                                onClear: homebrew.clearLog,
                                                onOpenTerminal: homebrew.openTerminalFallback)
                }
                if let error = updates.lastError, !error.isEmpty {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .panelCard()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // The surface is sized to what this shows, nothing more.
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            AppManagerPanelState.shared.setUpdatesHeight(height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// The one loader while a check runs; the heading and list wait for
    /// its answer.
    var compactLoader: some View {
        VStack(spacing: 8) {
            if reduceMotion {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            } else {
                ProgressView().controlSize(.small)
            }
            Text(text.checking + "…")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.compactLoaderHeight)
    }

    /// The list's heading, as in Settings. Apps the check could not read
    /// are a small mark beside the refresh button, opening Settings, which
    /// names them; the tooltip names them too.
    var compactHeader: some View {
        UpdatesHeading(text: text, count: updates.items.count, lastCheck: headingDetail,
                       isChecking: updates.isChecking, disabled: isBusy || allSourcesOff,
                       compact: true,
                       uncheckedNote: coverageIncomplete
                           ? [text.someAppsUnchecked, incompleteCheckDetail].filter { !$0.isEmpty }
                               .joined(separator: "\n")
                           : nil,
                       onShowUnchecked: {
                           SettingsRouter.shared.request(AppFeature.appUpdates.settingsDestination)
                           (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
                       }) { updates.check() }
            .frame(height: Self.headerLineHeight)
            .padding(.horizontal, 4)
    }

    /// "Last checked just now · 29 total apps" under the heading.
    var headingDetail: String {
        guard updates.hasCheckedThisSession, totalAppsCount > 0, !allSourcesOff else { return lastCheckLine }
        return lastCheckLine + " · " + String(format: text.totalAppsFormat, totalAppsCount)
    }

    var lastCheckLine: String {
        if allSourcesOff { return text.noSourcesSelected }
        guard updates.lastCheck != nil else { return text.neverChecked }
        return String(format: text.lastCheckFormat,
                      lastCheckRelativeText)
    }

    var compactEmptyState: some View {
        VStack(spacing: inNotch ? 3 : 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: inNotch ? 18 : 24))
                .foregroundStyle(Color.green)
            Label(text.emptyUpToDate,
                  systemImage: successfulEmptyCheck ? "checkmark.circle.fill" : "info.circle")
                .labelStyle(.titleOnly)
                .font(.system(size: inNotch ? 11.5 : 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, inNotch ? 6 : 20)
    }

    var compactNoSourcesState: some View {
        VStack(spacing: inNotch ? 3 : 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: inNotch ? 16 : 22))
                .foregroundStyle(.orange)
            Text(text.selectSource)
                .font(.system(size: inNotch ? 11 : 12.5, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, inNotch ? 6 : 20)
    }

    var incompleteCheckDetail: String {
        var lines: [String] = []
        if !updates.uncheckedAppNames.isEmpty { lines.append(updates.uncheckedAppNames.joined(separator: ", ")) }
        if includeOnlineCatalog && !updates.onlineCatalogAvailable { lines.append(text.onlineUnavailable) }
        return lines.joined(separator: "\n\n")
    }

    var incompleteCheck: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(text.incompleteCheck, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.orange)
            if !updates.uncheckedAppNames.isEmpty {
                Text(updates.uncheckedAppNames.joined(separator: ", "))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .help(updates.uncheckedAppNames.joined(separator: ", "))
            }
            if includeOnlineCatalog && !updates.onlineCatalogAvailable {
                Text(text.onlineUnavailable)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    var uncomparableVersions: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(text.uncomparableVersions, systemImage: "info.circle")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
            Text(updates.uncomparableAppNames.joined(separator: ", "))
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .help(updates.uncomparableAppNames.joined(separator: ", "))
            Text(text.uncomparableVersionsNote)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

}
