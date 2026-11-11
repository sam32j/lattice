// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import Combine
import SwiftUI

struct VideoDownloaderSettings: View {
    @ObservedObject var model: VideoDownloader
    @ObservedObject var toolchain: ToolchainManager
    @ObservedObject var history: DownloadHistoryStore = .shared
    @ObservedObject var router: SettingsRouter = .shared
    @ObservedObject var sessions: VideoWebsiteSessions
    @ObservedObject var l10n = L10n.shared

    @AppStorage(DefaultsKey.videoDownloaderEnabled) var enabled = true
    @AppStorage(DefaultsKey.notchVideoDownloader) private var notchVideoDownloader = true
    @AppStorage(DefaultsKey.notchHiddenModules) private var notchHiddenModules = ""
    @State var showDownloadConfirmation = false
    @State var detectedClipboardURL: String? = nil
    @State var pasteboardChangeCount = -1
    @State var skeletonPulsing = false
    @State var isSearchHovered = false
    @State private var showsBrowserSessionPath = false
    let clipboardTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    init(model: VideoDownloader = .shared, toolchain: ToolchainManager = .shared) {
        self.model = model
        self.toolchain = toolchain
        self.sessions = model.websiteSessions
    }

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 540

            ScrollViewReader { proxy in
                ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Enablement Card
                    SettingsCard {
                        SettingsRow(symbol: "square.and.arrow.down.on.square",
                                    title: VideoDownloaderStrings.enableTitle,
                                    caption: VideoDownloaderStrings.enableSubtitle) {
                            Toggle("", isOn: $enabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .onChange(of: enabled) { oldValue, isNowEnabled in
                                    if !isNowEnabled {
                                        model.teardown()
                                        toolchain.removeTools()
                                    } else if !oldValue && isNowEnabled {
                                        model.refreshDependencies()
                                        toolchain.checkHealth()
                                        if !toolchain.dependencies.ready {
                                            showDownloadConfirmation = true
                                        }
                                    }
                                }
                        }

                        if enabled {
                            showOnDynamicIslandRow
                            browserSignInRow
                        }
                    }

                    if enabled {
                        // Toolchain Installing State
                        if case .installing(_, _, let fraction, let message) = toolchain.state {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(VideoDownloaderStrings.gettingReady)
                                        .font(.headline)
                                    Spacer()
                                    Text("\(Int(fraction * 100))%")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                ProgressView(value: fraction)
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                            )
                        } else if !toolchain.dependencies.ready {
                            if !showDownloadConfirmation {
                                // Containerized section: "Some tools are missing"
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(alignment: .center) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(VideoDownloaderStrings.missingToolsTitle)
                                                .font(.headline)
                                            Text(VideoDownloaderStrings.missingToolsBody)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        Spacer()
                                        Button(VideoDownloaderStrings.repairAction) {
                                            toolchain.install()
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.orange)
                                        .foregroundStyle(.orange)
                                    }
                                }
                                .padding(14)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                                )
                            }
                        } else if case .failed(let error) = toolchain.state {
                            // Failed State
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.red)
                                    Text(VideoDownloaderStrings.installationFailed)
                                        .font(.headline)
                                }
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                HStack {
                                    Spacer()
                                    Button(VideoDownloaderStrings.keepOff) {
                                        enabled = false
                                    }
                                    .buttonStyle(.bordered)

                                    Button(VideoDownloaderStrings.retry) {
                                        toolchain.install()
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                            .padding(16)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                            )
                        } else {
                            // Active Video Downloader Surfaces
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(VideoDownloaderStrings.downloadVideoSectionTitle)
                                        .font(.headline)
                                    Text(VideoDownloaderStrings.downloadVideoSectionSubtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                searchInput(isCompact: isCompact)
                            }

                            // Fetching Video Details Skeleton Screen
                            if model.isFetching {
                                skeletonMediaCard(isCompact: isCompact)
                            } else if let error = model.error, model.info == nil {
                                VStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.circle")
                                        .font(.system(size: 26, weight: .regular))
                                        .foregroundStyle(.secondary)

                                    let displayError: String = {
                                        if model.websiteFailure == .authentication {
                                            return model.websiteSessions.hasSession
                                                ? VideoDownloaderStrings.noAccessNotice
                                                : VideoDownloaderStrings.loginRequiredNotice
                                        }
                                        if error.contains("Command failed") || error.contains("ERROR:") {
                                            return VideoDownloaderStrings.fetchFailedNotice
                                        }
                                        return error
                                    }()

                                    Text(displayError)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                    if model.websiteFailure != nil {
                                        let sessionButtonTitle = model.websiteSessions.hasSession
                                            ? VideoDownloaderStrings.tryDifferentSessions
                                            : VideoDownloaderStrings.manageSessions
                                        Button(sessionButtonTitle) { model.showWebsiteSessions = true }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 28)
                                .padding(.horizontal, 20)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.secondary.opacity(0.10), lineWidth: 1)
                                )
                            }

                            // Media Preview Card
                            if let info = model.info, !model.isFetching {
                                mediaCard(info: info, isCompact: isCompact)
                            }

                            // RECENT Section
                            if !history.items.isEmpty {
                                recentSection
                                    .id("recentSection")
                            }
                        }
                    }
                }
                .padding(.horizontal, isCompact ? 14 : 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .onAppear {
                if router.videoDownloaderSection == "recent" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("recentSection", anchor: .top)
                        }
                        router.videoDownloaderSection = nil
                    }
                }
            }
            .onChange(of: router.videoDownloaderSection) { _, section in
                if section == "recent" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("recentSection", anchor: .top)
                        }
                        router.videoDownloaderSection = nil
                    }
                }
            }
        }
    }
        .alert(VideoDownloaderStrings.downloadRequiredTitle, isPresented: $showDownloadConfirmation) {
            Button(VideoDownloaderStrings.cancel, role: .cancel) {
                enabled = false
            }
            Button(VideoDownloaderStrings.continueAction) {
                toolchain.install()
            }
        } message: {
            Text(VideoDownloaderStrings.downloadRequiredBody)
        }
        .onChange(of: showDownloadConfirmation) { wasShowing, isNowShowing in
            if wasShowing && !isNowShowing && !toolchain.dependencies.ready && !toolchain.isInstalling {
                enabled = false
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
        .settingsExpansionAnimation(value: enabled)
        .sheet(isPresented: $model.showWebsiteSessions) {
            VideoWebsiteSessionsSheet(downloader: model)
        }
    }

    // MARK: - Subviews
 
    private var showOnDynamicIslandBinding: Binding<Bool> {
        _ = notchHiddenModules
        _ = notchVideoDownloader
        return Binding(
            get: {
                IslandDestination.videoDownloader.isShown(in: .standard)
            },
            set: { shown in
                IslandDestination.videoDownloader.setShown(shown, in: .standard)
                notchVideoDownloader = shown
                NotchService.shared.syncWithPreferences()
            }
        )
    }

    private var showOnDynamicIslandRow: some View {
        let alwaysFloating = Binding<Bool>(
            get: { !showOnDynamicIslandBinding.wrappedValue },
            set: { showOnDynamicIslandBinding.wrappedValue = !$0 }
        )
        return SettingsToggleRow(
            title: SettingsOwnershipStrings.text(.alwaysFloating, l10n.language),
            caption: SettingsOwnershipStrings.text(.alwaysFloatingCaption, l10n.language),
            isOn: alwaysFloating
        )
        .padding(.leading, settingsRowTextInset)
    }

    private var browserSignInRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 5) {
                    Text(VideoDownloaderStrings.browserSessionTitle)
                        .font(.body)

                    browserSessionStatusSpan
                }

                Text(VideoDownloaderStrings.browserSignInDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button(VideoDownloaderStrings.manage) {
                model.showWebsiteSessions = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .fixedSize()
        }
        .padding(.leading, settingsRowTextInset)
    }

    private var browserSessionStatusSpan: some View {
        let label = sessions.hasSession ? sessions.summaryText : VideoDownloaderStrings.inactive
        let fullPath: String = {
            guard let session = sessions.activeSession else { return label }
            // A saved profile can be an absolute folder or just a profile ID.
            // Default profiles (including Safari) have no stored path, so
            // resolve their real on-disk location for the hover tooltip.
            if session.profile.hasPrefix("/") { return session.profile }
            let detected = VideoWebsiteSessions.detectDefaultProfile(for: session.browser)
            if let profile = detected.profiles.first(where: { $0.id == session.profile }) {
                return profile.path
            }
            return session.profile.isEmpty ? (detected.path ?? label) : session.profile
        }()
        // Fit short names naturally and cap lengthy profile names. Only the
        // label is truncated, in the middle, so both ends remain visible.
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let measuredLabelWidth = (label as NSString).size(withAttributes: [.font: font]).width
        let chipWidth = min(CGFloat(150), ceil(measuredLabelWidth) + 22)

        return HStack(spacing: 4) {
            Circle()
                .fill(sessions.hasSession ? Color.green : Color.secondary)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(sessions.hasSession ? Color.primary : Color.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: chipWidth - 22, alignment: .leading)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2.5)
        .frame(width: chipWidth, alignment: .leading)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
        // The native .help tooltip wraps long profile identifiers at arbitrary
        // characters. A one-line popover keeps the complete path on one line;
        // exceptionally long paths can scroll horizontally instead.
        .onHover { showsBrowserSessionPath = $0 }
        .popover(isPresented: $showsBrowserSessionPath, arrowEdge: .bottom) {
            let pathFont = NSFont.systemFont(ofSize: 11)
            let pathWidth = ceil((fullPath as NSString).size(withAttributes: [.font: pathFont]).width)
            let screenWidth = (NSScreen.main?.visibleFrame.width ?? 1024) - 80
            let tooltipWidth = min(max(180, pathWidth + 20), max(180, screenWidth))
            ScrollView(.horizontal, showsIndicators: false) {
                Text(fullPath)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 6)
            }
            .frame(width: tooltipWidth, height: 22)
            .padding(6)
        }
    }
}
