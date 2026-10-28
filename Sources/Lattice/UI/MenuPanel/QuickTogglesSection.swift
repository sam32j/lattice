// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The quick toggles bridge for the menu panel.
struct QuickTogglesSection: View {
    @ObservedObject private var l10n = L10n.shared
    var collapsible = true
    var notchSize: CGSize? = nil

    var body: some View {
        EmptyView()
    }

    private func shortcutHint(_ role: GlobalShortcutRole) -> String? {
        guard role.savedShortcut.isValid,
              role.requiredEnableKeys.allSatisfy({ UserDefaults.standard.bool(forKey: $0) })
        else { return nil }
        return role.savedShortcut.displayString
    }
}
