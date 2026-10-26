// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit

/// Settings uses the same native sheet presentation as its changelog.
/// Other entry points retain a standalone window when Settings is not visible.
enum FeedbackWindowPresentation {
    static func present(_ window: NSWindow, from settings: NSWindow?, fallbackVisibleFrame: CGRect) {
        guard window.sheetParent == nil else {
            window.makeKeyAndOrderFront(nil)
            return
        }
        window.setContentSize(FeedbackWindowGeometry.size)
        window.parent?.removeChildWindow(window)
        if let settings, settings.isVisible {
            settings.beginSheet(window) { _ in window.orderOut(nil) }
        } else {
            window.setFrame(FeedbackWindowGeometry.targetFrame(settingsFrame: nil,
                            visibleFrame: fallbackVisibleFrame), display: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    static func dismiss(_ window: NSWindow) {
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            window.parent?.removeChildWindow(window)
            window.close()
        }
    }
}
