import AppKit
import Combine

enum NotchMusicSwipeCompletionTests {
    static func run(_ suite: TestSuite) {
        func contacts(_ x: CGFloat) -> [NotchMusicTrackSwipe.Contact] {
            [.init(id: 1, position: CGPoint(x: x, y: 20)),
             .init(id: 2, position: CGPoint(x: x, y: 40))]
        }
        for interruption in 0...4 {
            let state = NotchMusicSwipeState()
            var commands = 0
            let controller = NotchMusicSwipeController(state: state) { _ in
                commands += 1
                return interruption != 4
            }
            _ = controller.update(contacts(0), began: true, enabled: true, expanded: false)
            _ = controller.scroll(-1, precise: true, momentum: false, cancelled: false,
                                  enabled: true, expanded: false)
            _ = controller.update(contacts(36), began: false, enabled: true, expanded: false)
            _ = controller.update(Array(contacts(36).prefix(1)), began: false,
                                  enabled: true, expanded: false)
            _ = controller.update([], began: false, cancelled: interruption == 3,
                                  enabled: interruption != 1, expanded: interruption == 2)
            suite.expect(commands == 1, "final release never duplicates the accepted swipe command")
            suite.expect(state.frame.progress == (interruption == 0 ? 1 : 0),
                         "final release preserves accepted feedback only on the same enabled surface")
            _ = controller.update([], began: false, enabled: true, expanded: false)
            suite.expect(state.frame.progress == (interruption == 0 ? 1 : 0),
                         "duplicate terminal packets preserve completion, not cancelled or rejected feedback")
        }
        let state = NotchMusicSwipeState()
        var publications = 0
        let subscription = state.$frame.sink { _ in publications += 1 }
        state.clear()
        suite.expect(publications == 1, "clearing an already empty frame does not publish")
        let frame = NotchMusicSwipeState.Frame(direction: .next, progress: 1)
        state.show(frame, held: true)
        state.show(frame, held: true)
        suite.expect(publications == 2, "identical held frames do not publish repeatedly")
        state.clear()
        state.clear()
        suite.expect(publications == 3, "clear publishes the empty frame exactly once")
        withExtendedLifetime(subscription) {}

        var deadlines: [(TimeInterval, DispatchWorkItem)] = []
        let timed = NotchMusicSwipeState(scheduleExpiry: { deadlines.append(($0, $1)) })
        timed.show(frame, held: true)
        suite.expect(deadlines.isEmpty && !timed.completionPending, "held feedback has no expiry")
        timed.show(frame, completed: true)
        suite.expect(deadlines.count == 1 && deadlines[0].0 == 0.22 && timed.completionPending,
                     "an unchanged held frame becomes completed and schedules the completion deadline")
        timed.show(frame, completed: true)
        suite.expect(deadlines.count == 2 && deadlines[0].1.isCancelled && !deadlines[1].1.isCancelled,
                     "an unchanged completion still cancels and rearms its expiry")
        deadlines[1].1.perform()
        suite.expect(timed.frame == .init() && !timed.completionPending,
                     "completion expiry clears both frame and completion metadata")
        timed.show(frame)
        suite.expect(deadlines.last?.0 == 0.5 && !timed.completionPending,
                     "ordinary unheld feedback retains its transient-feedback deadline")
        timed.clear()
        suite.expect(deadlines.last?.1.isCancelled == true, "explicit clear cancels pending expiry")
    }
}
