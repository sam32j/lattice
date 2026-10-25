// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/// Native Magic Mouse tracking shares the music cue, but never sends haptics
/// to a separate trackpad. Generation checks reject late native callbacks.
final class NotchMusicMouseSwipeController {
    typealias NativeUpdate = (Double, NSEvent.Phase, Bool) -> Bool
    private var gesture = NotchMusicMouseSwipe()
    private let state: NotchMusicSwipeState
    private let commit: (Bool) -> Bool
    private let schedule: (TimeInterval, DispatchWorkItem) -> Void
    private var epoch: UInt64 = 0
    private var expiry: DispatchWorkItem?
    private var ownsPresentation = false

    init(state: NotchMusicSwipeState, schedule: @escaping (TimeInterval, DispatchWorkItem) -> Void,
         commit: @escaping (Bool) -> Bool) {
        self.state = state; self.schedule = schedule; self.commit = commit
    }

    deinit { expiry?.cancel() }

    func cancel() {
        epoch &+= 1
        expiry?.cancel(); expiry = nil
        gesture.cancel()
        if ownsPresentation { state.clear() }
        ownsPresentation = false
    }

    func handle(_ event: NSEvent, enabled: Bool, expanded: Bool, hasTouches: Bool) -> Bool {
        guard NSEvent.isSwipeTrackingFromScrollEventsEnabled else { cancel(); return false }
        return receive(x: Double(event.scrollingDeltaX), y: Double(event.scrollingDeltaY), phase: event.phase,
            precise: event.hasPreciseScrollingDeltas, momentum: !event.momentumPhase.isEmpty,
            enabled: enabled, expanded: expanded, hasTouches: hasTouches) { update in
                event.trackSwipeEvent(options: [.lockDirection], dampenAmountThresholdMin: -1, max: 1) {
                    amount, phase, complete, stop in
                    stop.pointee = ObjCBool(update(Double(amount), phase, complete))
                }
            }
    }

    /// Input and native-tracker callback are explicit boundaries for isolated
    /// tests; production supplies NSEvent's own swipe tracker above.
    @discardableResult
    func receive(x: Double, y: Double, phase: NSEvent.Phase, precise: Bool, momentum: Bool,
                 enabled: Bool, expanded: Bool, hasTouches: Bool,
                 track: (@escaping NativeUpdate) -> Void) -> Bool {
        if !enabled || hasTouches { cancel(); return false }
        if phase.contains(.began), gesture.tracking { cancel() }
        if gesture.tracking { return true }
        guard gesture.wheel(x: x, y: y, phase: phase, precise: precise, momentum: momentum,
                            enabled: enabled, hasTouches: hasTouches) != nil else { return false }
        epoch &+= 1
        let generation = epoch
        ownsPresentation = true
        renewExpiry(generation)
        track { [weak self] amount, phase, complete in
            guard let self, self.epoch == generation, self.gesture.tracking else { return true }
            let action = self.gesture.native(amount: amount, phase: phase, complete: complete)
            if let action {
                self.expiry?.cancel(); self.expiry = nil
                self.ownsPresentation = false
                if self.commit(action == .next) {
                    self.state.show(.init(direction: action, progress: 1, expanded: expanded), completed: true)
                } else { self.state.clear() }
                return true
            }
            guard self.gesture.tracking else { self.cancel(); return true }
            self.state.show(.init(direction: self.gesture.direction, progress: self.gesture.progress,
                                  expanded: expanded), held: true)
            self.renewExpiry(generation)
            return false
        }
        return true
    }

    private func renewExpiry(_ generation: UInt64) {
        expiry?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.epoch == generation else { return }
            self.cancel()
        }
        expiry = work
        schedule(3, work)
    }
}
