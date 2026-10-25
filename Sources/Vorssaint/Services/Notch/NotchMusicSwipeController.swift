// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import Combine

/// A single owner joins native touch travel and preference-adjusted scroll
/// direction. Neither event stream alone can skip a track.
final class NotchMusicSwipeController {
    static func permitsCompact(stripVisible: Bool, expanded: Bool, peeking: Bool,
                               trackNotice: Bool, noticeExpanded: Bool, noticeCanPresent: Bool) -> Bool {
        !expanded && !peeking && (stripVisible || (trackNotice && !noticeExpanded && noticeCanPresent))
    }

    private var gesture = NotchMusicTrackSwipe()
    private var identities: [any NSObjectProtocol] = []
    private var device: NSObject?
    private weak var lastNativeEvent: NSEvent?
    private var lastNativeTimestamp: TimeInterval?
    private var inactivityWork: DispatchWorkItem?
    private var presentation: Bool?
    private var awaitingBegin = true
    private var blockedUntilLift = false
    private struct PendingDirection {
        var delta: Double
        let timestamp: TimeInterval
        let expanded: Bool
    }
    private var pending: PendingDirection?
    private var surface: String?

    func synchronizeSurface(_ value: String) {
        if let surface, surface != value { cancel() }
        surface = value
    }
    private let commit: (Bool) -> Bool
    private let state: NotchMusicSwipeState
    private let onStart: () -> Void
    private var started = false
    private let onArm: () -> Void
    private let scheduleExpiry: (TimeInterval, DispatchWorkItem) -> Void

    init(state: NotchMusicSwipeState = .shared, onStart: @escaping () -> Void = {},
         onArm: @escaping () -> Void = {},
         scheduleExpiry: @escaping (TimeInterval, DispatchWorkItem) -> Void = {
             DispatchQueue.main.asyncAfter(deadline: .now() + $0, execute: $1)
         }, commit: @escaping (Bool) -> Bool) {
        self.state = state
        self.onArm = onArm
        self.onStart = onStart
        self.scheduleExpiry = scheduleExpiry
        self.commit = commit
    }

