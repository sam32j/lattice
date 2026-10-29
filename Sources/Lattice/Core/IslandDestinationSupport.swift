// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

enum IslandDestination: String {
    case clipboard, files, scratchpad
    case cameraPreview = "camera"
    case launcherGrid = "hub"
    case videoDownloader
    case textSnippets = "snippets"

    private var hiddenKeys: [String] {
        self == .launcherGrid ? [rawValue, "tools"] : [rawValue]
    }

    var routeKey: String {
        switch self {
        case .clipboard: return DefaultsKey.notchClipboardWindow
        case .files: return DefaultsKey.notchShelf
        case .scratchpad: return DefaultsKey.notchScratchpad
        case .cameraPreview: return DefaultsKey.notchCameraEnabled
        case .launcherGrid: return DefaultsKey.notchQuickPanel
        case .videoDownloader: return DefaultsKey.notchVideoDownloader
        case .textSnippets: return DefaultsKey.notchSnippetsWindow
        }
    }

    func isShown(in defaults: UserDefaults) -> Bool {
        let hidden = Set((defaults.string(forKey: DefaultsKey.notchHiddenModules) ?? "")
            .split(separator: ",").map(String.init))
        let isHidden = hiddenKeys.contains { hidden.contains($0) }
        return (defaults.object(forKey: routeKey) as? Bool ?? true) && !isHidden
    }

    func setShown(_ shown: Bool, in defaults: UserDefaults) {
        var hidden = Set((defaults.string(forKey: DefaultsKey.notchHiddenModules) ?? "")
            .split(separator: ",").map(String.init))
        if shown {
            for key in hiddenKeys { hidden.remove(key) }
        } else {
            hidden.insert(rawValue)
        }
        defaults.set(shown, forKey: routeKey)
        defaults.set(hidden.sorted().joined(separator: ","), forKey: DefaultsKey.notchHiddenModules)
    }
}
