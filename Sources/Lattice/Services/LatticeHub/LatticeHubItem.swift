// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation
import SwiftUI

/// Pure workflow utilities hosted in Lattice Hub.
enum LatticeHubItem: String, PanelOrderItem, Identifiable {
    case screenshot, cleaner, uninstaller, clipboard, windowLayout,
         media, urlCleaner, cameraPreview, scratchpad, screenRecorder,
         homebrew, appUpdates, portManager

    var id: String { rawValue }

    func isAvailable(in defaults: UserDefaults = .standard) -> Bool {
        feature.isAvailable(in: defaults)
    }

    /// The hub feature behind the tile; off in the hub removes it from the
    /// grid, the hidden list and edit mode until it returns.
    var feature: AppFeature {
        switch self {
        case .screenshot: return .screenshot
        case .cleaner: return .cleaner
        case .uninstaller: return .uninstaller
        case .clipboard: return .clipboardHistory
        case .windowLayout: return .windowLayout
        case .media: return .mediaTools
        case .urlCleaner: return .urlCleaner
        case .cameraPreview: return .cameraPreview
        case .scratchpad: return .scratchpad
        case .screenRecorder: return .screenRecorder
        case .homebrew: return .homebrew
        case .appUpdates: return .appUpdates
        case .portManager: return .portManager
        }
    }
}
