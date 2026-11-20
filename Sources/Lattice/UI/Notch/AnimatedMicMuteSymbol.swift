// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// Uses the real SF Symbols microphone artwork, so the slash retains Apple's
/// correct top-left-to-bottom-right geometry. Both Hub and Island use it.
struct AnimatedMicMuteSymbol: View, Equatable {
    let muted: Bool
    let fontSize: CGFloat
    var weight: Font.Weight = .semibold
    var animateInitialChange = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var initialKickDone = false

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.muted == rhs.muted
            && lhs.fontSize == rhs.fontSize
            && lhs.weight == rhs.weight
            && lhs.animateInitialChange == rhs.animateInitialChange
    }

    private var renderedMuted: Bool {
        if animateInitialChange && !reduceMotion && !initialKickDone {
            return !muted
        }
        return muted
    }

    var body: some View {
        Image(systemName: renderedMuted ? "mic.slash.fill" : "mic.fill")
            .font(.system(size: fontSize, weight: weight))
            .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.26), value: renderedMuted)
            .transaction {
                if !reduceMotion {
                    $0.disablesAnimations = false
                }
            }
            .onAppear {
                guard animateInitialChange, !initialKickDone else { return }
                if reduceMotion {
                    initialKickDone = true
                } else {
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.26)) {
                            initialKickDone = true
                        }
                    }
                }
            }
    }
}
