import Foundation

extension Defaults {
    static let cleaningModeShortcutMigrationKey = "cleaningModeShortcutOwnershipMigrated"

    /// Retire the old master switch without reviving a previously disabled shortcut.
    static func migrateCleaningModeShortcut(in defaults: UserDefaults) {
        guard !defaults.bool(forKey: cleaningModeShortcutMigrationKey) else { return }
        if defaults.object(forKey: DefaultsKey.cleaningModeEnabled) as? Bool == false {
            defaults.set(false, forKey: DefaultsKey.cleaningModeShortcutEnabled)
        }
        defaults.removeObject(forKey: DefaultsKey.cleaningModeEnabled)
        defaults.set(true, forKey: cleaningModeShortcutMigrationKey)
    }

    static let permanentInputControlsMigrationKey = "permanentInputControlsMigrated"

    /// Translate the old installation gate before registering defaults, after
    /// legacy feature-split migrations have established their installation state.
    static func migratePermanentInputControls(in defaults: UserDefaults) {
        guard !defaults.bool(forKey: permanentInputControlsMigrationKey) else { return }
        for feature in AppFeature.allCases where feature.isMouseFeature || feature.isKeyboardFeature {
            let installed = defaults.object(forKey: feature.availabilityKey) as? Bool
                ?? feature.installedByDefault
            guard !installed else { continue }
            for key in feature.enabledKeys { defaults.set(false, forKey: key) }
        }
        defaults.set(true, forKey: permanentInputControlsMigrationKey)
    }
}
