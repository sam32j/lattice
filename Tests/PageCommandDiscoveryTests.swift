import Foundation

enum PageCommandDiscoveryTests {
    enum Directory {
        static var items: [SettingsSearchItem] = []
        static func searchItems(_ s: Strings, language: AppLanguage) -> [SettingsSearchItem] { items }
    }
    struct Entry {
        enum Icon { case symbol(String) }
        let id: String
        let run: (Int?) -> Void
        init(id: String, title: String, subtitle: String, keywords: String,
             icon: Icon, run: @escaping (Int?) -> Void) { self.id = id; self.run = run }
    }
    class State {
        typealias SettingsDirectory = Directory
        typealias CommandBarEntry = Entry
        static var defaults: UserDefaults!
        static var visited: FeatureSettingsDestination?
        static func openSettings(at destination: FeatureSettingsDestination,
                                 targetFeature: AppFeature?, sidebarFeature: AppFeature?) { visited = destination }
    }
    static func run(_ suite: TestSuite) {
        let domain = "io.github.sam32j.lattice.tests.page-command-discovery.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        State.defaults = defaults
        defer { defaults.removePersistentDomain(forName: domain); State.defaults = nil; Directory.items = [] }
        let owners: [AppFeature] = [.keepAwake, .mediaTools, .cleaner, .uninstaller, .homebrew,
                                   .appUpdates, .radialMenu, .commandBar, .killProcess, .portManager]
        for feature in owners { defaults.set(false, forKey: feature.availabilityKey) }
        defaults.set(false, forKey: DefaultsKey.radialMenuEnabled)
        Directory.items = owners.map { feature in
            SettingsSearchItem(id: feature == .keepAwake ? .feature(feature) : .page(feature.settingsDestination.page),
                destination: feature.settingsDestination, title: feature.rawValue,
                icon: feature.symbolName, feature: feature)
        }
        Directory.items.append(SettingsSearchItem(id: .page(.features), destination: .init(.features),
                                                  title: "Features", icon: "square.grid.2x2"))
        let entries = Catalog.settingsEntries(.enUS, language: .enUS, bar: FeatureStrings.commandBar(.enUS))
        suite.expect(entries.count == 10 && !entries.contains { $0.id == "settings.features" },
                     "Command Bar discovers all ten disabled owning pages and excludes Features")
        for (entry, feature) in zip(entries, owners) {
            entry.run(nil)
            suite.expect(State.visited == feature.settingsDestination,
                         "disabled \(feature) Command Bar navigation reaches its activation owner")
        }
    }
}
