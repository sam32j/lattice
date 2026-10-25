// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import SwiftUI

struct GeneralSoundSettings: View {
    @ObservedObject private var l10n = L10n.shared
    // Preserve the existing stored choice while moving ownership out of the island.
    @AppStorage(DefaultsKey.notchLockSounds) private var enabled = false

    var body: some View {
        SettingsCard(title: FeatureStrings.hub(l10n.language).groupSound) {
            SettingsRow(symbol: "speaker.wave.2", title: SettingsFollowupLabels.text(.lockSound, l10n.language), caption: title) {
                Toggle(title, isOn: $enabled).labelsHidden()
                    .onChange(of: enabled) { _, _ in LockSoundService.shared.syncWithPreferences() }
            }
        }
        .toggleStyle(.switch)
    }

    private var title: String {
        GeneralSoundCopy.label(l10n.language)
    }
}
