// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum ScreenshotSelectionChrome {
    static func draw(_ mark: ScreenshotSupport.Annotation, in cg: CGContext,
                     captureScale: CGFloat, displayZoom: CGFloat, imageSize: CGSize) {
        let unit = 1 / max(0.01, displayZoom)
        let blue = CGColor(srgbRed: 0.04, green: 0.52, blue: 1, alpha: 1)
        cg.saveGState()
        defer { cg.restoreGState() }
        cg.setStrokeColor(blue)
        cg.setLineWidth(unit)
        if mark.tool == .freehand {
            let path = ScreenshotEditorGeometry.freehandPath(mark.points)
            cg.setLineJoin(.round)
            cg.setLineCap(.round)
            cg.setLineWidth(mark.stroke.width * captureScale + 3 * unit)
            cg.addPath(path)
            cg.strokePath()
            cg.setStrokeColor(ScreenshotRenderer.color(mark.color))
            cg.setLineWidth(mark.stroke.width * captureScale)
            cg.addPath(path)
            cg.strokePath()
            return
        }
        if mark.tool == .highlight {
            for rect in ScreenshotEditorGeometry.highlightRects(mark) {
                let radius = min(4 * captureScale, rect.height / 2)
                cg.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
                cg.strokePath()
            }
            return
        }
        func grip(at point: CGPoint, radius: CGFloat, filled: Bool = false, square: Bool = false) {
            let rect = CGRect(x: point.x - radius * unit, y: point.y - radius * unit,
                              width: radius * unit * 2, height: radius * unit * 2)
            cg.setFillColor(filled ? blue : NSColor.white.cgColor)
            cg.setStrokeColor(filled ? NSColor.white.cgColor : blue)
            cg.setLineWidth((filled ? 2 : 1) * unit)
            if square { cg.fill(rect); cg.stroke(rect) }
            else { cg.fillEllipse(in: rect); cg.strokeEllipse(in: rect) }
        }
        if mark.tool == .line || mark.tool == .arrow {
            for point in mark.points.prefix(2) { grip(at: point, radius: 3) }
            return
        }
        let box: CGRect
        if mark.tool == .counter {
            let diameter = ScreenshotSupport.counterDiameter(for: imageSize, scale: 1)
            box = CGRect(x: mark.rect.midX - diameter / 2, y: mark.rect.midY - diameter / 2,
                         width: diameter, height: diameter)
        } else if mark.tool == .text { box = mark.rect }
        else { box = mark.rect.insetBy(dx: -3 * unit, dy: -3 * unit) }
        cg.setLineDash(phase: 0, lengths: [4 * unit, 3 * unit])
        cg.stroke(box)
        cg.setLineDash(phase: 0, lengths: [])
        if mark.tool == .text {
            for handle in [ScreenshotSupport.Handle.left, .right] {
                grip(at: handle.position(in: mark.rect), radius: 4.5, filled: true)
            }
            grip(at: ScreenshotSupport.Handle.bottomRight.position(in: mark.rect), radius: 3, filled: true, square: true)
        } else if mark.tool.resizesWithHandles {
            for handle in ScreenshotSupport.Handle.allCases { grip(at: handle.position(in: mark.rect), radius: 2.5) }
        }
    }
}
