// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import CoreText
import SwiftUI

/// The Stay Awake countdown as one vector shape, filled the way the bolt
/// symbol is. Live text drawn between pixels snapped each digit to the grid
/// on its own, so the digits wobbled against each other as the slide slowed;
/// a bitmap kept them together but its edges went soft and sharp by turns.
/// Glyph outlines keep the digits locked and the edges even at any position.
enum HubStayAwakeCountdownPath {
    struct Shape {
        /// Outlines in points, top-left origin, y growing downward.
        let path: Path
        /// The text's own measure: its advance width and line height.
        let size: CGSize
    }

    private struct Key: Hashable {
        let text: String
        let pointSize: CGFloat
    }

    private static var cache: [Key: Shape] = [:]

    static func font(size: CGFloat) -> NSFont {
        // The same face as .system(size:weight: .medium).monospacedDigit().
        NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium)
    }

    static func shape(_ text: String, pointSize: CGFloat) -> Shape {
        let key = Key(text: text, pointSize: pointSize)
        if let cached = cache[key] { return cached }
        let font = font(size: pointSize)
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: [.font: font]))
        let measured = (text as NSString).size(withAttributes: [.font: font])
        let size = CGSize(width: ceil(measured.width), height: ceil(measured.height))
        // Laid out as AppKit draws the line in its box: the baseline sits
        // the descender's depth above the bottom edge.
        let baseline = size.height + font.descender
        let outlines = CGMutablePath()
        for run in CTLineGetGlyphRuns(line) as? [CTRun] ?? [] {
            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }
            let attributes = CTRunGetAttributes(run) as NSDictionary
            let runFont = attributes[kCTFontAttributeName as String].map { $0 as! CTFont } ?? font as CTFont
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
            for (glyph, position) in zip(glyphs, positions) {
                guard let outline = CTFontCreatePathForGlyph(runFont, glyph, nil) else { continue }
                // Glyph outlines grow upward; flip them onto the baseline.
                let place = CGAffineTransform(a: 1, b: 0, c: 0, d: -1,
                                              tx: position.x, ty: baseline - position.y)
                outlines.addPath(outline, transform: place)
            }
        }
        // A countdown reads only a handful of strings; keep the set small.
        if cache.count > 48 { cache.removeAll() }
        let shape = Shape(path: Path(outlines), size: size)
        cache[key] = shape
        return shape
    }
}
