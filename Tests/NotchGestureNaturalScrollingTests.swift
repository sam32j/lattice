import Foundation

enum NotchGestureNaturalScrollingTests {
    static func run(_ suite: TestSuite) {
        let cases: [(Bool, Double, NotchGestureSupport.Action, String)] = [
            (false, -45, .nextTrack, "physical right swipe, natural off"),
            (false, 45, .previousTrack, "physical left swipe, natural off"),
            (true, 45, .previousTrack, "physical right swipe, natural on"),
            (true, -45, .nextTrack, "physical left swipe, natural on")
        ]
        for (natural, delta, expected, name) in cases {
            var gesture = NotchGestureSupport()
            let action = gesture.handle(
                x: NotchGestureSupport.movement(delta, precise: true, inverted: natural),
                y: 0, timestamp: 1, began: true, ended: false, momentum: false, precise: true,
                hasPhase: true, allowVertical: false, allowHorizontal: true, expanded: true,
                naturalScrolling: natural)
            suite.expect(action == expected, "normalized event routing honors the requested track action for \(name)")
        }
    }
}
