// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// The production finish method runs against inert capture windows and a fake
/// application handoff. No real application is activated or captured.
enum ScreenshotExitOrderingContract {
    final class Window {
        var ignoresMouseEvents = false
        var visible = true
        var restored = false
        var hiddenBeforeHandoff = false
        func orderOut(_ sender: Any?) { hiddenBeforeHandoff = !restored; visible = false }
    }
    final class Focus {
        let window: Window
        var visibleDuringHandoff = false
        init(_ window: Window) { self.window = window }
        func release(completion: () -> Void) {
            visibleDuringHandoff = window.visible
            window.restored = true
            completion()
        }
    }
    final class Waiting { func hide() {} }
    final class Monitor { func stop() {} }
    final class Options { var onSelectionChange: (() -> Void)? }
    enum CATransaction { static func flush() {} }
    enum NSEvent { static func removeMonitor(_ token: Int) {} }
    final class RecorderOverlayController {
        static let shared = RecorderOverlayController()
        func stop() {}
    }
}

enum ScreenshotExitOrderingTests {
    static func run(_ suite: TestSuite) {
        typealias Contract = ScreenshotExitOrderingContract
        let controller = Contract.Controller()
        let window = controller.panels[0]
        let focus = Contract.Focus(window)
        controller.captureFocus = focus
        controller.finish(.cancelled)
        suite.expect(focus.visibleDuringHandoff && !window.hiddenBeforeHandoff,
                     "Escape restores the original app before hiding capture panels, preventing a settings flash")
        suite.expect(controller.completed && !window.visible && window.ignoresMouseEvents,
                     "capture completion retires panels after the focus handoff")
        let early = Contract.Controller()
        early.finish(.cancelled)
        suite.expect(early.completed && !early.panels[0].visible,
                     "cancelling before focus acquisition still completes and retires the chooser")
    }
}
