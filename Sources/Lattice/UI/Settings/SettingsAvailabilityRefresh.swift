// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Settings' switches finish a feature's availability change through here:
/// a single flip refreshes Settings, the hub, and the island at once, and a
/// burst of flips across any switches refreshes them once more after it.
@MainActor
func settingsFinishAvailabilityChange() {
    SettingsSwitchBursts.run("feature-availability", immediately: true) {
        FeatureRuntime.shared.finishAvailabilityChange()
    }
}
