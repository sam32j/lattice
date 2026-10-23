// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct KeyboardLightSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var brightness = BrightnessService.shared
    @AppStorage(DefaultsKey.keyboardBrightnessShortcutsEnabled) private var enabled = false

    var body: some View {
        let strings = FeatureStrings.brightness(l10n.language)
        SettingsCard(title: strings.keyboardLight, headerAccessory: {
            if brightness.keyboardLightEnabled != nil {
                Toggle(strings.keyboardLight,
                       isOn: Binding(
                        get: { brightness.keyboardLightEnabled ?? false },
                        set: { brightness.setKeyboardLightEnabled($0) }
                       ))
                .labelsHidden()
            }
        }) {
            VStack(alignment: .leading, spacing: 14) {
                Text(strings.keyboardLightCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if brightness.keyboardLightEnabled != nil {
                    keyboardLightSlider

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
            }
        }
        .onAppear { brightness.refreshKeyboardLight() }
    }

    var keyboardLightSlider: some View {
        let strings = FeatureStrings.brightness(l10n.language)
        return SettingsSliderRow(title: strings.keyboardLight, value: Binding(
            get: { Double(brightness.keyboardLightLevel ?? 0) },
            set: { brightness.setKeyboardLightLevel(Float($0)) }
        ), range: 0...1,
            readout: "\(Int(((brightness.keyboardLightLevel ?? 0) * 100).rounded()))%",
            onEditingChanged: brightness.keyboardLightDragChanged)
    }
}
