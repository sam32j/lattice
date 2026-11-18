import SwiftUI

extension MouseSettings {
    // MARK: - Scrolling

    var scrollControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsControlRow(title: l10n.s.invertVerticalScroll,
                               caption: l10n.s.scrollTrackpadNote) {
                PermissionGatedToggle(l10n.s.invertVerticalScroll, isOn: $invertVertical)
                    .labelsHidden()
                    .onChange(of: invertVertical) { _, _ in
                        ScrollInverter.shared.syncWithPreferences()
                        if scrollDirectionEnabled { permissions.requestAccessibility() }
                    }
            }
            Divider()
            // The inverter only turns mouse-wheel events (ScrollWheelSupport.isMouseWheel);
            // trackpad gestures pass through untouched, as the caption says.
            SettingsControlRow(title: l10n.s.invertHorizontalScroll,
                               caption: l10n.s.scrollTrackpadNote) {
                PermissionGatedToggle(l10n.s.invertHorizontalScroll, isOn: $invertHorizontal)
                    .labelsHidden()
                    .onChange(of: invertHorizontal) { _, _ in
                        ScrollInverter.shared.syncWithPreferences()
                        if scrollDirectionEnabled { permissions.requestAccessibility() }
                    }
            }
            Divider()
            SettingsControlRow(title: l10n.s.scrollHorizontalName,
                               caption: l10n.s.scrollHorizontalCaption) {
                PermissionGatedToggle(l10n.s.scrollHorizontalName, isOn: $horizontalScrollEnabled)
                    .labelsHidden()
                    .onChange(of: horizontalScrollEnabled) { _, _ in
                        ScrollInverter.shared.syncWithPreferences()
                        if scrollDirectionEnabled { permissions.requestAccessibility() }
                    }
            }
            if horizontalScrollEnabled {
                modifierKeys
            }
        }
    }

    /// Follow-up controls share the trailing control column.
    var modifierKeys: some View {
        let modifierStrings = FeatureStrings.quitProtection(l10n.language)
        let choices: [(ScrollHorizontalModifier, String, String)] = [
            (.shift, "⇧", modifierStrings.shiftKey),
            (.option, "⌥", modifierStrings.optionKey),
            (.control, "⌃", modifierStrings.controlKey),
            (.command, "⌘", l10n.s.scrollHorizontalCommandKey),
        ]
        return SettingsControlRow(title: l10n.s.scrollHorizontalModifierLabel) {
            Picker(l10n.s.scrollHorizontalModifierLabel, selection: $horizontalScrollModifier) {
                ForEach(choices, id: \.0) { modifier, glyph, name in
                    Text("\(glyph) \(name)").tag(modifier)
                }
            }
            .labelsHidden().pickerStyle(.menu)
            .frame(width: 220, alignment: .trailing)
        }
    }

    // MARK: - Smooth scrolling

    var smoothScrollControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsControlRow(title: l10n.s.smoothScrollName, caption: l10n.s.smoothScrollCaption) {
                PermissionGatedToggle(l10n.s.smoothScrollName, isOn: $smoothScrollEnabled)
                    .labelsHidden()
                    .onChange(of: smoothScrollEnabled) { _, enabled in
                        SmoothScrollService.shared.syncWithPreferences()
                        if enabled { permissions.requestAccessibility() }
                    }
            }
            if smoothScrollEnabled {
                let presets = InputSettingsStrings.scrollPresets(l10n.language)
                VStack(alignment: .leading, spacing: 10) {
                    presetRow(l10n.s.smoothScrollStepLabel, value: $smoothScrollStep,
                              stops: SmoothScrollSupport.stepPresets,
                              names: [presets.slow, presets.normal, presets.fast, presets.faster],
                              sanitize: SmoothScrollSupport.sanitizedStep)
                    presetRow(l10n.s.smoothScrollResponseLabel, caption: presets.responseCaption,
                              value: $smoothScrollResponse,
                              stops: SmoothScrollSupport.responsePresets,
                              names: [presets.snappy, presets.balanced, presets.silky],
                              sanitize: SmoothScrollSupport.sanitizedResponse)
                    presetRow(l10n.s.smoothScrollCoastLabel, caption: presets.coastCaption,
                              value: $smoothScrollCoast,
                              stops: SmoothScrollSupport.coastPresets,
                              names: [presets.none, presets.short, presets.medium, presets.long],
                              sanitize: SmoothScrollSupport.sanitizedCoast)
                }
            }
        }
    }

    /// A named stop for each preference. A value saved by the old sliders
    /// shows as its nearest stop and stays as saved until one is picked.
    func presetRow(_ title: String, caption: String? = nil, value: Binding<Int>, stops: [Int],
                   names: [String], sanitize: @escaping (Int) -> Int) -> some View {
        SettingsControlRow(title: title, caption: caption) {
            Picker(title, selection: Binding(
                get: { SmoothScrollSupport.nearestPreset(sanitize(value.wrappedValue), in: stops) },
                set: { value.wrappedValue = $0 })) {
                ForEach(Array(zip(stops, names)), id: \.0) { stop, name in
                    Text(name).tag(stop)
                }
            }
            .labelsHidden().pickerStyle(.menu)
            // One width for the three, so their edges line up.
            .frame(width: 130, alignment: .trailing)
        }
    }

    // MARK: - Linear scrolling

    var linearScrollControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsControlRow(title: l10n.s.linearScrollName,
                               caption: l10n.s.linearScrollCaption) {
                PermissionGatedToggle(l10n.s.linearScrollName, isOn: $linearScrollEnabled)
                    .labelsHidden()
                    .onChange(of: linearScrollEnabled) { _, enabled in
                        ScrollInverter.shared.syncWithPreferences()
                        if enabled { permissions.requestAccessibility() }
                    }
            }
            if linearScrollEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    Stepper(value: Binding(
                                get: { ScrollWheelSupport.sanitizedLinesPerNotch(linearScrollLines) },
                                set: { linearScrollLines = $0 }),
                            in: ScrollWheelSupport.linesPerNotchRange, step: 1) {
                        HStack {
                            Text(l10n.s.linearScrollLinesLabel)
                            Spacer()
                            Text("\(ScrollWheelSupport.sanitizedLinesPerNotch(linearScrollLines))")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }
}
