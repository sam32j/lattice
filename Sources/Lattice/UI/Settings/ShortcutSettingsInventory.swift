// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

extension ShortcutsSettings {
    var availableRoles: [GlobalShortcutRole] {
        GlobalShortcutRole.availableRoles(isAvailable: { feature in
            switch feature {
            case .clipboardHistory, .shelf, .cameraPreview, .quickLauncher, .scratchpad:
                return feature.isAvailable
            default:
                return feature.isVisibleInSettings(isAvailable: { $0.isAvailable })
            }
        }).filter {
            !$0.isKeyboardBrightness || BrightnessService.keyboardLightIsSupported
        }
    }
}
