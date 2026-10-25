import AppKit

enum NotchMusicTrackSwipeTests {
    static func run(_ suite: TestSuite) {
        NotchMusicSwipeSurfaceTests.run(suite)
        NotchMusicSwipeRecoveryTests.run(suite)
        NotchMusicSwipeCompletionTests.run(suite)
        func contacts(_ x: CGFloat, second: CGFloat? = nil) -> [NotchMusicTrackSwipe.Contact] {
            [.init(id: 1, position: CGPoint(x: x, y: 20)),
             .init(id: 2, position: CGPoint(x: second ?? x, y: 40))]
        }
        var swipe = NotchMusicTrackSwipe()
        _ = swipe.update(contacts(0), enabled: true)
        suite.expect(swipe.scroll(-500, precise: true, momentum: false) == nil,
                     "accelerated scroll deltas alone never satisfy physical music travel")
        suite.expect(swipe.update(contacts(35.99), enabled: true) == nil && swipe.progress < 1,
                     "a track swipe shorter than half an inch does not fire")
        suite.expect(swipe.update(contacts(36), enabled: true) == nil && swipe.progress == 1,
                     "36 physical points arms feedback without changing the track")
        suite.expect(swipe.update(contacts(108), enabled: true) == nil,
                     "a held music swipe cannot fire twice")

        suite.expect(swipe.update([], enabled: true) == .next && swipe.update([], enabled: true) == nil,
                     "a simultaneous lift commits one armed action, never a duplicate")
        _ = swipe.update(contacts(0), enabled: true)
        _ = swipe.scroll(-1, precise: true, momentum: false)
        _ = swipe.update(contacts(35.99), enabled: true)
        suite.expect(swipe.update([], enabled: true) == nil && swipe.progress == 0,
                     "lifting a stroke below the physical threshold clears feedback without skipping")
        _ = swipe.update(contacts(0), enabled: true)
        suite.expect(swipe.update(contacts(-36), enabled: true) == nil,
                     "physical travel without an AppKit direction cannot skip")
        suite.expect(swipe.scroll(1, precise: true, momentum: false) == nil && swipe.progress == 1,
                     "contact-first event order arms feedback once direction arrives")
        suite.expect(swipe.update([], enabled: true) == .previous,
                     "contact-first travel commits previous only on lift")
        swipe = NotchMusicTrackSwipe()
        _ = swipe.update(contacts(0), enabled: true)
        _ = swipe.scroll(-1, precise: true, momentum: false)
        suite.expect(swipe.update(contacts(80, second: 35), enabled: true) == nil,
                     "both fingers must independently reach half an inch")
        suite.expect(swipe.update(contacts(80, second: 36), enabled: true) == nil && swipe.progress == 1,
                     "the slower finger completes physical travel without sending early")
        suite.expect(swipe.update([], enabled: true) == .next, "both-finger travel commits on lift")
        for invalid in [contacts(36, second: -36),
                        [.init(id: 1, position: CGPoint(x: 0, y: 100)),
                         .init(id: 2, position: CGPoint(x: 0, y: 120))],
                        [.init(id: 1, position: CGPoint(x: 36, y: 20)),
                         .init(id: 3, position: CGPoint(x: 36, y: 40))],
                        [.init(id: 1, position: CGPoint(x: CGFloat.nan, y: 20)),
                         .init(id: 2, position: CGPoint(x: 36, y: 40))]] {
            swipe = NotchMusicTrackSwipe()
            _ = swipe.update(contacts(0), enabled: true)
            _ = swipe.scroll(-100, precise: true, momentum: false)
            suite.expect(swipe.update(invalid, enabled: true) == nil && swipe.progress == 0,
                         "pinching, vertical, replaced and invalid contacts do not skip")
        }
        swipe = NotchMusicTrackSwipe()
        _ = swipe.update(contacts(0), enabled: true)
        _ = swipe.update(contacts(36), enabled: true)
        suite.expect(swipe.scroll(-100, precise: true, momentum: true) == nil
                     && swipe.scroll(-100, precise: false, momentum: false) == nil,
                     "momentum and unmeasured wheel devices cannot supply music direction")
        swipe = NotchMusicTrackSwipe()
        _ = swipe.update(contacts(0), enabled: true)
        _ = swipe.update(contacts(30), enabled: true)
        _ = swipe.update(contacts(10), enabled: true)
        suite.expect(abs(swipe.progress - 10.0 / 36) < 0.001,
                     "reversing before completion reduces the visual progress")
        _ = swipe.update(contacts(10), enabled: false)
        suite.expect(swipe.update(contacts(36), enabled: true) == nil && swipe.progress == 0,
                     "disabled contact sequences cannot resume midway")

        let state = NotchMusicSwipeState()
        var commands: [Bool] = []
        var accepts = true
        let controller = NotchMusicSwipeController(state: state) {
            commands.append($0); return accepts
        }
        _ = controller.update(contacts(0), began: true, enabled: true, expanded: false)
        _ = controller.scroll(-1, precise: true, momentum: false, cancelled: false, enabled: true, expanded: false)
        _ = controller.update(contacts(18), began: false, enabled: true, expanded: false)
        suite.expect(state.frame.direction == .next && state.frame.progress == 0.5 && commands.isEmpty,
                     "live compact feedback follows measured travel without sending early")
        _ = controller.update(contacts(36), began: false, enabled: true, expanded: false)
        _ = controller.update(contacts(90), began: false, enabled: true, expanded: false)
        let resting = contacts(90).map { NotchMusicTrackSwipe.Contact(id: $0.id, position: $0.position, isResting: true) }
        _ = controller.update(resting, began: false, enabled: true, expanded: false)
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        suite.expect(commands.isEmpty && state.frame.progress == 1,
                     "armed feedback remains visible while fingers are held, without an early command")
        _ = controller.update(Array(resting.prefix(1)), began: false, enabled: true, expanded: false)
        suite.expect(commands == [true] && state.frame.progress == 1,
                     "lifting the first original finger commits without waiting on its resting partner")
        _ = controller.update([], began: false, enabled: true, expanded: false)
        suite.expect(commands == [true],
                     "the remaining original finger cannot duplicate the accepted command")
        accepts = false
        _ = controller.update(contacts(0), began: true, enabled: true, expanded: true)
        _ = controller.scroll(1, precise: true, momentum: false, cancelled: false, enabled: true, expanded: true)
        _ = controller.update(contacts(-36), began: false, enabled: true, expanded: true)
        _ = controller.update([], began: false, enabled: true, expanded: true)
        suite.expect(commands == [true, false] && state.frame.progress == 0,
                     "a rejected previous command never shows successful feedback")
        _ = controller.update([], began: false, enabled: true, expanded: true)
        accepts = true
        _ = controller.update(contacts(0), began: true, enabled: true, expanded: true)
        _ = controller.scroll(-1, precise: true, momentum: false, cancelled: false, enabled: true, expanded: true)
        _ = controller.update(contacts(36), began: false, enabled: true, expanded: true)
        controller.cancel()
        _ = controller.update(contacts(36), began: true, enabled: true, expanded: true)
        suite.expect(commands.count == 2 && state.frame.progress == 0,
                     "cancellation prevents a second finger begin from reviving held input")
        _ = controller.update([], began: false, enabled: true, expanded: true)
        _ = controller.update(contacts(0), began: true, enabled: true, expanded: true)
        _ = controller.scroll(-1, precise: true, momentum: false, cancelled: false, enabled: true, expanded: true)
        _ = controller.update(contacts(36), began: false, enabled: true, expanded: false)
        suite.expect(commands.count == 2 && state.frame.progress == 0,
                     "presentation changes discard the old gesture and feedback")
        controller.cancel()
        _ = controller.update([], began: false, enabled: true, expanded: false)
        // The scroll began can precede even the first finger's touch snapshot.
        _ = controller.scroll(-12, precise: true, momentum: false, cancelled: false,
                              enabled: true, expanded: false, began: true, timestamp: 10)
        _ = controller.update(Array(contacts(0).prefix(1)), began: true, enabled: true,
                              expanded: false, timestamp: 9.99)
        _ = controller.update(contacts(0), began: true, enabled: true, expanded: false, timestamp: 10.02)
        _ = controller.update(contacts(36), began: false, enabled: true, expanded: false, timestamp: 10.1)
        _ = controller.update([], began: false, enabled: true, expanded: false, timestamp: 10.11)
        suite.expect(commands.count == 3 && commands.last == true,
                     "bounded phased direction survives reordered native timestamps and second-finger arrival")
        _ = controller.update([], began: false, enabled: true, expanded: false)
        _ = controller.scroll(-12, precise: true, momentum: false, cancelled: false,
                              enabled: true, expanded: false, began: true, timestamp: 20)
        _ = controller.update(contacts(0), began: true, enabled: true, expanded: false, timestamp: 20.5)
        _ = controller.update(contacts(36), began: false, enabled: true, expanded: false, timestamp: 20.6)
        suite.expect(commands.count == 3, "stale early direction cannot arm a later physical stroke")
        _ = controller.update([], began: false, enabled: true, expanded: false)
        _ = controller.scroll(-12, precise: true, momentum: true, cancelled: false,
                              enabled: true, expanded: false, began: true, timestamp: 30)
        _ = controller.update(contacts(0), began: true, enabled: true, expanded: false, timestamp: 30.01)
        _ = controller.update(contacts(36), began: false, enabled: true, expanded: false, timestamp: 30.02)
        suite.expect(commands.count == 3, "early momentum never supplies direction to a new physical stroke")
        _ = controller.update([], began: false, enabled: true, expanded: false)
        controller.synchronizeSurface("music")
        _ = controller.update(contacts(0), began: true, enabled: true, expanded: false)
        _ = controller.scroll(-1, precise: true, momentum: false, cancelled: false, enabled: true, expanded: false)
        _ = controller.update(contacts(18), began: false, enabled: true, expanded: false)
        controller.synchronizeSurface("gallery")
        controller.synchronizeSurface("music")
        _ = controller.update(contacts(36), began: false, enabled: true, expanded: false)
        suite.expect(commands.count == 3 && state.frame.progress == 0,
                     "leaving and returning without intervening input invalidates held music touches")
        _ = controller.update(contacts(0), began: true, enabled: true, expanded: false, freshSequence: true)
        _ = controller.scroll(-1, precise: true, momentum: false, cancelled: false, enabled: true, expanded: false)
        _ = controller.update(contacts(36), began: false, enabled: true, expanded: false)
        _ = controller.update([], began: false, enabled: true, expanded: false)
        suite.expect(commands.count == 4, "an entirely fresh native contact sequence recovers after interruption")
        state.clear()
    }
}
