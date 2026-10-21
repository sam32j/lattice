// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum ScreenshotWatermarkCollectionTests {
    class State {
        var watermarkPresets: [ScreenshotSupport.WatermarkStyle] = []
        var watermarkStyle = ScreenshotSupport.WatermarkStyle()
        var watermarkImage: CGImage?
    }

    static func run(_ suite: TestSuite) {
        let model = Model()
        let applied = ScreenshotSupport.WatermarkStyle(kind: .image, imagePath: "/tmp/applied-logo.png")
        model.watermarkStyle = applied
        model.watermarkPresets = [applied]
        model.removeWatermarkPreset(at: 0)
        suite.expect(model.watermarkPresets.isEmpty && model.watermarkStyle == applied,
                     "collection storage alone does not mutate the screenshot's watermark")
        model.removeWatermarkPreset(at: 0)
        suite.expect(model.watermarkStyle == applied, "a stale collection deletion cannot clear the applied image")
        model.addWatermarkPreset(.init(kind: .text, text: "Not a collection item"))
        suite.expect(model.watermarkPresets.isEmpty, "typing text cannot create a watermark collection entry")
    }
}
