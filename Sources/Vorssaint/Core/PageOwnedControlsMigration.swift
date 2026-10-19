import Foundation

extension Defaults {
    static let pageOwnedControlsMigrationKey = "pageOwnedControlsMigrated"

    /// Run before registering defaults. A retired installation switch must not
    /// resurrect saved behavior that was ineffective in the previous version.
    static func migratePageOwnedControls(in defaults: UserDefaults) {
        guard !defaults.bool(forKey: pageOwnedControlsMigrationKey) else { return }
        for feature in AppFeature.allCases where feature.isToggleOwned
            && !feature.isMouseFeature && !feature.isKeyboardFeature {
            let installed = defaults.object(forKey: feature.availabilityKey) as? Bool
                ?? feature.installedByDefault
            guard !installed else { continue }
            for key in feature.enabledKeys { defaults.set(false, forKey: key) }
        }
        defaults.set(true, forKey: pageOwnedControlsMigrationKey)
    }
}
