import Foundation

/// Exercise the production consumers, not a copy of their shared predicate.
enum SettingsPanelFilterTests {
    typealias ControlPanelItem = MenuPanelSectionGateContract.ControlPanelItem
    typealias UtilityPanelItem = MenuPanelSectionGateContract.UtilityPanelItem
    class LayoutState { static var defaults: UserDefaults! }
    class ControlState {
        let orderedItems: [ControlPanelItem] = [.superKey, .keyDebounce, .mouseScroll, .shelf]
        let defaults: UserDefaults
        var visible: Set<ControlPanelItem> = [.superKey, .keyDebounce, .mouseScroll, .shelf]
        init(_ defaults: UserDefaults) { self.defaults = defaults }
        func isVisible(_ item: ControlPanelItem) -> Bool { visible.contains(item) }
    }
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
        Layout.defaults = defaults
        defer { Layout.defaults = nil }
        suite.expect(Layout.isVisibleInPanel(.controls),
                     "the actual outer Controls section remains reachable when all input switches are off")
        suite.expect(!Layout.isVisibleInPanel(.utilities),
                     "the outer Utilities section stays runtime-gated")
        defaults.set(false, forKey: PanelSectionID.controls.visibilityKey)
        suite.expect(!Layout.isVisibleInPanel(.controls),
                     "permanent Controls reachability does not override an explicitly hidden section")
        defaults.removeObject(forKey: PanelSectionID.controls.visibilityKey)
        let controls = Controls(defaults)
        let expected: [ControlPanelItem] = [.superKey, .keyDebounce, .mouseScroll]
        suite.expect(controls.items(editing: false) == expected && controls.items(editing: true) == expected,
                     "actual Quick Controls retains off input rows but excludes uninstalled optional rows")
        controls.visible.remove(.superKey)
        suite.expect(!controls.items(editing: false).contains(.superKey)
                     && controls.items(editing: true).contains(.superKey),
                     "Quick Controls still respects hidden rows outside edit mode")
        defaults.set(true, forKey: AppFeature.screenshot.availabilityKey)
        let utilities = Utilities(defaults)
        suite.expect(utilities.items(editing: false) == [.screenshot]
                     && utilities.items(editing: true) == [.screenshot],
                     "actual Utilities never offers disabled Cleaning Mode, including in edit mode")
        defaults.set(true, forKey: DefaultsKey.cleaningModeEnabled)
        suite.expect(utilities.items(editing: false) == [.cleaning, .screenshot],
                     "enabled Cleaning Mode keeps its utility tile")
    }
}
