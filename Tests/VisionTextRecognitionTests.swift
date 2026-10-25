// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import CoreText

/// A generated text bitmap only. Never reads the screen, user files or clipboard.
enum VisionTextRecognitionTests {
    static func run(_ suite: TestSuite) {
        guard let context = CGContext(data: nil, width: 640, height: 100, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            suite.expect(false, "synthetic OCR fixture has a bitmap context"); return
        }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 640, height: 100))
        let text = NSAttributedString(string: "LOCAL OCR READY", attributes: [
            .font: NSFont.systemFont(ofSize: 40), .foregroundColor: NSColor.black])
        context.textPosition = CGPoint(x: 16, y: 24)
        CTLineDraw(CTLineCreateWithAttributedString(text), context)
        guard let image = context.makeImage() else { suite.expect(false, "synthetic OCR image exists"); return }
        VisionTextRecognition.prepare()
        VisionTextRecognition.prepare()
        let observations = VisionTextRecognition.observations(in: image, detectLanguage: false, languages: ["en-US"])
        let result = observations?.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
        suite.expect(result?.contains("LOCAL OCR READY") == true,
                     "real synthetic-image recognition stays available behind idempotent warm-up")
    }
}
