// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

enum NotchMusicMouseControllerTests {
    static func run(_ suite: TestSuite) {
        var timers: [DispatchWorkItem] = []
        var changes: [Bool] = []
        var update: NotchMusicMouseSwipeController.NativeUpdate?
        let state = NotchMusicSwipeState(scheduleExpiry: { _, work in timers.append(work) })
        let controller = NotchMusicMouseSwipeController(state: state,
            schedule: { _, work in timers.append(work) }, commit: { changes.append($0); return true })
        func begin(_ x: Double) {
            _ = controller.receive(x: 0, y: 0, phase: .began, precise: true, momentum: false,
                enabled: true, expanded: true, hasTouches: false) { update = $0 }
            _ = controller.receive(x: x, y: 0, phase: .changed, precise: true, momentum: false,
                enabled: true, expanded: true, hasTouches: false) { update = $0 }
        }
        begin(-8)
        suite.expect(update?(0.5, .changed, false) == false && changes.isEmpty
                     && state.frame.direction == .next && state.frame.progress == 0.5,
                     "Magic Mouse holds the shared cue until native finger-lift completion")
        let previous = update
        suite.expect(update?(0.5, .ended, false) == true && changes == [true] && state.completionPending,
                     "native accepted end commits one next-track action and completes the cue")
        _ = update?(1, .ended, true)
        suite.expect(changes == [true], "native animation completion cannot duplicate a track skip")
        begin(8)
        _ = update?(0.4, .changed, false)
        _ = previous?(1, .ended, true)
        suite.expect(state.frame.direction == .previous && state.frame.progress == 0.4 && changes == [true],
                     "a stale native callback cannot clear or commit a newer swipe")
        let interrupted = update
        begin(-8)
        _ = interrupted?(1, .ended, false)
        _ = update?(0.3, .changed, false)
        suite.expect(state.frame.direction == .next && changes == [true],
                     "a fresh physical begin replaces an interrupted native sequence immediately")
        controller.cancel()
        _ = update?(1, .ended, false)
        suite.expect(changes == [true] && state.frame.progress == 0,
                     "surface cancellation clears the cue and rejects a late lift")
        begin(-8)
        _ = update?(0.2, .changed, false)
        timers.last?.perform()
        _ = update?(1, .ended, false)
        suite.expect(changes == [true] && state.frame.progress == 0,
                     "a missing native end times out safely instead of leaving a stuck icon")
        func scroll(_ x: Double, phase: NSEvent.Phase, momentum: Bool = false, touches: Bool = false) {
            _ = controller.receive(x: x, y: 0, phase: phase, precise: true, momentum: momentum,
                enabled: true, expanded: false, hasTouches: touches, nativeTracking: false) { _ in
                    suite.expect(false, "disabled system gestures must not invoke native swipe tracking")
                }
        }
        scroll(0, phase: .began)
        scroll(-100, phase: .changed)
        suite.expect(changes == [true] && state.frame.progress == 1 && state.frame.direction == .next,
                     "system-gesture-off fallback holds an armed cue without changing the track")
        scroll(0, phase: .ended)
        scroll(0, phase: .ended)
        scroll(-100, phase: .changed, momentum: true)
        suite.expect(changes == [true, true], "fallback commits once on lift and ignores momentum and repeated ends")
        scroll(0, phase: .began)
        scroll(10, phase: .changed)
        scroll(0, phase: .ended)
        suite.expect(changes == [true, true] && state.frame.progress == 0,
                     "short fallback gestures clear without changing tracks")
        scroll(0, phase: .began)
        scroll(100, phase: .changed)
        scroll(0, phase: .cancelled)
        suite.expect(changes == [true, true] && state.frame.progress == 0,
                     "cancelled fallback gestures clear without a skip")
        scroll(0, phase: .began)
        scroll(100, phase: .changed)
        scroll(0, phase: .ended)
        suite.expect(changes == [true, true, false], "positive AppKit deltas select the previous track without a second inversion")
        scroll(0, phase: .mayBegin)
        scroll(0, phase: .began)
        scroll(-100, phase: .changed)
        scroll(0, phase: .ended)
        suite.expect(changes == [true, true, false], "trackpad may-begin sequences never use the mouse fallback")
        scroll(0, phase: .began)
        scroll(-100, phase: .changed)
        timers.last?.perform()
        scroll(0, phase: .ended)
        suite.expect(changes == [true, true, false] && state.frame.progress == 0,
                     "missing fallback lift times out and a late end cannot skip")
    }
}
