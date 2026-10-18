// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct DisplayBrightnessShortcutControls: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var brightness = BrightnessService.shared
    @AppStorage(DefaultsKey.displayBrightnessShortcutsEnabled) private var enabled = false
    var showsShortcutRows = true
    var showsSettingsRow = false

    var body: some View {
        if showsShortcutRows {
            ForEach([GlobalShortcutRole.displayBrightnessDecrease, .displayBrightnessIncrease]) { role in
                ShortcutPreferenceRow(role: role, isEnabled: enabled, label: role.title(l10n.s),
                                      includeInactiveConflicts: true,
                                      additionalConflict: { shortcut in
                    guard AppFeature.windowLayout.isAvailable else { return nil }
                    return WindowLayoutService.shared.shortcutConflictTitle(shortcut, excluding: nil)
                }) {
                    brightness.syncWithPreferences()
                }
                .padding(.leading, showsSettingsRow ? settingsRowTextInset : 0)
            }
        }
        if enabled, brightness.displayBrightnessShortcutRegistrationFailed {
            Text(l10n.s.shortcutUnavailable)
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.leading, showsSettingsRow ? settingsRowTextInset : 0)
        }
    }
}
