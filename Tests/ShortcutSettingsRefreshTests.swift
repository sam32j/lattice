// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Combine
import Foundation

enum ShortcutSettingsRefreshTests {
    static func run(_ suite: TestSuite) {
        let center = NotificationCenter()
        let observer = ShortcutSettingsObserver(center: center)
        let domain = "io.github.sam32j.lattice.tests.shortcut-refresh.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let role = GlobalShortcutRole.cleaningMode
        var states: [Bool] = []
        let subscription = observer.objectWillChange.sink {
            states.append(GlobalShortcut(storageValue: defaults.string(forKey: role.storageKey) ?? "")?.isValid == true)
        }
        defaults.set(role.defaultShortcut.storageValue, forKey: role.storageKey)
        center.post(name: UserDefaults.didChangeNotification, object: defaults)
        center.post(name: UserDefaults.didChangeNotification, object: defaults)
        RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        defaults.set("", forKey: role.storageKey)
        center.post(name: UserDefaults.didChangeNotification, object: defaults)
        RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        suite.expect(states == [true, false],
                     "shortcut edits and clearing invalidate badges after preferences land; bursts coalesce")
        withExtendedLifetime(subscription) {}
    }
}
