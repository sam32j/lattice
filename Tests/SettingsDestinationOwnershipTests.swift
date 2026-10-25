// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

enum SettingsDestinationOwnershipTests {
    static func run(_ suite: TestSuite) {
        var entries: [String] = []
        AppMenuReopenCoordinator.open(destination: { .none }, iconHidden: { false }, iconVisible: { true },
            recreateIcon: { entries.append("recreate") }, presentMenu: { entries.append("menu"); return true },
            openSettings: { entries.append("settings") }, schedule: { $0() })
        suite.expect(entries == ["settings"], "Don't show opens Settings on reopen even with a visible menu bar icon")
        entries = []
        AppMenuReopenCoordinator.open(destination: { .island }, iconHidden: { true }, iconVisible: { false },
            recreateIcon: { entries.append("recreate") }, presentMenu: { entries.append("menu"); return true },
            presentIsland: { entries.append("island"); return true },
            openSettings: { entries.append("settings") }, schedule: { $0() })
        suite.expect(entries == ["island"], "an island destination opens without the menu-bar popover or icon recovery")
        entries = []
        var requested = AppMenuDestination.menuBar
        var pending: (() -> Void)?
        AppMenuReopenCoordinator.open(destination: { requested }, iconHidden: { false }, iconVisible: { true },
            recreateIcon: { entries.append("recreate") }, presentMenu: { entries.append("menu"); return true },
            presentIsland: { entries.append("island"); return true },
            openSettings: { entries.append("settings") }, schedule: { pending = $0 })
        requested = .island
        pending?()
        suite.expect(entries == ["island"], "deferred reopen respects the latest destination")
        entries = []
        AppMenuReopenCoordinator.open(destination: { .island }, iconHidden: { true }, iconVisible: { false },
            recreateIcon: {}, presentMenu: { false }, presentIsland: { false },
            openSettings: { entries.append("settings") }, schedule: { $0() })
        suite.expect(entries == ["settings"], "an unavailable island presentation opens Settings")
        let domain = "io.github.sam32j.lattice.tests.destinations.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        suite.expect(AppMenuDestination.selected(in: defaults) == .menuBar,
                     "new app menu settings default to Menu Bar")
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
        defaults.set(false, forKey: DefaultsKey.notchHidesMenuBarIcon)
        suite.expect(AppMenuDestination.selected(in: defaults) == .menuBar, "restoring a target restores its remembered routing")
        defaults.set(true, forKey: AppFeature.notch.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.notchEnabled)
        AppMenuDestination.island.save(in: defaults)
        suite.expect(AppMenuDestination.selected(in: defaults) == .island, "enabled island can host app menu")
        defaults.set(false, forKey: DefaultsKey.notchEnabled)
        suite.expect(AppMenuDestination.selected(in: defaults) == .none, "disabled island never falls back to menu bar")
        suite.expect(AppMenuDestination.requested(in: defaults) == .island,
                     "temporarily unavailable targets retain their explicit preference")
        defaults.set(true, forKey: DefaultsKey.notchEnabled)
        suite.expect(AppMenuDestination.selected(in: defaults) == .island, "restoring the island restores its app menu")
        AppMenuDestination.none.save(in: defaults)
        defaults.set(false, forKey: DefaultsKey.notchEnabled)
        defaults.set(true, forKey: DefaultsKey.notchEnabled)
        suite.expect(AppMenuDestination.selected(in: defaults) == .none, "explicit Don't show never automatically reopens")
        AppMenuDestination.island.save(in: defaults)
        defaults.set(false, forKey: DefaultsKey.notchEnabled)
        AppMenuDestination.menuBar.save(in: defaults)
        defaults.set(true, forKey: DefaultsKey.notchEnabled)
        suite.expect(AppMenuDestination.selected(in: defaults) == .menuBar,
                     "an explicit replacement while a target is unavailable wins over the remembered target")
    }
}
