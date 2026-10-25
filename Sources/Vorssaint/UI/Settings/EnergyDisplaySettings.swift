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
    @AppStorage(DefaultsKey.brightnessKeyStep)
    private var brightnessKeyStep = BrightnessSupport.KeyStep.standard.rawValue

    // MARK: - Displays

    var body: some View {
        let strings = FeatureStrings.brightness(l10n.language)
        return VStack(alignment: .leading, spacing: 20) {
            SettingsCard(title: SettingsOrganizationStrings.text(.appearance, l10n.language)) {
                SettingsRow(symbol: "moon.fill", title: SettingsOrganizationStrings.text(.darkMode, l10n.language)) {
                    Toggle(SettingsOrganizationStrings.text(.darkMode, l10n.language),
                           isOn: Binding(get: {
                        toggles.systemAppearanceIsDark ?? (colorScheme == .dark)
                    }, set: { desired in
                        if desired != (toggles.systemAppearanceIsDark ?? (colorScheme == .dark)) {
                            toggles.toggleDarkMode()
                        }
                    }))
                    .labelsHidden()
                }
            }
            SettingsCard(title: SettingsOrganizationStrings.text(.displayControls, l10n.language)) {
                SettingsRow(symbol: "display.2", title: strings.enable, caption: strings.enableCaption) {
                    Toggle(strings.enable, isOn: $brightnessEnabled)
                        .labelsHidden()
                        .onChange(of: brightnessEnabled) { _, _ in
                            BrightnessService.shared.syncWithPreferences()
                            FeatureRuntime.shared.finishAvailabilityChange()
                        }
                }
                Group {
                    if !brightnessEnabled && brightness.displays.isEmpty {
                        ForEach(NSScreen.screens, id: \.self) { display in
                            SettingsControlRow(title: display.localizedName) {
                                Text(SettingsContentStrings.status(enabled: false, language: l10n.language))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading, settingsRowTextInset)
                        }
                    } else if brightness.displays.isEmpty {
                        Text(strings.noDisplays).font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(brightness.displays) { display in displayRow(display) }
                    }
                    if let failure = brightness.displayControlFailure {
                        Text(displayControlFailureText(failure, strings: strings))
                            .font(.caption).foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Divider()
                    SettingsRow(symbol: "cursorarrow.rays", title: strings.keysToggle, caption: strings.keysCaption) {
                        PermissionGatedToggle(strings.keysToggle, isOn: $brightnessKeysEnabled)
                            .labelsHidden()
                            .onChange(of: brightnessKeysEnabled) { _, isOn in
                                if isOn { Permissions.shared.requestAccessibility() }
                                BrightnessService.shared.syncWithPreferences()
                            }
                    }
                    SettingsRow(symbol: "sun.min", title: strings.keyStep, caption: strings.keyStepCaption) {
                        PermissionGatedPicker(title: strings.keyStep, selection: brightnessKeyStepBinding,
                                              requiring: { $0 == .standard ? [] : [.accessibility] }) {
                            Text(strings.keyStepStandard).tag(BrightnessSupport.KeyStep.standard)
                            Text(strings.keyStepHalf).tag(BrightnessSupport.KeyStep.half)
                            Text(strings.keyStepQuarter).tag(BrightnessSupport.KeyStep.quarter)
                        }
                        .pickerStyle(.menu).labelsHidden()
                    }
                    DisplayBrightnessShortcutControls(showsSettingsRow: true)
                    if brightnessKeysEnabled
                        || BrightnessSupport.KeyStep.sanitized(brightnessKeyStep) != .standard,
                       !permissions.accessibility {
                        PermissionRow(kind: .accessibility)
                    }
                    DisplayExtraBrightnessSettings()
                }
                .disabled(!brightnessEnabled || !AppFeature.brightness.isAvailable)
                .opacity(brightnessEnabled && AppFeature.brightness.isAvailable ? 1 : 0.5)
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
            BrightnessService.shared.syncWithPreferences()
        }
    }

    private func displayRow(_ display: BrightnessDisplay) -> some View {
        HStack(spacing: 12) {
            Text(display.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 80, alignment: .leading)
            if display.isActive, display.method != nil {
                Spacer(minLength: 12)
                SettingsValueSlider(title: display.name, value: Binding(get: { display.brightness },
                                                  set: { BrightnessService.shared.setBrightness($0, for: display.id) }),
                                    range: 0...1, step: 0.01,
                                    readout: "\(Int((display.brightness * 100).rounded()))%")
                    .frame(width: 220)
                    .disabled(brightness.isDisplayPending(display.id))
                    .accessibilityLabel(display.name)
            } else {
                Spacer()
                if !display.isActive {
                    Text(FeatureStrings.brightness(l10n.language).displayOff)
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .trailing)
                }
            }
            SoftwareDimmingButton(display: display)
        }
        .padding(.leading, settingsRowTextInset)
    }

}
