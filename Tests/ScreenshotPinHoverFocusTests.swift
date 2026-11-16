// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

/// Production focus coordination with inert window-server operations.
enum ScreenshotPinHoverFocusTests {
    class NSWindow {
        var isVisible = true, isKeyWindow = false
        var frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        var keyRequests = 0
        var parent: NSWindow?
        func makeKey() { keyRequests += 1; isKeyWindow = true; ScreenshotPinHoverFocusTests.NSApp.keyWindow = self }
    }
    final class Application { var keyWindow: NSWindow? }
    static let NSApp = Application()
    class PinState: NSWindow {
        var isHiddenForDrag = false, isClosed = false, ignoresMouseEvents = false
        var covered = false
        func isCovered(at point: CGPoint) -> Bool { covered }
        func updateHover(at point: CGPoint) {}
        /// The window server's front-to-back stack of pins.
        class func pinsFrontToBack() -> [ScreenshotPinWindow] { ScreenshotPinHoverFocusTests.stack }
    }
    static var stack: [ScreenshotPinWindow] = []
    class State {
        static var grantsHoverFocus = false
        var pins: [ScreenshotPinWindow] = []
        weak var hoverFocusPin: ScreenshotPinWindow?
    }
    static func run(_ suite: TestSuite) {
        let front = ScreenshotPinWindow(), back = ScreenshotPinWindow()
        let controller = Controller()
        controller.pins = [front, back]
        stack = [front, back]
        defer { stack = [] }
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

        // A capture preview or the editor keeps focus while the pointer passes a pin.
        let preview = NSWindow()
        NSApp.keyWindow = preview
        front.isKeyWindow = false
        controller.updateHover(at: CGPoint(x: 200, y: 200))
        controller.updateHover(at: point)
        suite.expect(front.keyRequests == 2 && NSApp.keyWindow === preview,
                     "passing over a pin never takes focus from another Lattice window")

        // A pin under the editor is not under the pointer at all.
        NSApp.keyWindow = nil
        front.covered = true
        back.covered = true
        controller.updateHover(at: CGPoint(x: 200, y: 200))
        controller.updateHover(at: point)
        suite.expect(front.keyRequests == 2 && back.keyRequests == 0 && controller.hoverFocusPin == nil,
                     "a pin covered by another window takes neither hover nor focus")
        NSApp.keyWindow = nil
    }
}
