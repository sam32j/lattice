// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

struct NotchVideoDownloaderView: View {
    let size: CGSize
    @ObservedObject private var downloader = VideoDownloader.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.notchSettingsPreview) private var isSettingsPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                    } else {
                        reviewControlsRow(info: info)
                    }
                } else if downloader.error != nil {
                    errorView
                }
            }
        }
        .frame(width: size.width, alignment: .top)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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

    private func previewRow(info: VideoDownloadInfo) -> some View {
        HStack(alignment: .center, spacing: 10) {
            // Thumbnail with duration badge
            thumbnailBox(duration: info.formattedDuration, width: 90, height: 52)

            // Title + Provider
            VStack(alignment: .leading, spacing: 2) {
                let source = info.sourceLabel.isEmpty ? info.creator : info.sourceLabel
                if !source.isEmpty {
                    Text(source.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(info.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            // Numeric percentage when actively downloading
            if (downloader.isDownloading || downloader.isPaused || (downloader.busy && downloader.progress != nil))
                && downloader.output == nil && !downloader.isCompletedSustaining {
                let percentText = downloader.downloadProgress?.percentText ?? "\(Int((downloader.progress ?? 0) * 100))%"
                Text(percentText)
                    .font(.system(size: 22, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Controls Row (Review State: Quality Selector & Download Button)

    private func reviewControlsRow(info: VideoDownloadInfo) -> some View {
        HStack(alignment: .center, spacing: 10) {
            // Quality options
            HStack(spacing: 3) {
                ForEach(info.segmentedOptions) { q in
                    let isSelected = downloader.selectedQuality == q
                    Button {
                        downloader.selectedQuality = q
                        downloader.selectedHeight = q.height != 0 ? q.height : (info.qualities.first?.height ?? 0)
                    } label: {
                        Text(q.title)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? .white : .white.opacity(0.65))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Estimated size and destination
            VStack(alignment: .leading, spacing: 1) {
                let format = downloader.selectedQuality.containerTag
                let est = info.estimatedSizeFormatted(for: downloader.selectedQuality)
                Text(est.map { "\($0) · \(format)" } ?? format)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("Saves to \(destinationFolderName)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            // Download Button
            Button {
                downloader.download()
            } label: {
                Text(VideoDownloaderStrings.download)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 28)
                    .background(Color.blue, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Controls Row (Downloading State: Converted to Progress Bar & Controls on Same Row)

    private var downloadingControlsRow: some View {
        HStack(alignment: .center, spacing: 8) {
            // Progress Bar and Details
            VStack(alignment: .leading, spacing: 3) {
                let fraction = downloader.progress ?? 0
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.14))
                            .frame(height: 5)
                        Capsule()
                            .fill(Color.blue)
                            .frame(width: max(5, proxy.size.width * min(1, max(0, fraction))), height: 5)
                            .animation(.linear(duration: 0.2), value: fraction)
                    }
                }
                .frame(height: 5)

                let details = downloader.downloadProgress?.formattedDetails ?? downloader.phase
                Text(details)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Pause / Resume
            Button {
                if downloader.isPaused {
                    downloader.resume()
                } else {
                    downloader.pause()
                }
            } label: {
                Text(downloader.isPaused ? VideoDownloaderStrings.resume : VideoDownloaderStrings.pause)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(Color.white.opacity(0.14), in: Capsule())
            }
            .buttonStyle(.plain)

            // Cancel
            Button {
                downloader.cancel()
            } label: {
                Text(VideoDownloaderStrings.cancel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.red.opacity(0.95))
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(Color.red.opacity(0.2), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Completed Controls Row (Prominent complete status banner)

    private var completedControlsRow: some View {
        Button {
            if let output = downloader.output {
                NSWorkspace.shared.activateFileViewerSelecting([output])
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 28, height: 28)
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(VideoDownloaderStrings.downloadComplete)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)

                    let sizeStr = downloader.output.map { outputFileSizeText(url: $0) } ?? ""
                    let detail = sizeStr.isEmpty ? "Saved · Click to reveal in Finder" : "\(sizeStr) · Click to reveal in Finder"
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.65))
                }

                Spacer(minLength: 4)

                HStack(spacing: 5) {
                    Text(VideoDownloaderStrings.showInFinder)
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "arrow.up.forward.square.fill")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.green.opacity(0.85), in: Capsule())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.green.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
            Text(VideoDownloaderStrings.fetchFailedNotice)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    // MARK: - Missing Tools Gate

    private var missingToolsView: some View {
        HStack(spacing: 8) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 18))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(VideoDownloaderStrings.missingToolsTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Text(VideoDownloaderStrings.missingToolsBody)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(VideoDownloaderStrings.repairAction) {
                SettingsRouter.shared.page = .videoDownloader
                (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
                NotchService.shared.collapse()
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.orange)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Color.orange.opacity(0.15), in: Capsule())
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private func thumbnailBox(duration: String?, width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if let thumb = downloader.thumbnailImage {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: width, height: height)
                    .overlay(
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.4))
                    )
            }

            if let duration, !duration.isEmpty {
                Text(duration)
                    .font(.system(size: 8, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .padding(3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func outputFileSizeText(url: URL) -> String {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64, size > 0 {
            let df = ByteCountFormatter()
            df.countStyle = .file
            return df.string(fromByteCount: size)
        }
        return ""
    }

    private var destinationFolderName: String {
        downloader.destination?.lastPathComponent ?? "Downloads"
    }
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
    @ObservedObject private var downloader = VideoDownloader.shared
    @State private var isCheckmarkHovered = false

    private var geometry: NotchGeometry { displayGeometry ?? service.compactActivityGeometry }
    private var wing: CGFloat { geometry.compactActivityWingWidth }
    private var iconSize: CGFloat {
        min(18, geometry.compactActivityContentHeight - NotchLayout.compactEdgeGap * 2)
    }
    private var artworkInset: CGFloat { geometry.compactMusicArtworkInset }
    private var rightInset: CGFloat { geometry.compactMusicBarsInset }

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

                // Right wing: completion checkmark (hover -> "Open" green button) or circular progress ring
                HStack(spacing: 0) {
                    if downloader.output != nil || downloader.isCompletedSustaining {
                        ZStack {
                            if isCheckmarkHovered {
                                Text("Open")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.green, in: Capsule())
                                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: iconSize))
                                    .foregroundStyle(.green)
                                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            }
                        }
                        .animation(.easeInOut(duration: 0.16), value: isCheckmarkHovered)
                        .onHover { isCheckmarkHovered = $0 }
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
    @ObservedObject private var downloader = VideoDownloader.shared
    @State private var isCheckmarkHovered = false

    private var geometry: NotchGeometry { displayGeometry ?? service.geometry }
    private var iconSize: CGFloat { min(16, geometry.stripHeight - 10) }

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
                    ZStack {
                        if isCheckmarkHovered {
                            Text("Open")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green, in: Capsule())
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: iconSize))
                                .foregroundStyle(.green)
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.16), value: isCheckmarkHovered)
                    .onHover { isCheckmarkHovered = $0 }
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
