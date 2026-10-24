// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

/// A brief directional nudge acknowledges the command without predicting the
/// next track or waiting for the player's artwork. No repeating work survives it.
struct NotchMusicSwipeFeedback: ViewModifier {
    var enabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var trigger = 0
    @State private var direction: CGFloat = -1

    func body(content: Content) -> some View {
        let displacement = reduceMotion ? 0 : direction
        return content
            .keyframeAnimator(initialValue: CGFloat.zero, trigger: trigger) { view, travel in
                view.offset(x: displacement * travel)
            } keyframes: { _ in
                CubicKeyframe(8, duration: 0.09)
                SpringKeyframe(0, duration: 0.25, spring: .smooth)
            }
            .onReceive(NotchMusicService.shared.gestureSkips) { forward in
                guard enabled, !reduceMotion else { return }
                direction = forward ? -1 : 1
                trigger &+= 1
            }
    }
}

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


/// A title/artist notice stays swipeable, with its artwork giving way to the
/// same held cue as the compact visualizer. Both island silhouettes share it.
struct NotchMusicSwipeNoticeArtwork: View {
    let size: CGFloat
    var capsule = false
    @ObservedObject private var music = NotchMusicService.shared
    @ObservedObject private var swipe = NotchMusicSwipeState.shared
    @Environment(\.notchSettingsPreview) private var preview

    var body: some View {
        NotchMusicSwipeVisualizer(frame: preview ? .init() : swipe.frame, height: size) {
            if capsule {
                NotchMusicCover(artwork: music.artwork, side: size, radius: size * 0.24, source: music.playback?.track)
            } else {
                NotchArtwork(image: music.artwork, size: size, source: music.playback?.track)
            }
        }
    }
}
