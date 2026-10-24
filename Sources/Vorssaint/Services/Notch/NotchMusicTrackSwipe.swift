// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// NSTouch device coordinates are physical points at 72 ppi, independent of
/// display scale and scroll acceleration. Scroll events supply direction only.
struct NotchMusicTrackSwipe {
    enum Direction { case next, previous }
    struct Contact {
        let id: Int
        let position: CGPoint
    }
    private var origins: [Contact] = []
    private var blocked = false
    private(set) var fired = false
    private var scrollDistance = 0.0
    private(set) var progress = 0.0
    var direction: Direction? {
        scrollDistance == 0 ? nil : (scrollDistance < 0 ? .next : .previous)
    }
    var horizontal: Bool { progress > 0 }

    mutating func cancel() {
        blocked = true
        progress = 0
        scrollDistance = 0
    }

    mutating func update(_ contacts: [Contact], enabled: Bool) -> Direction? {
        if contacts.isEmpty { self = Self(); return nil }
        guard enabled else { cancel(); return nil }
        guard !blocked, !fired else { return nil }
        guard contacts.count == 2 else {
            if !origins.isEmpty || contacts.count > 2 { cancel() }
            return nil
        }
        let contacts = contacts.sorted { $0.id < $1.id }
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
        progress = aligned && horizontal >= 4 ? min(1, horizontal / 54) : 0
        return complete()
    }

    mutating func scroll(_ deltaX: Double, precise: Bool, momentum: Bool) -> Direction? {
        guard deltaX.isFinite else { cancel(); return nil }
        guard precise, !momentum, !blocked, !fired else { return nil }
        // AppKit already applies the user's natural-scrolling preference.
        scrollDistance += deltaX
        return complete()
    }

    private mutating func complete() -> Direction? {
        guard progress == 1, let direction, !fired else { return nil }
        fired = true
        return direction
    }
}
