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

    init(feature: AppFeature) {
        self.feature = feature
        self._enabled = AppStorage(wrappedValue: false, feature.availabilityKey)
    }

    private var title: String {
        switch feature {
        case .cameraPreview: return FeatureStrings.cameraPreview(l10n.language).pageTitle
        case .diskImageInstaller: return SettingsOwnershipStrings.text(.dmgInstaller, l10n.language)
        default: return ""
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

    var body: some View {
        ScrollView {
            SettingsCard {
                let rowTitle = feature == .cameraPreview ? title : SettingsOwnershipStrings.enable(title, l10n.language)
                SettingsRow(symbol: feature.symbolName,
                            title: rowTitle) {
                    PermissionGatedToggle(rowTitle,
                        isOn: $enabled, requiring: requirements)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: enabled) { _, _ in
                            FeatureRuntime.shared.sync([feature])
                            settingsFinishAvailabilityChange()
                        }
                }
                if childrenEnabled {
                    VStack(alignment: .leading, spacing: 13) {
                        if let shortcut {
                            ShortcutPreferenceRow(role: shortcut, label: feature == .cameraPreview ? FeatureStrings.cameraPreview(l10n.language).openWithShortcut : UtilitySettingsCopy.open(title, l10n.language)) {
                                FeatureRuntime.shared.sync([feature])
                            }
                            .padding(.leading, settingsRowTextInset)
                        }
                        if let destination {
                            IslandDestinationSettings(destination: destination)
                                .padding(.leading, settingsRowTextInset)
                        }
                    }
                    .transition(.settingsReveal)
                }
            }
            .padding(22)
        }
        .toggleStyle(.switch)
        .controlSize(.regular)
        .settingsExpansionAnimation(value: [childrenEnabled, islandAvailable])
    }

    private var destination: IslandDestination? {
        switch feature {
        case .cameraPreview: return nil
        default: return nil
        }
    }

    private var shortcut: GlobalShortcutRole? {
        switch feature {
        case .cameraPreview: return .cameraPreview
        default: return nil
        }
    }
}
