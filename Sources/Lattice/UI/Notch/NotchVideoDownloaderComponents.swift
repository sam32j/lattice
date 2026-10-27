// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import SwiftUI

extension NotchVideoDownloaderView {
    func previewRow(info: VideoDownloadInfo) -> some View {
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

    func reviewControlsRow(info: VideoDownloadInfo) -> some View {
        HStack(alignment: .center, spacing: 8) {
            // Quality options
            ScrollableVideoQualitySegments(info: info, selectedQuality: downloader.selectedQuality, spacing: 3, viewportWidth: 168) { q in
                let isSelected = downloader.selectedQuality == q
                    || (downloader.selectedQuality.isBest && q == info.qualities.first)
                Button {
                    downloader.selectedQuality = q
                    downloader.selectedHeight = q.height != 0 ? q.height : (info.qualities.first?.height ?? 0)
                } label: {
                    Text(q.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.65))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isSelected ? Color.white.opacity(0.24) : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .padding(2)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Estimated size and destination
            VStack(alignment: .leading, spacing: 1) {
                let format = downloader.selectedQuality.containerTag
                let est = info.estimatedSizeFormatted(for: downloader.selectedQuality)
                Text(est.map { "\($0) · \(format)" } ?? format)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(VideoDownloaderStrings.savesTo(folder: destinationFolderName))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(minWidth: 40, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(0)

            Spacer(minLength: 4)

            // Download Button
            Button {
                downloader.download()
            } label: {
                Text(VideoDownloaderStrings.download)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 12)
                    .frame(height: 26)
                    .background(Color.blue, in: Capsule())
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    // MARK: - Controls Row (Downloading State: Converted to Progress Bar & Controls on Same Row)

    var downloadingControlsRow: some View {
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

    var completedControlsRow: some View {
        Button {
            if let output = downloader.output {
                NSWorkspace.shared.activateFileViewerSelecting([output])
            }
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.22))
                        .frame(width: 20, height: 20)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(VideoDownloaderStrings.downloadComplete)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)

                    let sizeStr = downloader.output.map { outputFileSizeText(url: $0) } ?? ""
                    let detail = sizeStr.isEmpty ? "Saved · Click to reveal in Finder" : "\(sizeStr) · Click to reveal in Finder"
                    Text(detail)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.70))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.green.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.green.opacity(0.38), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 10)
    }

    // MARK: - Controls Row (Failed State: Occupies same slot as review/completed controls)

    func failedControlsRow(info: VideoDownloadInfo, error: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 18, weight: .semibold))

            VStack(alignment: .leading, spacing: 1) {
                Text(VideoDownloaderStrings.downloadFailed)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.red)
                    .lineLimit(1)

                Text(VideoDownloadRequest.cleanErrorMessage(error))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(minWidth: 40, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(0)

            Spacer(minLength: 4)

            if downloader.websiteFailure != nil {
                let sessionButtonTitle = downloader.websiteSessions.hasSession
                    ? VideoDownloaderStrings.tryDifferentSessions
                    : VideoDownloaderStrings.manageSessions
                Button(sessionButtonTitle) {
                    guard !isSettingsPreview else { return }
                    SettingsRouter.shared.page = .videoDownloader
                    (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
                    downloader.showWebsiteSessions = true
                    NotchService.shared.collapse()
                }
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Color.white.opacity(0.14), in: Capsule())
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
            }

            Button {
                downloader.download()
            } label: {
                Text(VideoDownloaderStrings.retry)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 12)
                    .frame(height: 24)
                    .background(Color.red.opacity(0.85), in: Capsule())
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.red.opacity(0.38), lineWidth: 1)
        )
        .padding(.top, 10)
    }

    // MARK: - Error View

    var errorView: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
            let displayError: String = {
                if downloader.websiteFailure == .authentication {
                    return downloader.websiteSessions.hasSession
                        ? VideoDownloaderStrings.noAccessNotice
                        : VideoDownloaderStrings.loginRequiredNotice
                }
                return downloader.error ?? VideoDownloaderStrings.fetchFailedNotice
            }()
            Text(displayError)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
            if downloader.websiteFailure != nil {
                let sessionButtonTitle = downloader.websiteSessions.hasSession
                    ? VideoDownloaderStrings.tryDifferentSessions
                    : VideoDownloaderStrings.manageSessions
                Button {
                    guard !isSettingsPreview else { return }
                    SettingsRouter.shared.page = .videoDownloader
                    (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
                    downloader.showWebsiteSessions = true
                    NotchService.shared.collapse()
                } label: {
                    Text(sessionButtonTitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 24)
                        .background(Color.white.opacity(0.16), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 15)
    }

    // MARK: - Missing Tools Gate

    var missingToolsView: some View {
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

    func thumbnailBox(duration: String?, width: CGFloat, height: CGFloat) -> some View {
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

    func outputFileSizeText(url: URL) -> String {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64, size > 0 {
            let df = ByteCountFormatter()
            df.countStyle = .file
            return df.string(fromByteCount: size)
        }
        return ""
    }

    var destinationFolderName: String {
        downloader.destination?.lastPathComponent ?? "Downloads"
    }
}
