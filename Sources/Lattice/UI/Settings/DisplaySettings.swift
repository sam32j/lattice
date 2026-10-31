// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Display settings: Display brightness, XDR extra brightness,
/// wallpaper management, Keep Awake (when focused), and Bluetooth behavior.
struct DisplaySettings: View {
    var focus: SettingsSectionAnchor?
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @AppStorage(DefaultsKey.bluetoothSleepEnabled) private var bluetoothSleepEnabled = false
    @AppStorage(DefaultsKey.bluetoothSleepRestoreOnWake) private var bluetoothSleepRestoreOnWake = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if focus == nil || focus == .keepAwake {
                    FeatureActivationSection(feature: .keepAwake) { EnergyKeepAwakeSettings() }
                }
                if focus == nil || focus == .brightness || focus == .extraBrightness || focus == .wallpaper {
                    EnergyDisplaySettings()
                        .settingsSectionAnchor(.brightness, cornerRadius: 16)
                    wallpaperCard
                        .settingsSectionAnchor(.wallpaper, cornerRadius: 16)
                }
                if focus == nil || focus == .bluetoothSleep {
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
        .settingsExpansionAnimation(value: bluetoothSleepEnabled)
    }

    private func refreshVisibleServices() {
        if (focus == nil || focus == .keepAwake), AppFeature.keepAwake.isAvailable {
            KeepAwakeManager.shared.refreshPasswordlessStatus()
        }
        if (focus == nil || focus == .brightness || focus == .wallpaper) {
            // Displays may have changed since launch (docked, clamshell).
            BrightnessService.shared.refresh()
        }
    }

    // MARK: - Wallpaper

    private var wallpaperInstalled: Bool {
        AppFeature.wallpaper.isAvailable
    }

    private var wallpaperCard: some View {
        let strings = FeatureStrings.wallpaper(l10n.language)
        return SettingsCard(title: strings.pageTitle) {
            SettingsRow(symbol: "rectangle.inset.filled.and.cursorarrow", title: strings.enableManagement,
                        caption: strings.hubDescription) {
                Toggle(strings.enableManagement, isOn: Binding(
                    get: { wallpaperInstalled },
                    set: { enabled in
                        FeatureRuntime.shared.setAvailable([.wallpaper], enabled)
                    }
                ))
                .labelsHidden()
            }
        }
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
                            FeatureRuntime.shared.finishAvailabilityChange()
                        }
                }
                if bluetoothSleepEnabled {
                    SettingsRow(symbol: "arrow.counterclockwise", title: strings.restoreToggle,
                                caption: strings.restoreCaption) {
                        Toggle(strings.restoreToggle, isOn: $bluetoothSleepRestoreOnWake).labelsHidden()
                            .onChange(of: bluetoothSleepRestoreOnWake) { _, _ in
                                BluetoothSleepService.shared.syncWithPreferences()
                                FeatureRuntime.shared.finishAvailabilityChange()
                            }
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
