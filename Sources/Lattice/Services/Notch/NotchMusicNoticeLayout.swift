// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit

/// Track announcements keep the music strip's cover and right visualizer,
/// adding the same two-line metadata on the cover's left.
enum NotchMusicNoticeLayout {
    static func geometry(_ base: NotchGeometry) -> NotchGeometry { base.lockScreenMusicGeometry }

    static func wings(title: String, artist: String, geometry base: NotchGeometry) -> NotchNoticeWings {
        let music = geometry(base)
        let wing = music.compactActivityWingWidth
        let room = max(0, (base.screen.width - base.cameraWidth) / 2 - 12)
        return NotchMusicStripLayout.namedWings(title: title, artist: artist, geometry: music, room: room)
            ?? NotchNoticeWings(leading: wing, trailing: wing)
    }

    static func capsuleSize(title: String?, artist: String?, geometry: NotchGeometry) -> CGSize {
        let layout = NotchCapsuleLayout.self
        guard let title else { return layout.musicSurface(title: nil, geometry: geometry) }
        let titleWidth = (title as NSString).size(withAttributes: [.font: NotchMusicStripLayout.titleFont]).width
        let artistWidth = ((artist ?? "") as NSString).size(withAttributes: [.font: NotchMusicStripLayout.artistFont]).width
        let words = ceil(max(titleWidth, artistWidth)) + layout.air
        let content = words + layout.artworkSide(geometry) + layout.barsWidth + layout.endPadding * 2
        return layout.surface(content: content, maximum: layout.Maximum.music, geometry: geometry)
    }
}
