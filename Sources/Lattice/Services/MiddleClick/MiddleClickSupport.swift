// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// What to do with an incoming physical trackpad press.
enum MiddleClickClickAction: Equatable {
    case transform
    case passThrough
    /// A second synthesized click right on the heels of a transformed one
    /// (tap-to-click fires an extra click as the fingers release): passing it
    /// through would open in the same tab, transforming it would open a
    /// second tab, so it is dropped.
    case swallow
}

enum MiddleClickSupport {
    /// How recent the last contact frame must be for its finger count to
    /// describe "now". Frames stream continuously while fingers touch the
    /// trackpad, so anything older means the fingers already lifted.
    static let fingerFreshness: TimeInterval = 0.25

    /// The fingers must have been resting this long before the press: a
    /// click that arrives together with the last finger's touchdown is a
    /// synthesized tap-to-click, not a press (a real press needs the fingers
    /// on the pad before the force builds up).
    static let minimumSettle: TimeInterval = 0.04

    /// Window after a transformed click in which another qualifying click is
    /// treated as a synthesizer bounce and dropped.
    static let repeatGuard: TimeInterval = 0.30

    /// Decides what an incoming press becomes. Only real presses count
    /// (owner decision: taps, swipes and resting fingers must never click),
    /// and while the system's own three-finger drag gesture is enabled it
    /// owns three-finger touches: it synthesizes clicks from unpressed
    /// contact that are indistinguishable from real presses here, so the
    /// press moves to four fingers (issue #2061). Look Up's three-finger tap
    /// synthesizes no press, so it leaves the press alone.
    /// `clickFingers` is the user's chosen count, 3 (default) or 4. A Radial
    /// Menu that opens on the four-finger click takes four from it.
    static func actionForClick(fingerCount: Int,
                               frameAge: TimeInterval,
                               settledFor: TimeInterval,
                               sinceLastTransformEnd: TimeInterval?,
                               systemDragGestureEnabled: Bool,
                               clickFingers: Int = 3,
                               radialGesture: RadialMenuTrackpadGesture = .off) -> MiddleClickClickAction {
        let pressFingers = effectiveClickFingers(stored: clickFingers,
                                                 systemDragEnabled: systemDragGestureEnabled,
                                                 radialGesture: radialGesture)
        guard pressFingers != 0, fingerCount == pressFingers, frameAge >= 0, frameAge <= fingerFreshness else {
            return .passThrough
        }
        if let sinceLastTransformEnd, sinceLastTransformEnd >= 0,
           sinceLastTransformEnd < repeatGuard {
            return .swallow
        }
        guard settledFor >= minimumSettle else { return .passThrough }
        return .transform
    }

    /// The press always has a finger count; three-finger drag owning three
    /// fingers moves it to four rather than switching it off.
    static func availableClickSelection(_ stored: Int, systemDragEnabled: Bool) -> Int {
        stored == 4 || systemDragEnabled ? 4 : 3
    }

    // MARK: - Tap to middle click (issue #161, opt-in)

    /// A touch that lasts longer than this is a rest or a press, not a tap.
    static let tapMaxDuration: TimeInterval = 0.35

    /// How far the fingers' average position may travel (normalized trackpad
    /// units, 0...1 across the pad) before the touch counts as a swipe. Space
    /// switching and Mission Control travel far past this.
    static let tapMovementLimit: Float = 0.03

    /// How much the fingers' spread (mean distance from their centroid) may
    /// change before the touch counts as a pinch. A pinch or spread keeps the
    /// centroid still, so the movement limit alone would let Launchpad and
    /// show-desktop gestures fire a phantom middle click.
    static let tapSpreadChangeLimit: Float = 0.04

    /// Briefly ignore tap candidates after ordinary typing so incidental
    /// trackpad contact cannot move focus while the user is entering text.
    static let tapKeyboardIdle: TimeInterval = 0.5

    /// The tap the Settings picker shows. A three-finger tap belongs to
    /// macOS while it uses one (three-finger drag, or Look Up on a
    /// three-finger tap), so a saved three reads as off until it is free.
    static func availableTapSelection(_ stored: Int, systemOwnsThreeFingerTap: Bool) -> Int {
        stored == 3 && systemOwnsThreeFingerTap ? 0 : stored
    }

    /// Whether macOS answers a three-finger tap itself: three-finger drag,
    /// or Look Up & data detectors set to "Tap with Three Fingers" (stored
    /// as 2; 0 is off and 1 is the force click).
    static func systemOwnsThreeFingerTap(threeFingerDrag: Bool, lookUpTapGesture: Int) -> Bool {
        threeFingerDrag || lookUpTapGesture == 2
    }

    static func tapShouldFire(duration: TimeInterval,
                              maxMovement: Float,
                              maxSpreadChange: Float,
                              exceededFingerCount: Bool,
                              buttonPressedDuring: Bool,
                              positionUnavailable: Bool,
                              systemOwnsThreeFingerTap: Bool,
                              tapFingers: Int,
                              secondsSinceLastKeyDown: TimeInterval = .infinity) -> Bool {
        guard tapFingers == 3 || tapFingers == 4 else { return false }
        guard !exceededFingerCount, !buttonPressedDuring, !positionUnavailable else { return false }
        guard secondsSinceLastKeyDown >= tapKeyboardIdle else { return false }
        guard duration > 0, duration <= tapMaxDuration else { return false }
        guard maxMovement <= tapMovementLimit else { return false }
        guard maxSpreadChange <= tapSpreadChangeLimit else { return false }
        if tapFingers == 3, systemOwnsThreeFingerTap { return false }
        return true
    }

    // MARK: - Radial Menu precedence

    /// The finger count of the Radial Menu's trackpad gesture, or 0 for none.
    /// Only four fingers: three belong to Look Up and three-finger drag. It
    /// never depends on Middle Click: the menu takes precedence there.
    static func radialMenuGestureFingers(radialGesture: RadialMenuTrackpadGesture) -> Int {
        radialGesture == .off ? 0 : 4
    }

    /// The tap Middle Click really answers. macOS owning the three-finger
    /// tap turns a saved three off; the Radial Menu's four-finger tap turns
    /// a saved four off. The saved choice itself is never rewritten.
    static func effectiveTapFingers(stored: Int, systemOwnsThreeFingerTap: Bool,
                                    radialGesture: RadialMenuTrackpadGesture) -> Int {
        let available = availableTapSelection(stored, systemOwnsThreeFingerTap: systemOwnsThreeFingerTap)
        return available == 4 && radialGesture == .tap ? 0 : available
    }

    /// The press Middle Click really answers. With the Radial Menu on the
    /// four-finger click, a press at four moves to three when macOS leaves
    /// three free, and otherwise there is none (0).
    static func effectiveClickFingers(stored: Int, systemDragEnabled: Bool,
                                      radialGesture: RadialMenuTrackpadGesture) -> Int {
        let available = availableClickSelection(stored, systemDragEnabled: systemDragEnabled)
        guard available == 4, radialGesture == .click else { return available }
        return systemDragEnabled ? 0 : 3
    }

    /// Whether a physical press opens (or closes) the Radial Menu: four
    /// fingers that settled before the force built up, read from a fresh
    /// frame. Swipes and pinches carry no press, so they never get here.
    static func radialClickOpens(fingerCount: Int, frameAge: TimeInterval, settledFor: TimeInterval,
                                 radialGesture: RadialMenuTrackpadGesture) -> Bool {
        radialGesture == .click && fingerCount == 4
            && frameAge >= 0 && frameAge <= fingerFreshness
            && settledFor >= minimumSettle
    }
}
