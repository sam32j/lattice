import Foundation

/// Exercise the production consumers, not a copy of their shared predicate.
enum SettingsPanelFilterTests {
    typealias UtilityPanelItem = MenuPanelSectionGateContract.UtilityPanelItem
    class LayoutState { static var defaults: UserDefaults! }
    class UtilityState {
        let orderedItems: [UtilityPanelItem] = [.cleaning, .screenshot]
        let defaults: UserDefaults
        init(_ defaults: UserDefaults) { self.defaults = defaults }
        func isVisible(_ item: UtilityPanelItem) -> Bool { true }
    }
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
        suite.expect(!Layout.isVisibleInPanel(.utilities),
                     "the outer Utilities section stays runtime-gated")
        defaults.set(true, forKey: AppFeature.screenshot.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.screenshotEnabled)
        let utilities = Utilities(defaults)
        suite.expect(utilities.items(editing: false) == [.screenshot]
                     && utilities.items(editing: true) == [.screenshot],
                     "actual Utilities never offers disabled Cleaning Mode, including in edit mode")
        defaults.set(true, forKey: DefaultsKey.cleaningModeShortcutEnabled)
        suite.expect(utilities.items(editing: false) == [.cleaning, .screenshot],
                     "a configured Cleaning Mode shortcut keeps its utility tile")
    }
}
