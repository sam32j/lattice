// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum ScreenshotEditorResizeCursor {
    static func cursor(for handle: ScreenshotSupport.Handle) -> NSCursor {
        if #available(macOS 15, *) {
            let position: NSCursor.FrameResizePosition
            switch handle {
            case .topLeft: position = .topLeft
            case .top: position = .top
            case .topRight: position = .topRight
            case .right: position = .right
            case .bottomRight: position = .bottomRight
            case .bottom: position = .bottom
            case .bottomLeft: position = .bottomLeft
            case .left: position = .left
            }
            return .frameResize(position: position, directions: .all)
        }
        switch handle {
        case .top, .bottom: return .resizeUpDown
        case .left, .right: return .resizeLeftRight
        case .topLeft, .bottomRight: return descending
        case .topRight, .bottomLeft: return ascending
        }
    }

    private static let ascending = diagonal(mirrored: false)
    private static let descending = diagonal(mirrored: true)

    private static func diagonal(mirrored: Bool) -> NSCursor {
        let image = NSImage(size: CGSize(width: 24, height: 24), flipped: false) { _ in
            let path = NSBezierPath()
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: mirrored ? 24 - y : y) }
            path.move(to: point(5, 5)); path.line(to: point(19, 19))
            path.move(to: point(5, 11)); path.line(to: point(5, 5)); path.line(to: point(11, 5))
            path.move(to: point(13, 19)); path.line(to: point(19, 19)); path.line(to: point(19, 13))
            path.lineJoinStyle = .round
            path.lineCapStyle = .round
            NSColor.white.setStroke(); path.lineWidth = 4; path.stroke()
            NSColor.black.setStroke(); path.lineWidth = 1.5; path.stroke()
            return true
        }
        return NSCursor(image: image, hotSpot: CGPoint(x: 12, y: 12))
    }
}
