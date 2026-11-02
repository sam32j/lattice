// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import AppKit

extension WindowGestureFrontingRuntimeTests {
    static func completionChecks(_ suite: TestSuite) {
        WindowGestureSessionTests.run(suite)
        defer { targetWindow = Window() }
        boundary = Boundary()
        boundary.frontDelay = 0.12
        raiseEnabled = true
        let host = Host()
        send(host, .leftMouseDown, at: CGPoint(x: 200, y: 200))
        send(host, .leftMouseDragged, at: CGPoint(x: 240, y: 210))
        send(host, .leftMouseUp, at: CGPoint(x: 250, y: 220))
        targetWindow = Window(id: 8)
        send(host, .leftMouseDown, at: CGPoint(x: 500, y: 500))
        send(host, .leftMouseDragged, at: CGPoint(x: 540, y: 510))
        send(host, .leftMouseUp, at: CGPoint(x: 560, y: 525))
        host.flushGestureApplies()
        suite.expect(boundary.frame.origin == CGPoint(x: 150, y: 120)
                     && boundary.frame(for: 8).origin == CGPoint(x: 460, y: 425),
                     "queued consecutive gestures retain each exact window and final pointer position")
        suite.expect(boundary.log.filter { $0 == "restore" }.count == 4,
                     "each queued gesture restores accessibility after its own final frame")

        targetWindow = Window()
        boundary = Boundary()
        boundary.frontDelay = 0.12
        let cancelled = Host()
        send(cancelled, .leftMouseDown, at: CGPoint(x: 200, y: 200))
        send(cancelled, .leftMouseDragged, at: CGPoint(x: 240, y: 210))
        let start = ProcessInfo.processInfo.systemUptime
        send(cancelled, .tapDisabledByTimeout, at: .zero)
        suite.expect(ProcessInfo.processInfo.systemUptime - start < 0.075,
                     "cancelling during slow fronting does not block subsequent input")
        cancelled.flushGestureApplies()
        suite.expect(!boundary.log.contains { $0.hasPrefix("frame:") },
                     "cancelled preparation never sends a late frame to the window")

        boundary = Boundary()
        let started = DispatchSemaphore(value: 0), hold = DispatchSemaphore(value: 0)
        boundary.frontStarted = started; boundary.frontHold = hold
        let stopped = Host()
        send(stopped, .leftMouseDown, at: CGPoint(x: 200, y: 200))
        send(stopped, .leftMouseDragged, at: CGPoint(x: 240, y: 210))
        _ = started.wait(timeout: .now() + 1)
        send(stopped, .leftMouseUp, at: CGPoint(x: 250, y: 220))
        stopped.stopGestureTap()
        hold.signal()
        stopped.flushGestureApplies()
        suite.expect(!boundary.log.contains { $0.hasPrefix("frame:") || $0.hasPrefix("raise:") || $0 == "suspend" },
                     "teardown after release cancels a sealed session still waiting on fronting")

        boundary = Boundary()
        let snap = Host()
        var first = WindowPointerGesture(window: Window(), kind: .move, button: .primary,
            originalFrame: boundary.frame, pointerStart: .zero, lastAppliedAt: 0)
        first.snapsAtEdges = true
        first.applyContext.originalFrame = boundary.frame
        var second = WindowPointerGesture(window: Window(), kind: .move, button: .primary,
            originalFrame: boundary.frame, pointerStart: .zero, lastAppliedAt: 0)
        second.snapsAtEdges = true
        second.applyContext.originalFrame = boundary.frame
        snap.forwardToEdgeSnap(first, .moveGestureBegan(pressOrigin: .zero, initialFrame: boundary.frame,
                                                       windowID: 7, processID: 1001))
        snap.flushGestureApplies()
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        snap.forwardToEdgeSnap(second, .moveGestureBegan(pressOrigin: .zero, initialFrame: boundary.frame,
                                                        windowID: 7, processID: 1001))
        snap.forwardToEdgeSnap(first, .up(location: .zero, time: 1))
        snap.forwardToEdgeSnap(second, .dragged(location: CGPoint(x: 10, y: 10), time: 2))
        snap.flushGestureApplies()
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        suite.expect(snap.snapInputs.count == 3 && !snap.snapInputs.contains { if case .up = $0 { return true }; return false },
                     "a delayed release cannot finish or snap a newer modifier-drag session")
    }
}
