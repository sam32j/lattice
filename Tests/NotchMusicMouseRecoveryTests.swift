import AppKit

enum NotchMusicMouseRecoveryTests {
    static func run(_ suite: TestSuite) {
        boundaries(suite)
        var commands: [Bool] = []
        let state = NotchMusicSwipeState(scheduleExpiry: { _, _ in })
        let controller = NotchMusicMouseSwipeController(state: state, schedule: { _, _ in },
                                                       commit: { commands.append($0); return true })
        func scroll(_ x: Double, _ phase: NSEvent.Phase) {
            controller.receive(x: x, y: 0, phase: phase, precise: true, momentum: false,
                               enabled: true, expanded: false, hasTouches: false,
                               nativeTracking: true) { _ in /* Native tracker produces no callback. */ }
        }
        scroll(0, .began)
        scroll(-100, .changed)
        scroll(0, .ended)
        suite.expect(commands == [true] && state.completionPending,
                     "a silent native tracker recovers from mouse scroll input and commits on finger lift")
        for native in [false, true] {
            var lateCommands: [Bool] = []
            let late = NotchMusicMouseSwipeController(state: NotchMusicSwipeState(scheduleExpiry: { _, _ in }),
                schedule: { _, _ in }, commit: { lateCommands.append($0); return true })
            for (x, phase): (Double, NSEvent.Phase) in [(100, .changed), (0, .ended)] {
                late.receive(x: x, y: 0, phase: phase, precise: true, momentum: false,
                             enabled: true, expanded: false, hasTouches: false, nativeTracking: native) { _ in }
            }
            suite.expect(lateCommands == [false],
                         "mouse movement entering the island mid-scroll can skip on lift with native tracking \(native)")
        }
        var rejectedCommands = 0
        var nativeUpdate: NotchMusicMouseSwipeController.NativeUpdate?
        let rejected = NotchMusicMouseSwipeController(state: NotchMusicSwipeState(scheduleExpiry: { _, _ in }),
            schedule: { _, _ in }, commit: { _ in rejectedCommands += 1; return true })
        func rejectedScroll(_ x: Double, _ phase: NSEvent.Phase) {
            rejected.receive(x: x, y: 0, phase: phase, precise: true, momentum: false,
                             enabled: true, expanded: false, hasTouches: false) { nativeUpdate = $0 }
        }
        rejectedScroll(0, .began)
        rejectedScroll(-10, .changed)
        _ = nativeUpdate?(0.1, .cancelled, false)
        rejectedScroll(-100, .changed)
        rejectedScroll(0, .ended)
        suite.expect(rejectedCommands == 0,
                     "native cancellation vetoes raw recovery until that physical sequence ends")
    }

    private final class Session {
        let state = NotchMusicSwipeState(scheduleExpiry: { _, _ in })
        var commands: [Bool] = []
        var updates: [NotchMusicMouseSwipeController.NativeUpdate] = []
        var timers: [DispatchWorkItem] = []
        var accepts = true
        lazy var controller = NotchMusicMouseSwipeController(state: state,
            schedule: { [unowned self] _, work in timers.append(work) },
            commit: { [unowned self] forward in commands.append(forward); return accepts })
        @discardableResult
        func input(_ x: Double, _ phase: NSEvent.Phase, native: Bool = true,
                   precise: Bool = true, momentum: Bool = false, enabled: Bool = true,
                   touches: Bool = false) -> Bool {
            controller.receive(x: x, y: 0, phase: phase, precise: precise, momentum: momentum,
                               enabled: enabled, expanded: false, hasTouches: touches,
                               nativeTracking: native) { updates.append($0) }
        }
    }

