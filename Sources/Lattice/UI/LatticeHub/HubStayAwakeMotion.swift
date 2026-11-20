// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import CoreGraphics
import Foundation

/// The Stay Awake toggle's arrival and departure, worked out frame by frame
/// rather than left to SwiftUI transitions, which the Hub and Island hosts can
/// suppress or double up.
///
/// Starting: the countdown comes out from behind the separator (its leading
/// edge starts right at it) and slides left while the bolt drifts from the
/// centre to make room. Both follow one spring, so the bolt, with the shorter
/// way to go, moves slower and the gap between them closes as they travel.
/// Stopping: the countdown fades where it is and the bolt eases back to the
/// centre.
enum HubStayAwakeMotion {
    /// The whole motion; the curve below lands exactly on its target here.
    static let duration: TimeInterval = 0.8

    /// A critically damped spring, rescaled to reach exactly 1 at `duration`:
    /// eased in, gliding out, and never past the target. An overshoot creeping
    /// back, then snapping to the resting place, read as a last-moment glitch.
    static func spring(_ elapsed: TimeInterval, response: Double = 0.6) -> Double {
        guard elapsed > 0 else { return 0 }
        guard elapsed < duration else { return 1 }
        let omega = 2 * Double.pi / response
        func settle(_ t: Double) -> Double { 1 - (1 + omega * t) * exp(-omega * t) }
        return min(1, settle(elapsed) / settle(duration))
    }

    /// 0 before `lower`, 1 after `upper`, an eased ramp between.
    static func ramp(_ value: CGFloat, from lower: CGFloat, to upper: CGFloat) -> CGFloat {
        let x = min(1, max(0, (value - lower) / (upper - lower)))
        return x * x * (3 - 2 * x)
    }

    struct Frame: Equatable {
        /// Added to the bolt's place in the settled, countdown-showing layout.
        var boltOffset: CGFloat
        /// Added to the countdown's settled place.
        var countdownOffset: CGFloat
        var countdownOpacity: Double
        /// How far the toggle's tint has come in: 0 off to 1 on.
        var tint: Double
        /// How far the filled bolt has replaced the outline one. It completes
        /// mid-slide, so nothing about the icon changes in the final stretch.
        var boltFill: Double
        /// The countdown's size about its own centre; it shrinks away as it
        /// fades out on a stop.
        var countdownScale: CGFloat = 1
    }

    /// The settled frame when no motion runs.
    static func resting(active: Bool) -> Frame {
        Frame(boltOffset: 0, countdownOffset: 0, countdownOpacity: active ? 1 : 0,
              tint: active ? 1 : 0, boltFill: active ? 1 : 0)
    }

    /// One frame of the motion, measured in the settled layout that shows the
    /// countdown, centred in a stage whose right edge is the separator.
    static func frame(starting: Bool, elapsed: TimeInterval,
                      stageWidth: CGFloat, boltWidth: CGFloat,
                      countdownWidth: CGFloat, gap: CGFloat) -> Frame {
        let progress = CGFloat(spring(elapsed))
        // From its settled place, the bolt sits this far left of the centre.
        let boltShift = (gap + countdownWidth) / 2
        if starting {
            let content = boltWidth + gap + countdownWidth
            let settledLeading = (stageWidth - content) / 2 + boltWidth + gap
            // Starts flush behind the separator, a point past so no sliver shows.
            let entry = max(0, stageWidth - settledLeading) + 1
            return Frame(boltOffset: boltShift * (1 - progress),
                         countdownOffset: entry * (1 - progress),
                         countdownOpacity: 1,
                         tint: Double(progress),
                         boltFill: Double(ramp(progress, from: 0.1, to: 0.6)))
        }
        // The number fades and shrinks away together, gone well before the
        // bolt arrives back at the centre.
        let away = ramp(progress, from: 0, to: 0.6)
        return Frame(boltOffset: boltShift * progress,
                     countdownOffset: 0,
                     countdownOpacity: Double(1 - away),
                     tint: Double(1 - progress),
                     boltFill: Double(1 - ramp(progress, from: 0, to: 0.45)),
                     countdownScale: 1 - 0.4 * away)
    }
}
