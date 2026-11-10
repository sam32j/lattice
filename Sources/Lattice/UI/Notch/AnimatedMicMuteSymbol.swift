// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

/// Uses the real SF Symbols microphone artwork, so the slash retains Apple's
/// correct top-left-to-bottom-right geometry. Both Hub and Island use it.
struct AnimatedMicMuteSymbol: View {
    let muted: Bool
    let fontSize: CGFloat
    var weight: Font.Weight = .semibold
    var animateInitialChange = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedMuted: Bool?

    private var renderedMuted: Bool {
        displayedMuted ?? (animateInitialChange && !reduceMotion ? !muted : muted)
    }

    var body: some View {
        Image(systemName: renderedMuted ? "mic.slash.fill" : "mic.fill")
            .font(.system(size: fontSize, weight: weight))
            .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.26), value: renderedMuted)
            .task {
                guard displayedMuted == nil else { return }
                if animateInitialChange && !reduceMotion {
                    await Task.yield()
                    guard displayedMuted == nil else { return }
                    withAnimation(.easeInOut(duration: 0.26)) { displayedMuted = muted }
                } else {
                    displayedMuted = muted
                }
            }
            .onChange(of: muted) { _, newValue in
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.26)) {
                    displayedMuted = newValue
                }
            }
    }
}
