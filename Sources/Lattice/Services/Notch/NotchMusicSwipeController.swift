// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import Combine

/// The direction a music swipe skips.
enum NotchMusicTrackSwipe {
    enum Direction { case next, previous }
}

/// The music swipe's single owner. A trackpad stroke reaches the island as
/// two streams, finger touches and scroll events, in no fixed order; a mouse
/// sends scrolls only, and at the screen's top edge only a copy of the scroll
/// arrives at all. Each stroke has exactly one source, chosen when it starts,
/// and one stage machine, whatever drives it:
///
/// - first stage: the arrow and a tap;
/// - armed: a second tap;
/// - the switch commits only when the stroke ends (the fingers lift).
///
/// A stroke is sideways (music) or vertical (the island's own gestures),
/// decided once from its first few points of travel.
final class NotchMusicSwipeController {
    static func permitsCompact(stripVisible: Bool, expanded: Bool, peeking: Bool,
                               trackNotice: Bool, noticeExpanded: Bool, noticeCanPresent: Bool) -> Bool {
        !expanded && (stripVisible || (!peeking && trackNotice && !noticeExpanded && noticeCanPresent))
    }

    /// One finger on the trackpad or mouse, in physical points (72 per inch).
    struct Contact: Equatable {
        let id: Int
        let position: CGPoint
        var isResting = false
        var lifted = false
    }

    enum Source { case touch, scroll }
    private enum Axis { case horizontal, vertical }

    /// ¼ inch to the first stage and ¾ inch to arm, in physical points.
    static let touchFeedbackDistance = 18.0
    static let touchChangeDistance = 54.0
    /// The same stages on scroll travel, which includes the device's acceleration.
    static let scrollFeedbackDistance = 20.0
    static let scrollChangeDistance = 60.0
    /// Travel that decides a stroke's axis.
    static let axisDistance = 4.0
    /// How long after a scroll-started stroke its fingers may still take it over.
    static let touchTakeoverWindow = 0.08

    private struct Stroke {
        var source: Source
        let began: TimeInterval
        var lastInput: TimeInterval
        let expanded: Bool
        var axis: Axis?
        /// Signed travel in scroll terms: negative skips forward.
        var x = 0.0
        var y = 0.0
        var started = false
        var armed = false
        var haptics = true
        var origins: [Int: CGPoint] = [:]
        /// Scroll travel carried into a stroke its fingers took over.
        var carriedX = 0.0
        var fingerX = 0.0
        var fingerY = 0.0
        /// The stroke's direction: it follows the travel until the first stage,
        /// then never changes until the fingers lift. Negative skips forward.
        var lockedSign: Double?
        var direction: NotchMusicTrackSwipe.Direction { (lockedSign ?? x) < 0 ? .next : .previous }
        /// Travel in the locked direction only: backing up shrinks it to zero.
        var forward: Double { lockedSign.map { max(0, x * $0) } ?? 0 }
    }

    private var stroke: Stroke?
    private var swallowsMomentum = false
    private var lastSingleTouch: TimeInterval?
    private var surface: String?
    /// Learned during a stroke, applied from the next one so a stroke in
    /// progress never changes direction.
    private var learnedNaturalScrolling: Bool?
    /// Whether finger travel and scroll travel point the same way: natural
    /// scrolling, learned from strokes that send both.
    private var naturalScrolling: Bool

    private let state: NotchMusicSwipeState
    private let onStart: () -> Void
    private let onArm: () -> Void
    private let commit: (Bool) -> Bool

    init(state: NotchMusicSwipeState = .shared, onStart: @escaping () -> Void = {},
         onArm: @escaping () -> Void = {},
         naturalScrolling: Bool = UserDefaults.standard.object(forKey: "com.apple.swipescrolldirection") as? Bool ?? true,
         commit: @escaping (Bool) -> Bool) {
        self.state = state
        self.onStart = onStart
        self.onArm = onArm
        self.naturalScrolling = naturalScrolling
        self.commit = commit
    }

    var activeSource: Source? { stroke?.source }

    func synchronizeSurface(_ value: String) {
        if let surface, surface != value { cancel() }
        surface = value
    }

    func cancel() {
        applyLearnedDirection()
        stroke = nil
        swallowsMomentum = false
        state.clear()
    }

    // MARK: - Touches

