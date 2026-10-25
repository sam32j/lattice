// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum DockClickModeTests {
    static func run(_ suite: TestSuite) {
        let domain = "io.github.sam32j.lattice.tests.dock-click-mode.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        suite.expect(DockClickMode.selected(in: defaults) == .off && !AppFeature.dockClick.isAvailable(in: defaults),
                     "an unconfigured Dock Click always selects Off and remains unloaded")
        for mode in DockClickMode.allCases {
            mode.store(in: defaults)
            suite.expect(DockClickMode.selected(in: defaults) == mode,
                         "each selected Dock Click tile survives a settings reload")
            suite.expect(AppFeature.dockClick.isAvailable(in: defaults) == (mode != .off),
                         "only a non-Off tile installs Dock Click")
        }
        defaults.set(true, forKey: DefaultsKey.dockClickMinimize)
        defaults.set(true, forKey: DefaultsKey.dockClickHide)
        defaults.set(true, forKey: DefaultsKey.dockClickCycleWindows)
        suite.expect(DockClickMode.selected(in: defaults) == .cycleWindows,
                     "legacy conflicting flags resolve to one consistent tile and service action")
        DockClickMode.cycleWindows.store(in: defaults)
        DockClickMode.off.store(in: defaults)
        suite.expect(!defaults.bool(forKey: DefaultsKey.dockClickMinimize)
                     && !defaults.bool(forKey: DefaultsKey.dockClickHide)
                     && !defaults.bool(forKey: DefaultsKey.dockClickCycleWindows),
                     "Off clears every action so the service unloads rather than keeping stale work armed")
    }
}
