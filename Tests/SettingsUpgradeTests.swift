import Foundation

enum SettingsUpgradeTests {
    static func run(_ suite: TestSuite) {
        let domain = "vorss.tests.settings-upgrade.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(false, forKey: AppFeature.focusFollowsMouse.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.focusFollowsMouseEnabled)
        defaults.set(false, forKey: AppFeature.cleaningMode.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.cleaningModeEnabled)
        defaults.set(true, forKey: AppFeature.superKey.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.superKeyEnabled)
        defaults.set(false, forKey: AppFeature.quitWindowProtection.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.quitProtectionQuitEnabled)
        defaults.set(true, forKey: DefaultsKey.quitProtectionCloseEnabled)
        defaults.set(true, forKey: DefaultsKey.scrollHorizontalEnabled)
        Defaults.migratePermanentInputControls(in: defaults)
        suite.expect(!AppFeature.focusFollowsMouse.isAvailable(in: defaults)
                     && !AppFeature.cleaningMode.isAvailable(in: defaults),
                     "upgrading does not revive formerly uninstalled input controls")
        suite.expect(AppFeature.superKey.isAvailable(in: defaults),
                     "upgrading preserves an installed active input control")
        suite.expect(!defaults.bool(forKey: DefaultsKey.quitProtectionQuitEnabled)
                     && !defaults.bool(forKey: DefaultsKey.quitProtectionCloseEnabled),
                     "an uninstalled multi-key input feature stays entirely inactive")
        suite.expect(!AppFeature.scrollHorizontal.isAvailable(in: defaults),
                     "a missing opt-in installation cannot revive its saved enable key")
        defaults.set(true, forKey: DefaultsKey.focusFollowsMouseEnabled)
        Defaults.migratePermanentInputControls(in: defaults)
        suite.expect(AppFeature.focusFollowsMouse.isAvailable(in: defaults),
                     "later user choices survive subsequent launches")
        defaults.set(false, forKey: DefaultsKey.superKeyEnabled)
        defaults.set(false, forKey: DefaultsKey.focusFollowsMouseEnabled)
        suite.expect(AppFeature.superKey.isPresentInControls(in: defaults)
                     && AppFeature.focusFollowsMouse.isPresentInControls(in: defaults),
                     "off permanent input controls remain reachable to turn back on")
        defaults.set(false, forKey: AppFeature.clipboardHistory.availabilityKey)
        suite.expect(!AppFeature.clipboardHistory.isPresentInControls(in: defaults),
                     "uninstalled optional features remain absent from control surfaces")
        defaults.set(true, forKey: DefaultsKey.focusFollowsMouseEnabled)
        let backup = SettingsBackupSupport.payload(appVersion: "test") { defaults.object(forKey: $0) }
        let settings = SettingsBackupSupport.sanitizedSettings(from: backup)!
        suite.expect(settings[Defaults.permanentInputControlsMigrationKey] as? Bool == true,
                     "current backups carry the input upgrade marker")
        for key in SettingsBackupSupport.keysToClear(whenImporting: settings) { defaults.removeObject(forKey: key) }
        for (key, value) in settings { defaults.set(value, forKey: key) }
        Defaults.migratePermanentInputControls(in: defaults)
        suite.expect(AppFeature.focusFollowsMouse.isAvailable(in: defaults),
                     "restoring a current backup preserves post-upgrade input choices")
        let legacy: [String: Any] = [AppFeature.focusFollowsMouse.availabilityKey: false,
                                   DefaultsKey.focusFollowsMouseEnabled: true]
        for key in SettingsBackupSupport.keysToClear(whenImporting: legacy) { defaults.removeObject(forKey: key) }
        for (key, value) in legacy { defaults.set(value, forKey: key) }
        defaults.set(true, forKey: DefaultsKey.linearScrollEnabled)
        Defaults.migrateLinearScrollAvailability(in: defaults)
        Defaults.migratePermanentInputControls(in: defaults)
        suite.expect(!AppFeature.focusFollowsMouse.isAvailable(in: defaults)
                     && AppFeature.linearScroll.isAvailable(in: defaults),
                     "legacy restore re-applies upgrade while preserving the earlier linear-scroll migration")
    }
}