    /// One snapshot of the fingers on the device. True while a sideways
    /// stroke owns the input.
    @discardableResult
    func touches(_ contacts: [Contact], timestamp: TimeInterval, enabled: Bool, expanded: Bool) -> Bool {
        let down = contacts.filter { !$0.isResting && !$0.lifted }
        if down.count == 1 { lastSingleTouch = timestamp }
        guard var current = stroke else {
            guard enabled, down.count == 2 else { return false }
            stroke = Stroke(source: .touch, began: timestamp, lastInput: timestamp, expanded: expanded,
                            origins: Dictionary(uniqueKeysWithValues: down.map { ($0.id, $0.position) }))
            swallowsMomentum = false
            return false
        }
        guard enabled, current.expanded == expanded else { cancel(); return false }
        if current.source == .scroll {
            if down.count == 1 { current.haptics = false }
            // Fingers reaching the island just after their own scroll began
            // take the stroke over while nothing has fired yet.
            if down.count == 2, !current.started, current.axis != .vertical,
               timestamp - current.began <= Self.touchTakeoverWindow {
                current.source = .touch
                current.carriedX = current.x
                current.origins = Dictionary(uniqueKeysWithValues: down.map { ($0.id, $0.position) })
                current.lastInput = timestamp
                stroke = current
                return current.axis == .horizontal
            }
            stroke = current
            return current.axis == .horizontal
        }
        current.lastInput = timestamp
        let ids = Set(current.origins.keys)
        let downIDs = Set(down.map(\.id))
        // Only new fingers: the last stroke's lift never arrived. It ends
        // without switching, and these fingers start their own stroke.
        if !downIDs.isEmpty, ids.isDisjoint(with: downIDs) {
            abandon()
            return touches(contacts, timestamp: timestamp, enabled: enabled, expanded: expanded)
        }
        // A finger lifting ends the stroke, as the lift of both does.
        if down.isEmpty || !ids.isSubset(of: downIDs) && downIDs.isSubset(of: ids) {
            stroke = current
            return finish()
        }
        // Another finger joining is not a two-finger swipe.
        guard downIDs == ids else { abandon(); return false }
        let travel = down.compactMap { contact in
            current.origins[contact.id].map { CGPoint(x: contact.position.x - $0.x, y: contact.position.y - $0.y) }
        }
        guard travel.count == 2, travel.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { abandon(); return false }
        let aligned = travel[0].x * travel[1].x > 0
        let sideways = aligned ? min(abs(travel[0].x), abs(travel[1].x)) * (travel[0].x < 0 ? -1 : 1) : 0
        current.fingerX = sideways
        current.fingerY = travel.map { abs($0.y) }.max() ?? 0
        current.x = current.carriedX + sideways * (naturalScrolling ? 1 : -1)
        current.y = current.fingerY
        stroke = current
        return advance(feedback: Self.touchFeedbackDistance, change: Self.touchChangeDistance)
    }

    /// The NSTouch adapter: device-relative positions in physical points.
    @discardableResult
    func handle(_ event: NSEvent, in view: NSView, enabled: Bool, expanded: Bool) -> Bool {
        let touches = event.touches(matching: [.touching, .ended, .cancelled], in: view).filter { $0.type == .indirect }
        if touches.contains(where: { $0.phase == .cancelled }) { cancel(); return false }
        var contacts: [Contact] = []
        for touch in touches {
            guard touch.deviceSize.width.isFinite, touch.deviceSize.height.isFinite,
                  touch.deviceSize.width > 0, touch.deviceSize.height > 0 else { cancel(); return false }
            contacts.append(Contact(id: identity(touch.identity),
                                    position: CGPoint(x: touch.normalizedPosition.x * touch.deviceSize.width,
                                                      y: touch.normalizedPosition.y * touch.deviceSize.height),
                                    isResting: touch.isResting, lifted: touch.phase == .ended))
        }
        let owned = self.touches(contacts, timestamp: event.timestamp, enabled: enabled, expanded: expanded)
        if contacts.allSatisfy(\.lifted) { identities.removeAll() }
        return owned
    }

    private var identities: [any NSObjectProtocol] = []
    private func identity(_ object: any NSObjectProtocol) -> Int {
        if let index = identities.firstIndex(where: { $0.isEqual(object) }) { return index }
        identities.append(object)
        return identities.count - 1
    }

    // MARK: - Scroll

