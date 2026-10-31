// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

extension FeatureRuntime {
    /// Page activation preserves the existing availability key and all saved
    /// options. Radial Menu's former behavior switch is now the master switch.
    func setPageEnabled(_ feature: AppFeature, _ enabled: Bool) {
        guard AppFeature.migratedPageFeatures.contains(feature),
              !enabled || feature.isHardwareSupported else { return }
        if feature == .keepAwake, !enabled, feature.isAvailable {
            guard KeepAwakeManager.shared.prepareForFeatureDisable() else { return }
        }
        setAvailable([feature], enabled)
        if feature == .radialMenu {
            UserDefaults.standard.set(enabled, forKey: DefaultsKey.radialMenuEnabled)
        }
        // A saved availability can already be on while the radial behavior
        // was off. That change still has to register or tear down its inputs.
        if feature == .radialMenu {
            sync([feature])
            finishAvailabilityChange()
        }
    }
}
