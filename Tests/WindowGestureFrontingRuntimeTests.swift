// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import CoreGraphics
import Foundation

/// Real event callbacks and the real coalescing queue, with only the window
/// server, app activation and Accessibility operations replaced at the boundary.
enum WindowGestureFrontingRuntimeTests {
    static var raiseEnabled = true
    static var windowIDReadable = true
    static var boundary = Boundary()

    final class Boundary {
        private let lock = NSLock()
        var frontDelay: TimeInterval = 0
        private var entries: [String] = []
        private var enhanced = true
        private var current = CGRect(x: 100, y: 100, width: 800, height: 500)
        var log: [String] { lock.lock(); defer { lock.unlock() }; return entries }
        var frame: CGRect { lock.lock(); defer { lock.unlock() }; return current }
        func record(_ entry: String) { lock.lock(); entries.append(entry); lock.unlock() }
        func setEnhanced(_ enabled: Bool) {
            lock.lock(); enhanced = enabled; entries.append(enabled ? "restore" : "suspend"); lock.unlock()
        }
        func frame(_ point: CGPoint) {
            lock.lock(); defer { lock.unlock() }
            current.origin = point
            entries.append("frame:\(Int(point.x)),\(Int(point.y)):\(enhanced ? "enhanced" : "direct")")
        }
        func size(_ size: CGSize) {
            lock.lock(); defer { lock.unlock() }
            current.size = size
            entries.append("size:\(Int(size.width)),\(Int(size.height)):\(enhanced ? "enhanced" : "direct")")
        }
    }

    struct Window { let pid: pid_t = 1001; let id: CGWindowID = 7 }
    typealias AXUIElement = Window
    static func AXIsProcessTrusted() -> Bool { true }
    static func AXUIElementGetPid(_ window: Window, _ pid: inout pid_t) -> AXError {
        pid = window.pid; return .success
    }
    static func AXUIElementPerformAction(_ window: Window, _ action: CFString) -> AXError {
        boundary.setEnhanced(true)
        boundary.record("raise:\(window.id)"); return .success
    }
    enum AXWindowResolver {
        static func windowID(for window: Window) -> CGWindowID? { windowIDReadable ? window.id : nil }
    }
    enum SpaceWindowBridge {
        static func orderWindowFront(_ windowID: CGWindowID, ownerPID: pid_t) -> Bool {
            let recorder = boundary
            recorder.record("front-start:\(windowID)")
            Thread.sleep(forTimeInterval: recorder.frontDelay)
            recorder.record("front-end:\(windowID)")
            return true
        }
    }
    final class NSRunningApplication {
        let processIdentifier: pid_t
        init?(processIdentifier: pid_t) { self.processIdentifier = processIdentifier }
        func activate(options: AppKit.NSApplication.ActivationOptions) -> Bool {
            boundary.record("activate"); return true
        }
    }
    struct EnhancedUserInterfaceSuspension {
        static func suspend(forAppOf window: Window) -> Self? {
            boundary.setEnhanced(false); return Self()
        }
        func resume() { boundary.setEnhanced(true) }
    }
    enum UserDefaults {
        struct Store {
            func bool(forKey key: String) -> Bool { raiseEnabled }
            func string(forKey key: String) -> String? { nil }
        }
        static let standard = Store()
    }

    class Fixture {
        static let syntheticEventMarker: Int64 = 0x564F5253
        static let ownProcessID: Int64 = -1
        var activeGesture: WindowPointerGesture?
        var pendingGesture: PendingWindowGesture?
        var gestureAssistiveMode: EnhancedUserInterfaceSuspension?
        var gestureTap: CFMachPort?
        var edgeSnapTap: CFMachPort?
        let moveGestureUpdateInterval: TimeInterval = 0
        let resizeGestureUpdateInterval: TimeInterval = 0
        let gestureApplyQueue = DispatchQueue(label: "test fronting and movement", qos: .userInteractive)
        let gestureApplyLock = NSLock()
        var pendingGestureApply: (gesture: WindowPointerGesture, pointer: CGPoint)?
        var gestureApplyDraining = false
        var replayedClicks = 0

