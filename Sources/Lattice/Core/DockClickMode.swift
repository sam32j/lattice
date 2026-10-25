// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Exactly one tile is represented by the three existing activation flags.
/// No new preference domain or install flag is introduced.
enum DockClickMode: CaseIterable {
    case off, toggleWindows, hideApps, cycleWindows

    static func selected(in defaults: UserDefaults) -> Self {
        if defaults.bool(forKey: DefaultsKey.dockClickCycleWindows) { return .cycleWindows }
        if defaults.bool(forKey: DefaultsKey.dockClickHide) { return .hideApps }
        if defaults.bool(forKey: DefaultsKey.dockClickMinimize) { return .toggleWindows }
        return .off
    }

    func store(in defaults: UserDefaults) {
        defaults.set(self == .toggleWindows, forKey: DefaultsKey.dockClickMinimize)
        defaults.set(self == .hideApps, forKey: DefaultsKey.dockClickHide)
        defaults.set(self == .cycleWindows, forKey: DefaultsKey.dockClickCycleWindows)
    }

    var symbol: String {
        switch self {
        case .off: return "power"
        case .toggleWindows: return "dock.arrow.down.rectangle"
        case .hideApps: return "eye.slash"
        case .cycleWindows: return "arrow.triangle.2.circlepath"
        }
    }
}
