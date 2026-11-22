// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The Output segment of the Audio page: consolidates Volume Mixer and Output Priority & Switcher.
struct AudioOutputSettings: View {
    @AppStorage(DefaultsKey.volumeMixerEnabled) private var volumeMixerEnabled = true
    @AppStorage(DefaultsKey.mixerLowerVolumeOnHeadphonesDisconnect) private var lowerOnHeadphonesDisconnect = false
    @AppStorage(DefaultsKey.soundOutputSwitcherEnabled) private var outputSwitcherEnabled = false
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var priority = AudioPriorityService.shared

    /// The cards only: the Audio page shows them below its segmented control.
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MixerSection(settingsMode: true)
                .settingsSectionAnchor(.mixer, cornerRadius: 16)

            outputPriorityAndSwitcherCard
                .settingsSectionAnchor(.audioOutputPriority, cornerRadius: 16)
        }
        .settingsExpansionAnimation(value: [
            volumeMixerEnabled,
            priority.outputPriorityEnabled,
            outputSwitcherEnabled,
            lowerOnHeadphonesDisconnect
        ])
    }

    private var outputPriorityAndSwitcherCard: some View {
        SettingsCard(
            symbol: "line.horizontal.2.decrease.circle",
            title: l10n.s.manageAudioOutputPriorityTitle,
            headerAccessory: {
                Toggle(l10n.s.audioPriorityOutputEnable, isOn: Binding(
                    get: { priority.outputPriorityEnabled },
                    set: { priority.setOutputPriorityEnabled($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.regular)
                .accessibilityLabel(l10n.s.audioPriorityOutputEnable)
            }
        ) {
            if priority.outputPriorityEnabled {
                VStack(alignment: .leading, spacing: 14) {
                    AudioOutputPriorityControls(showsHeader: false)
                    Divider()
                    SoundOutputSwitcherControls()
                }
                .transition(.settingsReveal)
            }
        }
        .settingsExpansionAnimation(value: priority.outputPriorityEnabled)
    }
}
