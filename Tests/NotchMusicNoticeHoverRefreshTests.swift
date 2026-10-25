import Foundation

enum NotchMusicNoticeHoverRefreshTests {
    static func run(_ suite: TestSuite) {
        let service = NotchPresentationRefreshContract.Service()
        service.expanded = false
        service.notice = true
        service.trackNoticeVisible = true
        service.musicStripHover = true
        service.musicStripPointer = .bars
        let naming = DispatchWorkItem {}
        service.musicNamingWork = naming
        service.refreshPresentation(animated: false)
        suite.expect(service.musicStripPointer == .bars && service.musicStripHover,
                     "a track notice preserves the stationary music pointer and hover state")
        suite.expect(!naming.isCancelled && service.musicNamingWork != nil,
                     "a track notice preserves scheduled music naming without another pointer event")
        service.trackNoticeVisible = false
        service.refreshPresentation(animated: false)
        suite.expect(service.musicStripPointer == nil && !service.musicStripHover,
                     "a non-music surface clears music hover state")
        suite.expect(naming.isCancelled && service.musicNamingWork == nil,
                     "leaving the music surface cancels scheduled naming")
    }
}