    private static func boundaries(_ suite: TestSuite) {
        for native in [false, true] {
            let short = Session()
            short.input(0, .began, native: native)
            short.input(-40, .changed, native: native)
            short.input(0, .ended, native: native)
            suite.expect(short.commands.isEmpty && short.state.frame.progress == 0,
                         "short mouse motion never commits through recovery")
            let reversed = Session()
            reversed.input(-100, .changed, native: native)
            reversed.input(100, .changed, native: native)
            suite.expect(reversed.state.frame.progress == 0, "undoing raw recovery clears its armed cue before finger lift")
            reversed.input(0, .ended, native: native)
            suite.expect(reversed.commands.isEmpty, "reversing a recovered mouse stroke cancels its net movement")
            let trackpad = Session()
            trackpad.input(0, .mayBegin, native: native)
            trackpad.input(-100, .changed, native: native)
            trackpad.input(0, .began, native: native)
            trackpad.input(-100, .changed, native: native)
            trackpad.input(0, .ended, native: native)
            suite.expect(trackpad.commands.isEmpty && trackpad.updates.isEmpty && trackpad.state.frame.progress == 0,
                         "trackpad may-begin input never starts native mouse capture or recovery")
            for (precise, momentum, enabled, touches) in [(false, false, true, false),
                    (true, true, true, false), (true, false, false, false), (true, false, true, true)] {
                let blocked = Session()
                blocked.input(-100, .changed, native: native, precise: precise, momentum: momentum,
                              enabled: enabled, touches: touches)
                blocked.input(0, .ended, native: native, precise: precise, momentum: momentum,
                              enabled: enabled, touches: touches)
                suite.expect(blocked.commands.isEmpty, "non-mouse, momentum, disabled and physical-touch input cannot recover a skip")
            }
            let cancelled = Session()
            cancelled.input(-100, .changed, native: native)
            cancelled.input(0, .cancelled, native: native)
            cancelled.input(-100, .changed, native: native)
            cancelled.input(0, .ended, native: native)
            suite.expect(cancelled.commands.isEmpty, "raw cancellation vetoes the rest of the mouse sequence")
            cancelled.input(100, .changed, native: native)
            cancelled.input(0, .ended, native: native)
            suite.expect(cancelled.commands == [false], "a later physical mouse sequence recovers after cancellation")
            let expired = Session()
            expired.input(0, .began, native: native)
            expired.input(-100, .changed, native: native)
            expired.timers.last?.perform()
            expired.input(0, .ended, native: native)
            suite.expect(expired.commands.isEmpty && expired.state.frame.progress == 0,
                         "mouse timeout clears its cue without guessing a late finger lift")
            let rejected = Session()
            rejected.accepts = false
            rejected.input(-100, .changed, native: native)
            rejected.input(0, .ended, native: native)
            suite.expect(rejected.commands == [true] && !rejected.state.completionPending && rejected.state.frame.progress == 0,
                         "rejected playback commands never display recovery success")
        }
        let ambiguous = Session()
        ambiguous.input(-100, .changed)
        suite.expect(ambiguous.updates.isEmpty,
                     "Changed-first input uses passive recovery and never captures an unclassified trackpad stream")
        ambiguous.input(0, .changed, touches: true)
        ambiguous.input(0, .ended, touches: true)
        suite.expect(ambiguous.commands.isEmpty, "physical trackpad contact cancels passive mouse recovery before lift")
        let once = Session()
        once.input(0, .began)
        once.input(-100, .changed)
        _ = once.updates.last?(1, .ended, false)
        once.input(-100, .changed)
        _ = once.updates.last?(1, .ended, false)
        once.input(0, .ended)
        suite.expect(once.commands == [true], "native success cannot restart from queued Changed packets before raw finger lift")
        let recovered = Session()
        recovered.input(0, .began)
        recovered.input(-100, .changed)
        let stale = recovered.updates.last
        recovered.input(0, .ended)
        _ = stale?(1, .ended, true)
        recovered.input(100, .changed)
        _ = stale?(1, .ended, true)
        recovered.input(0, .ended)
        suite.expect(recovered.commands == [true, false], "late native callbacks cannot duplicate or overwrite recovered mouse swipes")
        let accepted = Session()
        accepted.input(0, .began)
        accepted.input(-10, .changed)
        _ = accepted.updates.last?(0.2, .changed, false)
        accepted.input(0, .ended)
        suite.expect(accepted.commands.isEmpty, "a responding native tracker retains authority over its physical end")
        _ = accepted.updates.last?(0.2, .ended, false)
        accepted.input(0, .ended)
        suite.expect(accepted.commands == [true], "native acceptance remains valid below the recovery movement threshold")
        accepted.input(100, .changed)
        accepted.input(0, .ended)
        suite.expect(accepted.commands == [true, false], "a later Changed-first stroke recovers after a responding native sequence")
        let switchToTrackpad = Session()
        switchToTrackpad.input(0, .began)
        switchToTrackpad.input(-100, .changed)
        _ = switchToTrackpad.updates.last?(1, .ended, false)
        switchToTrackpad.input(0, .mayBegin)
        switchToTrackpad.input(0, .began)
        switchToTrackpad.input(-100, .changed)
        switchToTrackpad.input(0, .ended)
        suite.expect(switchToTrackpad.commands == [true] && switchToTrackpad.updates.count == 1,
                     "switching from an accepted mouse stroke to trackpad input cannot capture the trackpad")

    }
}
