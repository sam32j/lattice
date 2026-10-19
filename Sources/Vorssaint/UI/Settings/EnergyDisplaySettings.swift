// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct EnergyDisplaySettings: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var brightness = BrightnessService.shared
    @ObservedObject private var toggles = QuickTogglesService.shared
    @AppStorage(DefaultsKey.brightnessControlEnabled) private var brightnessEnabled = false
    @AppStorage(DefaultsKey.brightnessKeysEnabled) private var brightnessKeysEnabled = false
    @AppStorage(DefaultsKey.brightnessOSDEnabled) private var brightnessOSDEnabled = false
    @AppStorage(DefaultsKey.brightnessKeyStep)
    private var brightnessKeyStep = BrightnessSupport.KeyStep.standard.rawValue
    @State private var brightnessOptionsExpanded = false

    // MARK: - Displays

    var body: some View {
        let strings = FeatureStrings.brightness(l10n.language)
        return SettingsCard {
            if AppFeature.quickToggles.isAvailable {
                let appearance = FeatureStrings.quickToggles(l10n.language)
                let isDark = toggles.systemAppearanceIsDark ?? (colorScheme == .dark)
                Button {
                    toggles.toggleDarkMode()
                } label: {
                    Label(isDark ? appearance.darkModeToLight : appearance.darkModeToDark,
                          systemImage: isDark ? "sun.max.fill" : "moon.fill")
                }
                Divider()
            }
            SettingsRow(symbol: "display.2", title: strings.enable, caption: strings.enableCaption) {
                Toggle(strings.enable, isOn: $brightnessEnabled)
                    .labelsHidden()
                    .onChange(of: brightnessEnabled) { _, _ in
                        BrightnessService.shared.syncWithPreferences()
                    }
            }
            if brightnessEnabled {
                Divider()
                if brightness.displays.isEmpty {
                    Text(strings.noDisplays)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(brightness.displays) { display in
                        displayRow(display)
                    }
                }
                if let failure = brightness.displayControlFailure {
                    Text(displayControlFailureText(failure, strings: strings))
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                DisclosureGroup(isExpanded: $brightnessOptionsExpanded) {
                    VStack(alignment: .leading, spacing: 13) {
                        SettingsRow(symbol: "cursorarrow.rays", title: strings.keysToggle,
                                    caption: strings.keysCaption) {
                            Toggle(strings.keysToggle, isOn: $brightnessKeysEnabled)
                                .labelsHidden()
                                .onChange(of: brightnessKeysEnabled) { _, isOn in
                                    if isOn { Permissions.shared.requestAccessibility() }
                                    BrightnessService.shared.syncWithPreferences()
                                }
                        }
                        SettingsRow(symbol: "sun.min", title: strings.keyStep, caption: strings.keyStepCaption) {
                            Picker(strings.keyStep, selection: brightnessKeyStepBinding) {
                                Text(strings.keyStepStandard).tag(BrightnessSupport.KeyStep.standard)
                                Text(strings.keyStepHalf).tag(BrightnessSupport.KeyStep.half)
                                Text(strings.keyStepQuarter).tag(BrightnessSupport.KeyStep.quarter)
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                        DisplayBrightnessShortcutControls(showsSettingsRow: true)
                        if brightness.brightnessOSDSupported {
                            SettingsRow(symbol: "sun.max", title: strings.osdToggle, caption: strings.osdCaption) {
                                Toggle(strings.osdToggle, isOn: $brightnessOSDEnabled)
                                    .labelsHidden()
                                    .onChange(of: brightnessOSDEnabled) { _, isOn in
                                        if isOn { Permissions.shared.requestAccessibility() }
                                        BrightnessService.shared.syncWithPreferences()
                                    }
                            }
                        }
                        if brightnessKeysEnabled || brightnessOSDEnabled
                            || BrightnessSupport.KeyStep.sanitized(brightnessKeyStep) != .standard,
                           !permissions.accessibility {
                            PermissionRow(kind: .accessibility)
                        }
                        Text(strings.externalCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 10)
                } label: {
                    Text(FeatureStrings.recorder(l10n.language).moreOptions)
                        .font(.subheadline.weight(.medium))
                }
            }
        }
    }

    /// A finer step answers the keys in place of the system, which takes the
    /// same permission as the other key options.
    private var brightnessKeyStepBinding: Binding<BrightnessSupport.KeyStep> {
        Binding {
            BrightnessSupport.KeyStep.sanitized(brightnessKeyStep)
        } set: { step in
            brightnessKeyStep = step.rawValue
            if step != .standard { Permissions.shared.requestAccessibility() }
            BrightnessService.shared.syncWithPreferences()
        }
    }

    private func displayRow(_ display: BrightnessDisplay) -> some View {
        HStack(spacing: 12) {
            Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(display.isActive ? Color.accentColor : Color.secondary)
                .frame(width: 26, height: 26)
                .background((display.isActive ? Color.accentColor : Color.secondary).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(display.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 80, alignment: .leading)
            if display.isActive, display.method != nil {
                Slider(value: Binding(get: { display.brightness },
                                      set: { BrightnessService.shared.setBrightness(
                                          $0, for: display.id,
                                          showOSD: brightnessOSDEnabled) }),
                       in: 0...1)
                    .disabled(brightness.isDisplayPending(display.id))
                    .accessibilityLabel(display.name)
                Text("\(Int((display.brightness * 100).rounded()))%")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
            } else {
                Spacer()
                if !display.isActive {
                    Text(FeatureStrings.brightness(l10n.language).displayOff)
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .trailing)
                }
            }
            SoftwareDimmingButton(display: display)
            DisplayPowerButton(display: display)
        }
    }

}
