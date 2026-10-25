import AppKit

enum NotchMusicSwipeRecoveryTests {
    static func run(_ suite: TestSuite) {
        var expiry: [(TimeInterval, DispatchWorkItem)] = []
        var arms = 0
        var starts = 0
        var commands = 0
        let state = NotchMusicSwipeState()
        let controller = NotchMusicSwipeController(state: state, onStart: { starts += 1 }, onArm: { arms += 1 },
            scheduleExpiry: { expiry.append(($0, $1)) }, commit: { _ in commands += 1; return true })
        func contacts(_ x: CGFloat) -> [NotchMusicTrackSwipe.Contact] {
            [.init(id: 1, position: CGPoint(x: x, y: 0)), .init(id: 2, position: CGPoint(x: x, y: 10))]
        }
        _ = controller.update(contacts(0), began: true, enabled: true, expanded: true)
        _ = controller.scroll(-1, precise: true, momentum: false, cancelled: false, enabled: true, expanded: true)
        _ = controller.update(contacts(17.99), began: false, enabled: true, expanded: true)
        suite.expect(starts == 0 && arms == 0, "no haptic occurs before a quarter inch")
        _ = controller.update(contacts(18), began: false, enabled: true, expanded: true)
        suite.expect(starts == 1 && arms == 0, "the first haptic occurs at exactly a quarter inch")
        _ = controller.update(contacts(96), began: false, enabled: true, expanded: true)
        _ = controller.update(contacts(50), began: false, enabled: true, expanded: true)
        suite.expect(starts == 1 && arms == 1 && commands == 0 && state.frame.progress == 1,
                     "crossing one and a third inches emits one arming feedback, never one per held update")
        suite.expect(expiry.last?.0 == 3 && expiry.dropLast().allSatisfy { $0.1.isCancelled },
                     "physical input renews a single three-second recovery deadline")
        expiry.last?.1.perform()
        suite.expect(state.frame.progress == 0 && commands == 0,
                     "missing lift events clear stuck icons/backdrops without guessing a playback command")
        _ = controller.update(contacts(50), began: false, enabled: true, expanded: true)
        suite.expect(commands == 0 && state.frame.progress == 0, "expired held input cannot revive its armed stroke")
        _ = controller.update([], began: false, enabled: true, expanded: true)
        _ = controller.update(contacts(0), began: true, enabled: true, expanded: true)
        _ = controller.scroll(-1, precise: true, momentum: false, cancelled: false, enabled: true, expanded: true)
        _ = controller.update(contacts(96), began: false, enabled: true, expanded: true)
        _ = controller.update(Array(contacts(96).prefix(1)), began: false, enabled: true, expanded: true)
        suite.expect(commands == 1 && arms == 2 && expiry.last?.1.isCancelled == true,
                     "a fresh stroke recovers and commits on its first original finger lift")
        _ = controller.update(contacts(60), began: false, enabled: true, expanded: true)
        _ = controller.update([], began: false, enabled: true, expanded: true)
        suite.expect(commands == 1, "remaining contacts and the final lift never duplicate an accepted stroke")
        _ = controller.update(contacts(0), began: true, enabled: true, expanded: true)
        _ = controller.scroll(-1, precise: true, momentum: false, cancelled: false, enabled: true, expanded: true)
        _ = controller.update(contacts(96), began: false, enabled: true, expanded: true)
        _ = controller.update(Array(contacts(96).prefix(1)), began: false, enabled: true, expanded: true, allowRelease: false)
        suite.expect(commands == 1 && state.frame.progress == 0,
                     "a partial native snapshot without an ended touch cancels instead of guessing a release")
        state.clear()

        var taps = 0
        let haptics = NotchMusicSwipeHaptics(perform: { taps += 1 })
        haptics.tap()
        suite.expect(taps == 1, "one gesture stage produces one immediate haptic tap")
        haptics.tap()
        suite.expect(taps == 2, "activation and arming supply two taps without a timing-based second pulse")
    }
}
