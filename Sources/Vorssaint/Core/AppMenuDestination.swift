// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

enum AppMenuDestination: String, CaseIterable {
    case none, menuBar, island
    static let disabledKey = "appMenuDisabled"

    static func available(in defaults: UserDefaults) -> [Self] {
        var targets: [Self] = [.none]
        if !defaults.bool(forKey: DefaultsKey.notchHidesMenuBarIcon) { targets.append(.menuBar) }
        if NotchSupport.isEnabled(in: defaults) { targets.append(.island) }
        return targets
    }

    static func selected(in defaults: UserDefaults) -> Self {
        guard !defaults.bool(forKey: disabledKey) else { return .none }
        let requested: Self = defaults.bool(forKey: DefaultsKey.notchAppPanel) ? .island : .menuBar
        return available(in: defaults).contains(requested) ? requested : .none
    }

    func save(in defaults: UserDefaults) {
        defaults.set(self == .none, forKey: Self.disabledKey)
        defaults.set(self == .island, forKey: DefaultsKey.notchAppPanel)
    }

    static func reconcile(in defaults: UserDefaults) {
        if selected(in: defaults) == .none { Self.none.save(in: defaults) }
    }
}
