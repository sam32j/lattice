// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreImage

enum ScreenshotPreviewTransformTests {
    static func run(_ suite: TestSuite) {
        guard let context = CGContext(data: nil, width: 6, height: 4, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        context.setFillColor(NSColor.red.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 3, height: 4))
        context.setFillColor(NSColor.blue.cgColor)
        context.fill(CGRect(x: 3, y: 0, width: 3, height: 4))
        guard let original = context.makeImage(),
              let flipped = ScreenshotPreviewImageActions.transformed(original, .flipHorizontal),
              let rotated = ScreenshotPreviewImageActions.transformed(original, .rotateLeft)
        else { suite.expect(false, "preview transformations allocate valid image frames"); return }
        let sample = RecorderOverlayCompositionTests.pixel
        suite.expect(sample(CIImage(cgImage: flipped), CGPoint(x: 0, y: 0))[2] > 240,
                     "horizontal flip changes image pixels, not only thumbnail presentation")
        suite.expect(rotated.width == 4 && rotated.height == 6,
                     "Rotate Left swaps the capture dimensions without resampling")
        suite.expect(sample(CIImage(cgImage: rotated), CGPoint(x: 1, y: 1))[0] > 240
                     && sample(CIImage(cgImage: rotated), CGPoint(x: 1, y: 5))[2] > 240,
                     "Rotate Left turns the image counterclockwise")
        let owner = NSPanel()
        owner.isReleasedWhenClosed = false
        owner.level = ScreenshotPinWindow.pinLevel
        defer { owner.close() }
        suite.expect(ScreenshotWindowLayering.editorLevel(above: owner).rawValue > owner.level.rawValue
                     && ScreenshotWindowLayering.editorLevel(above: nil).rawValue > ScreenshotPinWindow.pinLevel.rawValue,
                     "all capture editors sit above pins and ordinary app windows")
        let editorWindow = NSWindow()
        editorWindow.isReleasedWhenClosed = false
        editorWindow.level = ScreenshotWindowLayering.editorLevel(above: owner)
        defer { editorWindow.close() }
        let dialogLevel = ScreenshotWindowLayering.dialogLevel(above: editorWindow)
        suite.expect(dialogLevel.rawValue > editorWindow.level.rawValue
                     && dialogLevel.rawValue >= NSWindow.Level.modalPanel.rawValue,
                     "dialogs sit strictly above the editor window level even when editor is above a pinned window")
        suite.expect(ScreenshotWindowLayering.dialogLevel(above: nil).rawValue
                     > ScreenshotWindowLayering.editorLevel(above: nil).rawValue
                     && dialogLevel.rawValue < NSWindow.Level.screenSaver.rawValue,
                     "capture dialogs stay above editors but below Liftoff's screen-saver-level window")
        let rawFinderPaths = "/tmp/file\nwith\nnewlines.png\0/tmp/other.png\0"
        let parsed = rawFinderPaths.split(separator: "\0").map { String($0) }.filter { !$0.isEmpty }.map { URL(fileURLWithPath: $0) }
        suite.expect(parsed.count == 2 && parsed.first?.path == "/tmp/file\nwith\nnewlines.png",
                     "FinderBridge parses null-separated paths preserving embedded newlines")
    }
}
