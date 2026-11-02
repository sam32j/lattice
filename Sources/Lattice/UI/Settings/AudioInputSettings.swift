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
        .settingsExpansionAnimation(value: [microphoneControlEnabled, priority.inputPriorityEnabled])
    }

    private var microphoneCard: some View {
        SettingsCard(symbol: "mic", title: l10n.s.microphoneControlEnable, headerAccessory: {
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
            if microphoneControlEnabled {
                VStack(alignment: .leading, spacing: 14) {
                    AudioInputDeviceControls(title: l10n.s.mixerInputSourceLabel,
                                             levelTitle: SettingsOwnershipStrings.audioInput(l10n.language).level,
                                             sliderWidth: 140,
                                             showsUnavailableLabel: false,
                                             showsIcons: false)

                    HStack(alignment: .center) {
                        Text(l10n.s.micMuteName)
                            .font(.body)
                        Spacer(minLength: 12)
                        muteStateButton
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        ShortcutPreferenceRow(role: .micMute, alignment: .center) {
                            MicMuteService.shared.syncWithPreferences()
                        }
                        if micShortcutEnabled, micMute.shortcutRegistrationFailed {
                            Text(l10n.s.shortcutUnavailable)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    SettingsToggleRow(title: l10n.s.micMuteMenuBarToggle, isOn: $micMenuBarIndicator)
                }
                .padding(.leading, settingsRowTextInset)
            }
        }
    }

    @ViewBuilder
    private var muteStateButton: some View {
        if micMute.isMuted {
            Button {
                micMute.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "mic.slash")
                    Text(SettingsOwnershipStrings.audioInput(l10n.language).muted)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .foregroundStyle(.white)
            .frame(width: 140)
        } else {
            Button {
                micMute.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "mic")
                    Text(SettingsOwnershipStrings.audioInput(l10n.language).unmuted)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .frame(width: 140)
        }
    }

    private var inputPriorityCard: some View {
        SettingsCard(symbol: "line.horizontal.2.decrease.circle", title: l10n.s.manageAudioInputPriorityTitle, headerAccessory: {
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
            if priority.inputPriorityEnabled {
                AudioInputPriorityControls(showsHeader: false)
            }
        }
        .onAppear {
            AudioInputDeviceManager.shared.syncWithPreferences()
            MicMuteService.shared.syncWithPreferences()
            AudioPriorityService.shared.syncWithPreferences()
        }
    }
}
