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

/// Keeps the follow-up rows laid out and opens a clipped window onto them,
/// so they unroll from under the row above instead of fading in on top of
/// the rows that are still sliding down.
private struct SettingsCollapsible: ViewModifier {
    let isExpanded: Bool
    @State private var contentHeight: CGFloat?

    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            // Until the first measurement, an open group takes its natural
            // height so it never flashes shut on first render.
            .frame(height: isExpanded ? contentHeight : 0, alignment: .top)
            .clipped()
            .opacity(isExpanded ? 1 : 0)
            .allowsHitTesting(isExpanded)
            .accessibilityHidden(!isExpanded)
    }
}

extension View {
    /// Apply at the page boundary so cards and following rows animate together.
    func settingsExpansionAnimation<Value: Equatable>(value: Value) -> some View {
        modifier(SettingsExpansionAnimation(value: value))
    }

    /// Reveals follow-up rows as an accordion. Pair it with
    /// `settingsExpansionAnimation(value:)` on the page, keyed on the same
    /// condition, which supplies the motion.
    func settingsCollapsible(isExpanded: Bool) -> some View {
        modifier(SettingsCollapsible(isExpanded: isExpanded))
    }
}
