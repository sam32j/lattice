// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

struct VideoDownloaderSettings: View {
    @ObservedObject private var model: VideoDownloader
    @ObservedObject private var toolchain: ToolchainManager = .shared
    @ObservedObject private var history: DownloadHistoryStore = .shared

    @AppStorage(DefaultsKey.videoDownloaderUseSystemTools) private var useSystemTools = false
    @State private var showAdvanced = false

    init(model: VideoDownloader = .shared) {
        self.model = model
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text(VideoDownloaderStrings.pageTitle)
                    .font(.system(size: 26, weight: .bold))

                // Link Bar
                HStack(spacing: 12) {
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
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )

                    Button(VideoDownloaderStrings.paste) {
                        model.pasteFromClipboard()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                    .padding(18)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                // Media Preview Card
                if let info = model.info {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 16) {
                            // 16:9 Thumbnail preview
                            ZStack(alignment: .bottomTrailing) {
                                if let thumb = model.thumbnailImage {
                                    Image(nsImage: thumb)
                                        .resizable()
                                        .aspectRatio(16/9, contentMode: .fill)
                                        .frame(width: 280, height: 158)
                                        .clipped()
                                } else {
                                    Rectangle()
                                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.8))
                                        .frame(width: 280, height: 158)
                                        .overlay(
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Image(systemName: "play.fill")
                                                        .foregroundStyle(.white)
                                                        .offset(x: 1.5)
                                                )
                                        )
                                }

                                // Duration badge
                                if let duration = info.duration, duration.isFinite, duration > 0 {
                                    Text(formatDuration(duration))
                                        .font(.caption.monospacedDigit().weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 4))
                                        .padding(8)
                                }

                                // Accent bottom line
                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(height: 3)
                                    .frame(maxWidth: .infinity, alignment: .bottom)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            // Metadata Right Column
                            VStack(alignment: .leading, spacing: 8) {
                                if !info.sourceLabel.isEmpty {
                                    Text(info.sourceLabel)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                }

                                Text(info.title)
                                    .font(.system(size: 15, weight: .bold))
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)

                                // Chips row
                                HStack(spacing: 8) {
                                    chipView(model.selectedQuality.title)

                                    if let size = info.estimatedSizeFormatted(for: model.selectedQuality) {
                                        chipView(size)
                                    }

                                    chipView(model.selectedQuality.containerTag)
                                }
                            }
                        }

                        Divider()

                        // Quality & Destination row
                        HStack(alignment: .top, spacing: 24) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(VideoDownloaderStrings.quality)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                // Segmented Control
                                HStack(spacing: 2) {
                                    ForEach(info.segmentedOptions) { q in
                                        Button {
                                            model.selectedQuality = q
                                            model.selectedHeight = q.height
                                        } label: {
                                            Text(q.title)
                                                .font(.system(size: 13, weight: model.selectedQuality == q ? .semibold : .regular))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(
                                                    model.selectedQuality == q
                                                    ? Color(nsColor: .controlBackgroundColor)
                                                    : Color.clear
                                                )
                                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                                .shadow(color: model.selectedQuality == q ? .black.opacity(0.1) : .clear, radius: 2, y: 1)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(3)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            }

                            Spacer()

                            VStack(alignment: .leading, spacing: 6) {
                                Text(VideoDownloaderStrings.saveTo)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Button(action: model.chooseDestination) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "folder")
                                        Text(displayDestinationPath(model.destination))
                                            .lineLimit(1)
                                    }
                                    .font(.system(size: 13))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .buttonStyle(.plain)
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
                    .padding(20)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
                }

                // Download / Progress Card
                if model.busy {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(model.isPaused ? VideoDownloaderStrings.paused : VideoDownloaderStrings.downloading)
                                .font(.headline)
                            Spacer()
                            Text(model.downloadProgress?.percentText ?? "\(Int((model.progress ?? 0) * 100))%")
                                .font(.headline.weight(.bold))
                        }

                        ProgressView(value: model.progress ?? 0)
                            .tint(.blue)

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
                    .padding(18)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
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
                        }
                        Spacer()
                        Button(VideoDownloaderStrings.showInFinder) {
                            NSWorkspace.shared.activateFileViewerSelecting([output])
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(16)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                // RECENT Section
                if !history.items.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(VideoDownloaderStrings.recent)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)

                        ForEach(history.items) { item in
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(nsColor: .windowBackgroundColor))
                                    .frame(width: 54, height: 34)
                                    .overlay(
                                        Image(systemName: item.qualityTag == VideoDownloaderStrings.audioQuality ? "waveform" : "film")
                                            .foregroundStyle(.secondary)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 14, weight: .medium))
                                        .lineLimit(1)
                                    Text(item.formattedSubtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button(VideoDownloaderStrings.showInFinder) {
                                    NSWorkspace.shared.activateFileViewerSelecting([item.fileURL])
                                }
                                .buttonStyle(.borderless)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                            )
                        }
                    }
                }

                // Advanced Escape Hatch
                DisclosureGroup(isExpanded: $showAdvanced) {
                    VStack(alignment: .leading, spacing: 12) {
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
                    .padding(.top, 8)
                } label: {
                    Text(VideoDownloaderStrings.advanced)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 680)
            .padding(32)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            model.refreshDependencies()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshDependencies()
        }
    }

    private func chipView(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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
}