    private func renewInactivity() {
        inactivityWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.cancel() }
        inactivityWork = work
        scheduleExpiry(3, work)
    }

    private func finishTracking(contactsRemain: Bool) {
        inactivityWork?.cancel(); inactivityWork = nil
        pending = nil
        blockedUntilLift = contactsRemain
        gesture = NotchMusicTrackSwipe()
        started = false
        presentation = nil
        awaitingBegin = true
        if !contactsRemain { identities.removeAll(); device = nil }
    }

    deinit { inactivityWork?.cancel() }

    func cancel() {
        inactivityWork?.cancel(); inactivityWork = nil
        started = false
        blockedUntilLift = blockedUntilLift || !awaitingBegin
        gesture.cancel()
        pending = nil
        identities.removeAll()
        device = nil
        presentation = nil
        awaitingBegin = true
        state.clear()
    }

    @discardableResult
    func update(_ contacts: [NotchMusicTrackSwipe.Contact], began: Bool,
                cancelled: Bool = false, enabled: Bool, expanded: Bool,
                timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime, freshSequence: Bool = false,
                allowRelease: Bool = true) -> Bool {
        if cancelled { cancel(); return false }
        if let presentation, presentation != expanded { cancel() }
        if contacts.isEmpty {
            guard allowRelease else { cancel(); return false }
            let keepCompletion = enabled && state.completionPending && state.frame.expanded == expanded
            let action = gesture.update([], enabled: enabled)
            finishTracking(contactsRemain: false)
            if let action { publish(action, expanded: expanded) }
            else if !keepCompletion { state.clear() }
            return action != nil
        }
        guard enabled else {
            cancel(); blockedUntilLift = true; return false
        }
        if freshSequence, began, awaitingBegin || blockedUntilLift {
            blockedUntilLift = false
            awaitingBegin = true
        }
        guard !blockedUntilLift else { return false }
        if awaitingBegin {
            guard began else { return false }
            gesture = NotchMusicTrackSwipe()
            awaitingBegin = false
            presentation = expanded
            if let pending, pending.expanded == expanded,
               timestamp.isFinite, abs(timestamp - pending.timestamp) <= 0.15 {
                _ = gesture.scroll(pending.delta, precise: true, momentum: false)
            }
            pending = nil
        }
        guard presentation == expanded else { cancel(); return false }
        let wasArmed = gesture.armed != nil
        let action = gesture.update(contacts, enabled: true)
        if let action {
            guard allowRelease else { cancel(); return false }
            finishTracking(contactsRemain: true)
            publish(action, expanded: expanded)
            return true
        }
        emitFeedback(wasArmed: wasArmed)
        renewInactivity()
        publish(nil, expanded: expanded)
        return gesture.horizontal || gesture.armed != nil
    }

    @discardableResult
    func scroll(_ deltaX: Double, precise: Bool, momentum: Bool,
                cancelled: Bool, enabled: Bool, expanded: Bool,
                began: Bool = false, ended: Bool = false,
                timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        guard timestamp.isFinite, deltaX.isFinite else { cancel(); return false }
        if awaitingBegin, enabled, !cancelled, precise, !momentum, !ended {
            if began {
                pending = PendingDirection(delta: deltaX, timestamp: timestamp, expanded: expanded)
            } else if let prior = pending, prior.expanded == expanded,
                      timestamp >= prior.timestamp, timestamp - prior.timestamp <= 0.15 {
                pending?.delta += deltaX
            } else { pending = nil }
            return false
        }
        guard enabled, !cancelled, presentation == expanded, !awaitingBegin else {
            if !enabled || cancelled || presentation != nil { cancel() }
            else { pending = nil }
            return false
        }
        let wasArmed = gesture.armed != nil
        _ = gesture.scroll(deltaX, precise: precise, momentum: momentum)
        emitFeedback(wasArmed: wasArmed)
        if precise, !momentum, !ended { renewInactivity() }
        publish(nil, expanded: expanded)
        return gesture.horizontal || gesture.armed != nil
    }

    private func emitFeedback(wasArmed: Bool) {
        if !started, gesture.horizontal { started = true; onStart() }
        if !wasArmed, gesture.armed != nil { onArm() }
    }

    private func publish(_ action: NotchMusicTrackSwipe.Direction?, expanded: Bool) {
        if let action {
            if commit(action == .next) {
                state.show(.init(direction: action, progress: 1, expanded: expanded), completed: true)
            } else { state.clear() }
        } else {
            state.show(.init(direction: gesture.direction, progress: gesture.progress, expanded: expanded), held: true)
        }
    }

    func handle(_ event: NSEvent, in view: NSView, enabled: Bool, expanded: Bool) -> Bool {
        // A hosting view can forward an unhandled touch to its container.
        // Do not restart an all-began snapshot or count its travel twice.
        if lastNativeEvent === event, lastNativeTimestamp == event.timestamp { return enabled }
        lastNativeEvent = event
        lastNativeTimestamp = event.timestamp
        let touching = event.touches(matching: .touching, in: view)
            .filter { $0.type == .indirect }
        let ended = event.touches(matching: .ended, in: view)
            .filter { $0.type == .indirect }
        let cancelled = !event.touches(matching: .cancelled, in: view).isEmpty
        let touches = touching.union(ended)
        if cancelled {
            cancel()
            if touching.isEmpty { _ = update([], began: false, enabled: false, expanded: expanded) }
            return false
        }
        for touch in touches {
            guard let current = touch.device as? NSObject,
                  device == nil || device?.isEqual(current) == true,
                  touch.deviceSize.width.isFinite, touch.deviceSize.height.isFinite,
                  touch.deviceSize.width > 0, touch.deviceSize.height > 0 else {
                cancel(); return false
            }
            device = current
        }
        let contacts = touches.map { touch -> NotchMusicTrackSwipe.Contact in
            let id: Int
            if let index = identities.firstIndex(where: { $0.isEqual(touch.identity) }) { id = index }
            else { id = identities.count; identities.append(touch.identity) }
            return .init(id: id, position: CGPoint(x: touch.normalizedPosition.x * touch.deviceSize.width,
                                                    y: touch.normalizedPosition.y * touch.deviceSize.height), isResting: touch.isResting)
        }
        _ = update(contacts, began: touches.contains { $0.phase == .began },
                              enabled: enabled, expanded: expanded, timestamp: event.timestamp,
                              freshSequence: touches.contains { !$0.isResting && $0.phase == .began }
                                && touches.filter { !$0.isResting }.allSatisfy { $0.phase == .began },
                              allowRelease: !ended.isEmpty)
        if !ended.isEmpty {
            let remaining = Set(touching.compactMap { touch in
                identities.firstIndex { $0.isEqual(touch.identity) }
            })
            _ = update(contacts.filter { remaining.contains($0.id) }, began: false,
                       enabled: enabled, expanded: expanded, timestamp: event.timestamp)
        }
        return enabled
    }
}
