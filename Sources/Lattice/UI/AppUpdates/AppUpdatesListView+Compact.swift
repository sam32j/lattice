// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers


extension AppUpdatesListView {
    var compactBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            compactHeader
            if allSourcesOff {
                compactNoSourcesState
            } else if updates.items.isEmpty {
                compactEmptyState
            } else {
                compactList
            }
            // One line after the list, at its trailing edge, rather than a
            // card; the apps it means are in the tooltip and in Settings.
            if coverageIncomplete {
                incompleteCheckLine
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The list's heading, as in Settings.
    var compactHeader: some View {
        UpdatesHeading(text: text, count: updates.items.count, lastCheck: lastCheckLine,
                       isChecking: updates.isChecking, disabled: isBusy || allSourcesOff,
                       compact: true) { updates.check() }
            .frame(height: Self.headerLineHeight)
            .padding(.horizontal, 4)
    }

    var lastCheckLine: String {
        if allSourcesOff { return text.noSourcesSelected }
        guard updates.lastCheck != nil else { return text.neverChecked }
        return String(format: text.lastCheckFormat,
                      lastCheckRelativeText)
    }

    @ViewBuilder
    var compactEmptyState: some View {
        if updates.isChecking {
            VStack(spacing: inNotch ? 3 : 6) {
                if reduceMotion {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: inNotch ? 15 : 20))
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                        .controlSize(inNotch ? .mini : .small)
                }
                Text(text.checking)
                    .font(.system(size: inNotch ? 11 : 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, inNotch ? 6 : 20)
        } else {
            VStack(spacing: inNotch ? 3 : 6) {
                Image(systemName: successfulEmptyCheck ? "checkmark.circle.fill" : "info.circle")
                    .font(.system(size: inNotch ? 18 : 24))
                    .foregroundStyle(successfulEmptyCheck ? Color.green : Color.secondary)
                Label(statusHeadline,
                      systemImage: successfulEmptyCheck ? "checkmark.circle.fill" : "info.circle")
                    .labelStyle(.titleOnly)
                    .font(.system(size: inNotch ? 11.5 : 13, weight: .medium))
                    .foregroundStyle(.secondary)
                if successfulEmptyCheck {
                    Text(text.upToDate)
                        .font(.system(size: inNotch ? 9.5 : 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, inNotch ? 6 : 20)
        }
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

    /// Opens the App Updates settings, which list the apps it means.
    var incompleteCheckLine: some View {
        HStack(spacing: 6) {
            // At the bottom right, after the list it qualifies.
            Spacer(minLength: 4)
            if storeCoverageIncomplete {
                Button(text.openAppStore) { updates.openAppStoreUpdates() }
                    .buttonStyle(.link)
                    .font(.system(size: 10))
            }
            Button {
                SettingsRouter.shared.request(AppFeature.appUpdates.settingsDestination)
                (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
            } label: {
                HStack(spacing: 4) {
                    Label(text.someAppsUnchecked, systemImage: "exclamationmark.triangle.fill")
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                }
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.orange)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(height: Self.incompleteLineHeight)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .help(incompleteCheckDetail)
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
            if storeCoverageIncomplete {
                Button(text.openAppStore) { updates.openAppStoreUpdates() }
                    .buttonStyle(.link)
                    .font(.system(size: 10))
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
