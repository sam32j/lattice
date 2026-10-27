// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import SwiftUI

extension VideoDownloaderSettings {
    func searchInput(isCompact: Bool) -> some View {
        let isClear = model.hasCurrentSearchResult || (model.error != nil && !model.isFetching)
        let isFieldEmpty = model.link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isSearchClipboard = !isClear && isFieldEmpty && detectedClipboardURL != nil
        let canSearch = !model.busy && (isClear || !isFieldEmpty || isSearchClipboard)

        let buttonTitle: String = {
            if isClear { return VideoDownloaderStrings.clear }
            if isSearchClipboard { return VideoDownloaderStrings.searchClipboardURL }
            return VideoDownloaderStrings.search
        }()

        let buttonIcon: String? = {
            if isClear { return nil }
            return "magnifyingglass"
        }()

        let buttonForeground: Color = {
            if !canSearch { return Color.secondary.opacity(0.4) }
            if isClear { return Color.primary }
            return Color(nsColor: .controlAccentColor)
        }()

        let buttonBackground: Color = {
            if isClear {
                return isSearchHovered ? Color.secondary.opacity(0.12) : Color(nsColor: .controlBackgroundColor)
            }
            if isSearchClipboard {
                return Color(nsColor: .controlAccentColor).opacity(isSearchHovered ? 0.08 : 0.0)
            }
            if canSearch {
                return Color(nsColor: .controlAccentColor).opacity(isSearchHovered ? 0.20 : 0.12)
            }
            return Color(nsColor: .controlBackgroundColor)
        }()

        let buttonStroke: Color = {
            if isClear {
                return Color.secondary.opacity(isSearchHovered ? 0.35 : 0.20)
            }
            if isSearchClipboard {
                return Color(nsColor: .controlAccentColor).opacity(isSearchHovered ? 0.75 : 0.45)
            }
            if canSearch {
                return Color(nsColor: .controlAccentColor).opacity(isSearchHovered ? 0.50 : 0.30)
            }
            return Color.secondary.opacity(0.18)
        }()

        return HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                TextField(VideoDownloaderStrings.urlPlaceholder, text: $model.link)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit { model.fetchInfo() }
                    .onChange(of: model.link) { _, newLink in
                        model.linkChanged()
                        if newLink.isEmpty { updateClipboardURL() }
                    }

                if !model.link.isEmpty && !isClear && !model.isFetching {
                    Button {
                        model.link = ""
                        model.linkChanged()
                        updateClipboardURL()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )
            .onHover { isHovering in
                if isHovering && model.link.isEmpty {
                    updateClipboardURL()
                }
            }

            Button {
                if isClear {
                    model.resetDownloadState()
                    updateClipboardURL()
                } else if isSearchClipboard, let clip = detectedClipboardURL {
                    model.link = clip
                    model.fetchInfo()
                } else if canSearch {
                    model.fetchInfo()
                }
            } label: {
                HStack(spacing: 5) {
                    if let icon = buttonIcon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text(buttonTitle)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .id(buttonTitle)
                .transition(.opacity.animation(.easeInOut(duration: 0.18)))
                .padding(.horizontal, 14)
                .frame(minWidth: 107)
                .frame(height: 40)
                .foregroundStyle(buttonForeground)
                .background(buttonBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(buttonStroke, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSearch)
            .fixedSize(horizontal: true, vertical: false)
            .onHover { hovering in
                isSearchHovered = hovering
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: buttonTitle)
        .disabled(model.busy)
    }

    @ViewBuilder
    func mediaCard(info: VideoDownloadInfo, isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if isCompact {
                // Stack thumbnail on top when width is constrained
                thumbnailView(duration: info.duration)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16/9, contentMode: .fit)

                metadataView(info: info, isCompact: isCompact)
            } else {
                // Side-by-side thumbnail and metadata when width allows
                HStack(alignment: .top, spacing: 16) {
                    thumbnailView(duration: info.duration)
                        .frame(width: 230, height: 130)

                    metadataView(info: info, isCompact: isCompact)
                }
            }

            Divider()

            if model.isDownloading {
                downloadProgressContent(isCompact: isCompact)
            } else if let output = model.output {
                downloadCompleteContent(output: output)
            } else {
                // Quality & Destination
                if isCompact {
                    VStack(alignment: .leading, spacing: 12) {
                        qualityPicker(info: info)
                        saveToButton
                    }
                } else {
                    HStack(alignment: .top, spacing: 16) {
                        qualityPicker(info: info)
                            .layoutPriority(1)
                        Spacer(minLength: 8)
                        saveToButton
                    }
                }

                if let error = model.error {
                    downloadFailedRow(error: error, isCompact: isCompact)
                } else {
                    HStack {
                        Spacer()
                        Button(VideoDownloaderStrings.download, action: model.download)
                            .buttonStyle(.bordered)
                            .tint(.blue)
                            .controlSize(.regular)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    func downloadFailedRow(error: String, isCompact: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 18, weight: .semibold))

            VStack(alignment: .leading, spacing: 2) {
                Text(VideoDownloaderStrings.downloadFailed)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
                let displayError: String = {
                    if model.websiteFailure == .authentication {
                        return model.websiteSessions.hasSession
                            ? VideoDownloaderStrings.noAccessNotice
                            : VideoDownloaderStrings.loginRequiredNotice
                    }
                    return VideoDownloadRequest.cleanErrorMessage(error)
                }()
                Text(displayError)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if model.websiteFailure != nil {
                let sessionButtonTitle = model.websiteSessions.hasSession
                    ? VideoDownloaderStrings.tryDifferentSessions
                    : VideoDownloaderStrings.manageSessions
                Button(sessionButtonTitle) {
                    model.showWebsiteSessions = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button(VideoDownloaderStrings.retry, action: model.download)
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.regular)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.red.opacity(0.25), lineWidth: 1)
        )
    }

    @ViewBuilder
    func thumbnailView(duration: Double?) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if let thumb = model.thumbnailImage {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.9))
                    .overlay(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .foregroundStyle(.white)
                                    .offset(x: 1.5)
                            )
                    )
            }

            if let duration = duration, duration.isFinite, duration > 0 {
                Text(formatDuration(duration))
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 4))
                    .padding(6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    func metadataView(info: VideoDownloadInfo, isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !info.sourceLabel.isEmpty {
                Text(info.sourceLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            Text(info.title)
                .font(.system(size: 14, weight: .bold))
                .lineLimit(isCompact ? 2 : 3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                if model.selectedQuality.isBest {
                    chipView(VideoDownloaderStrings.bestQuality)
                    if let actualRes = info.qualities.first?.title {
                        chipView(actualRes)
                    }
                } else {
                    chipView(model.selectedQuality.title)
                }

                if let size = info.estimatedSizeFormatted(for: model.selectedQuality) {
                    chipView(size)
                }

                chipView(model.selectedQuality.containerTag)
            }
        }
    }

    @ViewBuilder
    func qualityPicker(info: VideoDownloadInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(VideoDownloaderStrings.quality)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollableVideoQualitySegments(info: info, selectedQuality: model.selectedQuality, spacing: 2, viewportWidth: 228) { q in
                let isSelected = model.selectedQuality == q
                    || (model.selectedQuality.isBest && q == info.qualities.first)
                Button {
                    model.selectedQuality = q
                    model.selectedHeight = q.height != 0 ? q.height : (info.qualities.first?.height ?? 0)
                } label: {
                    Text(q.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            isSelected
                            ? Color(nsColor: .controlBackgroundColor)
                            : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .shadow(color: isSelected ? .black.opacity(0.08) : .clear, radius: 2, y: 1)
                }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .padding(2)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    @ViewBuilder
    var saveToButton: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(VideoDownloaderStrings.saveTo)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Button(action: model.chooseDestination) {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                    Text(displayDestinationPath(model.destination))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                }
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(maxWidth: 235, alignment: .leading)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(model.destination?.path ?? VideoDownloaderStrings.defaultFolder)
        }
        .frame(maxWidth: 235, alignment: .leading)
    }

    @ViewBuilder
    func downloadProgressContent(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(model.isPaused ? VideoDownloaderStrings.paused : VideoDownloaderStrings.downloading)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(model.downloadProgress?.percentText ?? "\(Int((model.progress ?? 0) * 100))%")
                    .font(.subheadline.monospacedDigit().weight(.bold))
            }

            ProgressView(value: model.progress ?? 0)
                .tint(.blue)

            if isCompact {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.downloadProgress?.formattedDetails ?? model.phase)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack {
                        Spacer()
                        Button(model.isPaused ? VideoDownloaderStrings.resume : VideoDownloaderStrings.pause) {
                            if model.isPaused {
                                model.resume()
                            } else {
                                model.pause()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)

                        Button(VideoDownloaderStrings.cancel, action: model.cancel)
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .tint(.red)
                    }
                }
            } else {
                HStack {
                    Text(model.downloadProgress?.formattedDetails ?? model.phase)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Button(model.isPaused ? VideoDownloaderStrings.resume : VideoDownloaderStrings.pause) {
                        if model.isPaused {
                            model.resume()
                        } else {
                            model.pause()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Button(VideoDownloaderStrings.cancel, action: model.cancel)
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .tint(.red)
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    func downloadCompleteContent(output: URL) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(VideoDownloaderStrings.downloadComplete)
                    .font(.subheadline.weight(.semibold))
                Text(output.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    func skeletonMediaCard(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if isCompact {
                skeletonThumbnail
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16/9, contentMode: .fit)

                skeletonMetadata(isCompact: true)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    skeletonThumbnail
                        .frame(width: 230, height: 130)

                    skeletonMetadata(isCompact: false)
                }
            }

            Divider()

            if isCompact {
                VStack(alignment: .leading, spacing: 12) {
                    skeletonQualityPicker
                    skeletonSaveToButton
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    skeletonQualityPicker
                        .layoutPriority(1)
                    Spacer(minLength: 8)
                    skeletonSaveToButton
                }
            }

            HStack {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(VideoDownloaderStrings.fetchingDetails)
                        .font(isCompact ? .caption : .subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button(VideoDownloaderStrings.cancel, action: model.cancel)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    var skeletonThumbnail: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(skeletonPulsing ? 0.08 : 0.16))
                .overlay(
                    Circle()
                        .fill(Color.secondary.opacity(skeletonPulsing ? 0.10 : 0.20))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.secondary.opacity(0.35))
                                .offset(x: 1.5)
                        )
                )

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.secondary.opacity(skeletonPulsing ? 0.12 : 0.24))
                .frame(width: 36, height: 16)
                .padding(6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: skeletonPulsing)
    }

    @ViewBuilder
    func skeletonMetadata(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.secondary.opacity(skeletonPulsing ? 0.08 : 0.16))
                .frame(width: 70, height: 12)

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.secondary.opacity(skeletonPulsing ? 0.08 : 0.16))
                .frame(height: 16)
                .frame(maxWidth: isCompact ? .infinity : 240)

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.secondary.opacity(skeletonPulsing ? 0.08 : 0.16))
                .frame(width: isCompact ? 180 : 160, height: 16)

            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.secondary.opacity(skeletonPulsing ? 0.08 : 0.16))
                    .frame(width: 44, height: 20)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.secondary.opacity(skeletonPulsing ? 0.08 : 0.16))
                    .frame(width: 48, height: 20)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.secondary.opacity(skeletonPulsing ? 0.08 : 0.16))
                    .frame(width: 64, height: 20)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.secondary.opacity(skeletonPulsing ? 0.08 : 0.16))
                    .frame(width: 42, height: 20)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: skeletonPulsing)
    }

    @ViewBuilder
    var skeletonQualityPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.secondary.opacity(skeletonPulsing ? 0.08 : 0.16))
                .frame(width: 44, height: 10)

            HStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.secondary.opacity(skeletonPulsing ? (index == 0 ? 0.14 : 0.08) : (index == 0 ? 0.22 : 0.16)))
                        .frame(width: index == 0 ? 52 : 46, height: 22)
                }
            }
            .padding(2)
            .background(Color.secondary.opacity(skeletonPulsing ? 0.06 : 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: skeletonPulsing)
    }

    @ViewBuilder
    var skeletonSaveToButton: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.secondary.opacity(skeletonPulsing ? 0.08 : 0.16))
                .frame(width: 48, height: 10)

            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary.opacity(skeletonPulsing ? 0.15 : 0.25))
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.secondary.opacity(skeletonPulsing ? 0.08 : 0.16))
                    .frame(width: 80, height: 12)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: 235, alignment: .leading)
            .frame(height: 26)
            .background(Color.secondary.opacity(skeletonPulsing ? 0.06 : 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .frame(maxWidth: 235, alignment: .leading)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: skeletonPulsing)
    }

    // MARK: - Recent Downloads Section

    @ViewBuilder
    var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(VideoDownloaderStrings.recent)
                    .font(.headline)
                Spacer()
                if !history.items.isEmpty {
                    Button(VideoDownloaderStrings.clearHistory) {
                        history.clear()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(history.items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider()
                            .opacity(0.4)
                    }

                    let fileExists = FileManager.default.fileExists(atPath: item.fileURL.path)

                    HStack(spacing: 15) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: item.qualityTag == VideoDownloaderStrings.audioQuality ? "waveform" : "film")
                                    .font(.system(size: 13))
                                    .foregroundStyle(fileExists ? Color.secondary : Color.secondary.opacity(0.45))
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(fileExists ? Color.primary : Color.secondary)
                                .lineLimit(1)

                            Text(item.formattedSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 12)

                        Button(VideoDownloaderStrings.showInFinder) {
                            history.showInFinder(item)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button(VideoDownloaderStrings.showInFinder) {
                            history.showInFinder(item)
                        }
                        Button("Copy File Path") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(item.fileURL.path, forType: .string)
                        }
                        Divider()
                        Button("Remove from History", role: .destructive) {
                            history.remove(item)
                        }
                    }
                    .help(item.fileURL.path)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
    }

    func chipView(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    func displayDestinationPath(_ url: URL?) -> String {
        guard let path = url?.path else { return VideoDownloaderStrings.defaultFolder }
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    func formatDuration(_ seconds: Double) -> String {
        VideoDownloadRequest.formatDuration(seconds)
    }

    func updateClipboardURL() {
        pasteboardChangeCount = NSPasteboard.general.changeCount
        detectedClipboardURL = VideoDownloadRequest.validClipboardURL()
    }
}
