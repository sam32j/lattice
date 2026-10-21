// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// Unlike scroll deltas, NSTouch device coordinates are physical 72-ppi points.
struct NotchCaptureTrackpadGesture {
    struct Contact {
        let id: Int
        let position: CGPoint
    }
    private var origins: [Contact] = []
    private var blocked = false
    private var fired = false
    private var identities: [any NSObjectProtocol] = []
    private(set) var progress = 0.0

    mutating func update(_ contacts: [Contact], enabled: Bool) -> Bool {
        guard enabled, !contacts.isEmpty else { self = Self(); return false }
        guard contacts.count == 2 else {
            if !origins.isEmpty || contacts.count > 2 { blocked = true }
            progress = 0
            return false
        }
        guard !blocked, !fired else { return false }
        let contacts = contacts.sorted { $0.id < $1.id }
        guard contacts.allSatisfy({ $0.position.x.isFinite && $0.position.y.isFinite }) else {
            blocked = true; progress = 0; return false
        }
        if origins.isEmpty { origins = contacts; return false }
        guard origins.map(\.id) == contacts.map(\.id) else { blocked = true; progress = 0; return false }
        let travel = zip(contacts, origins).map {
            CGPoint(x: $0.position.x - $1.position.x, y: $0.position.y - $1.position.y)
        }
        let upward = travel.map(\.y).min() ?? 0
        let sideways = travel.map { abs($0.x) }.max() ?? 0
        progress = sideways <= max(4, upward * 0.67) ? min(1, max(0, upward / 72)) : 0
        guard upward >= 72, progress == 1 else { return false }
        fired = true
        return true
    }

    mutating func handle(_ event: NSEvent, in view: NSView, enabled: Bool) -> Bool {
        let touches = event.touches(matching: .touching, in: view).filter { $0.type == .indirect && !$0.isResting }
        if touches.count == 2 {
            guard let first = touches.first?.device as? NSObject,
                  touches.allSatisfy({ ($0.device as? NSObject)?.isEqual(first) == true }) else {
                return update([], enabled: false)
            }
        }
        let contacts = touches.map { touch -> Contact in
            let id: Int
            if let existing = identities.firstIndex(where: { $0.isEqual(touch.identity) }) { id = existing }
            else { id = identities.count; identities.append(touch.identity) }
            return Contact(id: id, position: CGPoint(x: touch.normalizedPosition.x * touch.deviceSize.width,
                                                      y: touch.normalizedPosition.y * touch.deviceSize.height))
        }
        return update(contacts, enabled: enabled)
    }
}
