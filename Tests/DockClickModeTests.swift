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

        for language in AppLanguage.allCases {
            let copy = DockClickCopy.strings(language)
            suite.expect(!copy.title.isEmpty && !copy.body.isEmpty && !copy.off.isEmpty
                         && !copy.toggleWindows.isEmpty && !copy.hideApps.isEmpty && !copy.cycleWindows.isEmpty,
                         "DockClickCopy provides non-empty strings for \(language.rawValue)")
            suite.expect(!copy.title.contains("'") && !copy.body.contains("'")
                         && !copy.toggleWindows.contains("'") && !copy.hideApps.contains("'") && !copy.cycleWindows.contains("'"),
                         "DockClickCopy curls all apostrophes in \(language.rawValue)")
        }
        let zh = DockClickCopy.strings(.zhHans)
        suite.expect(zh.title == "程序坞图标"
                     && zh.body == "点按程序坞图标以执行"
                     && zh.off == "关闭"
                     && zh.toggleWindows == "最小化/恢复窗口"
                     && zh.hideApps == "隐藏/关闭应用"
                     && zh.cycleWindows == "切换",
                     "Simplified Chinese Dock Click matches user specification")
    }
}
