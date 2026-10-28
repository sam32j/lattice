// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum LauncherShortcutTarget: String, CaseIterable {
    case island = "island"
    case floatingWindow = "floatingWindow"

    static func selected(in defaults: UserDefaults = .standard) -> LauncherShortcutTarget {
        guard let raw = defaults.string(forKey: DefaultsKey.launcherShortcutTarget),
              let target = LauncherShortcutTarget(rawValue: raw) else {
            return .island
        }
        return target
    }
}
