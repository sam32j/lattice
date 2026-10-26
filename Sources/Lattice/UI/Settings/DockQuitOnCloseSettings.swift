// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
import SwiftUI

struct DockQuitOnCloseSettings: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.autoQuitEnabled) private var enabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            SettingsRow(symbol: "xmark.rectangle", title: l10n.s.autoQuitName,
                        caption: l10n.s.autoQuitEnableCaption) {
                PermissionGatedToggle(l10n.s.autoQuitName, isOn: $enabled.animation(reduceMotion ? nil : .settingsExpansion)).labelsHidden()
                    .onChange(of: enabled) { _, _ in FeatureRuntime.shared.sync([.autoQuit]) }
            }
            if enabled {
                DockQuitOnCloseExceptions()
                    .padding(.leading, settingsRowTextInset)
            } else {
                SettingsControlRow(title: SettingsFollowupLabels.text(.dontQuitApps, l10n.language)) {
                    Button(SettingsAppListStrings.text(l10n.language).edit) {}
                }
                .padding(.leading, settingsRowTextInset)
                .disabled(true)
                .opacity(0.55)
            }
        }
        .settingsSectionAnchor(.autoQuit, cornerRadius: 16)
    }
}

private struct DockQuitOnCloseExceptions: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = AutoQuitService.shared
    @ObservedObject private var permissions = Permissions.shared

    private var exceptions: [String] {
        AutoQuitSupport.visibleExceptions(service.exceptions) { InstalledApps.url(for: $0) != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !permissions.accessibility { PermissionRow(kind: .accessibility) }
            AppBundleList(title: SettingsFollowupLabels.text(.dontQuitApps, l10n.language),
                          caption: SettingsAppListDescriptions.text(l10n.language).autoQuit,
                          addTitle: l10n.s.autoQuitAddApp,
                          removeLabel: l10n.s.autoQuitExceptionsTitle,
                          bundleIDs: exceptions,
                          usesSheet: true,
                          sheetTitle: SettingsFollowupLabels.text(.dontQuitApps, l10n.language),
                          canRemove: { !service.isMandatoryException($0) },
                          onAdd: { service.addException($0) },
                          onRemove: { service.removeException($0) })
        }
    }
}
