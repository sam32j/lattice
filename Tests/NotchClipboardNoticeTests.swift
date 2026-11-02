// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

/// Production monitoring with inert pasteboard and clock boundaries.
enum NotchClipboardNoticeTests {
    enum Bundle { static let main = App(); struct App { let bundleIdentifier: String? = "test.lattice" } }
    enum NSPasteboard {
        static let general = Board()
        final class Board {
            var changeCount = 0
            var source: String?
            func string(forType: Kind) -> String? { source }
        }
        enum Kind { case source }
    }
    enum NotchSupport { static func routes(_ event: NotchEvent) -> Bool { true } }
    final class Timer {
        let action: (Timer) -> Void
        var tolerance = 0.0
        var valid = true
        init(timeInterval: Double, repeats: Bool, block: @escaping (Timer) -> Void) { action = block }
        func fire() { if valid { action(self) } }
        func invalidate() { valid = false }
    }
    enum RunLoop {
        static let main = Loop()
        enum Mode { case common }
        struct Loop { func add(_ timer: Timer, forMode: Mode) {} }
    }
    final class GeneralPasteboardAccess {
        static let shared = GeneralPasteboardAccess()
        var work: [() -> Void] = []
        func async<T>(_ body: @escaping () -> T, then completion: @escaping (T) -> Void) {
            work.append { completion(body()) }
        }
        func drain() { while !work.isEmpty { work.removeFirst()() } }
    }
    class State {
        var running = true, suspended = false
        var lastClipboardChangeCount = 0, lastOwnClipboardChangeCount = 0
        var clipboardMonitoringGeneration = UUID()
        var clipboardTimer: Timer?
        var notices: [NotchNotice] = []
        func show(_ notice: NotchNotice) -> Bool { notices.append(notice); return true }
    }

    static func run(_ suite: TestSuite) {
        let board = NSPasteboard.general
        board.changeCount = 0; board.source = nil
        let service = Service()
        service.startClipboardMonitoring()
        service.suspended = true
        board.changeCount = 1
        service.clipboardTimer?.fire()
        service.suspended = false
        service.clipboardTimer?.fire()
        GeneralPasteboardAccess.shared.drain()
        suite.expect(service.notices.isEmpty, "clipboard changes while suspended never announce after resume")
        board.changeCount = 2; board.source = Bundle.main.bundleIdentifier
        service.clipboardTimer?.fire()
        GeneralPasteboardAccess.shared.drain()
        suite.expect(service.notices.isEmpty, "Lattice's own clipboard writes do not produce external-copy notices")
        board.changeCount = 3; board.source = "external.app"
        service.clipboardTimer?.fire()
        GeneralPasteboardAccess.shared.drain()
        suite.expect(service.notices.count == 1, "an external copy still announces once")
        board.changeCount = 4
        service.clipboardTimer?.fire()
        service.noteOwnClipboardChange(upTo: 4)
        GeneralPasteboardAccess.shared.drain()
        suite.expect(service.notices.count == 1, "transient restoration cannot announce a restored external source")
        board.changeCount = 5
        service.clipboardTimer?.fire()
        service.stopClipboardMonitoring()
        GeneralPasteboardAccess.shared.drain()
        suite.expect(service.notices.count == 1, "stopping monitoring invalidates a pending clipboard result")
    }
}
