// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// Image-pixel geometry shared by editor interactions and exported rendering.
enum ScreenshotEditorGeometry {
    static func resizedShape(_ rect: CGRect, handle: ScreenshotSupport.Handle, to point: CGPoint,
                             tool: ScreenshotSupport.Tool, constrained: Bool) -> CGRect {
        guard constrained, tool == .rect || tool == .ellipse || tool == .redact else {
            return ScreenshotSupport.resizedRect(rect, dragging: handle, to: point)
        }
        let anchor: CGPoint
        switch handle {
        case .topLeft: anchor = CGPoint(x: rect.maxX, y: rect.maxY)
        case .topRight: anchor = CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight: anchor = CGPoint(x: rect.minX, y: rect.minY)
        case .bottomLeft: anchor = CGPoint(x: rect.maxX, y: rect.minY)
        default: return ScreenshotSupport.resizedRect(rect, dragging: handle, to: point)
        }
        let end = shapeEnd(from: anchor, to: point, tool: tool, constrained: true)
        return ScreenshotSupport.selectionRect(from: anchor, to: end)
    }

    static func selectionHandles(for tool: ScreenshotSupport.Tool) -> [ScreenshotSupport.Handle] {
        guard tool.resizesWithHandles else { return [] }
        return tool == .text ? [.left, .right, .bottomRight]
            : [.topLeft, .topRight, .bottomRight, .bottomLeft]
    }

    static func selectionHandle(at point: CGPoint, mark: ScreenshotSupport.Annotation,
                                tolerance: CGFloat) -> ScreenshotSupport.Handle? {
        let candidates = selectionHandles(for: mark.tool)
        guard let nearest = candidates.min(by: {
            let a = $0.position(in: mark.rect), b = $1.position(in: mark.rect)
            return hypot(point.x - a.x, point.y - a.y) < hypot(point.x - b.x, point.y - b.y)
        }) else { return nil }
        let target = nearest.position(in: mark.rect)
        return hypot(point.x - target.x, point.y - target.y) <= tolerance ? nearest : nil
    }
    static func freehandPath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        for index in 1..<points.count {
            let current = points[index], previous = points[index - 1]
            path.addQuadCurve(to: CGPoint(x: (current.x + previous.x) / 2, y: (current.y + previous.y) / 2),
                             control: previous)
        }
        if let last = points.last { path.addLine(to: last) }
        return path
    }
    static func duplicate(_ mark: ScreenshotSupport.Annotation) -> ScreenshotSupport.Annotation {
        .init(tool: mark.tool, rect: mark.rect, points: mark.points, text: mark.text,
            color: mark.color, stroke: mark.stroke, textSize: mark.textSize,
            blurLevel: mark.blurLevel, blurStyle: mark.blurStyle, blurTextOnly: mark.blurTextOnly,
            arrowStyle: mark.arrowStyle, scribbleSeed: mark.scribbleSeed, number: mark.number,
            isBounded: mark.isBounded, hasCornerRadius: mark.hasCornerRadius)
    }
    static func shapeEnd(from start: CGPoint, to end: CGPoint,
                         tool: ScreenshotSupport.Tool, constrained: Bool) -> CGPoint {
        guard constrained else { return end }
        let dx = end.x - start.x, dy = end.y - start.y
        switch tool {
        case .rect, .ellipse, .redact:
            let side = max(abs(dx), abs(dy))
            return CGPoint(x: start.x + (dx < 0 ? -side : side), y: start.y + (dy < 0 ? -side : side))
        case .arrow, .line:
            let angle = (atan2(dy, dx) / (.pi / 4)).rounded() * (.pi / 4)
            let distance = hypot(dx, dy)
            return CGPoint(x: start.x + cos(angle) * distance, y: start.y + sin(angle) * distance)
        default: return end
        }
    }

    static func textSize(_ text: String, font: NSFont, width: CGFloat?) -> CGSize {
        // A sentinel represents the empty final line once. Counting trailing
        // newlines again after splitting was the source of the phantom row.
        let sample = text.isEmpty ? " " : text.hasSuffix("\n") ? text + " " : text
        let storage = NSTextStorage(string: sample, attributes: [.font: font])
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width ?? 1_000_000, height: 1_000_000))
        container.lineFragmentPadding = 0
        storage.addLayoutManager(manager)
        manager.addTextContainer(container)
        manager.ensureLayout(for: container)
        let used = manager.usedRect(for: container)
        return CGSize(width: ceil(used.width), height: ceil(max(used.height, manager.defaultLineHeight(for: font))))
    }

    static func aspectRect(from start: CGPoint, to end: CGPoint, aspect: CGFloat) -> CGRect {
        guard aspect.isFinite, aspect > 0 else { return ScreenshotSupport.selectionRect(from: start, to: end) }
        let dx = end.x - start.x, dy = end.y - start.y
        let proj = (abs(dx) * aspect + abs(dy)) / (aspect * aspect + 1)
        let width = proj * aspect
        let height = proj
        return ScreenshotSupport.selectionRect(from: start,
            to: CGPoint(x: start.x + (dx < 0 ? -width : width),
                        y: start.y + (dy < 0 ? -height : height)))
    }

    /// Reading-order range, merged within each line without bridging columns.
    static func highlightRuns(anchor: CGPoint, current: CGPoint, words: [CGRect], padding: CGFloat) -> [CGRect] {
        guard let first = words.firstIndex(where: { $0.insetBy(dx: -padding, dy: -padding).contains(anchor) }),
              let last = words.indices.min(by: { distance(current, words[$0]) < distance(current, words[$1]) })
        else { return [] }
        var runs: [CGRect] = []
        for box in words[min(first, last)...max(first, last)] {
            if let previous = runs.last {
                let overlap = min(previous.maxY, box.maxY) - max(previous.minY, box.minY)
                let gap = max(box.minX - previous.maxX, previous.minX - box.maxX, 0)
                if overlap >= min(previous.height, box.height) / 2, gap <= max(previous.height, box.height) * 1.5 {
                    runs[runs.count - 1] = previous.union(box)
                    continue
                }
            }
            runs.append(box)
        }
        return runs.map { $0.insetBy(dx: -padding, dy: -padding) }
    }

    static func highlightRects(_ annotation: ScreenshotSupport.Annotation) -> [CGRect] {
        guard annotation.points.count >= 2 else { return annotation.rect.isEmpty ? [] : [annotation.rect] }
        return stride(from: 0, to: annotation.points.count - 1, by: 2).map {
            ScreenshotSupport.selectionRect(from: annotation.points[$0], to: annotation.points[$0 + 1])
        }
    }

    private static func distance(_ point: CGPoint, _ box: CGRect) -> CGFloat {
        hypot(max(box.minX - point.x, point.x - box.maxX, 0), max(box.minY - point.y, point.y - box.maxY, 0))
    }
}
