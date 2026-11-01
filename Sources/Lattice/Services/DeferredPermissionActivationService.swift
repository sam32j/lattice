// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Application-level runtime execution of deferred permission activations.
enum DeferredPermissionActivationService {
    @MainActor
    static func recoverIfNeeded(in defaults: UserDefaults = .standard) {
        guard let feature = DeferredPermissionActivation.evaluateRecovery(in: defaults, verify: { permission in
            PermissionPreflight.isGranted(permission)
        }) else {
            return
        }
        fulfill(feature: feature, in: defaults)
    }

    @MainActor
    static func fulfill(feature: AppFeature, in defaults: UserDefaults = .standard) {
        switch feature {
        case .screenshot:
            defaults.set(true, forKey: DefaultsKey.screenshotEnabled)
            FeatureRuntime.shared.setAvailable([.screenshot], true)
            ScreenshotService.shared.syncWithPreferences()
            ScreenTextService.shared.syncWithPreferences()
            ScreenCaptureService.shared.syncWithPreferences()
        case .screenRecorder:
            defaults.set(true, forKey: DefaultsKey.screenRecorderEnabled)
            FeatureRuntime.shared.setAvailable([.screenRecorder], true)
            ScreenCaptureService.shared.syncWithPreferences()
            ScreenRecorderService.shared.syncWithPreferences()
            RecentCaptureService.shared.syncWithPreferences()
        case .switcher:
            defaults.set(true, forKey: DefaultsKey.switcherEnabled)
            FeatureRuntime.shared.setAvailable([.switcher], true)
            AppSwitcher.shared.syncWithPreferences()
        case .dockPreview:
            defaults.set(true, forKey: DefaultsKey.dockPreviewEnabled)
            FeatureRuntime.shared.setAvailable([.dockPreview], true)
            DockPreviewService.shared.syncWithPreferences()
        case .notchLiveEqualizer:
            defaults.set(true, forKey: DefaultsKey.notchLiveEqualizer)
            FeatureRuntime.shared.setIslandFeature(.notchLiveEqualizer, enabled: true)
        default:
            for key in feature.enabledKeys { defaults.set(true, forKey: key) }
            FeatureRuntime.shared.setAvailable([feature], true)
            FeatureRuntime.shared.sync([feature])
        }
        FeatureRuntime.shared.finishAvailabilityChange()

        // Restore Settings page & show confirmation HUD
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            SettingsRouter.shared.request(feature.settingsDestination)
            appDelegate()?.openSettingsWindow()
            let title = feature.hubTitle(L10n.shared.s, hub: FeatureStrings.hub(L10n.shared.language))
            QuickToolHUD.show(icon: "checkmark", message: "\(title) enabled")
        }
    }
}
