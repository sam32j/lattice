import AppKit

enum NotchMusicMixedInputTests {
    private final class Session {
        let state = NotchMusicSwipeState(scheduleExpiry: { _, _ in })
        var commands: [Bool] = []
        var taps = 0
        var nativeCaptures = 0
        var timers: [DispatchWorkItem] = []
        lazy var controller = NotchMusicSwipeController(state: state,
            onStart: { [unowned self] in taps += 1 }, onArm: { [unowned self] in taps += 1 },
            scheduleExpiry: { [unowned self] _, work in timers.append(work) },
            commit: { [unowned self] in commands.append($0); return true })
        func contacts(_ x: CGFloat) -> [NotchMusicTrackSwipe.Contact] {
            [.init(id: 1, position: CGPoint(x: x, y: 0)), .init(id: 2, position: CGPoint(x: x, y: 10))]
        }
        func touch(_ x: CGFloat, began: Bool = false, at time: Double) {
            controller.update(contacts(x), began: began, enabled: true, expanded: false,
                              timestamp: time, freshSequence: began)
        }
        func direction(at time: Double) {
            controller.scroll(-1, precise: true, momentum: false, cancelled: false,
                              enabled: true, expanded: false, began: true, timestamp: time)
        }
        func mouse(_ x: Double, _ phase: NSEvent.Phase, at time: Double, native: Bool) {
            controller.receiveMouseInput(x: x, y: 0, phase: phase, precise: true, momentum: false,
                enabled: true, expanded: false, timestamp: time, nativeTracking: native) { [unowned self] _ in nativeCaptures += 1 }
        }
        func mouseStroke(at time: Double, native: Bool) {
            mouse(0, .began, at: time, native: native)
            mouse(-100, .changed, at: time + 0.1, native: native)
            mouse(0, .ended, at: time + 0.2, native: native)
        }
    }

    static func run(_ suite: TestSuite) {
        for native in [false, true] {
            let mixed = Session()
            mixed.mouseStroke(at: 1, native: native)
            suite.expect(mixed.commands == [true] && mixed.taps == 0, "mouse works before trackpad use without haptics")
            mixed.touch(0, began: true, at: 2)
            mixed.direction(at: 2.01)
            mixed.touch(18, at: 2.1)
            mixed.touch(54, at: 2.2)
            mixed.controller.update(Array(mixed.contacts(54).prefix(1)), began: false, enabled: true,
                                    expanded: false, timestamp: 2.3)
            suite.expect(mixed.commands == [true, true] && mixed.taps == 2,
                         "trackpad commits once on first lift with its two original physical haptics")
            mixed.mouse(-100, .changed, at: 2.31, native: native)
            mixed.mouse(0, .ended, at: 2.4, native: native)
            suite.expect(mixed.commands == [true, true], "remaining trackpad scroll packets cannot become another mouse skip")
            mixed.mouseStroke(at: 2.5, native: native)
            suite.expect(mixed.commands == [true, true, true] && mixed.taps == 2,
                         "mouse works after trackpad input even if the final empty touch snapshot is lost")
            mixed.controller.update([], began: false, enabled: true, expanded: false, timestamp: 3)
            mixed.touch(0, began: true, at: 4)
            mixed.direction(at: 4.01)
            mixed.touch(18, at: 4.1)
            mixed.touch(54, at: 4.2)
            mixed.controller.update([], began: false, enabled: true, expanded: false, timestamp: 4.3)
            suite.expect(mixed.commands == [true, true, true, true] && mixed.taps == 4,
                         "returning to trackpad preserves first-stroke feedback and one commit")

            let cancelled = Session()
            cancelled.touch(0, began: true, at: 10)
            cancelled.direction(at: 10.01)
            cancelled.touch(18, at: 10.1)
            cancelled.controller.cancel()
            cancelled.mouse(0, .cancelled, at: 10.2, native: native)
            cancelled.mouseStroke(at: 10.3, native: native)
            suite.expect(cancelled.commands == [true] && cancelled.taps == 1,
                         "canceled trackpad input cannot permanently exclude a later mouse gesture")

            let missing = Session()
            missing.touch(0, began: true, at: 20)
            missing.direction(at: 20.01)
            missing.touch(18, at: 20.1)
            missing.timers.last?.perform()
            missing.mouseStroke(at: 24, native: native)
            suite.expect(missing.commands == [true] && missing.taps == 1,
                         "lost touch and raw terminals expire mouse exclusion without resuming the canceled trackpad")

            let marker = Session()
            marker.mouse(0, .mayBegin, at: 40, native: native)
            marker.mouse(0, .began, at: 40.01, native: native)
            marker.mouse(-100, .changed, at: 40.1, native: native)
            suite.expect(marker.commands.isEmpty && marker.taps == 0,
                         "trackpad-classified scroll stays excluded without capturing native tracking")
            marker.timers.last?.perform()
            marker.mouseStroke(at: 44, native: native)
            suite.expect(marker.commands == [true],
                         "an abandoned trackpad mayBegin marker expires before the next mouse gesture")

            let blocked = Session()
            blocked.touch(0, began: true, at: 50)
            blocked.direction(at: 50.01)
            blocked.touch(18, at: 50.1)
            blocked.controller.cancel()
            for time in [51.0, 52, 53, 54] { blocked.touch(18, at: time) }
            blocked.mouseStroke(at: 54.1, native: native)
            suite.expect(blocked.commands.isEmpty && blocked.nativeCaptures == 0 && blocked.taps == 1,
                         "fresh contacts keep a canceled stroke excluded even after three seconds")
            blocked.controller.update([], began: false, enabled: true, expanded: false, timestamp: 54.4)
            blocked.mouseStroke(at: 54.5, native: native)
            suite.expect(blocked.commands == [true] && blocked.taps == 1,
                         "mouse input recovers when the canceled physical contacts actually end")

            let launch = Session()
            launch.mouse(0, .mayBegin, at: 60, native: native)
            launch.mouse(-12, .began, at: 60.01, native: native)
            launch.controller.scroll(-12, precise: true, momentum: false, cancelled: false,
                                      enabled: true, expanded: false, began: true, timestamp: 60.01)
            launch.controller.update(Array(launch.contacts(0).prefix(1)), began: true, enabled: true,
                                      expanded: false, timestamp: 60)
            launch.touch(0, began: true, at: 60.02)
            launch.touch(18, at: 60.1)
            suite.expect(launch.taps == 1 && launch.nativeCaptures == 0,
                         "mouse recognition cannot capture launch-time trackpad input before its first haptic")
            launch.touch(54, at: 60.2)
            launch.controller.update([], began: false, enabled: true, expanded: false, timestamp: 60.3)
            launch.mouse(0, .ended, at: 60.4, native: native)
            suite.expect(launch.taps == 2 && launch.commands == [true] && launch.nativeCaptures == 0,
                         "the first trackpad gesture keeps both haptics with mouse recognition enabled")
            launch.mouseStroke(at: 61, native: native)
            suite.expect(launch.commands == [true, true] && launch.taps == 2,
                         "mouse navigation works immediately after that launch-time trackpad gesture")

            let live = Session()
            live.touch(0, began: true, at: 30)
            live.direction(at: 30.01)
            live.mouseStroke(at: 30.1, native: native)
            suite.expect(live.commands.isEmpty && live.taps == 0,
                         "recent physical trackpad input still excludes mouse capture before its threshold")
            live.touch(18, at: 30.4)
            suite.expect(live.taps == 1, "physical feedback remains available after interleaved scroll packets")
        }
    }
}
