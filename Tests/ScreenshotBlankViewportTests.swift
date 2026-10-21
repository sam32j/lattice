// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum ScreenshotBlankViewportTests {
    static func run(_ suite: TestSuite) {
        func image(content: Bool, transparent: Bool = false) -> CGImage {
            let context = CGContext(data: nil, width: 100, height: 100, bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.setFillColor(NSColor.darkGray.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            context.clear(CGRect(x: 20, y: 20, width: 60, height: 60))
            if !transparent {
                context.setFillColor(NSColor.white.cgColor)
                context.fill(CGRect(x: 20, y: 20, width: 60, height: 60))
            }
            if content {
                context.setFillColor(NSColor.blue.cgColor)
                context.fill(CGRect(x: 25, y: 25, width: 25, height: 40))
            }
            return context.makeImage()!
        }
        suite.expect(ScreenshotSupport.isImageBlank(image(content: false)),
                     "opaque white Chromium viewport is suspect even with nonuniform browser chrome")
        suite.expect(ScreenshotSupport.isImageBlank(image(content: false, transparent: true)),
                     "transparent GPU viewport remains blank")
        suite.expect(!ScreenshotSupport.isImageBlank(image(content: true)),
                     "a composed viewport with meaningful content is not blank")
        let composed = image(content: true)
        let blank = image(content: false)
        let fallback = ScreenshotSupport.resolvedWindowCapture((blank, 2),
            frozenImage: composed, viewFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            viewSize: CGSize(width: 100, height: 100), fallbackScale: 1)
        suite.expect(fallback?.scale == 1 && fallback.map { !ScreenshotSupport.isImageBlank($0.image) } == true,
                     "a missing GPU viewport is replaced by the fully composed frozen display pixels")
        let usable = ScreenshotSupport.resolvedWindowCapture((composed, 2),
            frozenImage: blank, viewFrame: .zero, viewSize: .zero, fallbackScale: 1)
        suite.expect(usable?.image === composed && usable?.scale == 2,
                     "a valid independent window keeps its pixels and scale without cropping the display")
        let partial = ScreenshotSupport.resolvedWindowCapture((blank, 2),
            frozenImage: composed, viewFrame: CGRect(x: -20, y: 0, width: 100, height: 100),
            viewSize: CGSize(width: 100, height: 100), fallbackScale: 1)
        suite.expect(partial?.image === blank && partial?.scale == 2,
                     "a partially offscreen window keeps its independent pixels instead of a clipped display crop")
        let sparseContext = CGContext(data: nil, width: 100, height: 100, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        sparseContext.draw(blank, in: CGRect(x: 0, y: 0, width: 100, height: 100))
        sparseContext.setFillColor(NSColor.black.cgColor)
        sparseContext.fill(CGRect(x: 25, y: 25, width: 8, height: 8))
        suite.expect(!ScreenshotSupport.isImageBlank(sparseContext.makeImage()!),
                     "a mostly white viewport with sparse real content is not a blank GPU layer")
        let frame = CGRect(x: 20, y: 20, width: 60, height: 60)
        let target = ScreenshotSupport.PickableWindow(windowID: 1, frame: frame)
        let covering = ScreenshotSupport.PickableWindow(windowID: 2, frame: frame)
        let viewSize = CGSize(width: 100, height: 100)
        suite.expect(ScreenshotSupport.canUseFrozenWindowCapture(windowID: 1, frame: frame,
            viewSize: viewSize, windows: [target, covering]),
                     "windows behind the selected window do not block a composed-display fallback")
        suite.expect(!ScreenshotSupport.canUseFrozenWindowCapture(windowID: 1, frame: frame,
            viewSize: viewSize, windows: [covering, target]),
                     "a foreground overlapping window makes a display crop unsafe")
        suite.expect(!ScreenshotSupport.canUseFrozenWindowCapture(windowID: 1, frame: frame,
            viewSize: viewSize, windows: []), "missing window metadata never authorizes a display crop")
    }
}
