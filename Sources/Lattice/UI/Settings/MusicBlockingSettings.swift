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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsControlRow(
                title: l10n.s.musicBlockSection,
                caption: l10n.s.musicBlockCaption
            ) {
                PermissionGatedToggle(l10n.s.musicBlockTitle, isOn: $enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.regular)
                    .accessibilityLabel(l10n.s.musicBlockTitle)
                    .onChange(of: enabled) { _, enabled in
                        FeatureRuntime.shared.setAvailable([.musicBlock], enabled)
                        musicBlocker.syncWithPreferences()
                        if enabled, !permissions.accessibility {
                            permissions.requestAccessibility()
                        }
                    }
            }
            if enabled, musicBlocker.monitoringFailed {
                Text(l10n.s.musicBlockUnavailable)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
