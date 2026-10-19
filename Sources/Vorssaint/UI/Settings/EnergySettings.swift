// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The Energy page: Keep Awake with its live status and options, the
/// displays' brightness and power, extra brightness on XDR panels, and
/// Bluetooth on sleep. One card per feature, opened by a row that names it,
/// says what it is doing right now and switches it.
struct EnergySettings: View {
    var focus: SettingsSectionAnchor?
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var extraBrightness = ExtraBrightnessService.shared
    @AppStorage(DefaultsKey.extraBrightnessEnabled) private var extraBrightnessEnabled = false
    @AppStorage(DefaultsKey.extraBrightnessLevel) private var extraBrightnessLevel = 100
    @AppStorage(DefaultsKey.bluetoothSleepEnabled) private var bluetoothSleepEnabled = false
    @AppStorage(DefaultsKey.bluetoothSleepRestoreOnWake) private var bluetoothSleepRestoreOnWake = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(pageTitle).font(.title2.bold())
                    Text(pageDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if (focus == nil || focus == .keepAwake), AppFeature.keepAwake.isAvailable {
                    EnergyKeepAwakeSettings()
                }
                if (focus == nil || focus == .brightness), AppFeature.brightness.isAvailable {
                    EnergyDisplaySettings()
                        .settingsSectionAnchor(.brightness, cornerRadius: 16)
                }
                if (focus == nil || focus == .keyboardBrightnessShortcuts),
                   AppFeature.brightness.isAvailable, BrightnessService.keyboardLightIsSupported {
                    KeyboardLightSettings()
                        .settingsSectionAnchor(.keyboardBrightnessShortcuts, cornerRadius: 16)
                }
                if (focus == nil || focus == .extraBrightness), AppFeature.extraBrightness.isAvailable {
                    extraBrightnessCard
                        .settingsSectionAnchor(.extraBrightness, cornerRadius: 16)
                }
                if (focus == nil || focus == .wallpaper), AppFeature.wallpaper.isAvailable {
                    WallpaperSettings()
                        .settingsSectionAnchor(.wallpaper, cornerRadius: 16)
                }
                if (focus == nil || focus == .bluetoothSleep), AppFeature.bluetoothSleep.isAvailable {
                    bluetoothCard
                        .settingsSectionAnchor(.bluetoothSleep, cornerRadius: 16)
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        // Shared subviews draw plain toggles; outside a Form those would be
        // checkboxes, so the whole page asks for switches.
        .toggleStyle(.switch)
        .onAppear {
            refreshVisibleServices()
        }
        .onChange(of: focus) { _, _ in refreshVisibleServices() }
    }

    private func refreshVisibleServices() {
        if focus == nil || focus == .keepAwake {
            KeepAwakeManager.shared.refreshPasswordlessStatus()
        }
        if focus == nil || focus == .extraBrightness {
            ExtraBrightnessService.shared.syncWithPreferences()
        }
        if focus == nil || focus == .brightness || focus == .keyboardBrightnessShortcuts {
            // Displays may have changed since launch (docked, clamshell).
            BrightnessService.shared.refresh()
        }
    }

    private var pageTitle: String {
        switch focus {
        case .keepAwake: return l10n.s.keepAwakeTitle
        case .brightness: return FeatureStrings.brightness(l10n.language).pageTitle
        case .keyboardBrightnessShortcuts: return FeatureStrings.brightness(l10n.language).keyboardLight
        case .wallpaper: return FeatureStrings.wallpaper(l10n.language).pageTitle
        case .extraBrightness: return l10n.s.extraBrightnessName
        case .bluetoothSleep: return FeatureStrings.bluetoothSleep(l10n.language).pageTitle
        default: return l10n.s.tabEnergy
        }
    }

    private var pageDescription: String {
        switch focus {
        case .keepAwake: return FeatureStrings.hub(l10n.language).descKeepAwake
        case .brightness: return FeatureStrings.brightness(l10n.language).hubDescription
        case .keyboardBrightnessShortcuts: return l10n.s.shortcutsPageCaption
        case .wallpaper: return FeatureStrings.wallpaper(l10n.language).hubDescription
        case .extraBrightness: return FeatureStrings.hub(l10n.language).descExtraBrightness
        case .bluetoothSleep: return FeatureStrings.bluetoothSleep(l10n.language).hubDescription
        default: return FeatureStrings.settingsPages(l10n.language).energyDescription
        }
    }

    // MARK: - Extra brightness

    private var extraBrightnessCard: some View {
        SettingsCard {
            if extraBrightness.supported {
                SettingsRow(symbol: "sun.max.fill", title: l10n.s.extraBrightnessName,
                            caption: l10n.s.extraBrightnessCaption) {
                    Toggle(l10n.s.extraBrightnessName, isOn: $extraBrightnessEnabled)
                        .labelsHidden()
                        .onChange(of: extraBrightnessEnabled) { _, _ in
                            ExtraBrightnessService.shared.syncWithPreferences()
                        }
                }
                if extraBrightnessEnabled {
                    HStack(spacing: 12) {
                        Text(l10n.s.extraBrightnessLevelLabel)
                        Slider(value: extraBrightnessLevelBinding, in: 10...100, step: 5)
                        Text("\(extraBrightnessLevel)%")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 52, alignment: .trailing)
                    }
                    .padding(.leading, settingsRowTextInset)
                }
            } else {
                SettingsRow(symbol: "sun.max.fill", title: l10n.s.extraBrightnessName,
                            caption: l10n.s.extraBrightnessUnsupported) {
                    EmptyView()
                }
            }
        }
    }

    private var extraBrightnessLevelBinding: Binding<Double> {
        Binding(get: { Double(extraBrightnessLevel) },
                set: { newValue in
                    extraBrightnessLevel = Int(newValue)
                    ExtraBrightnessService.shared.levelDidChange()
                })
    }

    // MARK: - Bluetooth on sleep

    private var bluetoothCard: some View {
        let strings = FeatureStrings.bluetoothSleep(l10n.language)
        return SettingsCard {
            if BluetoothSleepService.isSupported {
                SettingsRow(symbol: "dot.radiowaves.left.and.right", title: strings.enable,
                            caption: strings.enableCaption) {
                    Toggle(strings.enable, isOn: $bluetoothSleepEnabled)
                        .labelsHidden()
                        .onChange(of: bluetoothSleepEnabled) { _, _ in
                            BluetoothSleepService.shared.syncWithPreferences()
                        }
                }
                if bluetoothSleepEnabled {
                    SettingsRow(symbol: "arrow.counterclockwise", title: strings.restoreToggle,
                                caption: strings.restoreCaption) {
                        Toggle(strings.restoreToggle, isOn: $bluetoothSleepRestoreOnWake).labelsHidden()
                    }
                }
            } else {
                SettingsRow(symbol: "dot.radiowaves.left.and.right", title: strings.pageTitle,
                            caption: strings.unsupported) {
                    EmptyView()
                }
            }
        }
    }

}
