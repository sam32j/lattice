// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import SwiftUI

/// A single page-owned install switch; no second Features-page installation flag.
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
            }
            .padding(22)
        }
        .toggleStyle(.switch)
    }
}
