// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers


extension AppUpdatesListView {
    var compactBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            summaryRow
                .panelCard()

            if allSourcesOff {
                compactNoSourcesState
            } else if updates.items.isEmpty {
                compactEmptyState
            } else {
                compactList
            }
            if coverageIncomplete {
                incompleteCheck
                    .panelCard()
            }
            if versionsUncompared {
                uncomparableVersions
                    .panelCard()
            }
            if let status = homebrew.operationStatus {
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

    var summaryRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(lastCheckLine)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button {
                updates.check()
            } label: {
                if updates.isChecking {
                    HStack(spacing: 5) {
                        ProgressView().controlSize(.mini)
                        Text(text.checking)
                    }
                    .font(.system(size: 10.5, weight: .medium))
                } else {
                    Label(text.checkNow, systemImage: "arrow.clockwise")
                        .font(.system(size: 10.5, weight: .medium))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isBusy || allSourcesOff)
        }
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
            Text(text.onlineUnavailable)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
