import AppKit

enum NotchMusicSwipeSurfaceTests {
    static func run(_ suite: TestSuite) {
        func available(strip: Bool = false, track: Bool = true, expanded: Bool = false,
                       peeking: Bool = false, expandedNotice: Bool = false, canPresent: Bool = true) -> Bool {
            NotchMusicSwipeController.permitsCompact(stripVisible: strip, expanded: expanded, peeking: peeking,
                trackNotice: track, noticeExpanded: expandedNotice, noticeCanPresent: canPresent)
        }
        suite.expect(available(strip: true, track: false) && available(),
                     "both a compact music strip and its track-info notice accept music swipes")
        suite.expect(!available(expanded: true) && !available(peeking: true)
                     && !available(expandedNotice: true) && !available(canPresent: false)
                     && !available(track: false),
                     "an unavailable track notice or another surface cannot acquire compact music swipes")
        let state = NotchMusicSwipeState()
        var commands = 0
        let controller = NotchMusicSwipeController(state: state) { _ in commands += 1; return true }
        func contacts(_ x: CGFloat) -> [NotchMusicTrackSwipe.Contact] {
            [.init(id: 0, position: CGPoint(x: x, y: 0)), .init(id: 1, position: CGPoint(x: x, y: 10))]
        }
        controller.synchronizeSurface("compact-\(available(strip: true, track: false))")
        for index in 0..<3 {
            _ = controller.update(contacts(0), began: true, enabled: true, expanded: false)
            _ = controller.scroll(-1, precise: true, momentum: false, cancelled: false, enabled: true, expanded: false)
            _ = controller.update(contacts(27), began: false, enabled: true, expanded: false)
            // Track-info covers the strip, but remains the same usable music surface.
            controller.synchronizeSurface("compact-\(available())")
            _ = controller.update(contacts(54), began: false, enabled: true, expanded: false)
            suite.expect(commands == index && state.frame.progress == 1,
                         "each rapid swipe stays armed while the track-info notice is displayed")
            _ = controller.update([], began: false, enabled: true, expanded: false)
            suite.expect(commands == index + 1, "each separate lift can skip without waiting for the notice to dismiss")
        }
        state.clear()
    }
}
