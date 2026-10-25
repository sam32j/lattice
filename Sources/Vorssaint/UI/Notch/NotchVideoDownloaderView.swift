// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

struct NotchVideoDownloaderView: View {
    let size: CGSize
    @ObservedObject private var downloader = VideoDownloader.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var clipboardURL: String? = nil
    @State private var inputFocused = false

    var body: some View {
        Group {
            if !downloader.dependencies.ready {
                missingToolsView
            } else if let output = downloader.output {
                completedView(output: output)
            } else if downloader.isDownloading || downloader.isPaused || (downloader.busy && downloader.progress != nil) {
                downloadingView
            } else if let info = downloader.info {
                reviewView(info: info)
            } else {
                pasteLinkView
            }
        }
        .frame(width: size.width, alignment: .top)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .onAppear {
            refreshClipboard()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshClipboard()
        }
    }

    private func refreshClipboard() {
        clipboardURL = VideoDownloadRequest.validClipboardURL()
    }

    // MARK: - State A: Paste a Link

    private var pasteLinkView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header (Download icon + "Video Downloader", no "All tools ready" as requested)
            HStack(spacing: 7) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Text(VideoDownloaderStrings.pageTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
            }

            // Input Row
            HStack(spacing: 8) {
                // Text input container
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    TextField("Paste a video link", text: $downloader.link)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .onSubmit {
                            submitLink()
                        }

                    if let clip = clipboardURL, downloader.link.isEmpty {
                        Button {
                            downloader.link = clip
                            downloader.fetchInfo()
                        } label: {
                            Text(VideoDownloaderStrings.pasteClipboardURL)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.blue, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 38)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                // Action Button (Paste / Search / Loading)
                if downloader.isFetching {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 60, height: 38)
                } else {
                    Button {
                        submitLink()
                    } label: {
                        Text(downloader.link.isEmpty ? VideoDownloaderStrings.paste : VideoDownloaderStrings.search)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Error State
            if downloader.error != nil {
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                    Text(VideoDownloaderStrings.fetchFailedNotice)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else if downloader.isFetching {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.mini)
                    Text(VideoDownloaderStrings.fetchingDetails)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
        }
    }

    private func submitLink() {
        if downloader.link.isEmpty {
            if let clip = clipboardURL {
                downloader.link = clip
                downloader.fetchInfo()
            }
        } else {
            downloader.fetchInfo()
        }
    }

    // MARK: - State B: Review & Download

    private func reviewView(info: VideoDownloadInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Media Preview row
            HStack(alignment: .top, spacing: 12) {
                // Thumbnail
                thumbnailBox(duration: info.formattedDuration, width: 120, height: 68)

                // Title + Provider
                VStack(alignment: .leading, spacing: 4) {
                    let source = info.sourceLabel.isEmpty ? info.creator : info.sourceLabel
                    if !source.isEmpty {
                        Text(source.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Text(info.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            // Bottom control row
            HStack(alignment: .center, spacing: 10) {
                // Segmented quality options
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
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Size & save location details
                VStack(alignment: .leading, spacing: 2) {
                    let est = info.estimatedSizeFormatted(for: downloader.selectedQuality) ?? "~1.4 GB"
                    let format = downloader.selectedQuality.isAudio ? "M4A" : "MKV"
                    Text("\(est) · \(format)")
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
                        .frame(height: 30)
                        .background(Color.blue, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - State 2: Expanded while downloading

    private var downloadingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Media row
            HStack(alignment: .center, spacing: 10) {
                // Thumbnail
                thumbnailBox(duration: downloader.info?.formattedDuration, width: 80, height: 48)

                // Title + Subtitle
                VStack(alignment: .leading, spacing: 3) {
                    Text(downloader.info?.title ?? "Video")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    let provider = downloader.info?.sourceLabel.isEmpty == false ? (downloader.info?.sourceLabel ?? "") : (downloader.info?.creator ?? "")
                    let quality = downloader.selectedQuality.title
                    let format = downloader.selectedQuality.isAudio ? "M4A" : "MKV"
                    let subtitle = [provider, quality, format].filter { !$0.isEmpty }.joined(separator: " · ")
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                // Large Percentage
                let percentText = downloader.downloadProgress?.percentText ?? "\(Int((downloader.progress ?? 0) * 100))%"
                Text(percentText)
                    .font(.system(size: 24, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }

            // Linear Progress Bar
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

            // Bottom stats & controls
            HStack(alignment: .center, spacing: 8) {
                Text(downloader.downloadProgress?.formattedDetails ?? downloader.phase)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

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
                        .padding(.horizontal, 12)
                        .frame(height: 26)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)

                // Cancel
                Button {
                    downloader.cancel()
                } label: {
                    Text(VideoDownloaderStrings.cancel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.red.opacity(0.9))
                        .padding(.horizontal, 12)
                        .frame(height: 26)
                        .background(Color.red.opacity(0.18), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - State 3: Finished

    private func completedView(output: URL) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(VideoDownloaderStrings.downloadComplete)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                let sizeStr = outputFileSizeText(url: output)
                let subtext = sizeStr.isEmpty ? "Saved to \(destinationFolderName)" : "\(sizeStr) saved to \(destinationFolderName)"
                Text(subtext)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([output])
            } label: {
                Text(VideoDownloaderStrings.showInFinder)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .frame(height: 28)
                    .background(Color.white, in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                downloader.resetDownloadState()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Missing Tools Gate

    private var missingToolsView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 20))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(VideoDownloaderStrings.missingToolsTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(VideoDownloaderStrings.missingToolsBody)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(VideoDownloaderStrings.repairAction) {
                    SettingsRouter.shared.page = .videoDownloader
                    (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
                    NotchService.shared.collapse()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.orange)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(Color.orange.opacity(0.15), in: Capsule())
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
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
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.4))
                    )
            }

            if let duration, !duration.isEmpty {
                Text(duration)
                    .font(.system(size: 9, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                    .padding(4)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

// MARK: - Compact Strip Views (State 1: Circular Progress Ring, NO Center Text)

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

/// Notched display compact activity strip
struct NotchVideoDownloaderStrip: View {
    @ObservedObject var service: NotchService
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var downloader = VideoDownloader.shared

    private var geometry: NotchGeometry { displayGeometry ?? service.compactActivityGeometry }
    private var iconSize: CGFloat {
        min(16, geometry.compactActivityContentHeight - NotchLayout.compactEdgeGap * 2)
    }

    var body: some View {
        Button {
            service.openActivity(.videoDownloader)
        } label: {
            HStack(spacing: 0) {
                // Left wing: thumbnail or icon
                HStack(spacing: 6) {
                    if let thumb = downloader.thumbnailImage {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: iconSize * 1.4, height: iconSize)
                            .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                    } else {
                        Image(systemName: "arrow.down.square.fill")
                            .font(.system(size: iconSize))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.leading, 8)
                .frame(width: geometry.compactActivityWingWidth, alignment: .leading)
                .clipped()

                // Center camera gap: empty, no center text
                Color.clear.frame(width: geometry.compactActivityCameraGap)

                // Right wing: progress ring
                HStack(spacing: 6) {
                    Spacer(minLength: 0)
                    if let fraction = downloader.progress {
                        CircleProgressRing(fraction: fraction, size: iconSize)
                    } else {
                        ProgressView().controlSize(.mini)
                    }
                }
                .padding(.trailing, 8)
                .frame(width: geometry.compactActivityWingWidth, alignment: .trailing)
                .clipped()
            }
            .frame(height: geometry.compactActivityContentHeight)
            .padding(.horizontal, geometry.compactActivityHorizontalPadding)
            .padding(.top, geometry.compactActivityTopPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Floating capsule compact activity strip
struct NotchCapsuleVideoDownloaderStrip: View {
    @ObservedObject var service: NotchService
    let size: CGSize
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var downloader = VideoDownloader.shared

    private var geometry: NotchGeometry { displayGeometry ?? service.geometry }
    private var iconSize: CGFloat { min(16, geometry.stripHeight - 10) }

    var body: some View {
        Button {
            service.openActivity(.videoDownloader)
        } label: {
            HStack(spacing: 8) {
                if let thumb = downloader.thumbnailImage {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: iconSize * 1.4, height: iconSize)
                        .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                } else {
                    Image(systemName: "arrow.down.square.fill")
                        .font(.system(size: iconSize))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 12)

                if let fraction = downloader.progress {
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
