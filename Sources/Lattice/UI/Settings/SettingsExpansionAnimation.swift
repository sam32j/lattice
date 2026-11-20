// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

extension Animation {
    static let settingsExpansionDuration: TimeInterval = 0.18

    /// Matches the shortcut list's disclosure animation.
    static var settingsExpansion: Animation { .easeInOut(duration: settingsExpansionDuration) }
}

/// Applies a feature switch to its service. Turning on applies at once, so
/// the rows unroll already filled in. Turning off waits for the rows to fold
/// away: they collapse showing their last state instead of flashing empty
/// values, and the teardown never holds up the start of the collapse.
/// The work should read the current preference, so a switch flipped back
/// before the delay ends simply re-applies what is on.
@MainActor
func settingsApplyFeatureSwitch(enabled: Bool, _ apply: @escaping @MainActor () -> Void) {
    guard !enabled else { apply(); return }
    DispatchQueue.main.asyncAfter(deadline: .now() + Animation.settingsExpansionDuration + 0.05) {
        MainActor.assumeIsolated { apply() }
    }
}

/// Runs a switch's system work once its knob has finished sliding, in both
/// directions. For switches with no rows to fill in, whose work talks to
/// the system on the main thread (device properties, for one) and would
/// otherwise freeze the knob part-way. The work should read the current
/// preference, so a quick flip back simply applies what is on.
@MainActor
func settingsApplyAfterSwitch(_ apply: @escaping @MainActor () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + Animation.settingsExpansionDuration + 0.05) {
        MainActor.assumeIsolated { apply() }
    }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                // Rows growing or shrinking inside an open group animate
                // there; the window follows at the same pace instead of
                // snapping to the final height on the next frame.
                let animates = contentHeight != nil && isExpanded && !reduceMotion
                withAnimation(animates ? .settingsExpansion : nil) { contentHeight = height }
            }
            // Until the first measurement, an open group takes its natural
            // height so it never flashes shut on first render.
            .frame(height: isExpanded ? contentHeight : 0, alignment: .top)
            .clipped()
            .opacity(isExpanded ? 1 : 0)
            .allowsHitTesting(isExpanded)
            // Folded rows stay laid out; disabling them keeps Tab and Space
            // from reaching controls nobody can see.
            .disabled(!isExpanded)
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
