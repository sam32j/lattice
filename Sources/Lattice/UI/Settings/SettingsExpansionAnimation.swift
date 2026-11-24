// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

extension Animation {
    static let settingsExpansionDuration: TimeInterval = 0.18

    /// Matches the shortcut list's disclosure animation.
    static var settingsExpansion: Animation { .easeInOut(duration: settingsExpansionDuration) }
}

/// Collapses a burst of switch flips into one run of their work. Work that
/// may run at once does so when no burst is under way for its key; every
/// other flip replaces the pending work, which runs once the switch has been
/// left alone for a whole fold. Rapid clicking then costs one service sync
/// per burst instead of one per click, so the motion keeps its frame rate.
@MainActor
enum SettingsSwitchBursts {
    private struct Burst {
        var generation = 0
        var pending: (@MainActor () -> Void)?
    }

    private static var bursts: [String: Burst] = [:]
    static let settleDelay = Animation.settingsExpansionDuration + 0.05

    static func run(_ key: String, immediately: Bool, _ work: @escaping @MainActor () -> Void) {
        var burst = bursts[key] ?? Burst()
        if immediately, bursts[key] == nil {
            work()
        } else {
            burst.pending = work
        }
        burst.generation &+= 1
        bursts[key] = burst
        let generation = burst.generation
        DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay) {
            MainActor.assumeIsolated {
                guard let settled = bursts[key], settled.generation == generation else { return }
                bursts[key] = nil
                settled.pending?()
            }
        }
    }
}

/// Applies a feature switch to its service. Turning on applies at once, so
/// the rows unroll already filled in. Turning off waits for the rows to fold
/// away: they collapse showing their last state instead of flashing empty
/// values, and the teardown never holds up the start of the collapse.
/// Flips during a burst apply once, after it settles. The work should read
/// the current preference, so a switch flipped back before the delay ends
/// simply re-applies what is on.
@MainActor
func settingsApplyFeatureSwitch(enabled: Bool, key: String = "\(#fileID):\(#line)",
                                _ apply: @escaping @MainActor () -> Void) {
    SettingsSwitchBursts.run(key, immediately: enabled, apply)
}

/// Runs a switch's system work once its knob has finished sliding, in both
/// directions. For switches with no rows to fill in, whose work talks to
/// the system on the main thread (device properties, for one) and would
/// otherwise freeze the knob part-way. The work should read the current
/// preference, so a quick flip back simply applies what is on.
@MainActor
func settingsApplyAfterSwitch(key: String = "\(#fileID):\(#line)", _ apply: @escaping @MainActor () -> Void) {
    SettingsSwitchBursts.run(key, immediately: false, apply)
}

private struct SettingsExpansionAnimation<Value: Equatable>: ViewModifier {
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : .settingsExpansion, value: value)
    }
}

/// Clips a container to its shape only while its height is changing, so
/// rows folding away at its bottom edge are masked by that edge instead of
/// fading over the rows sliding up beneath it. Once the height settles, the
/// clip lifts again, so control borders, Liquid Glass lenses, and floating
/// tooltips can reach past the container at rest.
private struct SettingsClipsWhileResizing<ClipShape: Shape>: ViewModifier {
    let shape: ClipShape
    @State private var height: CGFloat?
    @State private var isResizing = false
    /// Bumped on every height change, so only the latest change's
    /// completion lifts the clip.
    @State private var resizeGeneration = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .clipShape(isResizing ? AnyShape(shape) : AnyShape(SettingsUnclippedShape()))
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { newHeight in
                defer { height = newHeight }
                guard let height, abs(height - newHeight) > 0.5, !reduceMotion else { return }
                resizeGeneration &+= 1
                let generation = resizeGeneration
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { isResizing = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + Animation.settingsExpansionDuration + 0.04) {
                    if resizeGeneration == generation {
                        withTransaction(transaction) { isResizing = false }
                    }
                }
            }
    }
}

/// A clip well past anything a control draws outside its card, standing in
/// for "no clip" so the view's identity, and any focused field inside it,
/// stays the same when the real clip comes and goes.
private struct SettingsUnclippedShape: Shape {
    static func path(around rect: CGRect) -> Path {
        Path(rect.insetBy(dx: -400, dy: -400))
    }

    func path(in rect: CGRect) -> Path {
        Self.path(around: rect)
    }
}

/// Opens a window onto revealed rows from the top down, `fraction` of their
/// height at a time. Fully open, it stands back, so control borders, Liquid
/// Glass lenses, and floating tooltips can reach past the rows at rest.
private struct SettingsRevealShape: Shape {
    var fraction: CGFloat

    var animatableData: CGFloat {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard fraction < 1 else { return SettingsUnclippedShape.path(around: rect) }
        return Path(CGRect(x: rect.minX - 28, y: rect.minY - 36,
                           width: rect.width + 56, height: 36 + rect.height * max(fraction, 0)))
    }
}

private struct SettingsRevealModifier: ViewModifier {
    let fraction: CGFloat

    func body(content: Content) -> some View {
        content.clipShape(SettingsRevealShape(fraction: fraction))
    }
}

extension AnyTransition {
    /// For rows an `if` inserts or removes inside a card. The rows unroll
    /// from under the row above and roll back up under it as the rows below
    /// slide over their place, instead of fading on top of those rows. Put
    /// it on a single view holding every row of the block, laid out with the
    /// parent stack's spacing, so the block folds as one. Pair it with
    /// `settingsExpansionAnimation(value:)` on the page, keyed on the same
    /// condition, which supplies the motion.
    static var settingsReveal: AnyTransition {
        .modifier(active: SettingsRevealModifier(fraction: 0),
                  identity: SettingsRevealModifier(fraction: 1))
            .combined(with: .opacity)
    }
}

extension View {
    /// Masks rows folding away at this container's edge while it resizes,
    /// and leaves overflow unclipped once it settles.
    func settingsClipsWhileResizing<ClipShape: Shape>(to shape: ClipShape) -> some View {
        modifier(SettingsClipsWhileResizing(shape: shape))
    }

    /// Apply at the page boundary so cards and following rows animate together.
    func settingsExpansionAnimation<Value: Equatable>(value: Value) -> some View {
        modifier(SettingsExpansionAnimation(value: value))
    }
}
