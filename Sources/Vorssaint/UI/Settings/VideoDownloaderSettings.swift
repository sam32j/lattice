// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import Combine
import SwiftUI

struct VideoDownloaderSettings: View {
    @ObservedObject private var model: VideoDownloader
    @ObservedObject private var toolchain: ToolchainManager = .shared
    @ObservedObject private var history: DownloadHistoryStore = .shared

    @AppStorage(DefaultsKey.videoDownloaderEnabled) private var enabled = true
    @AppStorage(DefaultsKey.videoDownloaderUseSystemTools) private var useSystemTools = false
    @State private var showAdvanced = false
    @State private var detectedClipboardURL: String? = nil
    @State private var pasteboardChangeCount = -1
    @State private var skeletonPulsing = false
    private let clipboardTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    init(model: VideoDownloader = .shared) {
        self.model = model
    }

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 540

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !enabled {
                        // Uninstalled / Disabled Placeholder
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.square")
                                .font(.system(size: 32))
                                .foregroundStyle(.tertiary)
                            Text(VideoDownloaderStrings.featureDisabledNotice)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        // Active Video Downloader Surfaces

                        // Link Bar
                        HStack(spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "link")
                                    .foregroundStyle(.secondary)
                                TextField(VideoDownloaderStrings.urlPlaceholder, text: $model.link)
                                    .textFieldStyle(.plain)
                                    .onSubmit { model.fetchInfo() }
                                    .onChange(of: model.link) { _, newLink in
                                        model.linkChanged()
                                        if newLink.isEmpty { updateClipboardURL() }
                                    }

                                if let clip = detectedClipboardURL, model.link.isEmpty {
                                    Button {
                                        model.link = clip
                                        model.linkChanged()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "doc.on.clipboard")
                                                .font(.system(size: 11, weight: .semibold))
                                            Text(isCompact ? "Paste URL" : VideoDownloaderStrings.pasteClipboardURL)
                                                .font(.system(size: 11.5, weight: .medium))
                                        }
                                        .foregroundStyle(Color.accentColor)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.12))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                } else if !model.link.isEmpty {
                                    Button {
                                        model.link = ""
                                        model.linkChanged()
                                        updateClipboardURL()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                            .font(.system(size: 13))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 44)
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
                                model.fetchInfo()
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "magnifyingglass")
                                    Text(VideoDownloaderStrings.search)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .frame(height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .disabled(model.busy || model.link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .disabled(model.busy)

                        // Toolchain Installing / Setup State
                        if case .installing(_, _, let fraction, let message) = toolchain.state {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(VideoDownloaderStrings.gettingReady)
                                    .font(.headline)
                                ProgressView(value: fraction)
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        // Toolchain Repair State
                        if case .needsRepair(let reason) = toolchain.state, !model.dependencies.ready {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(VideoDownloaderStrings.repairTitle)
                                            .font(.headline)
                                        Text(reason)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button(VideoDownloaderStrings.repairAction) {
                                        toolchain.repair()
                                    }
                                    .buttonStyle(.borderedProminent)
                                }

                                DisclosureGroup(VideoDownloaderStrings.technicalDetails) {
                                    technicalDetailsContent
                                }
                                .font(.caption)
                            }
                            .padding(16)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        // Fetching Video Details Skeleton Screen
                        if model.isFetching {
                            skeletonMediaCard(isCompact: isCompact)
                        } else if let error = model.error {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(.red)
                                Text(error)
                                    .font(.callout)
                                    .foregroundStyle(.red)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        // Media Preview Card
                        if let info = model.info, !model.isFetching {
                            mediaCard(info: info, isCompact: isCompact)
                        }

                        // RECENT Section
                        if !history.items.isEmpty {
                            recentSection
                        }

                        // Advanced Escape Hatch
                        DisclosureGroup(isExpanded: $showAdvanced) {
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle(VideoDownloaderStrings.useSystemTools, isOn: $useSystemTools)
                                    .onChange(of: useSystemTools) { _, _ in
                                        model.refreshDependencies()
                                    }

                                technicalDetailsContent

                                HStack {
                                    Button(VideoDownloaderStrings.checkUpdates) {
                                        model.refreshDependencies()
                                    }
                                    Spacer()
                                    Button(VideoDownloaderStrings.clearHistory) {
                                        history.clear()
                                    }
                                }
                            }
                            .padding(.top, 6)
                        } label: {
                            Text(VideoDownloaderStrings.advanced)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, isCompact ? 14 : 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .onAppear {
            updateClipboardURL()
            skeletonPulsing = true
            if enabled {
                model.refreshDependencies()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            updateClipboardURL()
            if enabled {
                model.refreshDependencies()
            }
        }
        .onReceive(clipboardTimer) { _ in
            let count = NSPasteboard.general.changeCount
            if count != pasteboardChangeCount {
                pasteboardChangeCount = count
                updateClipboardURL()
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func mediaCard(info: VideoDownloadInfo, isCompact: Bool) -> some View {
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

                HStack {
                    Spacer()
                    Button(VideoDownloaderStrings.download, action: model.download)
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        .controlSize(.regular)
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
    private func thumbnailView(duration: Double?) -> some View {
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

            Rectangle()
                .fill(Color.blue)
                .frame(height: 3)
                .frame(maxWidth: .infinity, alignment: .bottom)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func metadataView(info: VideoDownloadInfo, isCompact: Bool) -> some View {
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
                chipView(model.selectedQuality.title)

                if model.selectedQuality.isBest, let topQuality = info.qualities.first {
                    chipView(topQuality.title)
                }

                if let size = info.estimatedSizeFormatted(for: model.selectedQuality) {
                    chipView(size)
                }

                chipView(model.selectedQuality.containerTag)
            }
        }
    }

    @ViewBuilder
    private func qualityPicker(info: VideoDownloadInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(VideoDownloaderStrings.quality)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 2) {
                ForEach(info.segmentedOptions) { q in
                    Button {
                        model.selectedQuality = q
                        model.selectedHeight = q.isBest ? (info.qualities.first?.height ?? 0) : q.height
                    } label: {
                        Text(q.title)
                            .font(.system(size: 12, weight: model.selectedQuality == q ? .semibold : .regular))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                model.selectedQuality == q
                                ? Color(nsColor: .controlBackgroundColor)
                                : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .shadow(color: model.selectedQuality == q ? .black.opacity(0.08) : .clear, radius: 2, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    @ViewBuilder
    private var saveToButton: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(VideoDownloaderStrings.saveTo)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Button(action: model.chooseDestination) {
                HStack(spacing: 5) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                    Text(displayDestinationPath(model.destination))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 210)
                }
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(maxWidth: 245)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(model.destination?.path ?? VideoDownloaderStrings.defaultFolder)
        }
        .frame(maxWidth: 245, alignment: .leading)
    }

    @ViewBuilder
    private func downloadProgressContent(isCompact: Bool) -> some View {
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
    private func downloadCompleteContent(output: URL) -> some View {
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
    private func skeletonMediaCard(isCompact: Bool) -> some View {
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
    private var skeletonThumbnail: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.secondary.opacity(skeletonPulsing ? 0.08 : 0.16))
            .overlay(
                Image(systemName: "play.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.secondary.opacity(0.2))
            )
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: skeletonPulsing)
    }

    @ViewBuilder
    private func skeletonMetadata(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
                    .frame(width: 50, height: 20)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.secondary.opacity(skeletonPulsing ? 0.08 : 0.16))
                    .frame(width: 58, height: 20)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.secondary.opacity(skeletonPulsing ? 0.08 : 0.16))
                    .frame(width: 44, height: 20)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: skeletonPulsing)
    }

    @ViewBuilder
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(VideoDownloaderStrings.recent)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            ForEach(history.items) { item in
                let fileExists = FileManager.default.fileExists(atPath: item.fileURL.path)
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .frame(width: 44, height: 28)
                        .overlay(
                            Image(systemName: item.qualityTag == VideoDownloaderStrings.audioQuality ? "waveform" : "film")
                                .font(.caption2)
                                .foregroundStyle(fileExists ? Color.secondary : Color.secondary.opacity(0.45))
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(fileExists ? Color.primary : Color.secondary)
                            .lineLimit(1)
                        Text(item.formattedSubtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button(VideoDownloaderStrings.showInFinder) {
                        history.showInFinder(item)
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.08), lineWidth: 1)
                )
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
    }

    private var technicalDetailsContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(VideoDownloadDependencies.coreRequired, id: \.self) { tool in
                let path = model.dependencies.tools[tool]
                HStack {
                    Text(tool)
                    Spacer()
                    if let path {
                        Text(displayToolPath(path))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("Missing")
                            .foregroundStyle(.red)
                    }
                }
                .font(.caption)
                .help(path ?? "Missing")
            }
        }
        .padding(.vertical, 4)
    }

    private func displayToolPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func chipView(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }


    private func displayDestinationPath(_ url: URL?) -> String {
        guard let path = url?.path else { return VideoDownloaderStrings.defaultFolder }
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let s = total % 60
        let m = (total / 60) % 60
        let h = total / 3600
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }

    private func updateClipboardURL() {
        pasteboardChangeCount = NSPasteboard.general.changeCount
        guard let raw = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              !raw.contains(where: { $0.isWhitespace || $0.isNewline }),
              !raw.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            detectedClipboardURL = nil
            return
        }
        let candidate = raw.contains("://") ? raw : "https://" + raw
        guard let parts = URLComponents(string: candidate),
              ["http", "https"].contains(parts.scheme?.lowercased() ?? ""),
              let host = parts.host,
              host.contains("."),
              !host.hasPrefix("."),
              !host.hasSuffix("."),
              parts.user == nil, parts.password == nil else {
            detectedClipboardURL = nil
            return
        }
        detectedClipboardURL = parts.url?.absoluteString ?? candidate
    }
}

struct VideoDownloaderToolbarToggle: View {
    @AppStorage(DefaultsKey.videoDownloaderEnabled) private var enabled = true
    @ObservedObject private var model = VideoDownloader.shared
    @ObservedObject private var toolchain = ToolchainManager.shared

    var body: some View {
        Toggle("", isOn: $enabled)
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .help(VideoDownloaderStrings.enableSubtitle)
            .onChange(of: enabled) { _, isNowEnabled in
                if !isNowEnabled {
                    model.teardown()
                    toolchain.removeTools()
                } else {
                    model.refreshDependencies()
                }
            }
    }
}
