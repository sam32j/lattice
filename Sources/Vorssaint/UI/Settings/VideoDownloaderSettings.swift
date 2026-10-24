// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

struct VideoDownloaderSettings: View {
    @ObservedObject private var model: VideoDownloader
    @ObservedObject private var toolchain: ToolchainManager = .shared
    @ObservedObject private var history: DownloadHistoryStore = .shared

    @AppStorage(DefaultsKey.videoDownloaderEnabled) private var enabled = true
    @AppStorage(DefaultsKey.videoDownloaderUseSystemTools) private var useSystemTools = false
    @State private var showAdvanced = false

    init(model: VideoDownloader = .shared) {
        self.model = model
    }

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 540

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header & Enablement Row
                    VStack(alignment: .leading, spacing: 14) {
                        Text(VideoDownloaderStrings.pageTitle)
                            .font(.system(size: 24, weight: .bold))

                        // Enablement Card
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(VideoDownloaderStrings.enableTitle, systemImage: "arrow.down.square")
                                    .font(.headline)
                                Spacer()
                                Toggle("", isOn: $enabled)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                                    .onChange(of: enabled) { _, isNowEnabled in
                                        if !isNowEnabled {
                                            model.teardown()
                                            toolchain.removeTools()
                                        } else {
                                            model.refreshDependencies()
                                        }
                                    }
                            }
                            Text(VideoDownloaderStrings.enableSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                        )
                    }

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
                        .padding(.vertical, 40)
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
                                    .onChange(of: model.link) { _, _ in model.linkChanged() }

                                if model.isValidURL {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.system(size: 15))
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

                            Button(VideoDownloaderStrings.paste) {
                                model.pasteFromClipboard()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

                        // Media Preview Card
                        if let info = model.info {
                            mediaCard(info: info, isCompact: isCompact)
                        }

                        // Download / Progress Card
                        if model.busy {
                            downloadProgressCard(isCompact: isCompact)
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
                        } else if let output = model.output {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(VideoDownloaderStrings.downloadComplete)
                                        .font(.headline)
                                    Text(output.lastPathComponent)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Button(VideoDownloaderStrings.showInFinder) {
                                    NSWorkspace.shared.activateFileViewerSelecting([output])
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(14)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            if enabled {
                model.refreshDependencies()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if enabled {
                model.refreshDependencies()
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

                metadataView(info: info)
            } else {
                // Side-by-side thumbnail and metadata when width allows
                HStack(alignment: .top, spacing: 16) {
                    thumbnailView(duration: info.duration)
                        .frame(width: 230, height: 130)

                    metadataView(info: info)
                }
            }

            Divider()

            // Quality & Destination
            if isCompact {
                VStack(alignment: .leading, spacing: 12) {
                    qualityPicker(info: info)
                    saveToButton
                }
            } else {
                HStack(alignment: .top, spacing: 20) {
                    qualityPicker(info: info)
                    Spacer()
                    saveToButton
                }
            }

            if !model.busy {
                HStack {
                    Spacer()
                    Button(VideoDownloaderStrings.download, action: model.download)
                        .buttonStyle(.borderedProminent)
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
    private func metadataView(info: VideoDownloadInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !info.sourceLabel.isEmpty {
                Text(info.sourceLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            Text(info.title)
                .font(.system(size: 14, weight: .bold))
                .lineLimit(isCompactView ? 2 : 3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                chipView(model.selectedQuality.title)

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
                        model.selectedHeight = q.height
                    } label: {
                        Text(q.title)
                            .font(.system(size: 12, weight: model.selectedQuality == q ? .semibold : .regular))
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
                    Text(displayDestinationPath(model.destination))
                        .lineLimit(1)
                }
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func downloadProgressCard(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(model.isPaused ? VideoDownloaderStrings.paused : VideoDownloaderStrings.downloading)
                    .font(.headline)
                Spacer()
                Text(model.downloadProgress?.percentText ?? "\(Int((model.progress ?? 0) * 100))%")
                    .font(.headline.weight(.bold))
            }

            ProgressView(value: model.progress ?? 0)
                .tint(.blue)

            if isCompact {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.downloadProgress?.formattedDetails ?? model.phase)
                        .font(.caption)
                        .foregroundStyle(.secondary)

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
                        .controlSize(.small)

                        Button(VideoDownloaderStrings.cancel, action: model.cancel)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.red)
                    }
                }
            } else {
                HStack {
                    Text(model.downloadProgress?.formattedDetails ?? model.phase)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(model.isPaused ? VideoDownloaderStrings.resume : VideoDownloaderStrings.pause) {
                        if model.isPaused {
                            model.resume()
                        } else {
                            model.pause()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(VideoDownloaderStrings.cancel, action: model.cancel)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.red)
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(VideoDownloaderStrings.recent)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            ForEach(history.items) { item in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .frame(width: 44, height: 28)
                        .overlay(
                            Image(systemName: item.qualityTag == VideoDownloaderStrings.audioQuality ? "waveform" : "film")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        Text(item.formattedSubtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button(VideoDownloaderStrings.showInFinder) {
                        NSWorkspace.shared.activateFileViewerSelecting([item.fileURL])
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
            }
        }
    }

    private var technicalDetailsContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(VideoDownloadDependencies.coreRequired, id: \.self) { tool in
                let isReady = model.dependencies.tools[tool] != nil
                HStack {
                    Text(tool)
                    Spacer()
                    Text(isReady ? "Ready" : "Missing")
                        .foregroundStyle(isReady ? Color.secondary : Color.red)
                }
                .font(.caption)
            }
        }
        .padding(.top, 6)
    }

    private func chipView(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private var isCompactView: Bool {
        false
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
}
