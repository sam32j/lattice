// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Foundation
import SwiftUI

/// Displays the current playback session and opens its owning app.
struct RadialNowPlayingCard: View {
    let snapshot: RadialNowPlayingSnapshot
    let openApplication: () -> Void

    @ObservedObject var l10n = L10n.shared

    var text: RadialMenuFeatureStrings { FeatureStrings.radialMenu(l10n.language) }
    var appName: String {
        RadialNowPlayingApplication.name(for: snapshot) ?? text.mediaNowPlaying
    }
    var title: String { snapshot.title ?? appName }

    var body: some View {
        Button(action: openApplication) {
            HStack(alignment: .center, spacing: 12) {
                artwork
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                    if let album = snapshot.album {
                        Text(album)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if let artist = snapshot.artist {
                        Text(artist)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    HStack(spacing: 5) {
                        if let icon = RadialNowPlayingApplication.icon(for: snapshot) {
                            Image(nsImage: icon)
                                .resizable()
                                .interpolation(.high)
                                .frame(width: 14, height: 14)
                        }
                        Text(String(format: text.mediaOpenAppFormat, appName))
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(width: 320, alignment: .leading)
            .background(HUDBackdrop(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.14), lineWidth: 0.6)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(String(format: text.mediaOpenAppFormat, appName))
    }

    @ViewBuilder
    var artwork: some View {
        if let data = snapshot.artworkData, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.spaceGradient)
                .frame(width: 76, height: 76)
                .overlay {
                    if let icon = RadialNowPlayingApplication.icon(for: snapshot) {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 42, height: 42)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
        }
    }
}
