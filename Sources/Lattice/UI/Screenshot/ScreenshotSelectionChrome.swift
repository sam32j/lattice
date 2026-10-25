// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum ScreenshotSelectionChrome {
    static func draw(_ mark: ScreenshotSupport.Annotation, in cg: CGContext,
                     captureScale: CGFloat, displayZoom: CGFloat, imageSize: CGSize,
                     showsHandles: Bool = true) {
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
            guard mark.points.count >= 2 else { return }
            let width = mark.stroke.width * captureScale
            let start = mark.points[0], end = mark.points[1]
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            let path: CGPath
            let filled: Bool
            if mark.tool == .arrow {
                let stroke = ScreenshotSupport.arrowStrokePath(from: start, to: end, strokeWidth: width,
                    style: mark.arrowStyle, seed: mark.scribbleSeed)
                path = stroke ?? ScreenshotSupport.arrowSilhouette(from: start, to: end, strokeWidth: width)
                filled = stroke == nil
            } else {
                let line = CGMutablePath()
                line.move(to: start); line.addLine(to: end)
                path = line
                filled = false
            }
            cg.setStrokeColor(blue)
            if filled {
                cg.setFillColor(ScreenshotRenderer.color(mark.color))
                cg.setLineWidth(3 * unit)
                cg.addPath(path); cg.strokePath()
                cg.addPath(path); cg.fillPath()
            } else {
                cg.setLineWidth(width + 3 * unit)
                cg.addPath(path); cg.strokePath()
                cg.setStrokeColor(ScreenshotRenderer.color(mark.color))
                cg.setLineWidth(width)
                cg.addPath(path); cg.strokePath()
            }
            if showsHandles { for point in mark.points.prefix(2) { grip(at: point, radius: 3) } }
            return
        }
        let strokeHalfWidth = (mark.stroke.width * captureScale) / 2
        let outset: CGFloat
        switch mark.tool {
        case .rect, .ellipse:
            outset = max(3 * unit, strokeHalfWidth + 2 * unit)
        case .counter, .redact, .pixelate, .sticker:
            outset = 3 * unit
        case .text:
            outset = 0
        default:
            outset = 3 * unit
        }

        cg.setLineDash(phase: 0, lengths: mark.tool == .text ? [4 * unit, 3 * unit] : [])
        if mark.tool == .counter {
            let diameter = ScreenshotSupport.counterDiameter(for: imageSize, scale: 1)
            let box = CGRect(x: mark.rect.midX - diameter / 2, y: mark.rect.midY - diameter / 2,
                             width: diameter, height: diameter).insetBy(dx: -outset, dy: -outset)
            cg.addEllipse(in: box)
            cg.strokePath()
        } else if mark.tool == .ellipse {
            let box = mark.rect.insetBy(dx: -outset, dy: -outset)
            cg.addEllipse(in: box)
            cg.strokePath()
        } else if (mark.tool == .rect || mark.tool == .redact) && mark.isRounded {
            let box = mark.rect.insetBy(dx: -outset, dy: -outset)
            let radius = min(10 * captureScale, min(mark.rect.width, mark.rect.height) / 2) + outset
            cg.addPath(CGPath(roundedRect: box, cornerWidth: radius, cornerHeight: radius, transform: nil))
            cg.strokePath()
        } else if mark.tool == .text {
            cg.stroke(mark.rect)
        } else {
            let box = mark.rect.insetBy(dx: -outset, dy: -outset)
            cg.stroke(box)
        }
        cg.setLineDash(phase: 0, lengths: [])
        guard showsHandles else { return }
        if mark.tool == .text {
            for handle in [ScreenshotSupport.Handle.left, .right] {
                grip(at: handle.position(in: mark.rect), radius: 4.5, filled: true)
            }
            grip(at: ScreenshotSupport.Handle.bottomRight.position(in: mark.rect), radius: 3, filled: true, square: true)
        } else if mark.tool.resizesWithHandles {
            for handle in ScreenshotEditorGeometry.selectionHandles(for: mark.tool) {
                grip(at: handle.position(in: mark.rect), radius: 2.5)
            }
        }
    }
}
