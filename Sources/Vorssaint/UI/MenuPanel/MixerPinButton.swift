// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import SwiftUI

struct MixerPinButton: View {
    let isPinned: Bool
    let pinTitle: String
    let unpinTitle: String
    let appName: String
    let action: () -> Void

    var symbolName: String { isPinned ? "pin.fill" : "pin" }
    var tint: Color { isPinned ? .blue : .secondary }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbolName).foregroundStyle(tint)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .help(isPinned ? unpinTitle : pinTitle)
        .accessibilityLabel("\(isPinned ? unpinTitle : pinTitle): \(appName)")
    }
}
