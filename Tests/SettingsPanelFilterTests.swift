import Foundation

/// Exercise the production consumers, not a copy of their shared predicate.
enum SettingsPanelFilterTests {
    class LayoutState { static var defaults: UserDefaults! }
    static func run(_ suite: TestSuite) {
        let domain = "vorss.tests.panel-filter.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        for feature in AppFeature.allCases {
            defaults.set(false, forKey: feature.availabilityKey)
            for key in feature.enabledKeys { defaults.set(false, forKey: key) }
        }
        defaults.set(false, forKey: DefaultsKey.screenshotEnabled)
        defaults.set(false, forKey: DefaultsKey.screenRecorderEnabled)
        Layout.defaults = defaults
        defer { Layout.defaults = nil }
        suite.expect(!Layout.isVisibleInPanel(.toggles),
                     "the outer Toggles section stays runtime-gated")
    }
}
