// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum ScreenshotMultiWindowShiftTests {
    static func run(_ suite: TestSuite) {
        var shiftDown = true, canConfirm = true, captures = 0
        let watcher = ScreenshotMultiWindowShiftMonitor(shiftIsPressed: { shiftDown },
            canConfirm: { canConfirm }, released: { captures += 1 })
        func tick() { RunLoop.main.run(until: Date().addingTimeInterval(0.12)) }
        watcher.start()
        watcher.start()
        tick()
        suite.expect(captures == 0, "multi-window selection waits while Shift remains held")
        shiftDown = false
        canConfirm = false
        tick()
        suite.expect(captures == 0, "Shift release waits for an in-progress pointer gesture or refresh")
        canConfirm = true
        tick()
        tick()
        suite.expect(captures == 1, "Shift release confirms once even if the monitor was started twice")
        watcher.start()
        watcher.stop()
        tick()
        suite.expect(captures == 1, "clearing or cancelling selection stops release confirmation")
        watcher.start()
        tick()
        suite.expect(captures == 2, "a later selection can arm its own Shift-release confirmation")
        var temporary: ScreenshotMultiWindowShiftMonitor? = ScreenshotMultiWindowShiftMonitor(
            shiftIsPressed: { false }, released: { captures += 1 })
        temporary?.start()
        let liveWatchers = NSHashTable<ScreenshotMultiWindowShiftMonitor>.weakObjects()
        liveWatchers.add(temporary)
        temporary = nil
        tick()
        suite.expect(liveWatchers.allObjects.isEmpty && captures == 2,
                     "the run loop does not retain a dead selection or fire its completion")
    }
}
