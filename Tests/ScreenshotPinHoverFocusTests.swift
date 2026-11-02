// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

/// Production focus coordination with inert window-server operations.
enum ScreenshotPinHoverFocusTests {
    class NSWindow {
        var isVisible = true, isKeyWindow = false
        var frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        var keyRequests = 0
        func makeKey() { keyRequests += 1; isKeyWindow = true }
    }
    class PinState: NSWindow {
        var isHiddenForDrag = false, isClosed = false, ignoresMouseEvents = false
        func updateHover(at point: CGPoint) {}
    }
    final class Application { var orderedWindows: [NSWindow] = [] }
    static let NSApp = Application()
    class State {
        var pins: [ScreenshotPinWindow] = []
        weak var hoverFocusPin: ScreenshotPinWindow?
    }
    static func run(_ suite: TestSuite) {
        let front = ScreenshotPinWindow(), back = ScreenshotPinWindow()
        let controller = Controller()
        controller.pins = [front, back]
        NSApp.orderedWindows = [front, back]
        defer { NSApp.orderedWindows = [] }
        let point = CGPoint(x: 50, y: 50)
        controller.updateHover(at: point)
        suite.expect(front.keyRequests == 1 && back.keyRequests == 0,
                     "overlapping pins grant focus only to the frontmost eligible window")
        front.isKeyWindow = false
        controller.updateHover(at: point)
        suite.expect(front.keyRequests == 1,
                     "a stationary pointer never takes focus back from an opened editor")
        controller.updateHover(at: CGPoint(x: 200, y: 200))
        controller.updateHover(at: point)
        suite.expect(front.keyRequests == 2, "leaving and reentering the pin intentionally grants focus again")
    }
}