    /// One scroll event. True while a sideways stroke owns it, so the island's
    /// vertical gestures leave it alone.
    @discardableResult
    func scroll(dx: Double, dy: Double, phase: NSEvent.Phase, momentum: Bool, precise: Bool,
                timestamp: TimeInterval, enabled: Bool, expanded: Bool, inverted: Bool? = nil) -> Bool {
        // Each scroll event says exactly whether natural scrolling is on. It
        // turns finger travel into a direction from the next stroke on; a guess
        // from one jittery delta once locked whole strokes the wrong way.
        if let inverted {
            if stroke == nil { naturalScrolling = inverted } else { learnedNaturalScrolling = inverted }
        }
        guard dx.isFinite, dy.isFinite else { cancel(); return false }
        // The coast after a sideways stroke belongs to it.
        if momentum { return swallowsMomentum }
        let begins = !phase.isDisjoint(with: [.began, .mayBegin])
        if begins, stroke?.source == .scroll {
            // A new scroll means the last one's end never came.
            _ = finish()
        }
        if stroke == nil {
            guard begins else { return false }
            guard enabled, precise else { return false }
            let mouse = lastSingleTouch.map { abs(timestamp - $0) <= 0.3 } ?? false
            stroke = Stroke(source: .scroll, began: timestamp, lastInput: timestamp, expanded: expanded,
                            haptics: !mouse)
            swallowsMomentum = false
            if !phase.contains(.began) { return false }
        }
        guard var current = stroke else { return false }
        guard enabled, current.expanded == expanded else { cancel(); return false }
        if current.source == .touch {
            if phase.contains(.cancelled) { abandon(); return false }
            // The scroll ends when the fingers lift, even if their own lift is lost.
            if phase.contains(.ended) { return finish() }
            return current.axis == .horizontal
        }
        if phase.contains(.cancelled) { abandon(); return false }
        current.lastInput = timestamp
        if phase.contains(.ended) {
            stroke = current
            return finish()
        }
        current.x += dx
        current.y += abs(dy)
        stroke = current
        return advance(feedback: Self.scrollFeedbackDistance, change: Self.scrollChangeDistance)
    }

    // MARK: - Stages

    private func advance(feedback: Double, change: Double) -> Bool {
        guard var current = stroke else { return false }
        if current.axis == nil {
            let x = abs(current.x), y = current.y
            if x >= Self.axisDistance, x >= y * 1.5 {
                current.axis = .horizontal
                current.lockedSign = current.x < 0 ? -1 : 1
            } else if y >= Self.axisDistance, y >= x * 1.5 {
                current.axis = .vertical
                stroke = current
                return false
            } else { stroke = current; return false }
        }
        guard current.axis == .horizontal else { stroke = current; return false }
        // Until the first stage the swipe may still change its mind and follows
        // the travel; from the first tap on the direction is locked, and backing
        // up only shrinks the cue and disarms, silently.
        if !current.started, current.x != 0 { current.lockedSign = current.x < 0 ? -1 : 1 }
        let distance = current.forward
        let progress = min(1, distance / change)
        if !current.started, distance >= feedback {
            current.started = true
            if current.haptics { onStart() }
        }
        if distance >= change {
            if !current.armed {
                current.armed = true
                if current.haptics { onArm() }
            }
        } else if current.armed {
            current.armed = false
        }
        stroke = current
        state.show(.init(direction: current.direction, progress: progress, expanded: current.expanded), held: true)
        return true
    }

    /// The stroke ended: an armed sideways stroke switches the track.
    private func finish() -> Bool {
        guard let current = stroke else { return false }
        stroke = nil
        applyLearnedDirection()
        let sideways = current.axis == .horizontal
        swallowsMomentum = sideways
        if sideways, current.armed {
            if commit(current.direction == .next) {
                state.show(.init(direction: current.direction, progress: 1, expanded: current.expanded), completed: true)
            } else { state.clear() }
        } else if sideways {
            state.clear()
        }
        return sideways
    }

    private func abandon() {
        let sideways = stroke?.axis == .horizontal
        stroke = nil
        applyLearnedDirection()
        swallowsMomentum = sideways
        state.clear()
    }

    private func applyLearnedDirection() {
        if let learned = learnedNaturalScrolling { naturalScrolling = learned }
        learnedNaturalScrolling = nil
    }
}
