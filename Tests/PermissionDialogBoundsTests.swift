// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum PermissionDialogBoundsTests {
    static func run(_ suite: TestSuite) {
        guard let screen = NSScreen.main else {
            suite.expect(false, "dialog placement tests require a screen")
            return
        }
        let visible = screen.visibleFrame
        let parent = NSWindow(contentRect: NSRect(x: visible.maxX - 310, y: visible.maxY - 180,
                                                 width: 300, height: 150),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let dialog = NSWindow(contentRect: NSRect(x: 0, y: 0, width: visible.width * 0.7,
                                                 height: visible.height * 0.8),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        _ = PermissionDialogPresentation.run(dialog, over: parent) {
            suite.expect(visible.contains(dialog.frame),
                         "a tall file panel near the screen's upper right remains entirely reachable")
            parent.setFrameOrigin(NSPoint(x: visible.minX - 200, y: visible.minY - 100))
            NotificationCenter.default.post(name: NSWindow.didMoveNotification, object: parent)
            suite.expect(visible.contains(dialog.frame),
                         "moving the owner beyond the lower left keeps its dialog within the screen")
            return .OK
        }
    }
}
