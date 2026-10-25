import AppKit

enum NotchMusicNoticeLayoutTests {
    static func run(_ suite: TestSuite) {
        let geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1440, height: 900),
                                     safeAreaTop: 32, cameraWidth: 210, compactSideRoom: 420)
        let notice = NotchNotice(event: .track, title: "A Song", detail: "An Artist", symbol: "music.note")
        let wings = notice.wings(in: geometry)
        let music = NotchMusicNoticeLayout.geometry(geometry)
        suite.expect(wings.leading > wings.trailing && wings.trailing == music.compactActivityWingWidth,
                     "full music puts both metadata lines left of the cover, preserving the compact right waveform slot")
        let longArtist = NotchNotice(event: .track, title: "A", detail: String(repeating: "Artist ", count: 20), symbol: "music.note")
        let long = longArtist.wings(in: geometry)
        suite.expect(long.leading > wings.leading && long.trailing == wings.trailing,
                     "a long artist widens the metadata side without moving the control to the left")
        let constrained = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1440, height: 900),
                                        safeAreaTop: 32, cameraWidth: 210, compactSideRoom: 0)
        suite.expect(notice.wings(in: constrained).trailing > 0,
                     "a track-change announcement retains a right control even when normal compact wings have no menu room")
        let capsule = NotchGeometry(screen: geometry.screen, safeAreaTop: 0, cameraWidth: 0, silhouette: .capsule)
        let short = NotchMusicNoticeLayout.capsuleSize(title: "A", artist: "B", geometry: capsule)
        let wide = NotchMusicNoticeLayout.capsuleSize(title: "A", artist: "An artist with a longer name", geometry: capsule)
        suite.expect(wide.width > short.width && wide.height == short.height,
                     "capsule music measures both stacked metadata lines while remaining in the menu bar")
    }
}
