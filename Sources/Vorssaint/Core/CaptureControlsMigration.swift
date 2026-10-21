// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

extension Defaults {
    static let captureControlsMigrationKey = "captureControlsMigrated"

    /// Migrate retired capture installation gates to their owning toggles before defaults registration.
    static func migrateCaptureControls(in defaults: UserDefaults) {
        guard !defaults.bool(forKey: captureControlsMigrationKey) else { return }

        if let screenshotInstalled = defaults.object(forKey: AppFeature.screenshot.availabilityKey) as? Bool, !screenshotInstalled {
            defaults.set(false, forKey: DefaultsKey.screenshotEnabled)
        }
        if let recorderInstalled = defaults.object(forKey: AppFeature.screenRecorder.availabilityKey) as? Bool, !recorderInstalled {
            defaults.set(false, forKey: DefaultsKey.screenRecorderEnabled)
        }

        defaults.set(true, forKey: captureControlsMigrationKey)
    }
}
