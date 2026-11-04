// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

/// Production monitoring with inert pasteboard and clock boundaries.
enum NotchClipboardNoticeTests {
    enum Bundle { static let main = App(); struct App { let bundleIdentifier: String? = "test.lattice" } }
    enum NSPasteboard {
        static let general = Board()
        final class Board {
            var storedCount = 0
            var offLaneReads = 0
            var sourceReads = 0
            var changeCount: Int {
                get {
                    if !GeneralPasteboardAccess.shared.onLane { offLaneReads += 1 }
                    return storedCount
                }
                set { storedCount = newValue }
            }
            var source: String?
            var types: [Kind]? = [.source]
            func string(forType: Kind) -> String? { sourceReads += 1; return source }
        }
        enum Kind: String {
            case source = "org.nspasteboard.source"
            case concealed = "org.nspasteboard.ConcealedType"
        }
    }
    enum ClipboardHistorySensitiveText {
        static func isConcealed(_ types: [String]) -> Bool {
            types.contains("org.nspasteboard.ConcealedType")
        }
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
        var onLane = false
        func async<T>(_ body: @escaping () -> T, then completion: @escaping (T) -> Void) {
            work.append {
                self.onLane = true
                let result = body()
                self.onLane = false
                completion(result)
            }
        }
        func drain() { while !work.isEmpty { work.removeFirst()() } }
    }
    class State {
        var running = true, suspended = false
        var lastClipboardChangeCount = 0, lastOwnClipboardChangeCount = 0
        var clipboardMonitoringGeneration = UUID()
        var clipboardReadInFlight = false
        var clipboardBaselinePending = false
        var clipboardTimer: Timer?
        var notices: [NotchNotice] = []
        func show(_ notice: NotchNotice) -> Bool { notices.append(notice); return true }
    }

    static func run(_ suite: TestSuite) {
        let board = NSPasteboard.general
        board.changeCount = 0; board.source = nil
        board.offLaneReads = 0
        let service = Service()
        service.startClipboardMonitoring()
        service.clipboardTimer?.fire()
        suite.expect(board.offLaneReads == 0,
                     "startup and timer polling never read the pasteboard on the caller's lane")
        GeneralPasteboardAccess.shared.drain()
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
        let sourceReads = board.sourceReads
        service.clipboardTimer?.fire()
        GeneralPasteboardAccess.shared.drain()
        suite.expect(board.sourceReads == sourceReads,
                     "an unchanged pasteboard never invokes a promised source provider")
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
        service.startClipboardMonitoring()
        for count in 6...15 {
            board.changeCount = count
            service.clipboardTimer?.fire()
        }
        suite.expect(GeneralPasteboardAccess.shared.work.count == 1,
                     "a blocked provider admits at most one clipboard read instead of an unbounded timer backlog")
        GeneralPasteboardAccess.shared.drain()
        suite.expect(board.offLaneReads == 0, "every change-count read stays on the pasteboard lane")
        service.stopClipboardMonitoring()
        board.changeCount = 20
        service.startClipboardMonitoring()
        for _ in 0..<5 {
            service.stopClipboardMonitoring()
            service.startClipboardMonitoring()
        }
        suite.expect(GeneralPasteboardAccess.shared.work.count == 1,
                     "restarting monitoring cannot enqueue more baselines behind a blocked provider")
        GeneralPasteboardAccess.shared.drain()
        suite.expect(service.lastClipboardChangeCount == 20 && service.notices.count == 1,
                     "a stale completion establishes one fresh baseline for the latest monitoring generation")
        board.changeCount = 21
        service.clipboardTimer?.fire()
        GeneralPasteboardAccess.shared.drain()
        suite.expect(service.notices.count == 2, "copy notices resume after the latest restart baseline")
        board.changeCount = 22
        board.types = []
        service.clipboardTimer?.fire()
        GeneralPasteboardAccess.shared.drain()
        suite.expect(service.notices.count == 2, "empty pasteboard clear never announces")
        board.changeCount = 23
        board.types = [.concealed]
        service.clipboardTimer?.fire()
        GeneralPasteboardAccess.shared.drain()
        suite.expect(service.notices.count == 2, "concealed pasteboard copy never announces")
        board.changeCount = 2
        board.types = [.source]
        service.clipboardTimer?.fire()
        GeneralPasteboardAccess.shared.drain()
        suite.expect(service.notices.count == 2, "count decrease establishes a new baseline without notice")
        board.changeCount = 3
        service.clipboardTimer?.fire()
        GeneralPasteboardAccess.shared.drain()
        suite.expect(service.notices.count == 3, "notices resume after pasteboard count decrease")
        service.stopClipboardMonitoring()
    }
}
