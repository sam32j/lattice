// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import SwiftUI

struct VideoWebsiteSessionsSheet: View {
    @ObservedObject var downloader: VideoDownloader
    @ObservedObject private var sessions: VideoWebsiteSessions
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedBrowser: VideoSessionBrowser? = nil
    @State private var selectedProfile: String = ""
    @State private var hasSafariFDA: Bool = true
    @State private var detectionResult: BrowserProfileDetection?
    @State private var showingDisconnectConfirmation: Bool = false

    init(downloader: VideoDownloader) {
        self.downloader = downloader
        self.sessions = downloader.websiteSessions
    }

    private var isBrowserNotFound: Bool {
        guard let browser = selectedBrowser, browser != .safari, browser != .chromium else {
            return false
        }
        return detectionResult?.isFound == false
    }

    private var isSaveDisabled: Bool {
        guard let browser = selectedBrowser else { return false }
        if browser == .chromium {
            return selectedProfile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if browser == .safari {
            return false
        }
        if let detection = detectionResult, !detection.isFound {
            return true
        }
        return false
    }

    private var isDisconnectShown: Bool {
        guard sessions.hasSession else { return false }
        if selectedBrowser == nil {
            return true
        }
        if selectedBrowser == .chromium && !selectedProfile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return false
    }

    private var selectedBrowserTitle: String {
        if let browser = selectedBrowser {
            return browser.title
        }
        return VideoDownloaderStrings.noneAnonymous
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Title
            Text(VideoDownloaderStrings.browserSessionTitle)
                .font(.headline)

            // Browser Section
            VStack(alignment: .leading, spacing: 6) {
                Text(VideoDownloaderStrings.browserSectionLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                browserDropdown
            }

            // Item Row Section (optional)
            itemRowSection

            // Footnote
            footnoteView

            Spacer(minLength: 4)

            Divider()

            // Footer
            HStack(spacing: 10) {
                if isDisconnectShown {
                    Button(VideoDownloaderStrings.disconnect) {
                        showingDisconnectConfirmation = true
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }

                Spacer()

                Button(VideoDownloaderStrings.cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(VideoDownloaderStrings.save) {
                    saveAndDismiss(retry: canRetryCurrentLink)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaveDisabled)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
        .disabled(downloader.busy)
        .onAppear {
            loadCurrentSession()
        }
        .onChange(of: selectedBrowser) { _, newBrowser in
            handleBrowserChanged(newBrowser)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkSafariFDA()
            if let browser = selectedBrowser {
                detectionResult = VideoWebsiteSessions.detectDefaultProfile(for: browser)
            }
        }
        .confirmationDialog(
            VideoDownloaderStrings.disconnectConfirmTitle,
            isPresented: $showingDisconnectConfirmation,
            titleVisibility: .visible
        ) {
            Button(VideoDownloaderStrings.disconnect, role: .destructive) {
                disconnect()
            }
            Button(VideoDownloaderStrings.cancel, role: .cancel) {}
        } message: {
            Text(VideoDownloaderStrings.disconnectConfirmMessage)
        }
    }

    // MARK: - Browser Dropdown

    private var browserDropdown: some View {
        Menu {
            Button {
                selectedBrowser = nil
            } label: {
                if selectedBrowser == nil {
                    Label(VideoDownloaderStrings.noneAnonymous, systemImage: "checkmark")
                } else {
                    Text(VideoDownloaderStrings.noneAnonymous)
                }
            }

            Divider()

            ForEach(VideoSessionBrowser.standardBrowsers) { browser in
                Button {
                    selectedBrowser = browser
                } label: {
                    if selectedBrowser == browser {
                        Label(browser.title, systemImage: "checkmark")
                    } else {
                        Text(browser.title)
                    }
                }
            }

            Divider()

            Button {
                selectedBrowser = .chromium
            } label: {
                if selectedBrowser == .chromium {
                    Label(VideoSessionBrowser.chromium.title, systemImage: "checkmark")
                } else {
                    Text(VideoSessionBrowser.chromium.title)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedBrowserTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isBrowserNotFound ? Color.orange : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Browser: \(selectedBrowserTitle)")
    }

    // MARK: - Item Row Section

    @ViewBuilder
    private var itemRowSection: some View {
        if let browser = selectedBrowser {
            if browser == .chromium {
                VStack(alignment: .leading, spacing: 6) {
                    Text(VideoDownloaderStrings.profileFolderSectionLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    chromiumItemRow
                }
            } else if browser == .safari {
                safariItemRow
            } else {
                namedBrowserItemRow(browser)
            }
        }
    }

    @ViewBuilder
    private var safariItemRow: some View {
        if hasSafariFDA {
            ItemRowView(
                icon: AnyView(
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 17))
                ),
                title: VideoDownloaderStrings.readyTitle(browser: "Safari"),
                description: VideoDownloaderStrings.readyDescription(browser: "Safari"),
                isWarning: false,
                action: nil
            )
        } else {
            ItemRowView(
                icon: AnyView(
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 16))
                ),
                title: VideoDownloaderStrings.allowFullDiskAccess,
                description: VideoDownloaderStrings.allowFullDiskAccessDescription(browser: "Safari"),
                isWarning: true,
                action: AnyView(
                    ItemRowButton(title: VideoDownloaderStrings.openSystemSettings) {
                        VideoWebsiteSessions.openFullDiskAccessSettings()
                    }
                )
            )
        }
    }

    @ViewBuilder
    private var chromiumItemRow: some View {
        if selectedProfile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ItemRowView(
                icon: AnyView(
                    Image(systemName: "folder")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                ),
                title: VideoDownloaderStrings.chooseProfileFolder,
                description: VideoDownloaderStrings.chooseProfileFolderDescription,
                isWarning: false,
                action: AnyView(
                    ItemRowButton(title: VideoDownloaderStrings.chooseFolderAction) {
                        pickProfileFolder()
                    }
                )
            )
        } else {
            ItemRowView(
                icon: AnyView(
                    Image(systemName: "folder.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)
                ),
                title: displayFolderName(selectedProfile),
                description: displayPath(selectedProfile),
                isMonospacedDescription: true,
                isWarning: false,
                tooltip: selectedProfile,
                action: AnyView(
                    ItemRowButton(title: VideoDownloaderStrings.changeFolderAction) {
                        pickProfileFolder()
                    }
                )
            )
        }
    }

    @ViewBuilder
    private func namedBrowserItemRow(_ browser: VideoSessionBrowser) -> some View {
        if let detection = detectionResult, detection.isFound {
            if detection.profiles.count > 1 {
                ItemRowView(
                    icon: AnyView(
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 17))
                    ),
                    title: VideoDownloaderStrings.readyTitle(browser: browser.title),
                    description: VideoDownloaderStrings.readyDescription(browser: browser.title),
                    isWarning: false,
                    action: AnyView(
                        Menu {
                            ForEach(detection.profiles) { p in
                                Button(p.name) {
                                    selectedProfile = (p.id == "Default" ? "" : p.id)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(currentProfileDisplayName(detection: detection))
                                    .lineLimit(1)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .medium))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    )
                )
            } else {
                ItemRowView(
                    icon: AnyView(
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 17))
                    ),
                    title: VideoDownloaderStrings.readyTitle(browser: browser.title),
                    description: VideoDownloaderStrings.readyDescription(browser: browser.title),
                    isWarning: false,
                    action: nil
                )
            }
        } else {
            ItemRowView(
                icon: AnyView(
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(.orange)
                ),
                title: VideoDownloaderStrings.browserNotFoundTitle(browser: browser.title),
                description: VideoDownloaderStrings.browserNotFoundDescription(browser: browser.title),
                isWarning: true,
                action: nil
            )
        }
    }

    // MARK: - Footnote

    private var footnoteView: some View {
        HStack(spacing: 6) {
            Image(systemName: selectedBrowser == nil ? "shield.slash" : "lock")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(
                selectedBrowser == nil
                    ? VideoDownloaderStrings.footnoteAnonymous
                    : VideoDownloaderStrings.footnoteSignedIn
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Actions & Helpers

    private var canRetryCurrentLink: Bool {
        (try? VideoDownloadRequest.validatedURL(downloader.link)) != nil
    }

    private func loadCurrentSession() {
        if let session = sessions.activeSession {
            selectedBrowser = session.browser
            selectedProfile = session.profile
        } else {
            selectedBrowser = nil
            selectedProfile = ""
        }
        checkSafariFDA()
        if let browser = selectedBrowser {
            detectionResult = VideoWebsiteSessions.detectDefaultProfile(for: browser)
        }
    }

    private func handleBrowserChanged(_ newBrowser: VideoSessionBrowser?) {
        checkSafariFDA()
        if let browser = newBrowser {
            detectionResult = VideoWebsiteSessions.detectDefaultProfile(for: browser)
            if browser != sessions.activeSession?.browser {
                selectedProfile = ""
            }
        } else {
            selectedProfile = ""
            detectionResult = nil
        }
        announceStatusIfNeeded()
    }

    private func announceStatusIfNeeded() {
        let title: String
        if let browser = selectedBrowser {
            if browser == .chromium {
                title = selectedProfile.isEmpty ? VideoDownloaderStrings.chooseProfileFolder : displayFolderName(selectedProfile)
            } else if browser == .safari {
                title = hasSafariFDA ? VideoDownloaderStrings.readyTitle(browser: "Safari") : VideoDownloaderStrings.allowFullDiskAccess
            } else if let detection = detectionResult, !detection.isFound {
                title = VideoDownloaderStrings.browserNotFoundTitle(browser: browser.title)
            } else {
                title = VideoDownloaderStrings.readyTitle(browser: browser.title)
            }
        } else {
            title = VideoDownloaderStrings.noneAnonymous
        }
        AccessibilityNotification.Announcement(title).post()
    }

    private func checkSafariFDA() {
        hasSafariFDA = VideoWebsiteSessions.isSafariFullDiskAccessGranted
    }

    private func pickProfileFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = VideoDownloaderStrings.selectProfilePanelPrompt
        panel.message = VideoDownloaderStrings.selectProfilePanelMessage

        let appSupport = ("~/Library/Application Support" as NSString).expandingTildeInPath
        panel.directoryURL = URL(fileURLWithPath: appSupport)

        if panel.runModal() == .OK, let url = panel.url {
            selectedProfile = url.path
            announceStatusIfNeeded()
        }
    }

    private func saveAndDismiss(retry: Bool) {
        if let browser = selectedBrowser {
            sessions.saveSession(browser: browser, profile: selectedProfile)
        } else {
            sessions.clearSession()
        }
        downloader.websiteSessionChanged()
        dismiss()
        if retry {
            downloader.fetchInfo()
        }
    }

    private func disconnect() {
        selectedBrowser = nil
        selectedProfile = ""
        sessions.clearSession()
        downloader.websiteSessionChanged()
    }

    private func displayFolderName(_ path: String) -> String {
        let name = (path as NSString).lastPathComponent
        return name.isEmpty ? "Profile" : name
    }

    private func displayPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func currentProfileDisplayName(detection: BrowserProfileDetection) -> String {
        if selectedProfile.isEmpty {
            return detection.profiles.first(where: { $0.id == "Default" })?.name ?? "Default"
        }
        return detection.profiles.first(where: { $0.id == selectedProfile })?.name ?? selectedProfile
    }
}

// MARK: - Supporting Subviews

private struct ItemRowView: View {
    let icon: AnyView
    let title: String
    let description: String
    var isMonospacedDescription: Bool = false
    var isWarning: Bool = false
    var tooltip: String? = nil
    var action: AnyView? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            icon
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isWarning ? Color.orange : Color.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if isMonospacedDescription {
                    Text(description)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(tooltip ?? "")

            if let action = action {
                action
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isWarning ? Color.orange.opacity(0.35) : Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title). \(description)")
    }
}

private struct ItemRowButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .controlSize(.small)
    }
}
