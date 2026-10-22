// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Audio Input settings: consolidates microphone level control, mute shortcut, and microphone device priority.
struct AudioInputSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var micMute = MicMuteService.shared
    @ObservedObject private var priority = AudioPriorityService.shared
    @AppStorage(DefaultsKey.microphoneLevelControlEnabled)
    private var microphoneControlEnabled = true
    @AppStorage(DefaultsKey.micMuteShortcutEnabled)
    private var micShortcutEnabled = false
    @AppStorage(DefaultsKey.micMuteMenuBarIndicator)
    private var micMenuBarIndicator = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                microphoneCard
                    .settingsSectionAnchor(.micMute, cornerRadius: 16)

                inputPriorityCard
                    .settingsSectionAnchor(.audioPriority, cornerRadius: 16)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
    }

    private var microphoneCard: some View {
        SettingsCard(title: l10n.s.microphoneControlEnable, headerAccessory: {
            Toggle(l10n.s.microphoneControlEnable, isOn: $microphoneControlEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.regular)
                .help(l10n.s.microphoneControlEnable)
                .accessibilityLabel(l10n.s.microphoneControlEnable)
                .onChange(of: microphoneControlEnabled) { _, enabled in
                    FeatureRuntime.shared.setAvailable([.micMute], enabled)
                    AudioInputDeviceManager.shared.syncWithPreferences()
                    MicMuteService.shared.syncWithPreferences()
                }
        }) {
            VStack(alignment: .leading, spacing: 14) {
                AudioInputDeviceControls(title: l10n.s.mixerInputSourceLabel)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text(l10n.s.muteAudioInputSubtitle)
                        .font(.subheadline.weight(.semibold))

                    ShortcutPreferenceRow(role: .micMute) {
                        MicMuteService.shared.syncWithPreferences()
                    }
                    if micShortcutEnabled, micMute.shortcutRegistrationFailed {
                        Text(l10n.s.shortcutUnavailable)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    SettingsToggleRow(title: l10n.s.showInMenuBarLabel, isOn: $micMenuBarIndicator)
                }
            }
            .disabled(!microphoneControlEnabled)
            .opacity(microphoneControlEnabled ? 1 : 0.55)
        }
    }

    private var inputPriorityCard: some View {
        SettingsCard(title: l10n.s.manageAudioInputPriorityTitle, headerAccessory: {
            Toggle(l10n.s.audioPriorityInputEnable, isOn: Binding(
                get: { priority.inputPriorityEnabled },
                set: { priority.setInputPriorityEnabled($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.regular)
            .help(l10n.s.audioPriorityInputEnable)
            .accessibilityLabel(l10n.s.audioPriorityInputEnable)
        }) {
            AudioInputPriorityControls(showsHeader: false)
                .disabled(!priority.inputPriorityEnabled)
                .opacity(priority.inputPriorityEnabled ? 1 : 0.55)
        }
    }
}
