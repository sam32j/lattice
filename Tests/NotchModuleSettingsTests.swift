import Foundation
import SwiftUI

enum NotchModuleSettingsTests {
    final class State {
        let defaults: UserDefaults
        var returnHome = true
        var homeModule = "tools"
        var timerEnabled = true, cameraEnabled = true, calendarEnabled = true
        var notificationsEnabled = true, agentsEnabled = true, watchEnabled = true
        init(_ defaults: UserDefaults) { self.defaults = defaults }
    }

    static func run(_ suite: TestSuite) {
        let domain = "io.github.sam32j.lattice.tests.hub-settings.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.register(defaults: Defaults.registeredDefaults)
        defaults.register(defaults: AppFeature.availabilityDefaults)
        let state = State(defaults)
        let settings = Settings(state: state)
        defaults.set("music,tools", forKey: DefaultsKey.notchHiddenModules)
        let shown = settings.moduleBinding(.hub)
        suite.expect(!shown.wrappedValue, "the Hub switch reflects a legacy hidden Tools module")
        shown.wrappedValue = true
        suite.expect(shown.wrappedValue && NotchSupport.modules(in: defaults).contains(.hub)
                     && defaults.string(forKey: DefaultsKey.notchHiddenModules) == "music",
                     "showing Hub removes its legacy hidden identifier without changing other modules")
        shown.wrappedValue = false
        suite.expect(!shown.wrappedValue && !NotchSupport.modules(in: defaults).contains(.hub),
                     "the Hub switch and runtime agree when hiding the renamed module")
        suite.expect(settings.reopeningSelection == "hub",
                     "a saved Tools reopening destination selects the canonical Hub picker item")
        state.returnHome = false
        suite.expect(settings.reopeningSelection.isEmpty, "last-page reopening keeps its empty picker selection")
        state.returnHome = true
        state.homeModule = "unknown"
        suite.expect(settings.reopeningSelection == "controls", "unknown reopening destinations retain their default")
    }
}
