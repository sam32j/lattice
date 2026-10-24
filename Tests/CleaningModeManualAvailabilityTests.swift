import Foundation

enum CleaningModeManualAvailabilityTests {
    static func run(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.manual-cleaning.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(false, forKey: DefaultsKey.cleaningModeShortcutEnabled)
        defaults.set("", forKey: DefaultsKey.cleaningModeShortcut)
        suite.expect(!AppFeature.cleaningMode.isAvailable(in: defaults),
                     "manual availability does not install persistent Cleaning Mode registration")
        suite.expect(QuickLauncherContract.QuickLauncherItem.cleaning.isAvailable(in: defaults),
                     "Launcher Grid offers on-demand Cleaning Mode without a shortcut")
        suite.expect(RadialMenuTool.cleaningMode.isRunnable(isFeatureAvailable: { $0.isAvailable(in: defaults) }),
                     "a configured radial action offers on-demand Cleaning Mode without a shortcut")
    }
}
