// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// One decision per physical scroll sequence. No timer is needed for wheel
/// devices without phases: the next event itself expires an old sequence.
struct NotchGestureSupport {
    enum Action: Equatable { case open, close }
    private enum Axis { case horizontal, vertical }
    private struct Origin {
        let vertical: Bool
        let horizontal: Bool
        let expanded: Bool
        let deepDismiss: Bool
    }
    private var origin: Origin?
    private var axis: Axis?
    private var pendingX = 0.0
    private var pendingY = 0.0
    private var distance = 0.0
    private var currentExpanded = false
    private var hasFiredAction = false
    private var coasting = false
    private var lastTimestamp: TimeInterval?
    static let verticalThreshold = 16.0
    /// 3/4 inch at 72 physical points per inch, required when swiping up over
    /// the main window's controls, toggles, or utility section to prevent accidental dismissals.
    static let deepVerticalThreshold = 54.0

    static func nativeInteraction(at view: NSView?) -> (control: Bool, scroll: Bool) {
        var control = false
        var scroll = false
        var view = view
        while let current = view {
            // The transparent opening button is the gesture surface itself.
            if (current is NSControl && !(current is NotchActivationButton)) || current is NSTextView {
                control = true
            }
            if current is NSScrollView { scroll = true }
            view = current.superview
        }
        return (control, scroll)
    }

    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        NotchSupport.isEnabled(in: defaults) && AppFeature.notchGestures.isAvailable(in: defaults)
            && defaults.bool(forKey: DefaultsKey.notchGesturesEnabled)
    }

    static func movement(_ delta: Double, precise: Bool, inverted: Bool) -> Double {
        guard delta.isFinite else { return 0 }
        return delta * (inverted ? 1 : -1) * (precise ? 1 : 24)
    }

    static func allowsVertical(expanded: Bool, inHeader: Bool, musicSurface: Bool,
                               hubSurface: Bool = false,
                               control: Bool, scroll: Bool) -> Bool {
        !control && (!expanded || inHeader || (musicSurface && !scroll) || hubSurface)
    }

    mutating func handle(x: Double, y: Double, timestamp: TimeInterval,
                         began: Bool, ended: Bool, momentum: Bool, precise: Bool, hasPhase: Bool,
                         allowVertical: Bool, allowHorizontal: Bool, expanded: Bool,
                         deepDismiss: Bool = false) -> Action? {
        guard timestamp.isFinite, x.isFinite, y.isFinite else { self = Self(); return nil }
        // A quick flick lifts the fingers before the swipe has travelled far
        // enough. Its momentum can finish the opening or closing it began,
        // never a track change. Trackpads can send one phaseless event between
        // the lift and the momentum; it belongs to the same flick. Momentum
        // that pauses, or turns sideways like the end of a track swipe, stops.
        let transition = coasting && !momentum && !hasPhase && precise
            && lastTimestamp.map({ timestamp >= $0 && timestamp - $0 <= 0.35 }) == true
        if momentum || transition {
            guard coasting, !hasFiredAction, let origin, let last = lastTimestamp,
                  timestamp >= last, timestamp - last <= 0.35, abs(y) >= abs(x) * 1.5 else {
                self = Self(); return nil
            }
            lastTimestamp = timestamp
            distance += y
            return verticalAction(deepDismiss: origin.deepDismiss)
        }
        if ended {
            coasting = origin != nil && axis == .vertical && !hasFiredAction
            if coasting { lastTimestamp = timestamp } else { self = Self() }
            return nil
        }
        if coasting { self = Self() }
        if hasPhase {
            if began {
                self = Self()
                origin = Origin(vertical: allowVertical, horizontal: allowHorizontal,
                                expanded: expanded, deepDismiss: deepDismiss)
                currentExpanded = expanded
            }
            // AppKit keeps a phased scroll attached to its original view.
            // A blocked beginning stays blocked, and an interrupted sequence
            // cannot restart from a later changed event under another view.
            guard origin != nil else { return nil }
            if lastTimestamp.map({ timestamp < $0 }) == true { self = Self(); return nil }
        } else if origin != nil || began
                    || lastTimestamp.map({ timestamp < $0 || timestamp - $0 > 0.35 }) == true {
            self = Self()
            currentExpanded = expanded
        }
        lastTimestamp = timestamp
        let allowVertical = origin?.vertical ?? allowVertical
        let allowHorizontal = origin?.horizontal ?? allowHorizontal
        let deepDismiss = origin?.deepDismiss ?? deepDismiss
        if axis == nil {
            // Establish intent from a little accumulated travel, not the first
            // fraction of a point as the fingers touch the trackpad.
            pendingX += x
            pendingY += y
            if precise, allowHorizontal, abs(pendingX) >= 4, abs(pendingX) >= abs(pendingY) * 1.5 {
                axis = .horizontal
                distance = pendingX
            }
            else if allowVertical, abs(pendingY) >= 4, abs(pendingY) >= abs(pendingX) * 1.5 {
                axis = .vertical
                if currentExpanded {
                    distance = min(0, pendingY)
                } else {
                    distance = max(0, pendingY)
                }
            }
            else { return nil }
        } else {
            if axis == .vertical {
                if !currentExpanded {
                    if y > 0 {
                        distance = max(0, distance) + y
                    } else {
                        distance = max(0, distance + y)
                    }
                } else {
                    if y < 0 {
                        distance = min(0, distance) + y
                    } else {
                        distance = min(0, distance + y)
                    }
                }
            } else {
                distance += x
            }
        }
        switch axis {
        case .vertical where allowVertical:
            return verticalAction(deepDismiss: deepDismiss)
        default:
            return nil
        }
    }

    private mutating func verticalAction(deepDismiss: Bool) -> Action? {
        let threshold = (currentExpanded && distance < 0 && deepDismiss)
            ? Self.deepVerticalThreshold
            : Self.verticalThreshold
        guard abs(distance) >= threshold else { return nil }
        if distance > 0, !currentExpanded {
            currentExpanded = true
            distance = 0
            hasFiredAction = true
            return .open
        }
        if distance < 0, currentExpanded {
            currentExpanded = false
            distance = 0
            hasFiredAction = true
            return .close
        }
        return nil
    }
}
