// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// The folders the wallpaper gallery imports: a titled row with the button
/// that adds one, then a row per folder, laid out like the card's other rows.
struct WallpaperFolderSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = WallpaperService.shared
    /// Turning the feature off empties the service's list at once; the rows
    /// fold away with the card showing what they last held.
    @State private var lastSources: [WallpaperService.OwnSource] = []

    private var text: WallpaperFeatureStrings { FeatureStrings.wallpaper(l10n.language) }

    private var sources: [WallpaperService.OwnSource] {
        service.isAvailable ? service.ownSources : lastSources
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsControlRow(title: text.importedFolders,
                               caption: sources.isEmpty ? text.noFolders : nil) {
                Button {
                    service.addFolder()
                } label: {
                    Label(text.addFolder, systemImage: "plus")
                }
            }
            ForEach(sources) { source in
                Divider()
                row(source)
            }
        }
        .onAppear { service.reloadSources() }
        .onChange(of: service.ownSources, initial: true) { _, current in
            if service.isAvailable { lastSources = current }
        }
    }

    private func row(_ source: WallpaperService.OwnSource) -> some View {
        HStack(spacing: 9) {
            icon(for: source)
            VStack(alignment: .leading, spacing: 1) {
                Text(source.title)
                    .lineLimit(1)
                if let path = source.path {
                    // Folders of one name differ by where they sit, so the
                    // tail of the path is what truncation must keep.
                    Text(WallpaperSupport.displayPath(path))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            .help(source.path ?? source.title)
            Spacer(minLength: 8)
            Button {
                service.removeOwnSource(source)
            } label: {
                Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(text.removeAdded)
            .accessibilityLabel(text.removeAdded + ": " + source.title)
        }
    }

    @ViewBuilder
    private func icon(for source: WallpaperService.OwnSource) -> some View {
        if source.isReachable, let path = source.path {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .frame(width: 18, height: 18)
        }
    }
}
