// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum ScreenshotReopenedBlurTests {
    // The generated model uses the production initializer and sample builders.
    // Backdrop/watermark loading is unrelated to restoring censor samples.
    static func run(_ suite: TestSuite) {
        let image = CGContext(data: nil, width: 100, height: 100, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
        let marks: [ScreenshotSupport.Annotation] = [
            .init(tool: .pixelate, rect: CGRect(x: 10, y: 10, width: 40, height: 40), blurLevel: 3),
            .init(tool: .pixelate, rect: CGRect(x: 50, y: 50, width: 40, height: 40), blurLevel: 5, blurStyle: .blur)
        ]
        let model = Model(image: image, scale: 2, annotations: marks)
        suite.expect(model.pixelated[3] != nil && model.softBlurred[5] != nil,
                     "reopening editable captures prepares both censor styles before the first canvas draw")
        let empty = Model(image: image, scale: 2)
        suite.expect(empty.pixelated.isEmpty && empty.softBlurred.isEmpty,
                     "captures without censor annotations allocate no blur samples")
    }
}
