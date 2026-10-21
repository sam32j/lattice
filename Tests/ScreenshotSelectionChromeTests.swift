// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum ScreenshotSelectionChromeTests {
    static func run(_ suite: TestSuite) {
        let samples = [ScreenshotSupport.Annotation(tool: .line)]
            + ScreenshotSupport.ArrowStyleID.allCases.map { ScreenshotSupport.Annotation(tool: .arrow, arrowStyle: $0) }
        for sample in samples {
            let tool = sample.tool
            let context = CGContext(data: nil, width: 300, height: 100, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            let mark = ScreenshotSupport.Annotation(tool: tool,
                points: [CGPoint(x: 20, y: 50), CGPoint(x: 280, y: 50)], color: .red, arrowStyle: sample.arrowStyle)
            ScreenshotRenderer.drawAnnotations([mark], in: context, blurSources: .none,
                imageSize: CGSize(width: 300, height: 100), scale: 1, annotationShadowsEnabled: false)
            ScreenshotSelectionChrome.draw(mark, in: context, captureScale: 1, displayZoom: 1,
                imageSize: CGSize(width: 300, height: 100))
            let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
            var blue = 0, red = 0
            for y in 0..<100 { for x in 40..<260 {
                let offset = y * context.bytesPerRow + x * 4
                if pixels[offset] < 80 && pixels[offset + 1] > 80 && pixels[offset + 2] > 180 { blue += 1 }
                if pixels[offset] > 180 && pixels[offset + 2] < 80 { red += 1 }
            } }
            suite.expect(blue > 100, "selected \(tool) has a blue outline along its body, not just endpoint grips")
            suite.expect(red > 100, "selection preserves the \(tool)'s original color inside its blue outline")
        }
        for handle in ScreenshotSupport.Handle.allCases {
            let cursor = ScreenshotEditorResizeCursor.cursor(for: handle)
            suite.expect(cursor !== NSCursor.openHand && cursor.image.size.width > 0,
                         "a \(handle) resize grip has a directional resize cursor")
        }
    }
}
