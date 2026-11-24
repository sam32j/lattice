// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import CoreGraphics
import Foundation

/// The rules behind the profile tabs on the live menu's arc and in the
/// Settings editor: which tabs show, how stepping wraps, how scrolling turns
/// into steps, and how the list is reordered so the first tab stays the
/// primary profile.
enum RadialProfileTabs {
    /// The most tabs the arc shows at once: the current one and three on
    /// each side.
    static let maxVisible = 7

    struct VisibleTab: Equatable {
        let index: Int
        /// The outermost two of a window that does not show every profile.
        let faded: Bool
    }

    /// The tabs the arc draws, left to right. One profile draws no arc.
    static func visibleTabs(count: Int, current: Int) -> [VisibleTab] {
        guard count > 1 else { return [] }
        guard count > maxVisible else {
            return (0..<count).map { VisibleTab(index: $0, faded: false) }
        }
        let reach = maxVisible / 2
        return (-reach...reach).map { offset in
            VisibleTab(index: wrapped(current + offset, count: count), faded: abs(offset) == reach)
        }
    }

    /// The profile `step` tabs away, wrapping at both ends. Empty profiles
    /// stay in the cycle: their tab is still a place to go.
    static func index(from current: Int, step: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return wrapped(current + step, count: count)
    }

    /// The menu opens on the primary even when it is empty, as long as some
    /// profile has an action to switch to; with none anywhere it stays shut.
    static func canOpen(availableItemCounts: [Int]) -> Bool {
        availableItemCounts.contains { $0 > 0 }
    }

    /// Moves a profile to `destination` (an index in the list as it is now,
    /// the moved profile counted). Moving to 0 makes it the primary.
    static func moving(_ id: UUID, to destination: Int,
                       in profiles: [RadialMenuProfile]) -> [RadialMenuProfile] {
        guard let from = profiles.firstIndex(where: { $0.id == id }) else { return profiles }
        var result = profiles
        let profile = result.remove(at: from)
        result.insert(profile, at: min(max(destination, 0), result.count))
        return result
    }

    /// Moves a profile in front of another, the drop of a dragged tab on the
    /// tab it lands before. Nil appends it.
    static func moving(_ id: UUID, before target: UUID?,
                       in profiles: [RadialMenuProfile]) -> [RadialMenuProfile] {
        guard id != target, let from = profiles.firstIndex(where: { $0.id == id }) else { return profiles }
        var result = profiles
        let profile = result.remove(at: from)
        let destination = target.flatMap { target in result.firstIndex { $0.id == target } } ?? result.count
        result.insert(profile, at: destination)
        return result
    }

    static func makingPrimary(_ id: UUID, in profiles: [RadialMenuProfile]) -> [RadialMenuProfile] {
        moving(id, to: 0, in: profiles)
    }

    /// Deletes a profile, never the last one. Returns the list and the
    /// profile to select next: the one that took the deleted one's place, or
    /// the new last one.
    static func deleting(_ id: UUID, in profiles: [RadialMenuProfile])
        -> (profiles: [RadialMenuProfile], selected: UUID?)? {
        guard profiles.count > 1, let index = profiles.firstIndex(where: { $0.id == id }) else { return nil }
        var result = profiles
        result.remove(at: index)
        return (result, result[min(index, result.count - 1)].id)
    }

    /// The profile that becomes primary when the first tab is deleted.
    static func nextPrimary(afterDeleting id: UUID, in profiles: [RadialMenuProfile]) -> RadialMenuProfile? {
        guard profiles.first?.id == id, profiles.count > 1 else { return nil }
        return profiles[1]
    }

    /// Where each tab of the arc sits, as the angle range of its band's
    /// centre line (radians clockwise from twelve o'clock); the rounded ends
    /// reach `capHeight / 2` beyond it. `widths` are the tabs' full lengths,
    /// ends included. The run is centred over twelve o'clock and squeezed
    /// (gaps first) to stay inside `maxSpan`.
    static func arcSpans(widths: [CGFloat], radius: CGFloat, capHeight: CGFloat,
                         gap: CGFloat = 5, maxSpan: Double) -> [ClosedRange<Double>] {
        guard !widths.isEmpty, radius > 0 else { return [] }
        var spacing = gap
        let natural = widths.reduce(0, +) + gap * CGFloat(widths.count - 1)
        let limit = CGFloat(maxSpan) * radius
        if natural > limit, widths.count > 1 {
            spacing = max(0, gap - (natural - limit) / CGFloat(widths.count - 1))
        }
        let total = widths.reduce(0, +) + spacing * CGFloat(widths.count - 1)
        var run = -total / 2
        return widths.map { width in
            let start = Double((run + capHeight / 2) / radius)
            let end = Double((run + max(width - capHeight / 2, capHeight / 2 + 0.01)) / radius)
            run += width + spacing
            return start...max(start, end)
        }
    }

    /// The tab under a point given relative to the wheel's centre (dyUp
    /// towards the top), or nil off the arc's band. In a gap that two tabs'
    /// slack both reach, the nearer tab owns the point, the earlier on a tie,
    /// so hover, dwell and click always agree.
    static func tabIndex(dx: CGFloat, dyUp: CGFloat, spans: [Int: ClosedRange<Double>],
                         radius: CGFloat, capHeight: CGFloat, slack: CGFloat = 4) -> Int? {
        let distance = (dx * dx + dyUp * dyUp).squareRoot()
        guard abs(distance - radius) <= capHeight / 2 + slack, radius > 0 else { return nil }
        var angle = Double(RadialMenuGeometry.angle(dx: dx, dyUp: dyUp))
        if angle > .pi { angle -= 2 * .pi }
        let cap = Double((capHeight / 2 + slack) / radius)
        func gap(_ span: ClosedRange<Double>) -> Double {
            max(0, span.lowerBound - angle, angle - span.upperBound)
        }
        return spans.filter { gap($0.value) <= cap }
            .min { gap($0.value) != gap($1.value) ? gap($0.value) < gap($1.value) : $0.key < $1.key }?.key
    }

    private static func wrapped(_ value: Int, count: Int) -> Int {
        ((value % count) + count) % count
    }
}

/// Turns scrolling over the menu into profile steps: one per notch of a
/// mouse wheel; for a trackpad, one per 40 points of accumulated movement on
/// whichever axis moved more, then a short pause, with momentum ignored.
struct RadialProfileScrollAccumulator {
    static let continuousStep: CGFloat = 40
    static let cooldown: TimeInterval = 0.25

    private(set) var accumulated: CGFloat = 0
    private var lastStepAt: TimeInterval?

    /// -1 for the previous profile, +1 for the next, 0 for none yet.
    /// Scrolling down or right moves to the next one.
    mutating func step(deltaX: CGFloat, deltaY: CGFloat, isContinuous: Bool,
                       isMomentum: Bool, now: TimeInterval) -> Int {
        guard !isMomentum else { return 0 }
        let delta = abs(deltaY) >= abs(deltaX) ? deltaY : deltaX
        guard delta != 0 else { return 0 }
        guard isContinuous else {
            accumulated = 0
            return delta < 0 ? 1 : -1
        }
        if let lastStepAt, now - lastStepAt < Self.cooldown {
            accumulated = 0
            return 0
        }
        // A change of direction starts the count over.
        if accumulated != 0, (accumulated < 0) != (delta < 0) { accumulated = 0 }
        accumulated += delta
        guard abs(accumulated) >= Self.continuousStep else { return 0 }
        let result = accumulated < 0 ? 1 : -1
        accumulated = 0
        lastStepAt = now
        return result
    }

    mutating func reset() {
        accumulated = 0
    }
}
