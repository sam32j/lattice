// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum ScreenshotQuickLookTests {
    @MainActor static func run(_ suite: TestSuite, image: CGImage) {
        let owner = NSPanel(contentRect: CGRect(x: 100, y: 100, width: 200, height: 100),
                            styleMask: [.titled], backing: .buffered, defer: true)
        owner.isReleasedWhenClosed = false
        let preview = ScreenshotQuickLookController()
        defer { preview.close(); owner.close() }
        suite.expect(preview.show(image: image, scale: 2, owner: owner),
                     "native Quick Look accepts a screenshot without launching an image editor")
        let url = preview.previewURL
        suite.expect(url != nil && FileManager.default.fileExists(atPath: url!.path),
                     "Quick Look owns a preview file for its visible lifetime")
        preview.cancelOperation(nil)
        suite.expect(!preview.isVisible && preview.previewURL == nil,
                     "Escape dismisses native Quick Look and releases its screenshot")
        suite.expect(url.map { !FileManager.default.fileExists(atPath: $0.path) } == true,
                     "dismissing Quick Look removes its temporary preview file")
    }
}
