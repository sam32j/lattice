// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Music App Blocker settings: intercepts media key launches of Apple Music.
struct MusicBlockingSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var musicBlocker = MusicLaunchBlocker.shared
    @AppStorage(DefaultsKey.musicBlockEnabled) private var enabled = false

    private var hasSubSettings: Bool {
        enabled && (!permissions.accessibility || musicBlocker.monitoringFailed)
    }

    var body: some View {
        SettingsCard(
            symbol: "play.slash",
            title: l10n.s.musicBlockSection,
            caption: "Stop using the media key to start up the default music app",
            headerSpacing: 0,
            headerAccessory: {
                PermissionGatedToggle(l10n.s.musicBlockTitle, isOn: $enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.regular)
                    .accessibilityLabel(l10n.s.musicBlockTitle)
                    .onChange(of: enabled) { _, enabled in
                        FeatureRuntime.shared.setAvailable([.musicBlock], enabled)
                        musicBlocker.syncWithPreferences()
                    }
            }
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if enabled {
                    if !permissions.accessibility {
                        PermissionRow(kind: .accessibility)
                    } else if musicBlocker.monitoringFailed {
                        Text(l10n.s.musicBlockUnavailable)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.leading, settingsRowTextInset)
            .padding(.top, hasSubSettings ? SettingsCard<EmptyView>.defaultHeaderSpacing : 0)
            .settingsCollapsible(isExpanded: hasSubSettings)
        }
        .settingsExpansionAnimation(value: [enabled, permissions.accessibility, musicBlocker.monitoringFailed])
    }
}
