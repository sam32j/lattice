// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers


extension AppUpdatesListView {
    /// The Hub and island's updates: one loader while a check runs, then
    /// the heading, fixed, over a list as tall as its rows up to five in the
    /// island and eight in the floating Hub, scrolling past that.
    @ViewBuilder
    var compactBody: some View {
        if inNotch { islandBody } else { hubBody }
    }

    /// The island is a window onto App Updates, not the place to work it:
    /// one state, centered, with a way into App Updates when there is
    /// something to update.
    var islandBody: some View {
        VStack(spacing: 10) {
            if updates.isChecking {
                ProgressView().controlSize(.small)
                AnimatedEllipsisText(base: text.checking)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } else if allSourcesOff {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.orange)
                Text(text.selectSource)
                    .font(.system(size: 13, weight: .semibold))
            } else if updates.items.isEmpty {
                upToDateState
            } else {
                stackedIcons
                Text(text.updatesAvailableShort)
                    .font(.system(size: 13, weight: .semibold))
                Button(text.openAppUpdates) {
                    SettingsRouter.shared.request(AppFeature.appUpdates.settingsDestination)
                    (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
                }
                .buttonStyle(.appManager(compact: true))
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Nothing to update: a check, the line, and a way to check again. The
    /// island and the floating Hub show the same.
    @ViewBuilder
    var upToDateState: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 30))
            .foregroundStyle(.green)
        Text(text.emptyUpToDate)
            .font(.system(size: 13, weight: .semibold))
        Button {
            updates.check()
        } label: {
            Label(text.checkNow, systemImage: "arrow.clockwise")
        }
        .buttonStyle(.appManager(.neutral, compact: true))
        .disabled(isBusy)
        .padding(.top, 2)
    }

    /// Up to four of the apps with updates, overlapping.
    private var stackedIcons: some View {
        let shown = Array(updates.items.prefix(4))
        return HStack(spacing: -14) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                Image(nsImage: icon(for: item))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                    .zIndex(Double(shown.count - index))
            }
        }
    }

    var hubBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            if updates.isChecking {
                // Keep the floating heading above the skeleton rows so the
                // header never disappears while checking, matching Homebrew.
                VStack(alignment: .leading, spacing: 0) {
                    compactHeader
                    AppManagerListSkeleton(rows: 6)
                        .padding(.horizontal, 4)
                        .padding(.top, HubScrollEdge.inset)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            } else if allSourcesOff {
                compactNoSourcesState
                    .frame(maxHeight: .infinity)
            } else if updates.items.isEmpty {
                // No heading: the state alone, centered, as in the island.
                VStack(spacing: 10) { upToDateState }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    compactHeader
                    ScrollView(showsIndicators: false) {
                        compactList
                    }
                    .contentMargins(.vertical, HubScrollEdge.inset, for: .scrollContent)
                    .hubScrollEdgeFade()
                    // The floating Hub keeps the All Tools height; the list
                    // takes what the heading leaves.
                    .frame(maxHeight: .infinity, alignment: .top)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// The list's heading, as in Settings. Apps the check could not read
    /// are a small mark beside the refresh button, opening Settings, which
    /// names them; the tooltip names them too.
    var compactHeader: some View {
        UpdatesHeading(text: text, count: updates.items.count, lastCheck: headingDetail,
                       isChecking: updates.isChecking, disabled: isBusy || allSourcesOff,
                       compact: true, showsDetail: false,
                       onOpen: {
                           SettingsRouter.shared.request(AppFeature.appUpdates.settingsDestination)
                           (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
                       }) { updates.check() }
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
