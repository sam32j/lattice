import Foundation

/// The production registration method runs without creating a real input tap.
enum CleaningModePreferencesTests {
    final class Hotkey {
        var enabled = false
        func sync(enabled: Bool, shortcut: GlobalShortcut, storageKey: String) -> Bool {
            self.enabled = enabled && shortcut.isValid
            return true
        }
    }
    class State {
        let defaults: UserDefaults
        let hotkey = Hotkey()
        var isActive = true
        var shortcutRegistrationFailed = false
        var deactivations = 0
        init(_ defaults: UserDefaults) { self.defaults = defaults }
        func deactivate() { deactivations += 1; isActive = false }
    }
    static func run(_ suite: TestSuite) {
        let domain = "vorss.tests.cleaning-preferences.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let service = Service(defaults)
        defaults.set(false, forKey: DefaultsKey.cleaningModeEnabled)
        defaults.set(true, forKey: DefaultsKey.cleaningModeShortcutEnabled)
        defaults.set(GlobalShortcut.cleaningModeDefault.storageValue, forKey: DefaultsKey.cleaningModeShortcut)
        Defaults.migrateCleaningModeShortcut(in: defaults)
        suite.expect(!AppFeature.cleaningMode.isAvailable(in: defaults)
                     && defaults.object(forKey: DefaultsKey.cleaningModeEnabled) == nil,
                     "the upgrade preserves a legacy opt-out and retires its master switch")
        defaults.set(true, forKey: DefaultsKey.cleaningModeShortcutEnabled)
        defaults.set(GlobalShortcut.cleaningModeDefault.storageValue, forKey: DefaultsKey.cleaningModeShortcut)
        service.syncWithPreferences()
        Defaults.migrateCleaningModeShortcut(in: defaults)
        suite.expect(service.hotkey.enabled, "a saved shortcut registers Cleaning Mode")
        suite.expect(AppFeature.cleaningMode.isAvailable(in: defaults),
                     "later shortcut choices survive repeated upgrade checks")
        defaults.set(false, forKey: DefaultsKey.cleaningModeShortcutEnabled)
        defaults.set("", forKey: DefaultsKey.cleaningModeShortcut)
        service.syncWithPreferences()
        suite.expect(!service.hotkey.enabled, "clearing a shortcut unregisters Cleaning Mode immediately")
        suite.expect(service.isActive && service.deactivations == 0,
                     "removing the shortcut leaves the temporary lock active until deliberate unlock")
    }
}
