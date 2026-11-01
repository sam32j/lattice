// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit

/// A drag near an edge keeps scrolling even when the pointer stops moving.
/// Native scroll positions preserve normal trackpad behavior between drags.
final class HubDragScrolling {
    private weak var anchor: NSView?
    private var timer: Timer?
    private var lastTick: TimeInterval = 0
    private var lastScreenPoint = CGPoint.zero
    private var onScroll: ((CGPoint) -> Void)?

    func update(anchor: NSView, screenPoint: CGPoint, onScroll: ((CGPoint) -> Void)? = nil) {
        self.anchor = anchor
        lastScreenPoint = screenPoint
        self.onScroll = onScroll
        guard timer == nil else { return }
        lastTick = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.add(timer, forMode: .eventTracking)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        anchor = nil
        onScroll = nil
    }

    func stop(ifAnchoredTo view: NSView) { if anchor === view { stop() } }

    private func tick() {
        guard let anchor, let window = anchor.window else { stop(); return }
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = min(0.05, max(0, now - lastTick))
        lastTick = now
        let windowPoint = window.convertPoint(fromScreen: lastScreenPoint)
        var ancestor: NSView? = anchor
        var visited = Set<ObjectIdentifier>()
        var moved = false
        while let scroll = ancestor?.enclosingScrollView,
              visited.insert(ObjectIdentifier(scroll)).inserted {
            let clip = scroll.contentView
            let point = clip.convert(windowPoint, from: nil)
            let viewport = clip.bounds
            if viewport.insetBy(dx: -8, dy: -8).contains(point), let document = scroll.documentView {
                let maxX = max(0, document.bounds.width - viewport.width)
                let maxY = max(0, document.bounds.height - viewport.height)
                let dx = maxX > 0 ? speed(point.x, minimum: viewport.minX, maximum: viewport.maxX) : 0
                let dy = maxY > 0 ? speed(point.y, minimum: viewport.minY, maximum: viewport.maxY) : 0
                let next = CGPoint(x: min(maxX, max(0, viewport.minX + dx * elapsed)),
                                   y: min(maxY, max(0, viewport.minY + dy * elapsed)))
                if next != viewport.origin {
                    clip.scroll(to: next)
                    scroll.reflectScrolledClipView(clip)
                    moved = true
                }
            }
            ancestor = scroll.superview
        }
        if moved { onScroll?(windowPoint) }
    }

    private func speed(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        let edge: CGFloat = min(32, (maximum - minimum) / 3)
        guard edge > 0 else { return 0 }
        if value < minimum + edge { return -360 * min(1, (minimum + edge - value) / edge) }
        if value > maximum - edge { return 360 * min(1, (value - maximum + edge) / edge) }
        return 0
    }

    deinit { timer?.invalidate() }
}
