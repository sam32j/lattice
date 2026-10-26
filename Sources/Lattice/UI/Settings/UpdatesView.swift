// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct UpdatesView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var updates = UpdateService.shared
    @AppStorage(DefaultsKey.autoCheckUpdates) private var autoCheck = true

    private var copy: UpdateSettingsStrings { .localized(l10n.language) }
    private var presentation: UpdateSettingsPresentation { .init(state: updates.state) }

    var body: some View {
        Section(l10n.s.updatesSection) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "clock.arrow.2.circlepath")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(copy.automatic)
                    .font(.callout.weight(.medium))
                Spacer()
                Toggle(copy.automatic, isOn: $autoCheck)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.regular)
            }
            .frame(minHeight: 40)
            .onChange(of: autoCheck) { _, value in
                updates.autoCheckEnabled = value
            }

            VStack(alignment: .leading, spacing: 10) {
                UpdateSettingsStatusRow(status: status, actions: actions)
                if case let .downloading(progress) = updates.state, let progress {
                    ProgressView(value: min(max(progress, 0), 1))
                        .accessibilityLabel(l10n.s.updateDownloading)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button(copy.check) { updates.check(manual: true) }
                .disabled(!presentation.canCheck)
            if presentation.reviewVersion != nil {
                Button(copy.review) { appDelegate()?.showUpdatePreview() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var status: some View {
        HStack(alignment: .center, spacing: 10) {
            if presentation.canCheck {
                Image(systemName: statusSymbol)
                    .font(.system(size: 16))
                    .foregroundStyle(statusColor)
                    .frame(width: 20)
            } else {
                ProgressView().controlSize(.small).frame(width: 20)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                if case let .failed(reason) = updates.state {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let lastChecked = updates.lastChecked {
                    Text("\(l10n.s.updateLastChecked) \(lastChecked.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .frame(minHeight: 40)
        .accessibilityElement(children: .combine)
    }

    private var statusTitle: String {
        switch updates.state {
        case .idle: return copy.notChecked
        case .checking: return l10n.s.updateChecking
        case .upToDate: return l10n.s.updateUpToDate
        case let .available(version): return "\(l10n.s.updateAvailablePrefix) \(version)"
        case let .downloading(progress):
            guard let progress else { return l10n.s.updateDownloading }
            return "\(l10n.s.updateDownloading) \(Int((min(max(progress, 0), 1) * 100).rounded()))%"
        case .installing: return l10n.s.updateInstalling
        case .failed: return l10n.s.updateFailedPrefix
        }
    }

    private var statusSymbol: String {
        switch updates.state {
        case .upToDate: return "checkmark.circle.fill"
        case .available: return "arrow.down.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        default: return "arrow.triangle.2.circlepath"
        }
    }

    private var statusColor: Color {
        switch updates.state {
        case .upToDate: return .green
        case .available: return .accentColor
        case .failed: return .orange
        default: return .secondary
        }
    }
}
