// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

enum SettingsDestinationOwnershipTests {
    static func run(_ suite: TestSuite) {
        let domain = "io.github.sam32j.lattice.tests.destinations.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        for destination in [IslandDestination.clipboard, .files, .scratchpad, .cameraPreview, .launcherGrid] {
            defaults.set("music,\(destination.rawValue)", forKey: DefaultsKey.notchHiddenModules)
            destination.setShown(true, in: defaults)
            suite.expect(defaults.bool(forKey: destination.routeKey) && destination.isShown(in: defaults)
                         && defaults.string(forKey: DefaultsKey.notchHiddenModules) == "music",
                         "island destination enables routing and widget without changing other widgets")
            destination.setShown(false, in: defaults)
            suite.expect(!defaults.bool(forKey: destination.routeKey) && !destination.isShown(in: defaults),
                         "island destination disables both widget and routing")
        }

        let router = SettingsRouter()
        router.page = .notch
        router.request(FeatureSettingsDestination(.notchWidget(.music)))
        suite.expect(router.page == .notchWidget(.music) && router.canGoBack(),
                     "navigating to a widget subpage sets router page and enables back navigation")
        router.goBack()
        suite.expect(router.page == .notch,
                     "going back from a widget subpage returns to the Dynamic Island page")
        router.request(FeatureSettingsDestination(.notchCompanion))
        suite.expect(router.page == .notchCompanion && router.canGoBack(),
                     "navigating to the companion subpage sets router page and enables back navigation")
        router.goBack()
        suite.expect(router.page == .notch,
                     "going back from companion returns to the Dynamic Island page")

        suite.expect(NotchSettingsStrings.widgetTitle(.music, language: .enUS) == "Now Playing Widget"
                     && NotchSettingsStrings.widgetTitle(.controls, language: .enUS) == "Controls Widget"
                     && NotchSettingsStrings.widgetTitle(.calendar, language: .enUS) == "Calendar Widget",
                     "widget titles append Widget in English")
        suite.expect(NotchSettingsStrings.widgetTitle(.music, language: .zhHans) == "正在播放小组件"
                     && NotchSettingsStrings.widgetTitle(.controls, language: .zhHans) == "控制小组件",
                     "widget titles append localized widget word in Simplified Chinese without space")
        suite.expect(NotchSettingsStrings.widgetTitle(.music, language: .zhTW) == "播放中小工具",
                     "widget titles append localized widget word in Traditional Chinese")

        suite.expect(SettingsSidebarSupport.selection(for: FeatureSettingsDestination(.notchWidget(.music)), in: []) == .page(.notch)
                     && SettingsSidebarSupport.selection(for: FeatureSettingsDestination(.notchCompanion), in: []) == .page(.notch),
                     "widget subpages and companion map selection to the Dynamic Island sidebar item")
    }
}
