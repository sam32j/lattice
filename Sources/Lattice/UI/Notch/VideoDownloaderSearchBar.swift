// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import AppKit
import Combine
import SwiftUI

struct VideoDownloaderSearchBar: View {
    @ObservedObject var downloader: VideoDownloader
    let isSettingsPreview: Bool
    @State private var clipboardURL: String?
    @State private var isPresented = false

    var body: some View {
        searchBarRow
            .onAppear { isPresented = true; refreshClipboard() }
            .onDisappear { isPresented = false; clipboardURL = nil }
            .onChange(of: downloader.link) { _, value in if value.isEmpty { refreshClipboard() } }
            .onChange(of: downloader.isSearchInputEnabled) { _, _ in refreshClipboard() }
            .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
                refreshClipboard()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                refreshClipboard()
            }
    }

    private func refreshClipboard() {
        guard isPresented, !isSettingsPreview, downloader.isSearchInputEnabled, downloader.link.isEmpty else { return }
        let current = VideoDownloadRequest.validClipboardURL(read: downloader.readClipboard)
        if clipboardURL != current { clipboardURL = current }
    }

    // MARK: - Search Bar Header

    private var searchBarRow: some View {
        HStack(spacing: 8) {
            // Text input container
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                TextField(VideoDownloaderStrings.urlPlaceholder, text: $downloader.link)
                    .accessibilityIdentifier("video-downloader.url")
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .onSubmit {
                        submitLink()
                    }

                if clipboardURL != nil, downloader.link.isEmpty {
                    Button {
                        // Paste clipboard URL into text field without triggering search
                        downloader.pasteFromClipboard()
                        refreshClipboard()
                    } label: {
                        Text(VideoDownloaderStrings.pasteClipboardURL)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue, in: Capsule())
                    }
                    .accessibilityIdentifier("video-downloader.paste")
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .disabled(!downloader.isSearchInputEnabled)
            .opacity(downloader.isSearchInputEnabled ? 1 : 0.5)

            // Action Button: Clear when results are shown, Search otherwise
            if downloader.hasCurrentSearchResult {
                Button {
                    downloader.resetDownloadState()
                } label: {
                    Text(VideoDownloaderStrings.clear)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(downloader.busy)
            } else {
                Button {
                    if !downloader.isFetching {
                        submitLink()
                    }
                } label: {
                    Group {
                        if downloader.isFetching {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 20, height: 20)
                        } else {
                            Text(VideoDownloaderStrings.search)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(downloader.busy)
            }
        }
    }

    private func submitLink() {
        guard !downloader.busy else { return }
        if downloader.link.isEmpty {
            downloader.pasteFromClipboard()
            refreshClipboard()
            guard !downloader.link.isEmpty else { return }
        }
        downloader.fetchInfo()
    }
}
