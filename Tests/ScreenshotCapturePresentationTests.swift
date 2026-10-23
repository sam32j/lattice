// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum ScreenshotCapturePresentationTests {
    static func run(_ suite: TestSuite) {
        ScreenshotCaptureFocusTests.run(suite)
        let original = CGContext(data: nil, width: 20, height: 10, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
        let rendered = CGContext(data: nil, width: 30, height: 15, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
        let marks = [ScreenshotSupport.Annotation(tool: .text, text: "Edited")]
        let edited = Payload.Capture(image: original, scale: 2, annotations: marks, renderedImage: rendered)
        suite.expect(edited.presentationCapture.image === rendered && edited.image === original
                     && edited.annotations == marks && edited.presentationCapture.annotations.isEmpty,
                     "history preview uses edited pixels while reopening the editor preserves editable originals")
        suite.expect(edited.presentationCapture.id == edited.id && edited.presentationCapture.scale == 2,
                     "preview, Quick Look and pinning retain the edited capture identity and scale")
        suite.expect(Payload.Capture(image: original, scale: 1).presentationCapture.image === original,
                     "unmodified captures present the original without an unnecessary render")
        let source = (try? String(contentsOfFile:
            "Sources/Vorssaint/Services/QuickTools/ScreenshotSelectionController.swift", encoding: .utf8)) ?? ""
        suite.expect(source.contains("captureFocus?.acquire(keyPanel)")
                     && source.contains("captureFocus?.release")
                     && !source.contains("NSApp.activate("),
                     "capture delegates cursor ownership and focus restoration to its bounded focus session")
        let screen = CGRect(x: 0, y: 0, width: 1400, height: 1000)
        for height: CGFloat in [72, 82, 146] {
            let frame = ScreenshotCapturePanel.guideFrame(in: screen, preferredHeight: height)
            suite.expect(frame.maxY == 898 && frame.midX == 700 && frame.width == 620,
                         "every capture toolbar sits 70 points higher with unchanged horizontal alignment")
        }
        let shortScreen = CGRect(x: 0, y: 0, width: 320, height: 130)
        suite.expect(shortScreen.contains(ScreenshotCapturePanel.guideFrame(in: shortScreen, preferredHeight: 146)),
                     "raised capture controls remain inside a short screen")
        let panel = ScreenshotCapturePanel(screenRect: CGRect(x: -10000, y: -10000, width: 320, height: 240))
        panel.isReleasedWhenClosed = false
        defer { panel.orderOut(nil); panel.close() }
        suite.expect(panel.worksWhenModal, "capture remains interactive while the app has a modal permission dialog")
        suite.expect(panel.styleMask.contains(.nonactivatingPanel),
                     "capture takes keyboard focus without activating all Lattice windows")
        suite.expect(panel.canBecomeKey && !panel.canBecomeMain,
                     "capture accepts shortcuts without becoming the app's main editor window")
        let frontmostBefore = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let mainBefore = NSApp.mainWindow
        panel.orderFrontRegardless()
        panel.makeKey()
        suite.expect(panel.isKeyWindow, "nonactivating capture still receives keyboard shortcuts")
        suite.expect(NSWorkspace.shared.frontmostApplication?.processIdentifier == frontmostBefore
                     && NSApp.mainWindow === mainBefore,
                     "presenting a capture panel does not activate the app or replace its main window")
        panel.orderOut(nil)
        suite.expect(NSWorkspace.shared.frontmostApplication?.processIdentifier == frontmostBefore,
                     "dismissing capture does not activate or reorder another application")
    }
}
