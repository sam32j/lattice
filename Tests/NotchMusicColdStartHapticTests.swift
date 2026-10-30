import AppKit

enum NotchMusicColdStartHapticTests {
    static func run(_ suite: TestSuite) {
        for peeking in [false, true] {
            var taps = 0, commands = 0
            let haptics = NotchMusicSwipeHaptics(perform: { taps += 1 })
            let state = NotchMusicSwipeState(scheduleExpiry: { _, _ in })
            let controller = NotchMusicSwipeController(state: state, onStart: { haptics.tap() },
                onArm: { haptics.tap() }, scheduleExpiry: { _, _ in }, commit: { _ in commands += 1; return true })
            let enabled = NotchMusicSwipeController.permitsCompact(stripVisible: true, expanded: false,
                peeking: peeking, trackNotice: false, noticeExpanded: false, noticeCanPresent: true)
            func contacts(_ x: CGFloat) -> [NotchMusicTrackSwipe.Contact] {
                [.init(id: 0, position: CGPoint(x: x, y: 0)), .init(id: 1, position: CGPoint(x: x, y: 10))]
            }
            controller.synchronizeSurface("initial-playing-strip")
            // Scroll may arrive before the first two-finger snapshot at launch.
            controller.scroll(-12, precise: true, momentum: false, cancelled: false,
                              enabled: enabled, expanded: false, began: true, timestamp: 10)
            controller.update(Array(contacts(0).prefix(1)), began: true, enabled: enabled,
                              expanded: false, timestamp: 9.99)
            controller.update(contacts(0), began: true, enabled: enabled, expanded: false, timestamp: 10.02)
            controller.update(contacts(17.99), began: false, enabled: enabled, expanded: false, timestamp: 10.1)
            suite.expect(taps == 0 && commands == 0, "the first compact trackpad stroke stays silent below its physical threshold")
            controller.update(contacts(18), began: false, enabled: enabled, expanded: false, timestamp: 10.2)
            suite.expect(taps == 1 && commands == 0, "launch-time trackpad feedback fires at 18 points without opening Now Playing")
            controller.update(contacts(54), began: false, enabled: enabled, expanded: false, timestamp: 10.3)
            suite.expect(taps == 2 && commands == 0, "launch-time trackpad arming supplies its second haptic before lift")
            controller.update(Array(contacts(54).prefix(1)), began: false, enabled: enabled,
                              expanded: false, timestamp: 10.4)
            controller.update([], began: false, enabled: enabled, expanded: false, timestamp: 10.5)
            suite.expect(taps == 2 && commands == 1, "the first compact trackpad lift commits exactly once without another haptic")
        }
    }
}