        func syncWithPreferences() {}
        func isTrackedButtonDown() -> Bool { false }
        func forwardToEdgeSnap(_ gesture: WindowPointerGesture, _ input: WindowEdgeSnapPointerInput) {}
        static func seconds(of event: CGEvent) -> TimeInterval { Double(event.timestamp) / 1e9 }
        func gestureTarget(at point: CGPoint, requiresResize: Bool) -> WindowGestureTarget? {
            WindowGestureTarget(window: Window(), app: NSRunningApplication(processIdentifier: 1001)!,
                frame: WindowLayoutFrame(origin: boundary.frame.origin, size: boundary.frame.size))
        }
        func flushPending(proxy: CGEventTapProxy?, at point: CGPoint?) {
            if pendingGesture != nil { replayedClicks += 1; pendingGesture = nil }
        }
        func setPosition(_ point: CGPoint, on window: Window) -> Bool { boundary.frame(point); return true }
        func setSize(_ size: CGSize, on window: Window) -> Bool { boundary.size(size); return true }
        func frame(of window: Window) -> WindowLayoutFrame? {
            WindowLayoutFrame(origin: boundary.frame.origin, size: boundary.frame.size)
        }
    }

    @discardableResult
    static func send(_ host: Host, _ type: CGEventType, at point: CGPoint,
                     flags: CGEventFlags = [.maskControl, .maskCommand]) -> Bool {
        let event = CGEvent(source: nil)!
        event.location = point
        event.flags = flags
        event.setIntegerValueField(.eventSourceUnixProcessID, value: 1001)
        return host.handleGestureEvent(proxy: nil, type: type, event: event) != nil
    }

