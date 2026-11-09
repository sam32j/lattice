// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct NotchLyricsView: View {
    let playback: NotchPlayback
    @ObservedObject private var service = NotchLyricsService.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchLyricsOnline) private var online = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var text: NotchMusicExtrasStrings { FeatureStrings.notchMusicExtras(l10n.language) }

    // The verses sit on the island itself, as a player's own lyrics do, and
    // a song without them says so like the island's other empty pages.
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let lyrics = service.lyrics {
                if lyrics.instrumental {
                    NotchEmptyView(symbol: "music.note", message: text.instrumental)
                } else if !lyrics.lines.isEmpty, playback.hasPosition {
                    synced(lyrics)
                } else {
                    if !playback.hasPosition { Text(text.noPosition).font(.caption).foregroundStyle(.secondary) }
                    ScrollView {
                        Text(lyrics.plain.isEmpty ? lyrics.lines.map(\.text).joined(separator: "\n") : lyrics.plain)
                            .font(.system(size: 15, weight: .medium)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .notchScrollEdgeFade()
                }
            } else if service.state == .loading {
                VStack(spacing: 12) {
                    HStack(spacing: 8) { ProgressView().controlSize(.small); Text(text.loading) }
                        .font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                NotchEmptyView(symbol: service.state == .failed ? "exclamationmark.triangle" : "quote.bubble",
                               message: emptyMessage) {
                    nextStep
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: online) { update() }
    }

    private func update() { service.update(playback: playback, visible: true) }

    private var emptyMessage: String {
        service.state == .failed ? text.failed : text.unavailable
    }

    @ViewBuilder private var nextStep: some View {
        NotchPillButton(title: text.retry, prominent: true, action: service.retry)
    }

    private func synced(_ lyrics: NotchLyrics) -> some View {
        TimelineView(.explicit(lyrics.changeDates(for: playback, from: .now))) { context in
            let active = lyrics.activeIndex(at: playback.position(at: context.date))
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if active == nil {
                            Text(text.waiting).font(.caption).foregroundStyle(.secondary).id("start")
                        }
                        // Every verse keeps one size, so the lines never
                        // rewrap as the song moves. The sung one lights up.
                        ForEach(Array(lyrics.lines.enumerated()), id: \.element.id) { index, line in
                            Text(line.text.isEmpty ? "♪" : line.text)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white.opacity(index == active ? 1 : 0.35))
                                .animation(reduceMotion ? nil : .smooth(duration: 0.28), value: index == active)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .id(index)
                        }
                    }.padding(.vertical, 6)
                }
                .notchScrollEdgeFade(length: 24)
                .onChange(of: active, initial: true) { _, index in
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.28)) {
                        if let index { proxy.scrollTo(index, anchor: .center) }
                        else { proxy.scrollTo("start", anchor: .top) }
                    }
                }
            }
        }
    }
}
