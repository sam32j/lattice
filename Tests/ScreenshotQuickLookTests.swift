// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum ScreenshotQuickLookTests {
    @MainActor static func run(_ suite: TestSuite, image: CGImage) {
        let owner = NSPanel(contentRect: CGRect(x: 100, y: 100, width: 200, height: 100),
                            styleMask: [.titled], backing: .buffered, defer: true)
        owner.isReleasedWhenClosed = false
        owner.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        let preview = ScreenshotQuickLookController()
        defer { preview.close(); owner.close() }
        suite.expect(preview.show(image: image, scale: 2, owner: owner),
                     "native Quick Look accepts a screenshot without launching an image editor")
        suite.expect((preview.presentationWindow?.level.rawValue ?? 0) > owner.level.rawValue,
                     "Quick Look remains above its Dynamic Island owner")
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