    static func run(_ suite: TestSuite) {
        boundary = Boundary()
        boundary.frontDelay = 0.15
        raiseEnabled = true
        let host = Host()
        send(host, .leftMouseDown, at: CGPoint(x: 200, y: 200))
        let began = ProcessInfo.processInfo.systemUptime
        send(host, .leftMouseDragged, at: CGPoint(x: 240, y: 210))
        let duration = ProcessInfo.processInfo.systemUptime - began
        send(host, .leftMouseDragged, at: CGPoint(x: 300, y: 230))
        send(host, .leftMouseUp, at: CGPoint(x: 350, y: 240))
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        let log = boundary.log
        print("WINDOW_FRONTING callbackMs=\(duration * 1000) log=\(log)")
        suite.expect(duration < 0.075,
                     "a slow application fronting response does not stall the modifier-drag input callback")
        suite.expect(log.firstIndex(of: "front-end:7")! < log.firstIndex(of: "suspend")!,
                     "the selected window comes forward before entering the normal drag preparation")
        suite.expect(log.filter { $0 == "front-start:7" }.count == 1
                     && log.filter { $0 == "raise:7" }.count == 1 && !log.contains("activate"),
                     "one drag fronts its selected window once and does not activate again at release")
        suite.expect(log.contains("frame:250,140:direct") && !log.contains { $0.hasSuffix(":enhanced") },
                     "the final pointer position lands through the normal direct path after fronting finishes")

        boundary = Boundary()
        raiseEnabled = false
        let background = Host()
        send(background, .leftMouseDown, at: CGPoint(x: 200, y: 200))
        send(background, .leftMouseDragged, at: CGPoint(x: 240, y: 210))
        send(background, .leftMouseUp, at: CGPoint(x: 350, y: 240))
        suite.expect(boundary.log.first == "suspend" && boundary.log.last == "restore"
                     && boundary.log.contains("frame:250,140:direct")
                     && !boundary.log.contains { $0.hasPrefix("front") || $0.hasPrefix("raise") || $0 == "activate" },
                     "with fronting off the same queue applies the final move and restores accessibility without raising")

        boundary = Boundary()
        raiseEnabled = true
        let click = Host()
        let held = !send(click, .leftMouseDown, at: CGPoint(x: 200, y: 200))
        let released = send(click, .leftMouseUp, at: CGPoint(x: 200, y: 200))
        suite.expect(held && released && click.replayedClicks == 1 && boundary.log.isEmpty,
                     "a plain modifier-click goes back to the app without fronting, moving or changing accessibility")

        boundary = Boundary()
        let cancelled = Host()
        send(cancelled, .leftMouseDown, at: CGPoint(x: 200, y: 200))
        send(cancelled, .leftMouseDragged, at: CGPoint(x: 240, y: 210))
        cancelled.flushGestureApplies()
        send(cancelled, .tapDisabledByTimeout, at: .zero)
        let cancelledLog = boundary.log
        send(cancelled, .leftMouseUp, at: CGPoint(x: 350, y: 240))
        suite.expect(cancelled.activeGesture == nil && cancelledLog.last == "restore"
                     && boundary.log == cancelledLog,
                     "a drag interrupted by a lost release flushes its frame and restores without a late activation")

        boundary = Boundary()
        boundary.frontDelay = 0.1
        let earlyCancel = Host()
        send(earlyCancel, .leftMouseDown, at: CGPoint(x: 200, y: 200))
        send(earlyCancel, .leftMouseDragged, at: CGPoint(x: 240, y: 210))
        send(earlyCancel, .tapDisabledByTimeout, at: .zero)
        let afterCancel = boundary.log
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        suite.expect(earlyCancel.activeGesture == nil && afterCancel.last == "restore"
                     && afterCancel == boundary.log,
                     "cancelling during delayed startup finishes its queued work before restoring and leaves no late focus or frames")

        boundary = Boundary()
        let consecutive = Host()
        for end in [CGPoint(x: 250, y: 220), CGPoint(x: 260, y: 225)] {
            send(consecutive, .leftMouseDown, at: CGPoint(x: 200, y: 200))
            send(consecutive, .leftMouseDragged, at: CGPoint(x: 240, y: 210))
            send(consecutive, .leftMouseUp, at: end)
        }
        let suspensions = boundary.log.indices.filter { boundary.log[$0] == "suspend" }
        suite.expect(suspensions.count == 2 && boundary.log[suspensions[1] - 1] == "raise:7"
                     && boundary.log.last == "restore" && boundary.frame.origin == CGPoint(x: 210, y: 145)
                     && !boundary.log.contains { $0.hasSuffix(":enhanced") },
                     "back-to-back drags each front and prepare before moving, with the final frame and restoration retained")

        boundary = Boundary()
        windowIDReadable = false
        let withoutID = Host()
        send(withoutID, .leftMouseDown, at: CGPoint(x: 200, y: 200))
        send(withoutID, .leftMouseDragged, at: CGPoint(x: 240, y: 210))
        send(withoutID, .leftMouseUp, at: CGPoint(x: 350, y: 240))
        suite.expect(boundary.log.prefix(4) == ["activate", "restore", "raise:7", "suspend"]
                     && boundary.log.last == "restore" && boundary.frame.origin == CGPoint(x: 250, y: 140),
                     "when a server ID is unavailable app activation and the selected AX raise precede the normal drag")
        windowIDReadable = true

        boundary = Boundary()
        let resized = Host()
        let resizeFlags: CGEventFlags = [.maskControl, .maskCommand, .maskShift]
        send(resized, .leftMouseDown, at: CGPoint(x: 850, y: 550), flags: resizeFlags)
        send(resized, .leftMouseDragged, at: CGPoint(x: 900, y: 580), flags: resizeFlags)
        send(resized, .leftMouseUp, at: CGPoint(x: 900, y: 580), flags: resizeFlags)
        suite.expect(boundary.frame == CGRect(x: 100, y: 100, width: 850, height: 530)
                     && !boundary.log.contains { $0.hasSuffix(":enhanced") },
                     "fronting preserves bottom-right resize geometry without an intermediate position write")
    }
}
