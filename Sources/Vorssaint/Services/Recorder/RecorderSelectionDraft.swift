// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics

/// Editable area before recording starts. A drag never changes the accepted
/// area to an empty or off-screen region.
struct RecorderSelectionDraft {
    private(set) var rect: CGRect
    private var origin: CGPoint?
    private var initial = CGRect.zero
    private var handle: ScreenshotSupport.Handle?

    mutating func begin(at point: CGPoint) {
        handle = ScreenshotSupport.handle(at: point, rect: rect, tolerance: 8)
        origin = handle != nil || rect.contains(point) ? point : nil
        initial = rect
    }
    @discardableResult mutating func drag(to point: CGPoint, within bounds: CGRect) -> Bool {
        guard let origin, point.x.isFinite, point.y.isFinite else { return false }
        let next: CGRect
        if let handle {
            next = ScreenshotSupport.resizedRect(initial, dragging: handle, to: point).intersection(bounds)
        } else {
            next = ScreenshotSupport.movedRect(initial,
                by: CGPoint(x: point.x - origin.x, y: point.y - origin.y), within: bounds)
        }
        guard !next.isNull, next.width >= 2, next.height >= 2, next != rect else { return false }
        rect = next
        return true
    }
    mutating func end() { origin = nil; handle = nil }
}
