// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The same output-switcher preferences in the menu panel and Settings.
struct SoundOutputSwitcherControls: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var outputSwitcher = SoundOutputSwitcher.shared
    @AppStorage(DefaultsKey.soundOutputSwitcherEnabled)
    private var enabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ShortcutPreferenceRow(role: .soundOutputSwitcher,
                                  label: l10n.s.soundOutputSwitcherEnable,
                                  help: l10n.s.soundOutputSwitcherCaption,
                                  additionalConflict: WindowLayoutService.shared.shortcutConflictTitle) {
                outputSwitcher.syncWithPreferences()
            }

            if outputSwitcher.registrationFailed, enabled {
                inputMessage(l10n.s.shortcutUnavailable, systemImage: "keyboard.badge.ellipsis")
                    .transition(.settingsReveal)
            }
        }
    }

    private func inputMessage(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 9.5))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}
