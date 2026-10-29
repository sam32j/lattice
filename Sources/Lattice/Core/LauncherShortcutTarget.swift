// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum LauncherShortcutTarget: String, CaseIterable {
    case automatic = "automatic"
    case floatingWindow = "floatingWindow"

    static let island = LauncherShortcutTarget.automatic

    init?(rawValue: String) {
        switch rawValue {
        case "automatic", "island":
            self = .automatic
        case "floatingWindow":
            self = .floatingWindow
        default:
            return nil
        }
    }

    static func selected(in defaults: UserDefaults = .standard) -> LauncherShortcutTarget {
        guard let raw = defaults.string(forKey: DefaultsKey.launcherShortcutTarget),
              let target = LauncherShortcutTarget(rawValue: raw) else {
            return .automatic
        }
        return target
    }
}
