// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The Input segment of the Audio page: consolidates microphone level control, mute shortcut, and microphone device priority.
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
    @AppStorage(DefaultsKey.micMuteFollowCallApps)
    private var micFollowCallApps = false

    /// The cards only: the Audio page shows them below its segmented control.
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            microphoneCard
                .settingsSectionAnchor(.micMute, cornerRadius: 16)

            inputPriorityCard
                .settingsSectionAnchor(.audioPriority, cornerRadius: 16)
        }
        .settingsExpansionAnimation(value: [microphoneControlEnabled, priority.inputPriorityEnabled])
    }

    private var microphoneCard: some View {
        SettingsCard(symbol: "mic", title: l10n.s.microphoneControlEnable, headerAccessory: {
            Toggle(l10n.s.microphoneControlEnable, isOn: $microphoneControlEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.regular)
                .accessibilityLabel(l10n.s.microphoneControlEnable)
                .onChange(of: microphoneControlEnabled) { _, enabled in
                    settingsApplyFeatureSwitch(enabled: enabled) {
                        let enabled = UserDefaults.standard.bool(forKey: DefaultsKey.microphoneLevelControlEnabled)
                        FeatureRuntime.shared.setAvailable([.micMute], enabled)
                        AudioInputDeviceManager.shared.syncWithPreferences()
                        MicMuteService.shared.syncWithPreferences()
                    }
                }
        }) {
            if microphoneControlEnabled {
                VStack(alignment: .leading, spacing: 14) {
                    AudioInputDeviceControls(title: l10n.s.mixerInputSourceLabel,
                                             levelTitle: SettingsOwnershipStrings.audioInput(l10n.language).level,
                                             sliderWidth: 140,
                                             showsUnavailableLabel: false,
                                             showsIcons: false)

                    VStack(alignment: .leading, spacing: 4) {
                        ShortcutPreferenceRow(role: .micMute, alignment: .center) {
                            MicMuteService.shared.syncWithPreferences()
                        }
                        if micShortcutEnabled, micMute.shortcutRegistrationFailed {
                            Text(l10n.s.shortcutUnavailable)
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .transition(.settingsReveal)
                        }
                    }

                    SettingsToggleRow(title: l10n.s.micMuteMenuBarToggle, isOn: $micMenuBarIndicator)

                    SettingsToggleRow(title: l10n.s.micMuteFollowCallAppsToggle,
                                      caption: l10n.s.micMuteFollowCallAppsCaption,
                                      isOn: $micFollowCallApps)
                        .onChange(of: micFollowCallApps) { _, _ in
                            MicMuteService.shared.syncWithPreferences()
                        }
                }
                .padding(.leading, settingsRowTextInset)
                .transition(.settingsReveal)
            }
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
