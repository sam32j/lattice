// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import AppKit
import Combine
import SwiftUI

struct VideoDownloaderSearchBar: View {
    @ObservedObject var downloader: VideoDownloader
    @ObservedObject var l10n = L10n.shared
    let isSettingsPreview: Bool
    @State private var clipboardURL: String?
    @State private var isPresented = false

    var body: some View {
        searchBarRow
            .onAppear { isPresented = true; refreshClipboard() }
            .onDisappear { isPresented = false; clipboardURL = nil }
            .onChange(of: downloader.link) { _, value in
                downloader.linkChanged()
                if value.isEmpty { refreshClipboard() }
            }
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

    private enum ActionState: Equatable {
        case clear
        case cancel
        case searchClipboard
        case search(enabled: Bool)

        var title: String {
            switch self {
            case .clear: return VideoDownloaderStrings.clear
            case .cancel: return VideoDownloaderStrings.cancel
            case .searchClipboard: return VideoDownloaderStrings.searchClipboardURL
            case .search: return VideoDownloaderStrings.search
            }
        }

        var isEnabled: Bool {
            switch self {
            case .clear, .cancel, .searchClipboard: return true
            case .search(let enabled): return enabled
            }
        }
    }

    private var actionState: ActionState {
        if downloader.isFetching {
            return .cancel
        }
        if downloader.hasCurrentSearchResult || downloader.error != nil {
            return .clear
        }
        let isFieldEmpty = downloader.link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if isFieldEmpty {
            if clipboardURL != nil {
                return .searchClipboard
            }
            return .search(enabled: false)
        }
        return .search(enabled: !downloader.busy)
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

                if downloader.isFetching {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.75)
                        .frame(width: 14, height: 14)
                        .transition(.opacity)
                } else if !downloader.link.isEmpty && !downloader.hasCurrentSearchResult && downloader.error == nil {
                    Button {
                        downloader.link = ""
                        downloader.linkChanged()
                        refreshClipboard()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .disabled(!downloader.isSearchInputEnabled)
            .opacity(downloader.isSearchInputEnabled ? 1 : 0.5)

            // Dynamic Action Button (Search Clipboard URL / Search / Clear / Cancel)
            Button {
                handleAction(actionState)
            } label: {
                Text(actionState.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(actionState.isEnabled ? Color.white : Color.white.opacity(0.35))
                    .id(actionState.title)
                    .transition(.opacity.animation(.easeInOut(duration: 0.18)))
                    .padding(.horizontal, 14)
                    .frame(minWidth: 84)
                    .frame(height: 36)
                    .background(
                        actionState.isEnabled ? Color.white.opacity(0.12) : Color.white.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(actionState == .searchClipboard ? "video-downloader.paste" : (actionState == .clear ? "video-downloader.clear" : "video-downloader.search"))
            .disabled(!actionState.isEnabled || (downloader.busy && actionState != .cancel))
            .fixedSize(horizontal: true, vertical: false)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: actionState.title)
    }

    private func handleAction(_ state: ActionState) {
        guard !downloader.busy || state == .cancel else { return }
        switch state {
        case .clear:
            downloader.resetDownloadState()
        case .cancel:
            downloader.cancel()
        case .searchClipboard:
            downloader.pasteFromClipboard()
            refreshClipboard()
            guard !downloader.link.isEmpty else { return }
            downloader.fetchInfo()
        case .search(let enabled):
            guard enabled else { return }
            submitLink()
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
