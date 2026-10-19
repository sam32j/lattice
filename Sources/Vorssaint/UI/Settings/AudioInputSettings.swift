// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Audio Input settings: consolidates microphone mute controls and audio input device priority.
struct AudioInputSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared

    private var pageStrings: SettingsPageStrings { FeatureStrings.settingsPages(l10n.language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(pageStrings.audioInputTitle).font(.title2.bold())
                    Text(pageStrings.audioInputDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if AppFeature.micMute.isAvailable {
                    AudioInputMuteCard()
                        .settingsSectionAnchor(.micMute, cornerRadius: 16)
                }
                if AppFeature.audioPriority.isAvailable {
                    SettingsCard(title: l10n.s.audioPrioritySection) {
                        AudioPriorityDisclosure(initiallyExpanded: true, showsHeader: false)
                    }
                    .settingsSectionAnchor(.audioPriority, cornerRadius: 16)
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
    }
}

private struct AudioInputMuteCard: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var micMute = MicMuteService.shared
    @AppStorage(DefaultsKey.micMuteShortcutEnabled) private var micShortcutEnabled = false
    @AppStorage(DefaultsKey.micMuteMenuBarIndicator) private var micMenuBarIndicator = false

    var body: some View {
        SettingsCard(title: l10n.s.micMuteName) {
            Button {
                MicMuteService.shared.toggle()
            } label: {
                Label(micMute.isMuted ? l10n.s.micUnmuteName : l10n.s.micMuteName,
                      systemImage: micMute.isMuted ? "mic.slash.fill" : "mic")
            }
            if micMute.isMuted {
                Label(l10n.s.micMutedHUD, systemImage: "mic.slash.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Text(l10n.s.micMuteCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle(l10n.s.micMuteMenuBarToggle, isOn: $micMenuBarIndicator)
            Text(l10n.s.micMuteMenuBarCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
            ShortcutPreferenceRow(role: .micMute) {
                MicMuteService.shared.syncWithPreferences()
            }
            if micShortcutEnabled, micMute.shortcutRegistrationFailed {
                Text(l10n.s.shortcutUnavailable)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}
