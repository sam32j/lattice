// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
/// Settings for the screen recorder: how a recording starts, what it captures
/// and where the file lands.
struct ScreenRecorderSettings: View {
    @ObservedObject var l10n = L10n.shared
    @ObservedObject private var sharing = RecordingShareService.shared
    @AppStorage(DefaultsKey.screenRecorderEnabled) var screenRecorderEnabled = true
    @AppStorage(DefaultsKey.recorderQuality) private var qualityRaw =
        RecorderSupport.Quality.balanced.rawValue
    @AppStorage(DefaultsKey.recorderExportFrameRate) private var exportFrameRate = 60
    @AppStorage(DefaultsKey.recorderImmediateStartAfterSelection) private var immediateStart = true
    @AppStorage(DefaultsKey.recorderPlaySound) private var playRecordSound = true
    @AppStorage(DefaultsKey.recorderCopyAfterRecording) private var copyAfterRecording = false
    @AppStorage(DefaultsKey.recorderSaveAutomatically) private var saveAutomatically = false
    @AppStorage(DefaultsKey.recorderAddToFileCache) private var addToFileCache = true
    @AppStorage(DefaultsKey.shelfEnabled) private var shelfEnabled = false
    @AppStorage(AppFeature.shelf.availabilityKey) private var shelfAvailable = false
    @AppStorage(DefaultsKey.recorderOpenEditor) private var opensEditor = true
    @AppStorage(DefaultsKey.recorderGIFSize) private var gifSizeRaw =
        RecorderSupport.GIFSize.medium.rawValue
    @AppStorage(DefaultsKey.recorderGIFFrameRate) private var gifFrameRate = 12
    @AppStorage(DefaultsKey.recorderSharingEnabled) private var sharingEnabled = true
    @AppStorage(DefaultsKey.recentRecordingLimit) private var recentRecordingLimit = 0
    @State private var showingSharedLinks = false
    @State private var showingSharePrivacy = false
    @State private var showingRecordingDefaults = false

    var strings: RecorderFeatureStrings {
        FeatureStrings.recorder(l10n.language)
    }

    private var shareStrings: RecorderShareStrings {
        FeatureStrings.recorderShare(l10n.language)
    }

    private var screenshotStrings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    private var workflow: CaptureWorkflowStrings { .localized(l10n.language) }

