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
    var direction: Direction? {
        armed ?? (scrollDistance == 0 ? nil : (scrollDistance < 0 ? .next : .previous))
    }
    var horizontal: Bool { progress > 0 }
    var feedbackReady: Bool { progress >= Self.feedbackDistance / Self.trackChangeDistance }

    mutating func cancel() {
        armed = nil
        blocked = true
        progress = 0
        scrollDistance = 0
    }

    mutating func update(_ contacts: [Contact], enabled: Bool) -> Direction? {
        if contacts.isEmpty {
            let action = enabled && !blocked ? armed : nil
            self = Self()
            return action
        }
        guard enabled else { cancel(); return nil }
        guard !blocked else { return nil }
        if armed != nil {
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
            // Resting is still down; the first missing original contact commits.
            return nil
        }
        // Resting is still physical contact, never a lift. Only active touches
        // may establish or advance an unarmed stroke.
        let contacts = contacts.filter { !$0.isResting }.sorted { $0.id < $1.id }
        guard contacts.count == 2 else {
            if !origins.isEmpty || contacts.count > 2 { cancel() }
            return nil
        }
        guard Set(contacts.map(\.id)).count == 2,
              contacts.allSatisfy({ $0.position.x.isFinite && $0.position.y.isFinite }) else {
            cancel(); return nil
        }
        if origins.isEmpty { origins = contacts; return nil }
        guard origins.map(\.id) == contacts.map(\.id) else { cancel(); return nil }
        let travel = zip(contacts, origins).map {
            CGPoint(x: $0.position.x - $1.position.x, y: $0.position.y - $1.position.y)
        }
        let horizontal = travel.map { abs($0.x) }.min() ?? 0
        let vertical = travel.map { abs($0.y) }.max() ?? 0
        if vertical >= 4, vertical > horizontal * 1.5 { cancel(); return nil }
        let aligned = travel[0].x * travel[1].x > 0 && vertical <= max(4, horizontal * 0.67)
        progress = aligned && horizontal >= 4 ? min(1, horizontal / Self.trackChangeDistance) : 0
        armIfReady()
        return nil
    }

    mutating func scroll(_ deltaX: Double, precise: Bool, momentum: Bool) -> Direction? {
        guard deltaX.isFinite else { cancel(); return nil }
        guard precise, !momentum, !blocked, armed == nil else { return nil }
        // AppKit already applies the user's natural-scrolling preference.
        scrollDistance += deltaX
        armIfReady()
        return nil
    }

    private mutating func armIfReady() {
        guard progress == 1, armed == nil, let direction else { return }
        armed = direction
    }
}
