// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// Uses the real SF Symbols microphone artwork, so the slash retains Apple's
/// correct top-left-to-bottom-right geometry. Both Hub and Island use it.
struct AnimatedMicMuteSymbol: View, Equatable {
    let muted: Bool
    var warning = false
    let fontSize: CGFloat
    var weight: Font.Weight = .semibold
    var animateInitialChange = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var initialKickDone = false

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.muted == rhs.muted
            && lhs.warning == rhs.warning
            && lhs.fontSize == rhs.fontSize
            && lhs.weight == rhs.weight
            && lhs.animateInitialChange == rhs.animateInitialChange
    }

    private var renderedSymbol: String {
        if warning { return "exclamationmark.triangle" }
        let effectiveMuted = (animateInitialChange && !reduceMotion && !initialKickDone) ? !muted : muted
        return effectiveMuted ? "mic.slash.fill" : "mic.fill"
    }

    var body: some View {
        Image(systemName: renderedSymbol)
            .font(.system(size: fontSize, weight: weight))
            .frame(minWidth: ceil(fontSize * 1.25), alignment: .center)
            .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.26), value: renderedSymbol)
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
