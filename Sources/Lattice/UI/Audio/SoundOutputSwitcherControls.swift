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
                                  label: "Cycle through with shortcut",
                                  help: l10n.s.soundOutputSwitcherCaption,
                                  additionalConflict: WindowLayoutService.shared.shortcutConflictTitle) {
                outputSwitcher.syncWithPreferences()
            }

            VStack(alignment: .leading, spacing: 4) {
                if outputSwitcher.registrationFailed {
                    inputMessage(l10n.s.shortcutUnavailable, systemImage: "keyboard.badge.ellipsis")
                }
                if outputSwitcher.lastSwitchFailed {
                    inputMessage(l10n.s.soundOutputSwitcherNoAvailableSelection,
                                 systemImage: "speaker.badge.exclamationmark")
                }
            }
            .settingsCollapsible(isExpanded: enabled)
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
