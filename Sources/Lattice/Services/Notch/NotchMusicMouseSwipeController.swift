// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/// Magic Mouse tracking shares the music cue, but never sends haptics
/// to a separate trackpad. Generation checks reject late native callbacks.
final class NotchMusicMouseSwipeController {
    typealias NativeUpdate = (Double, NSEvent.Phase, Bool) -> Bool
    private var gesture = NotchMusicMouseSwipe()
    private var recoveryGesture = NotchMusicMouseSwipe()
    private var receivedNativeUpdate = false
    private var receivedScrollBegin = false
    private var receivedScrollEnd = false
    private var ignoresRemainingScroll = false
    private let state: NotchMusicSwipeState
    private let commit: (Bool) -> Bool
    private let schedule: (TimeInterval, DispatchWorkItem) -> Void
    private var epoch: UInt64 = 0
    private var expiry: DispatchWorkItem?
    private var ownsPresentation = false
    private var usingFallback = false

    init(state: NotchMusicSwipeState, schedule: @escaping (TimeInterval, DispatchWorkItem) -> Void,
         commit: @escaping (Bool) -> Bool) {
        self.state = state; self.schedule = schedule; self.commit = commit
    }

    deinit { expiry?.cancel() }

    func cancel() {
        epoch &+= 1
        expiry?.cancel(); expiry = nil
        gesture.cancel()
        recoveryGesture.cancel()
        receivedNativeUpdate = false
        receivedScrollBegin = false
        receivedScrollEnd = false
        ignoresRemainingScroll = false
        usingFallback = false
        if ownsPresentation { state.clear() }
        ownsPresentation = false
    }

    /// Input and native-tracker callback are explicit boundaries for isolated
    /// tests; production supplies NSEvent's own swipe tracker above.
    @discardableResult
    func receive(x: Double, y: Double, phase: NSEvent.Phase, precise: Bool, momentum: Bool,
                 enabled: Bool, expanded: Bool, hasTouches: Bool,
                 nativeTracking: Bool = true,
                 track: (@escaping NativeUpdate) -> Void) -> Bool {
        if !enabled || hasTouches { cancel(); return false }
        // A mayBegin is trackpad evidence, but its terminal packet can be lost.
        // Retain the exclusion while input arrives; never latch it for the app's lifetime.
        defer {
            if gesture.excludesTrackpadSequence || recoveryGesture.excludesTrackpadSequence {
                renewExpiry(epoch)
            }
        }
        // Raw cancellation is terminal; AppKit need not send another Ended.
        if phase.contains(.cancelled) {
            let handled = gesture.tracking || recoveryGesture.tracking
            cancel()
            return handled
        }
        if !phase.isDisjoint(with: [.began, .mayBegin]) {
            ignoresRemainingScroll = false
            receivedScrollEnd = false
        }
        if phase.contains(.ended) { receivedScrollEnd = true }
        if ignoresRemainingScroll {
            if phase.contains(.ended) {
                ignoresRemainingScroll = false
                receivedScrollBegin = false
            }
            return false
        }
        let fallback = !nativeTracking
        if usingFallback != fallback { cancel() }
        usingFallback = fallback
        if !nativeTracking {
            if phase.contains(.began) {
                epoch &+= 1
                expiry?.cancel(); expiry = nil
            }
            let result = gesture.fallback(x: x, y: y, phase: phase, precise: precise, momentum: momentum)
            if !phase.isDisjoint(with: [.ended, .cancelled]) {
                expiry?.cancel(); expiry = nil
            }
            if let action = result.action {
                expiry?.cancel(); expiry = nil
                ownsPresentation = false
                if commit(action == .next) {
                    state.show(.init(direction: action, progress: 1, expanded: expanded), completed: true)
                } else { state.clear() }
            } else if gesture.tracking {
                ownsPresentation = true
                state.show(.init(direction: gesture.direction, progress: gesture.progress, expanded: expanded), held: true)
                renewExpiry(epoch)
            } else if ownsPresentation {
                state.clear(); ownsPresentation = false
            }
            return result.handled
        }
        if phase.contains(.began), gesture.tracking { cancel() }
        if phase.contains(.began) {
            receivedNativeUpdate = false
            receivedScrollBegin = true
        }
        // The preference permits native tracking but cannot guarantee a callback.
        // Keep physical scroll input until native tracking actually responds.
        let recovery = recoveryGesture.fallback(x: x, y: y, phase: phase, precise: precise, momentum: momentum)
        if phase.contains(.ended), gesture.tracking, !receivedNativeUpdate {
            cancel()
            if let action = recovery.action, commit(action == .next) {
                state.show(.init(direction: action, progress: 1, expanded: expanded), completed: true)
            }
            return recovery.handled
        }
        if gesture.tracking {
            if !receivedNativeUpdate { showRecovery(expanded: expanded) }
            return true
        }
        guard gesture.wheel(x: x, y: y, phase: phase, precise: precise, momentum: momentum,
                            enabled: enabled, hasTouches: hasTouches) != nil else { return false }
        receivedNativeUpdate = false
        receivedScrollEnd = false
        epoch &+= 1
        let generation = epoch
        ownsPresentation = true
        renewExpiry(generation)
        showRecovery(expanded: expanded)
        // A Changed-first stream could precede trackpad touch delivery. Keep
        // recovery passive instead of letting AppKit capture that stream.
        guard receivedScrollBegin else { return true }
        track { [weak self] amount, phase, complete in
            guard let self, self.epoch == generation, self.gesture.tracking else { return true }
            self.receivedNativeUpdate = true
            let action = self.gesture.native(amount: amount, phase: phase, complete: complete)
            if let action {
                self.expiry?.cancel(); self.expiry = nil
                self.ownsPresentation = false
                self.recoveryGesture.cancel()
                self.receivedScrollBegin = false
                self.ignoresRemainingScroll = !self.receivedScrollEnd
                if self.commit(action == .next) {
                    self.state.show(.init(direction: action, progress: 1, expanded: expanded), completed: true)
                } else { self.state.clear() }
                return true
            }
            guard self.gesture.tracking else {
                let ended = self.receivedScrollEnd
                self.cancel()
                self.ignoresRemainingScroll = !ended
                return true
            }
            self.state.show(.init(direction: self.gesture.direction, progress: self.gesture.progress,
                                  expanded: expanded), held: true)
            self.renewExpiry(generation)
            return false
        }
        return true
    }

    private func showRecovery(expanded: Bool) {
        guard recoveryGesture.tracking else {
            if ownsPresentation { state.clear() }
            return
        }
        state.show(.init(direction: recoveryGesture.direction, progress: recoveryGesture.progress,
                         expanded: expanded), held: true)
        renewExpiry(epoch)
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
