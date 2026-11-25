// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers


extension AppUpdatesListView {
    var updateSourcesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppManagerSectionHeader(title: text.sourcesTitle)
            SettingsCard {
                SettingsControlRow(title: text.homebrewBadge) {
                    Toggle(text.homebrewBadge, isOn: $includeHomebrewApps)
                        .labelsHidden()
                        .onChange(of: includeHomebrewApps) { _, _ in handleSourceChange() }
                }
                Divider()
                SettingsControlRow(title: text.appStoreBadge) {
                    Toggle(text.appStoreBadge, isOn: $includeAppStore)
                        .labelsHidden()
                        .onChange(of: includeAppStore) { _, _ in handleSourceChange() }
                }
                Divider()
                SettingsControlRow(title: text.applicationChannel, caption: text.applicationChannelCaption) {
                    Toggle(text.applicationChannel, isOn: $includeOnlineCatalog)
                        .labelsHidden()
                        .onChange(of: includeOnlineCatalog) { _, _ in handleSourceChange() }
                }
            }
            .toggleStyle(.switch)
        }
    }

    func handleSourceChange() {
        updates.sourceSelectionDidChange()
        updates.syncWithPreferences()
    }

    // MARK: - Update Preferences

}
