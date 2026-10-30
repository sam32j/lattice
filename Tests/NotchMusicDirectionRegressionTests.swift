import Foundation

enum NotchMusicDirectionRegressionTests {
    static func run(_ suite: TestSuite) {
        func contacts(_ x: Double) -> [NotchMusicTrackSwipe.Contact] {
            [.init(id: 1, position: CGPoint(x: x, y: 20)), .init(id: 2, position: CGPoint(x: x, y: 40))]
        }
        for cancelsAtThreshold in [false, true] {
            var swipe = NotchMusicTrackSwipe()
            _ = swipe.update(contacts(0), enabled: true)
            _ = swipe.scroll(-1, precise: true, momentum: false)
            _ = swipe.update(contacts(10), enabled: true)
            _ = swipe.scroll(cancelsAtThreshold ? 1 : 10, precise: true, momentum: false)
            _ = swipe.update(contacts(18), enabled: true)
            if cancelsAtThreshold { _ = swipe.scroll(10, precise: true, momentum: false) }
            _ = swipe.update(contacts(54), enabled: true)
            suite.expect(swipe.update([], enabled: true) == .previous,
                         "direction follows the trigger-time movement after reversal, cancelled total=\(cancelsAtThreshold)")
        }
    }
}
