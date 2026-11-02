// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Remembers user activation intent when a permission requiring process restart
/// (such as Screen & System Audio Recording) interrupts enablement.
///
/// While running without permission, the operational toggle strictly stays OFF.
/// If macOS forces a process restart (via "Quit & Reopen") or the user relaunches,
/// the coordinator verifies whether the required permission is now granted.
/// If verified, it completes the user's intended activation, restores Settings context,
/// and displays a confirmation HUD.
enum DeferredPermissionActivation {
    static let expirationInterval: TimeInterval = 15 * 60 // 15 minutes

    /// Records the user's intent to turn on a feature that requires a permission requiring restart.
    static func record(feature: AppFeature, in defaults: UserDefaults = .standard, now: Date = Date()) {
        let payload: [String: Any] = [
            "feature": feature.rawValue,
            "timestamp": now.timeIntervalSinceReferenceDate
        ]
        defaults.set(payload, forKey: DefaultsKey.pendingPermissionActivation)
    }

    /// Clears any pending intent (e.g. if the user explicitly cancels or turns off the control).
    static func clear(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: DefaultsKey.pendingPermissionActivation)
    }

    /// Returns the pending feature if it exists and has not expired.
    static func pendingFeature(in defaults: UserDefaults = .standard, now: Date = Date()) -> AppFeature? {
        guard let dict = defaults.dictionary(forKey: DefaultsKey.pendingPermissionActivation),
              let featureRaw = dict["feature"] as? String,
              let timestamp = dict["timestamp"] as? TimeInterval,
              now.timeIntervalSinceReferenceDate - timestamp <= expirationInterval,
              let feature = AppFeature(rawValue: featureRaw) else {
            return nil
        }
        return feature
    }

    /// Evaluates any pending activation. If permissions are verified as granted,
    /// clears the intent and returns the feature to fulfill. If ungranted or expired,
    /// clears the intent and returns nil.
    static func evaluateRecovery(in defaults: UserDefaults = .standard,
                                 now: Date = Date(),
                                 verify: (SettingsPermission) -> Bool) -> AppFeature? {
        guard let feature = pendingFeature(in: defaults, now: now) else {
            clear(in: defaults)
            return nil
        }
        clear(in: defaults)
        // System audio is a distinct Core Audio permission. A screen grant
        // cannot complete an old visualizer enable across restart.
        guard feature != .notchLiveEqualizer,
              requiredPermissions(for: feature).allSatisfy(verify) else { return nil }
        return feature
    }

    private static func requiredPermissions(for feature: AppFeature) -> [SettingsPermission] {
        switch feature {
        case .dockPreview, .switcher: return [.accessibility, .screenRecording]
        default: return [.screenRecording]
        }
    }
}
