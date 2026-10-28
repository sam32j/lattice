// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import SwiftUI

/// Page-owned installation, shortcut and presentation destination.
struct DedicatedUtilitySettings: View {
    let feature: AppFeature
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @Environment(\.settingsPermissionAccess) private var access
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage private var enabled: Bool
    @AppStorage(DefaultsKey.notchEnabled) private var islandEnabled = false
    @AppStorage(DefaultsKey.notchQuickPanel) private var launcherIslandRoute = true
    @AppStorage(DefaultsKey.quickLauncherShortcutEnabled) private var launcherShortcutEnabled = false
    @AppStorage(DefaultsKey.quickLauncherShortcut) private var launcherShortcut = ""
    @AppStorage(DefaultsKey.launcherShortcutTarget) private var launcherShortcutTarget = LauncherShortcutTarget.island.rawValue

    init(feature: AppFeature) {
        self.feature = feature
        self._enabled = AppStorage(wrappedValue: false, feature.availabilityKey)
    }

    private var title: String {
        switch feature {
        case .cameraPreview: return FeatureStrings.cameraPreview(l10n.language).pageTitle
        case .diskImageInstaller: return SettingsOwnershipStrings.text(.dmgInstaller, l10n.language)
        default: return l10n.s.launcherName
        }
    }

    private var requirements: [SettingsPermission] { feature == .cameraPreview ? [.camera] : [] }
    private var childrenEnabled: Bool {
        _ = permissions.camera // Invalidate on permission publication, but verify the live grant below.
        return enabled && requirements.allSatisfy(access.verify)
    }

    private var islandAvailable: Bool {
        islandEnabled && features.isAvailable(.notch)
    }

    private var launcherIslandShown: Binding<Bool> {
        _ = launcherIslandRoute
        return Binding(get: {
            IslandDestination.launcherGrid.isShown(in: .standard)
        }, set: { newValue in
            withAnimation(reduceMotion ? nil : .settingsExpansion) {
                IslandDestination.launcherGrid.setShown(newValue, in: .standard)
                NotchService.shared.syncWithPreferences()
                QuickLauncherService.shared.syncWithPreferences()
            }
        })
    }

    private var shortcutHasValue: Bool {
        guard launcherShortcutEnabled else { return false }
        let raw = UserDefaults.standard.string(forKey: DefaultsKey.quickLauncherShortcut)
        if let raw, raw.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        let shortcut = GlobalShortcut.saved(for: DefaultsKey.quickLauncherShortcut,
                                            fallback: .quickLauncherDefault)
        return shortcut.isValid
    }

    var body: some View {
        ScrollView {
            SettingsCard {
                SettingsRow(symbol: feature.symbolName,
                            title: SettingsOwnershipStrings.enable(title, l10n.language)) {
                    PermissionGatedToggle(SettingsOwnershipStrings.enable(title, l10n.language),
                        isOn: $enabled, requiring: requirements)
                        .labelsHidden()
                        .onChange(of: enabled) { _, _ in
                            FeatureRuntime.shared.sync([feature])
                            FeatureRuntime.shared.finishAvailabilityChange()
                        }
                }
                if childrenEnabled {
                    if feature == .quickLauncher {
                        if islandAvailable {
                            SettingsToggleRow(title: SettingsOwnershipStrings.text(.showIsland, l10n.language),
                                              isOn: launcherIslandShown)
                                .padding(.leading, settingsRowTextInset)
                        }
                        ShortcutPreferenceRow(role: .quickLauncher, label: UtilitySettingsCopy.open(title, l10n.language)) {
                            FeatureRuntime.shared.sync([feature])
                        }
                        .padding(.leading, settingsRowTextInset)

                        if islandAvailable && launcherIslandShown.wrappedValue {
                            SettingsControlRow(title: SettingsOwnershipStrings.text(.shortcutTarget, l10n.language),
                                               caption: SettingsOwnershipStrings.text(.shortcutTargetCaption, l10n.language)) {
                                Picker(SettingsOwnershipStrings.text(.shortcutTarget, l10n.language), selection: $launcherShortcutTarget) {
                                    Text(SettingsOwnershipStrings.text(.dynamicIsland, l10n.language)).tag(LauncherShortcutTarget.island.rawValue)
                                    Text(SettingsOwnershipStrings.text(.floatingWindow, l10n.language)).tag(LauncherShortcutTarget.floatingWindow.rawValue)
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .disabled(!shortcutHasValue)
                            }
                            .padding(.leading, settingsRowTextInset)
                            .onChange(of: launcherShortcutTarget) { _, _ in
                                QuickLauncherService.shared.syncWithPreferences()
                            }
                        }
                    } else {
                        if let shortcut {
                            ShortcutPreferenceRow(role: shortcut, label: UtilitySettingsCopy.open(title, l10n.language)) {
                                FeatureRuntime.shared.sync([feature])
                            }
                            .padding(.leading, settingsRowTextInset)
                        }
                        if let destination {
                            IslandDestinationSettings(destination: destination)
                                .padding(.leading, settingsRowTextInset)
                        }
                    }
                }
            }
            .padding(22)
        }
        .toggleStyle(.switch)
        .controlSize(.regular)
        .settingsExpansionAnimation(value: [childrenEnabled, islandAvailable, launcherIslandShown.wrappedValue, shortcutHasValue])
    }

    private var destination: IslandDestination? {
        switch feature {
        case .cameraPreview: return .cameraPreview
        case .quickLauncher: return .launcherGrid
        default: return nil
        }
    }

    private var shortcut: GlobalShortcutRole? {
        switch feature {
        case .cameraPreview: return .cameraPreview
        case .quickLauncher: return .quickLauncher
        default: return nil
        }
    }
}
