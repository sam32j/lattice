// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

struct NotchMusicSwipeBackdrop: View {
    let direction: NotchMusicTrackSwipe.Direction
    let frame: NotchMusicSwipeState.Frame
    let size: CGFloat
    var reduceMotionOverride: Bool? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var usesReducedMotion: Bool { reduceMotionOverride ?? reduceMotion }
    private var progress: Double {
        frame.expanded && frame.direction == direction ? frame.progress : 0
    }

    var body: some View {
        Circle()
            .fill(.white.opacity(0.24))
            .frame(width: size, height: size)
            .scaleEffect(usesReducedMotion ? 1 : 0.4 + 0.6 * progress)
            .opacity(progress)
            .animation(.easeOut(duration: 0.12), value: progress)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Shared by the live compact strip and the isolated rendering fixture.
struct NotchMusicSwipeVisualizer<Content: View>: View {
    let frame: NotchMusicSwipeState.Frame
    let height: CGFloat
    var reduceMotionOverride: Bool? = nil
    @ViewBuilder var content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var usesReducedMotion: Bool { reduceMotionOverride ?? reduceMotion }
    private var amount: Double { frame.expanded || frame.direction == nil ? 0 : frame.progress }

    var body: some View {
        content().opacity(1 - amount)
        .overlay {
            if let direction = frame.direction, !frame.expanded {
                Image(systemName: direction == .next ? "forward.fill" : "backward.fill")
                    .font(.system(size: min(14, height), weight: .semibold))
                    .foregroundStyle(.white)
                    .opacity(amount)
                    .scaleEffect(usesReducedMotion ? 1 : 0.65 + amount * 0.35)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .animation(.easeOut(duration: 0.12), value: amount)
    }
}
