// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

extension Animation {
    /// Matches the shortcut list's disclosure animation.
    static var settingsExpansion: Animation { .easeInOut(duration: 0.18) }
}

private struct SettingsExpansionAnimation<Value: Equatable>: ViewModifier {
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : .settingsExpansion, value: value)
    }
}

extension View {
    /// Apply at the page boundary so cards and following rows animate together.
    func settingsExpansionAnimation<Value: Equatable>(value: Value) -> some View {
        modifier(SettingsExpansionAnimation(value: value))
    }
}
