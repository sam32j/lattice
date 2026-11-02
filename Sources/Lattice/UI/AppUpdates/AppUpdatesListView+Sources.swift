// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers


extension AppUpdatesListView {
    var updateSourcesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text.sourcesTitle)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 0) {
                // Homebrew row
                HStack(alignment: .center) {
                    Text(text.homebrewBadge)
                        .font(.system(size: 13, weight: .regular))
                    Spacer()
                    Toggle(text.homebrewBadge, isOn: $includeHomebrewApps)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .accessibilityLabel(text.homebrewBadge)
                        .onChange(of: includeHomebrewApps) { _, _ in handleSourceChange() }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                preferenceDivider

                // App Store row
                HStack(alignment: .center) {
                    Text(text.appStoreBadge)
                        .font(.system(size: 13, weight: .regular))
                    Spacer()
                    Toggle(text.appStoreBadge, isOn: $includeAppStore)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .accessibilityLabel(text.appStoreBadge)
                        .onChange(of: includeAppStore) { _, _ in handleSourceChange() }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                preferenceDivider

                // Application Channel row
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(text.applicationChannel)
                            .font(.system(size: 13, weight: .regular))
                        Text(text.applicationChannelCaption)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(text.applicationChannel, isOn: $includeOnlineCatalog)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .accessibilityLabel(text.applicationChannel)
                        .onChange(of: includeOnlineCatalog) { _, _ in handleSourceChange() }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
        }
    }

    func handleSourceChange() {
        updates.sourceSelectionDidChange()
        updates.syncWithPreferences()
    }

    // MARK: - Update Preferences

}
