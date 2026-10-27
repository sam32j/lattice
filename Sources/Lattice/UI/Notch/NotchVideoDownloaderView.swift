// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

struct NotchVideoDownloaderView: View {
    let size: CGSize
    @ObservedObject var downloader = VideoDownloader.shared
    @ObservedObject var l10n = L10n.shared
    @Environment(\.notchSettingsPreview) var isSettingsPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !downloader.dependencies.ready {
                missingToolsView
            } else {
                // Top row: search bar header
                VideoDownloaderSearchBar(downloader: downloader, isSettingsPreview: isSettingsPreview)

                if let info = downloader.info {
                    // Search successful: extends downwards with image preview & controls
                    previewRow(info: info)

                    if downloader.output != nil || downloader.isCompletedSustaining {
                        completedControlsRow
                    } else if downloader.isDownloading || downloader.isPaused || (downloader.busy && downloader.progress != nil) {
                        downloadingControlsRow
                    } else if let error = downloader.error {
                        failedControlsRow(info: info, error: error)
                    } else {
                        reviewControlsRow(info: info)
                    }
                } else if downloader.error != nil {
                    errorView
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .frame(width: size.width, alignment: .top)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: downloader.info != nil)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: downloader.isDownloading)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: downloader.output != nil)
        .notchBand(trailing: {
            NotchIconButton(symbol: "clock.arrow.circlepath", title: VideoDownloaderStrings.recent) {
                SettingsRouter.shared.page = .videoDownloader
                SettingsRouter.shared.videoDownloaderSection = "recent"
                (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
                NotchService.shared.collapse()
            }
        })
        .onAppear {
            guard !isSettingsPreview else { return }
            if downloader.output != nil && !downloader.isCompletedSustaining {
                downloader.resetDownloadState()
            }
        }
        .onDisappear {
            guard !isSettingsPreview else { return }
            if downloader.output != nil && !downloader.isCompletedSustaining {
                downloader.resetDownloadState()
            }
        }
    }

    // MARK: - Preview Row (Extended Downwards)


}

// MARK: - Compact Strip Views

struct CircleProgressRing: View {
    let fraction: Double
    var size: CGFloat = 15
    var tint: Color = .blue

    var body: some View {
        let clamped = min(1, max(0, fraction))
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 2)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

/// Notched display compact activity strip (sits beside the camera in the wings)
struct NotchVideoDownloaderStrip: View {
    @ObservedObject var service: NotchService
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject var downloader = VideoDownloader.shared

    var geometry: NotchGeometry { displayGeometry ?? service.compactActivityGeometry }
    var wing: CGFloat { geometry.compactActivityWingWidth }
    var iconSize: CGFloat {
        min(18, geometry.compactActivityContentHeight - NotchLayout.compactEdgeGap * 2)
    }
    var artworkInset: CGFloat { geometry.compactMusicArtworkInset }
    var rightInset: CGFloat { geometry.compactMusicBarsInset }

    var body: some View {
        Button {
            // When complete, clicking compact mode opens the file in Finder without expanding
            if downloader.output != nil || downloader.isCompletedSustaining {
                if let output = downloader.output {
                    NSWorkspace.shared.activateFileViewerSelecting([output])
                }
            } else {
                service.openActivity(.videoDownloader)
            }
        } label: {
            HStack(spacing: 0) {
                // Left wing: thumbnail or download icon
                HStack(spacing: 0) {
                    if let thumb = downloader.thumbnailImage {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: iconSize * 1.35, height: iconSize)
                            .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: iconSize))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.leading, artworkInset)
                .frame(width: wing, height: geometry.compactActivityContentHeight, alignment: .leading)
                .clipped()

                // Center camera cutout: empty, NO text
                Color.clear
                    .frame(width: geometry.compactActivityCameraGap, height: geometry.compactActivityContentHeight)

                // Right wing: completion checkmark or circular progress ring
                HStack(spacing: 0) {
                    if downloader.output != nil || downloader.isCompletedSustaining {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: iconSize))
                            .foregroundStyle(.green)
                    } else if downloader.error != nil {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: iconSize))
                            .foregroundStyle(.red)
                    } else if let fraction = downloader.progress {
                        CircleProgressRing(fraction: fraction, size: iconSize)
                    } else {
                        ProgressView().controlSize(.mini)
                    }
                }
                .padding(.trailing, rightInset)
                .frame(width: wing, height: geometry.compactActivityContentHeight, alignment: .trailing)
                .clipped()
            }
            .frame(height: geometry.compactActivityContentHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: wing * 2 + geometry.compactActivityCameraGap, alignment: .center)
    }
}

/// Floating capsule compact activity strip
struct NotchCapsuleVideoDownloaderStrip: View {
    @ObservedObject var service: NotchService
    let size: CGSize
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject var downloader = VideoDownloader.shared

    var geometry: NotchGeometry { displayGeometry ?? service.geometry }
    var iconSize: CGFloat { min(16, geometry.stripHeight - 10) }

    var body: some View {
        Button {
            // When complete, clicking compact mode opens the file in Finder without expanding
            if downloader.output != nil || downloader.isCompletedSustaining {
                if let output = downloader.output {
                    NSWorkspace.shared.activateFileViewerSelecting([output])
                }
            } else {
                service.openActivity(.videoDownloader)
            }
        } label: {
            HStack(spacing: 8) {
                if let thumb = downloader.thumbnailImage {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: iconSize * 1.35, height: iconSize)
                        .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: iconSize))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 12)

                if downloader.output != nil || downloader.isCompletedSustaining {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: iconSize))
                        .foregroundStyle(.green)
                } else if downloader.error != nil {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: iconSize))
                        .foregroundStyle(.red)
                } else if let fraction = downloader.progress {
                    CircleProgressRing(fraction: fraction, size: iconSize)
                } else {
                    ProgressView().controlSize(.mini)
                }
            }
            .padding(.horizontal, 10)
            .frame(width: size.width, height: geometry.stripHeight)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
