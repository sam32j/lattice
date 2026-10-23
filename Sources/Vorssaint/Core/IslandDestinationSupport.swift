// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

enum IslandDestination: String {
    case clipboard, files, scratchpad

    var routeKey: String {
        switch self {
        case .clipboard: return DefaultsKey.notchClipboardWindow
        case .files: return DefaultsKey.notchShelf
        case .scratchpad: return DefaultsKey.notchScratchpad
        }
    }

    func isShown(in defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: routeKey)
            && !(defaults.string(forKey: DefaultsKey.notchHiddenModules) ?? "")
                .split(separator: ",").contains(Substring(rawValue))
    }

    func setShown(_ shown: Bool, in defaults: UserDefaults) {
        var hidden = Set((defaults.string(forKey: DefaultsKey.notchHiddenModules) ?? "")
            .split(separator: ",").map(String.init))
        if shown { hidden.remove(rawValue) } else { hidden.insert(rawValue) }
        defaults.set(shown, forKey: routeKey)
        defaults.set(hidden.sorted().joined(separator: ","), forKey: DefaultsKey.notchHiddenModules)
    }
}
