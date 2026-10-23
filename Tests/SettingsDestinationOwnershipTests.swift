// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

enum SettingsDestinationOwnershipTests {
    static func run(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.destinations.\(UUID().uuidString)"
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
        AppMenuDestination.menuBar.save(in: defaults)
        suite.expect(AppMenuDestination.selected(in: defaults) == .menuBar, "app menu opens at selected menu bar")
        defaults.set(true, forKey: DefaultsKey.notchHidesMenuBarIcon)
        suite.expect(AppMenuDestination.selected(in: defaults) == .none, "hidden target does not choose a different surface")
        AppMenuDestination.reconcile(in: defaults)
        defaults.set(false, forKey: DefaultsKey.notchHidesMenuBarIcon)
        suite.expect(AppMenuDestination.selected(in: defaults) == .none, "restoring a target does not restore canceled routing")
        defaults.set(true, forKey: AppFeature.notch.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.notchEnabled)
        AppMenuDestination.island.save(in: defaults)
        suite.expect(AppMenuDestination.selected(in: defaults) == .island, "enabled island can host app menu")
        defaults.set(false, forKey: DefaultsKey.notchEnabled)
        suite.expect(AppMenuDestination.selected(in: defaults) == .none, "disabled island never falls back to menu bar")
    }
}
