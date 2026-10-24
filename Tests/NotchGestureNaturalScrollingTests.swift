import Foundation

enum NotchGestureNaturalScrollingTests {
    static func run(_ suite: TestSuite) {
        let cases: [(Double, CGFloat, NotchMusicTrackSwipe.Direction, String)] = [
            (-45, 54, .next, "physical right swipe, natural off"),
            (45, -54, .previous, "physical left swipe, natural off"),
            (45, 54, .previous, "physical right swipe, natural on"),
            (-45, -54, .next, "physical left swipe, natural on")
        ]
        for (delta, travel, expected, name) in cases {
            var gesture = NotchMusicTrackSwipe()
            func contacts(_ x: CGFloat) -> [NotchMusicTrackSwipe.Contact] {
                [.init(id: 0, position: CGPoint(x: x, y: 0)),
                 .init(id: 1, position: CGPoint(x: x, y: 10))]
            }
            _ = gesture.update(contacts(0), enabled: true)
            _ = gesture.scroll(delta, precise: true, momentum: false)
            suite.expect(gesture.update(contacts(travel), enabled: true) == expected,
                         "raw AppKit direction honors \(name) without a second inversion")
        }
    }
}
