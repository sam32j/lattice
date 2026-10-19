// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct KeyboardLightSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var brightness = BrightnessService.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.keyboardBrightnessShortcutsEnabled) private var enabled = false

    var body: some View {
        SettingsCard(title: FeatureStrings.brightness(l10n.language).keyboardLight) {
            if brightness.keyboardLightEnabled != nil {
                Toggle(FeatureStrings.brightness(l10n.language).keyboardLight,
                       isOn: Binding(
                        get: { brightness.keyboardLightEnabled ?? false },
                        set: { brightness.setKeyboardLightEnabled($0) }
                       ))
                HStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { Double(brightness.keyboardLightLevel ?? 0) },
                        set: { brightness.setKeyboardLightLevel(Float($0)) }
                    ), in: 0...1, onEditingChanged: brightness.keyboardLightDragChanged)
                    .accessibilityLabel(FeatureStrings.brightness(l10n.language).keyboardLight)
                    Text("\(Int(((brightness.keyboardLightLevel ?? 0) * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .trailing)
                }
                Divider()
            }
            ForEach([GlobalShortcutRole.keyboardBrightnessDecrease, .keyboardBrightnessIncrease]) { role in
                ShortcutPreferenceRow(role: role, label: role.title(l10n.s),
                                      includeInactiveConflicts: true,
                                      additionalConflict: { shortcut in
                    guard AppFeature.windowLayout.isAvailable else { return nil }
                    return WindowLayoutService.shared.shortcutConflictTitle(shortcut, excluding: nil)
                }) {
                    brightness.syncWithPreferences()
                }
            }
            if enabled, brightness.keyboardBrightnessShortcutRegistrationFailed {
                Text(l10n.s.shortcutUnavailable)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if enabled, !permissions.accessibility {
                PermissionRow(kind: .accessibility)
            }
        }
        .onAppear { brightness.refreshKeyboardLight() }
    }
}
