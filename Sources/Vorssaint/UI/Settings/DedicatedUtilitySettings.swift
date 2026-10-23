// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import SwiftUI

/// Page-owned installation, shortcut and presentation destination.
struct DedicatedUtilitySettings: View {
    let feature: AppFeature
    @ObservedObject private var l10n = L10n.shared
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

    var body: some View {
        ScrollView {
            SettingsCard {
                SettingsRow(symbol: feature.symbolName,
                            title: SettingsOwnershipStrings.enable(title, l10n.language)) {
                    PermissionGatedToggle(SettingsOwnershipStrings.enable(title, l10n.language),
                        isOn: $enabled, requiring: feature == .cameraPreview ? [.camera] : [])
                        .labelsHidden()
                        .onChange(of: enabled) { _, _ in
                            FeatureRuntime.shared.sync([feature])
                            FeatureRuntime.shared.finishAvailabilityChange()
                        }
                }
                if let destination {
                    IslandDestinationSettings(destination: destination, includeDivider: true)
                        .disabled(!enabled)
                }
                if let shortcut {
                    Divider()
                    ShortcutPreferenceRow(role: shortcut) {
                        FeatureRuntime.shared.sync([feature])
                    }
                    .disabled(!enabled)
                }
            }
            .padding(22)
        }
        .toggleStyle(.switch)
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
