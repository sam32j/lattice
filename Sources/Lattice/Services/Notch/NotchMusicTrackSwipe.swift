// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// NSTouch device coordinates are physical points at 72 ppi, independent of
/// display scale and scroll acceleration. Scroll events supply direction only.
struct NotchMusicTrackSwipe {
    private static let feedbackDistance = 18.0 // ¼ inch at 72 physical points per inch.
    private static let trackChangeDistance = 54.0 // ¾ inch.
    enum Direction { case next, previous }
    struct Contact {
        let id: Int
        let position: CGPoint
        let isResting: Bool

        init(id: Int, position: CGPoint, isResting: Bool = false) {
            self.id = id
            self.position = position
            self.isResting = isResting
        }
    }
    private var origins: [Contact] = []
    private var blocked = false
    private(set) var armed: Direction?
    private var scrollDistance = 0.0
    private(set) var progress = 0.0
    private var triggeredSign: Double?
    private var triggeredDirection: Direction?

    var direction: Direction? {
        if let armed { return armed }
        if let triggeredDirection { return triggeredDirection }
        return scrollDistance == 0 ? nil : (scrollDistance < 0 ? .next : .previous)
    }
    var horizontal: Bool { progress > 0 }
    var feedbackReady: Bool { progress >= Self.feedbackDistance / Self.trackChangeDistance }

    mutating func cancel() {
        armed = nil
        blocked = true
        progress = 0
        scrollDistance = 0
        triggeredSign = nil
        triggeredDirection = nil
    }

    mutating func update(_ contacts: [Contact], enabled: Bool) -> Direction? {
        if contacts.isEmpty {
            let action = enabled && !blocked ? armed : nil
            self = Self()
            return action
        }
        guard enabled else { cancel(); return nil }
        guard !blocked else { return nil }

        // If origins exist, verify contact validity and check if any finger lifted.
        if !origins.isEmpty {
            let ids = Set(origins.map(\.id))
            guard Set(contacts.map(\.id)).count == contacts.count,
                  contacts.allSatisfy({ (ids.contains($0.id) || $0.isResting)
                      && $0.position.x.isFinite && $0.position.y.isFinite }) else {
                cancel(); return nil
            }
            if !ids.isSubset(of: Set(contacts.map(\.id))) {
                let action = armed
                self = Self()
                return action
            }
        }

        // Resting is still physical contact, never a lift. Resting touches hold
        // the current stroke without advancing or undoing.
        if contacts.contains(where: \.isResting) {
            return nil
        }

        let activeContacts = contacts.sorted { $0.id < $1.id }
        guard activeContacts.count == 2 else {
            if !origins.isEmpty || activeContacts.count > 2 { cancel() }
            return nil
        }
        guard Set(activeContacts.map(\.id)).count == 2,
              activeContacts.allSatisfy({ $0.position.x.isFinite && $0.position.y.isFinite }) else {
            cancel(); return nil
        }
        if origins.isEmpty { origins = activeContacts; return nil }
        guard origins.map(\.id) == activeContacts.map(\.id) else { cancel(); return nil }
        let travel = zip(activeContacts, origins).map {
            CGPoint(x: $0.position.x - $1.position.x, y: $0.position.y - $1.position.y)
        }
        let horizontal = travel.map { abs($0.x) }.min() ?? 0
        let vertical = travel.map { abs($0.y) }.max() ?? 0
        if vertical >= 4, vertical > horizontal * 1.5 { cancel(); return nil }

        let aligned = travel[0].x * travel[1].x > 0 && vertical <= max(4, horizontal * 0.67)

        // Lock trigger direction once the 1/4 inch (18 pt) threshold is reached.
        if triggeredSign == nil, aligned, horizontal >= Self.feedbackDistance {
            triggeredSign = travel[0].x > 0 ? 1 : -1
            if scrollDistance != 0 {
                triggeredDirection = scrollDistance < 0 ? .next : .previous
            }
        }
        if triggeredDirection == nil, triggeredSign != nil, scrollDistance != 0 {
            triggeredDirection = scrollDistance < 0 ? .next : .previous
        }

        if let sign = triggeredSign {
            let d0 = travel[0].x * sign
            let d1 = travel[1].x * sign
            let forwardTravel = min(d0, d1)
            let verticalOk = vertical <= max(4, max(abs(travel[0].x), abs(travel[1].x)) * 0.67)
            if verticalOk, forwardTravel >= 4 {
                if armed != nil, forwardTravel >= Self.trackChangeDistance - 4 {
                    progress = 1
                } else {
                    progress = min(1, forwardTravel / Self.trackChangeDistance)
                }
            } else {
                progress = 0
            }
        } else {
            progress = aligned && horizontal >= 4 ? min(1, horizontal / Self.trackChangeDistance) : 0
        }

        if progress == 1 {
            armIfReady()
        } else {
            armed = nil
        }
        return nil
    }

    mutating func scroll(_ deltaX: Double, precise: Bool, momentum: Bool) -> Direction? {
        guard deltaX.isFinite else { cancel(); return nil }
        guard precise, !momentum, !blocked else { return nil }
        // AppKit already applies the user's natural-scrolling preference.
        scrollDistance += deltaX
        if triggeredDirection == nil, scrollDistance != 0 {
            triggeredDirection = scrollDistance < 0 ? .next : .previous
        }
        if progress == 1 {
            armIfReady()
        }
        return nil
    }

    private mutating func armIfReady() {
        guard progress == 1, armed == nil, let direction else { return }
        armed = direction
    }
}
