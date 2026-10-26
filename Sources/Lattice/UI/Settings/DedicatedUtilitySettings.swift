// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import SwiftUI

/// Page-owned installation, shortcut and presentation destination.
struct DedicatedUtilitySettings: View {
    let feature: AppFeature
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @Environment(\.settingsPermissionAccess) private var access
    @AppStorage private var enabled: Bool

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
            .padding(22)
        }
        .toggleStyle(.switch)
        .controlSize(.regular)
        .settingsExpansionAnimation(value: childrenEnabled)
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
