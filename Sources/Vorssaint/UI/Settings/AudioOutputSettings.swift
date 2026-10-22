// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Audio Output settings: consolidates Volume Mixer, Output Priority & Switcher, and Music App Blocker.
struct AudioOutputSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var priority = AudioPriorityService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MixerSection(settingsMode: true)
                    .settingsSectionAnchor(.mixer, cornerRadius: 16)

                outputPriorityAndSwitcherCard
                    .settingsSectionAnchor(.audioOutputPriority, cornerRadius: 16)

                MusicBlockingSettings()
                    .settingsSectionAnchor(.musicBlocking, cornerRadius: 16)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
    }

    private var outputPriorityAndSwitcherCard: some View {
        SettingsCard(title: l10n.s.manageAudioOutputPriorityTitle, headerAccessory: {
            Toggle(l10n.s.audioPriorityOutputEnable, isOn: Binding(
                get: { priority.outputPriorityEnabled },
                set: { priority.setOutputPriorityEnabled($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.regular)
            .help(l10n.s.audioPriorityOutputEnable)
            .accessibilityLabel(l10n.s.audioPriorityOutputEnable)
        }) {
            VStack(alignment: .leading, spacing: 14) {
                AudioOutputPriorityControls(showsHeader: false)
                Divider()
                SoundOutputSwitcherControls()
            }
            .disabled(!priority.outputPriorityEnabled)
            .opacity(priority.outputPriorityEnabled ? 1 : 0.55)
        }
    }
}
