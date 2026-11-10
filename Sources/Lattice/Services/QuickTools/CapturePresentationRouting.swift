// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Shared routing for capture previews, Recent Captures, and future media HUDs.
/// Source context is explicit: a UI click inherits its surface in Automatic,
/// while shortcuts/commands follow General > Prefer Lattice opens at.
enum CapturePresentationRouting {
    enum Preference: String, CaseIterable {
        case automatic, dynamicIsland, floatingWindow
    }

    enum Origin {
        case dynamicIsland
        case floatingWindow
        case external
    }

    enum Destination: Equatable {
        case dynamicIsland
        case floatingWindow
    }

    static func preference(in defaults: UserDefaults = .standard) -> Preference {
        Preference(rawValue: defaults.string(forKey: DefaultsKey.capturePresentationDestination) ?? "")
            ?? .automatic
    }

    static func destination(origin: Origin,
                            preference: Preference = CapturePresentationRouting.preference(),
                            islandAvailable: Bool = NotchSupport.routesCapturePreviews(),
                            latticePreference: LauncherShortcutTarget = LauncherShortcutTarget.selected()) -> Destination {
        guard islandAvailable else { return .floatingWindow }
        switch preference {
        case .automatic:
            // A click stays on the surface the person is using. External
            // triggers follow General > Prefer Lattice opens at instead of
            // assuming that the Dynamic Island is preferred.
            switch origin {
            case .dynamicIsland: return .dynamicIsland
            case .floatingWindow: return .floatingWindow
            case .external:
                return latticePreference == .floatingWindow ? .floatingWindow : .dynamicIsland
            }
        case .dynamicIsland: return .dynamicIsland
        case .floatingWindow: return .floatingWindow
        }
    }

    static func opensInIsland(origin: Origin) -> Bool {
        destination(origin: origin) == .dynamicIsland
    }
}
