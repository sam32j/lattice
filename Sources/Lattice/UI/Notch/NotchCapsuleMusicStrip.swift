// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

private typealias CapsuleLayout = NotchCapsuleLayout

/// Playing music: the cover in the round end, concentric with it, the title
/// in the middle and the bars at the other end.
struct NotchCapsuleMusicStrip: View {
    @ObservedObject var service: NotchService
    var snapshot: NotchCompactMusicSnapshot? = nil
    /// The surface the strip fills; a departing strip keeps its own.
    var size: CGSize? = nil
    /// Another display's capsule, when the island shows on every display.
    var displayGeometry: NotchGeometry? = nil
    /// The island's own capsule answers the pointer. A copy on another
    /// display or a strip on its way out only shows the song.
    var interactive = false
    var trackNotice: NotchNotice? = nil
    @ObservedObject private var swipe = NotchMusicSwipeState.shared
    @ObservedObject private var music = NotchMusicService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var geometry: NotchGeometry { snapshot?.geometry ?? displayGeometry ?? service.geometry }
    /// A new song stays off the strip until its notice has shown it, and a
    /// held song through a reading from its player without a name.
    private var shown: NotchCompactMusicSnapshot? {
        if trackNotice != nil { return snapshot }
        return snapshot ?? service.heldMusic ?? (interactive ? service.musicStripStandIn(for: music.playback) : nil)
    }
    private var playback: NotchPlayback? { shown?.playback ?? music.playback }
    private var artwork: NSImage? { shown == nil ? music.artwork : shown?.artwork }
    private var tint: NotchArtworkTint? { shown == nil ? music.artworkTint : shown?.tint }
    private var title: String { trackNotice?.title ?? playback?.track.title ?? FeatureStrings.radialMenu(l10n.language).mediaNowPlaying }
    private var artist: String? {
        let text = (trackNotice?.detail ?? playback?.track.artist)?.trimmingCharacters(in: .whitespaces)
        return text?.isEmpty == false ? text : nil
    }
    private var live: Bool { interactive && snapshot == nil }
    private var showsControl: Bool { live && service.musicStripShowsControl }
    /// A click's request shows at once, before the player says so.
    private var playing: Bool { (live ? service.musicStripRequest : nil) ?? playback?.isPlaying == true }

    var body: some View {
        let side = CapsuleLayout.artworkSide(geometry)
        // A song is named as it starts and while the pointer rests on its
        // cover, and a strip on its way out leaves as it was. Otherwise the
        // cover and bars say enough.
        let named = trackNotice != nil || service.capsuleMusicTitleShown || (live ? service.musicStripNamesSong : snapshot?.namesSong == true)
        NotchCapsuleRow(size: size ?? NotchMusicNoticeLayout.capsuleSize(title: named ? title : nil, artist: artist, geometry: geometry),
                        geometry: geometry, leading: 0, trailing: 0) {
            HStack(spacing: 0) {
                if named {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(title).font(Font(NotchMusicStripLayout.titleFont as CTFont)).lineLimit(1)
                        if let artist {
                            Text(artist).font(Font(NotchMusicStripLayout.artistFont as CTFont))
                                .foregroundStyle(.white.opacity(0.62)).lineLimit(1)
                        }
                    }
                    .padding(.horizontal, CapsuleLayout.endPadding)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .contentShape(Rectangle())
                    .onHover { if live { service.hoverMusicStrip(.cover, entered: $0) } }
                }
                NotchMusicCover(artwork: artwork, side: side, radius: side / 2, source: playback?.track)
                    .padding(.leading, named ? 0 : CapsuleLayout.artworkInset(geometry))
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onHover { if live { service.hoverMusicStrip(.cover, entered: $0) } }
                if named { Color.clear.frame(width: CapsuleLayout.endPadding) }
                else { Spacer(minLength: CapsuleLayout.endPadding) }
                NotchMusicSwipeVisualizer(frame: live ? swipe.frame : .init(), height: CapsuleLayout.barsHeight(geometry)) {
                    ZStack {
                        NotchLiveEqualizerBars(isPlaying: playing && !showsControl,
                                               bars: NotchLayout.compactMusicBarCount,
                                               barWidth: NotchLayout.compactMusicBarWidth,
                                               height: CapsuleLayout.barsHeight(geometry),
                                               tint: tint?.color ?? .white)
                            .opacity(showsControl ? 0 : 1)
                        if showsControl {
                            NotchMusicStripButton(playing: playing, tint: tint?.color ?? .white,
                                                  height: CapsuleLayout.barsHeight(geometry))
                                .transition(.opacity)
                        }
                    }
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: showsControl)
                .padding(.trailing, CapsuleLayout.endPadding)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .onHover { if live { service.hoverMusicStrip(.bars, entered: $0) } }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([title, artist].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAction(named: Text(FeatureStrings.radialMenu(l10n.language).mediaPlayPause)) {
            if !service.toggleMusicStripSong() { service.openActivity(.music) }
        }
    }
}

