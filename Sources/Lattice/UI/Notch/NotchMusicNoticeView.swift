// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

/// A track-change notice is the compact player with its metadata made visible,
/// never a second layout with the artist and swipe control on opposite sides.
struct NotchMusicNoticeView: View {
    @ObservedObject var service: NotchService
    let notice: NotchNotice
    var displayGeometry: NotchGeometry? = nil

    var body: some View {
        let base = displayGeometry ?? service.geometry
        if base.floats {
            Button { service.activateMusicStrip() } label: {
                NotchCapsuleMusicStrip(service: service,
                    size: NotchMusicNoticeLayout.capsuleSize(title: notice.title, artist: notice.detail, geometry: base),
                    displayGeometry: base, interactive: true, trackNotice: notice)
            }
            .buttonStyle(.plain)
        } else {
            NotchMusicStrip(service: service, displayGeometry: NotchMusicNoticeLayout.geometry(base),
                            interactive: true, trackNotice: notice)
        }
    }
}
