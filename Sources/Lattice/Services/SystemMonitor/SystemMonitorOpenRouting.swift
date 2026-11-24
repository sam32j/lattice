// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Where a menu bar reading opens System Monitor, decided the way capture
/// previews are: a fixed choice goes where it says; Automatic follows
/// General > Prefer Lattice opens at, since the menu bar is neither surface.
/// Without the Dynamic Island, or with the menu bar hidden, Automatic uses
/// the floating window, which opens right under the reading.
enum SystemMonitorOpenRouting {
    enum Preference: String, CaseIterable {
        case automatic, floatingWindow, dynamicIsland
    }

    enum Destination: Equatable {
        case dynamicIsland
        case floatingWindow
    }

    static func preference(in defaults: UserDefaults = .standard) -> Preference {
        Preference(rawValue: defaults.string(forKey: DefaultsKey.systemMonitorOpenAt) ?? "") ?? .automatic
    }

    static func destination(preference: Preference,
                            islandAvailable: Bool,
                            menuBarHidden: Bool,
                            latticePreference: LauncherShortcutTarget) -> Destination {
        guard islandAvailable else { return .floatingWindow }
        switch preference {
        case .dynamicIsland: return .dynamicIsland
        case .floatingWindow: return .floatingWindow
        case .automatic:
            if menuBarHidden { return .floatingWindow }
            return latticePreference == .floatingWindow ? .floatingWindow : .dynamicIsland
        }
    }
}