    private func copy(_ key: CaptureOptionsStrings.Key) -> String {
        CaptureOptionsStrings.text(key, l10n.language)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    recordingCard
                        .settingsSectionAnchor(.screenRecorder, cornerRadius: 16)
                    afterRecordingCard
                    exportCard
                }
                .disabled(!screenRecorderInstalled)
                .opacity(screenRecorderInstalled ? 1 : 0.55)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .sheet(isPresented: $showingRecordingDefaults) {
            RecorderDefaultBehaviorSheet()
        }
        .onChange(of: recentRecordingLimit) { _, _ in
            RecentCaptureService.shared.reload()
        }
    }

    // MARK: - Master Header & Shortcuts Card


    // MARK: - Recording behavior

    private var recordingCard: some View {
        SettingsCard(title: copy(.recordingBehavior)) {
            VStack(alignment: .leading, spacing: 14) {
                SettingsToggleRow(title: copy(.playStartSound), isOn: $playRecordSound)
                SettingsToggleRow(title: workflow.immediate, isOn: $immediateStart)

                SettingsControlRow(title: copy(.keepRecordings)) {
                    Picker(copy(.keepRecordings), selection: $recentRecordingLimit) {
                        Text(workflow.unlimited).tag(0)
                        Text("5").tag(5)
                        Text("10").tag(10)
                        Text("20").tag(20)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                    .onChange(of: recentRecordingLimit) { _, _ in
                        RecentCaptureService.shared.reload()
                    }
                }

                SettingsControlRow(title: copy(.defaultRecordingBehavior)) {
                    Button(CaptureInterfaceStrings.localized(l10n.language).manage) { showingRecordingDefaults = true }
                        .font(.system(size: 14, weight: .semibold))
                        .controlSize(.regular)
                }
            }
        }
    }

    // MARK: - After recording

    private var afterRecordingCard: some View {
        SettingsCard(title: copy(.afterRecording)) {
            VStack(alignment: .leading, spacing: 14) {
                SettingsToggleRow(title: copy(.copyRecording), isOn: $copyAfterRecording)
                SettingsToggleRow(title: copy(.saveRecording), isOn: $saveAutomatically)
                SettingsToggleRow(title: copy(.addToFileCache), isOn: addToShelfBinding)
                    .disabled(!shelfIsOn)
                SettingsToggleRow(title: copy(.openEditorWithRecording), isOn: $opensEditor)
            }
        }
    }

    private var shelfIsOn: Bool { shelfEnabled && shelfAvailable }

    private var addToShelfBinding: Binding<Bool> {
        Binding(get: { addToFileCache && shelfIsOn }, set: { addToFileCache = $0 })
    }

    // MARK: - Video export & format

    private var exportCard: some View {
        SettingsCard(title: copy(.videoExportFormat)) {
            VStack(alignment: .leading, spacing: 14) {
                SettingsControlRow(title: copy(.exportQuality)) {
                    Picker(copy(.exportQuality), selection: $qualityRaw) {
                        Text(copy(.low)).tag(RecorderSupport.Quality.small.rawValue)
                        Text(copy(.medium)).tag(RecorderSupport.Quality.balanced.rawValue)
                        Text(copy(.raw)).tag(RecorderSupport.Quality.high.rawValue)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                }

                SettingsControlRow(title: copy(.exportFrameRate)) {
                    Picker(copy(.exportFrameRate), selection: $exportFrameRate) {
                        Text(String(format: strings.frameRateFormat, 30)).tag(30)
                        Text(String(format: strings.frameRateFormat, 60)).tag(60)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                }

                Divider()
                Text(copy(.gifExportFormat)).font(.headline)

                SettingsControlRow(title: copy(.gifQuality)) {
                    Picker(copy(.gifQuality), selection: $gifSizeRaw) {
                        Text(copy(.low)).tag(RecorderSupport.GIFSize.small.rawValue)
                        Text(copy(.standard)).tag(RecorderSupport.GIFSize.medium.rawValue)
                        Text(copy(.best)).tag(RecorderSupport.GIFSize.large.rawValue)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                }

                SettingsControlRow(title: copy(.gifFrameRate)) {
                    Picker(copy(.gifFrameRate), selection: $gifFrameRate) {
                        Text(String(format: strings.frameRateFormat, 8)).tag(8)
                        Text(String(format: strings.frameRateFormat, 12)).tag(12)
                        Text(String(format: strings.frameRateFormat, 15)).tag(15)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                }
            }
        }
    }

    // MARK: - Sharing

    private var sharingCard: some View {
        SettingsCard(title: screenshotStrings.shareSectionTitle, headerAccessory: {
            Button {
                showingSharePrivacy = true
            } label: {
                Label(screenshotStrings.sharePrivacyButton, systemImage: "hand.raised")
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }) {
            VStack(alignment: .leading, spacing: 14) {
                SettingsToggleRow(title: screenshotStrings.shareEnabledToggle,
                                  caption: sharingEnabled ? shareStrings.caption : nil,
                                  isOn: $sharingEnabled)

                if sharingEnabled {
                    if !sharing.records.isEmpty {
                        Button {
                            showingSharedLinks = true
                        } label: {
                            HStack {
                                Text(screenshotStrings.sharedLinksTitle)
                                    .font(.body)
                                Spacer()
                                Text("\(sharing.records.count)")
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }


}

private struct RecorderSharePrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var l10n = L10n.shared

    private var strings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    private var shareStrings: RecorderShareStrings {
        FeatureStrings.recorderShare(l10n.language)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(strings.sharePrivacyTitle, systemImage: "hand.raised")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(strings.done) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    privacyParagraph(symbol: "video", text: shareStrings.privacyData)
                    privacyParagraph(symbol: "externaldrive", text: shareStrings.privacyStorage)
                    privacyParagraph(symbol: "person.2", text: shareStrings.privacyAccess)
                }
                .padding(20)
            }
        }
        .frame(width: 560, height: 390)
    }

    private func privacyParagraph(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct RecorderSharedLinksView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var sharing = RecordingShareService.shared
    @State private var deletingID: String?
    @State private var showingDeleteError = false

    private var strings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(strings.sharedLinksTitle)
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(strings.done) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(18)

            Divider()

            if sharing.records.isEmpty {
                ContentUnavailableView(strings.sharedLinksEmpty,
                                       systemImage: "link.badge.plus")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(sharing.records) { record in
                    linkRow(record)
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 560, height: 360)
        .onAppear { sharing.refresh() }
        .alert(strings.deleteFailedHUD, isPresented: $showingDeleteError) {
            Button(strings.done, role: .cancel) {}
        }
    }

    private func linkRow(_ record: RecordingShareRecord) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "link")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(record.url.absoluteString)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                HStack(spacing: 4) {
                    Text(strings.expiresLabel)
                    Text(record.expiresAt, style: .relative)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button {
                sharing.copy(record.url)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .screenshotSafeHelp(strings.copyLink)
            Button {
                NSWorkspace.shared.open(record.url)
            } label: {
                Image(systemName: "arrow.up.forward.app")
            }
            .buttonStyle(.borderless)
            .screenshotSafeHelp(strings.openLink)
            Button(role: .destructive) {
                delete(record)
            } label: {
                if deletingID == record.id {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "trash")
                }
            }
            .buttonStyle(.borderless)
            .disabled(deletingID != nil)
            .screenshotSafeHelp(strings.deleteLink)
        }
        .padding(.vertical, 5)
    }

    private func delete(_ record: RecordingShareRecord) {
        deletingID = record.id
        Task { @MainActor in
            do {
                try await sharing.delete(record)
                QuickToolHUD.show(icon: "link", message: strings.linkDeletedHUD)
            } catch {
                showingDeleteError = true
            }
            deletingID = nil
        }
    }
}

/// These are the initial values for each new recording. The selection toolbar
/// may still change camera, keys and sound for just that recording.
private struct RecorderDefaultBehaviorSheet: View {
    @ObservedObject private var l10n = L10n.shared

    private func copy(_ key: CaptureOptionsStrings.Key) -> String {
        CaptureOptionsStrings.text(key, l10n.language)
    }
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.recorderSystemAudio) private var systemAudio = true
    @AppStorage(DefaultsKey.recorderMicrophone) private var microphone = false
    @AppStorage(DefaultsKey.recorderDefaultCamera) private var camera = false
    @AppStorage(DefaultsKey.recorderDefaultKeyboardEvents) private var keyboardEvents = false
    @AppStorage(DefaultsKey.recorderAutomaticZoom) private var automaticZoom = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text(copy(.defaultRecordingBehavior))
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button(FeatureStrings.screenshot(l10n.language).done) { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .fixedSize()
            }
            Divider()

            behaviorRow(copy(.recordSystemSound), symbol: "speaker.wave.2.fill") {
                Toggle(copy(.recordSystemSound), isOn: $systemAudio)
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
            behaviorRow(copy(.recordMicrophone), symbol: "mic.fill") {
                PermissionGatedToggle(copy(.recordMicrophone), isOn: $microphone,
                                      requiring: [.microphone])
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    .onChange(of: microphone) { _, enabled in
                        if enabled, permissions.microphone == .undetermined {
                            permissions.requestMicrophone()
                        }
                    }
            }
            behaviorRow(copy(.recordCamera), symbol: "video.fill") {
                Toggle(copy(.recordCamera), isOn: $camera)
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
            behaviorRow(copy(.recordKeyboardEvents), symbol: "keyboard") {
                Toggle(copy(.recordKeyboardEvents), isOn: $keyboardEvents)
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
            behaviorRow(copy(.addZoomAutomatically), symbol: "plus.magnifyingglass") {
                Toggle(copy(.addZoomAutomatically), isOn: $automaticZoom)
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 420)
    }

    /// Match the application's primary accent-colored icon tiles while
    /// leaving enough room for two-line labels in the compact sheet.
    private func behaviorRow<Control: View>(
        _ title: String, symbol: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.accentColor,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            control()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
