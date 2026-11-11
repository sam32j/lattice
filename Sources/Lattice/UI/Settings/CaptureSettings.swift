// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Overview for screenshots and screen recordings. Options pages are native
/// Settings destinations so the window toolbar owns Back/Forward navigation.
struct CaptureSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var router = SettingsRouter.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var screenshotSharing = ScreenshotShareService.shared
    @ObservedObject private var recordingSharing = RecordingShareService.shared

    @AppStorage(DefaultsKey.screenshotEnabled) private var screenshotEnabled = true
    @AppStorage(DefaultsKey.screenRecorderEnabled) private var recorderEnabled = true
    @AppStorage(DefaultsKey.screenshotPreviewTakesFocus) private var previewTakesFocus = true
    @AppStorage(DefaultsKey.capturePreviewCloseAfter) private var previewCloseAfter = CapturePreviewClosePolicy.fiveSeconds.rawValue
    @AppStorage(DefaultsKey.capturePresentationDestination) private var presentationDestination = "automatic"
    @AppStorage(DefaultsKey.notchEnabled) private var islandEnabled = false
    @AppStorage(DefaultsKey.screenshotSharingEnabled) private var screenshotLinksEnabled = true
    @AppStorage(DefaultsKey.recorderSharingEnabled) private var recordingLinksEnabled = true

    @State private var showingQuickLinks = false
    @State private var showingSharePrivacy = false

    /// Sidebar title shared with the directory; keep it short at narrow widths.
    static func title(for language: AppLanguage) -> String {
        switch language {
        case .enUS: "Screen Captures"
        case .ptBR: "Capturas de tela"
        case .tr: "Ekran Yakalamaları"
        case .ru: "Снимки и записи экрана"
        case .es: "Capturas de pantalla"
        case .sk: "Snímky obrazovky"
        case .de: "Bildschirmaufnahmen"
        case .fr: "Captures d’écran"
        case .it: "Acquisizioni schermo"
        case .ja: "スクリーンキャプチャ"
        case .ko: "화면 캡처"
        case .uk: "Знімки й записи екрана"
        case .zhHans: "屏幕捕获"
        case .zhTW, .zhHK: "螢幕擷取"
        }
    }

    private var screenshotStrings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    private var recorderStrings: RecorderFeatureStrings {
        FeatureStrings.recorder(l10n.language)
    }

    private var workflow: CaptureWorkflowStrings { .localized(l10n.language) }
    private var copy: CaptureInterfaceStrings { .localized(l10n.language) }

    var body: some View {
        overview
            .onAppear {
                screenshotSharing.refresh()
                recordingSharing.refresh()
                // Preserve the meaning of saved selections from the earlier
                // 15/60-second picker before applying the revised 5/15 options.
                let migrated = CapturePreviewClosePolicy.migratedRawValue(previewCloseAfter)
                if migrated != previewCloseAfter { previewCloseAfter = migrated }
                // A preference created before autofocus was disabled must not
                // point at the conditionally unavailable focus-loss choice.
                if !previewTakesFocus && previewCloseAfter == CapturePreviewClosePolicy.focusLost.rawValue {
                    previewCloseAfter = CapturePreviewClosePolicy.fiveSeconds.rawValue
                }
            }
            .sheet(isPresented: $showingQuickLinks) { CaptureQuickLinksManageView() }
            .sheet(isPresented: $showingSharePrivacy) { CaptureSharePrivacyView() }
    }

    private var overview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                screenshotCard
                    .settingsSectionAnchor(.screenshot, cornerRadius: 16)
                recordingCard
                if screenshotEnabled || recorderEnabled {
                    VStack(alignment: .leading, spacing: 20) {
                        CaptureSaveSettingsCard()
                        SettingsCard(title: copy.previewRecent) {
                        VStack(alignment: .leading, spacing: 14) {
                            if islandEnabled {
                                SettingsControlRow(title: copy.openAt) {
                                    CapturePresentationPicker()
                                        .labelsHidden()
                                        .fixedSize()
                                }
                            }
                            if !islandEnabled || presentationDestination == CapturePresentationRouting.Preference.floatingWindow.rawValue {
                                SettingsControlRow(title: screenshotStrings.previewPositionLabel) {
                                    CapturePreviewPositionPicker()
                                        .labelsHidden()
                                        .fixedSize()
                                }
                            }
                            SettingsToggleRow(title: screenshotStrings.previewFocusToggle,
                                              isOn: $previewTakesFocus)
                                .onChange(of: previewTakesFocus) { _, takesFocus in
                                    if !takesFocus && previewCloseAfter == CapturePreviewClosePolicy.focusLost.rawValue {
                                        previewCloseAfter = CapturePreviewClosePolicy.fiveSeconds.rawValue
                                    }
                                }
                            SettingsControlRow(title: copy.closeAfter) {
                                Picker(copy.closeAfter, selection: $previewCloseAfter) {
                                    if previewTakesFocus {
                                        Text(copy.focusLost).tag(CapturePreviewClosePolicy.focusLost.rawValue)
                                    }
                                    Text(copy.fiveSeconds).tag(CapturePreviewClosePolicy.fiveSeconds.rawValue)
                                    Text(copy.fifteenSeconds).tag(CapturePreviewClosePolicy.fifteenSeconds.rawValue)
                                    Text(copy.untilClose).tag(CapturePreviewClosePolicy.untilClose.rawValue)
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .fixedSize()
                            }
                            CompactShortcutPreferenceRow(
                                title: FeatureStrings.recentCapturesShortcutTitle(l10n.language),
                                role: .recentCaptures,
                                enabledKey: DefaultsKey.recentCapturesShortcutEnabled
                            ) {
                                RecentCaptureService.shared.syncWithPreferences()
                            }
                        }
                        }
                        sharingCard
                    }
                    // Fade in the space *below* the master cards. A top-edge
                    // move transition painted these sections over Recording.
                    .transition(.opacity)
                    .clipped()
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .settingsExpansionAnimation(value: [screenshotEnabled, recorderEnabled,
                                           linksBinding.wrappedValue, islandEnabled,
                                           presentationDestination == CapturePresentationRouting.Preference.floatingWindow.rawValue])
    }

    private var screenshotCard: some View {
        SettingsCard(title: screenshotStrings.pageTitle, headerAccessory: {
            PermissionGatedToggle(l10n.s.screenshotEnable, isOn: Binding(
                get: { features.isAvailable(.screenshot) },
                set: { enabled in
                    screenshotEnabled = enabled
                    features.setAvailable([.screenshot], enabled)
                    ScreenshotService.shared.syncWithPreferences()
                    ScreenTextService.shared.syncWithPreferences()
                    ScreenCaptureService.shared.syncWithPreferences()
                }
            ), requiring: [.screenRecording], feature: .screenshot)
                .labelsHidden()
                .toggleStyle(.switch)
                .help(l10n.s.screenshotEnable)
        }) {
            if screenshotEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    CompactShortcutPreferenceRow(
                        title: screenshotStrings.pageTitle,
                        role: .screenshot,
                        enabledKey: DefaultsKey.screenshotShortcutEnabled
                    ) {
                        ScreenCaptureService.shared.syncWithPreferences()
                        ScreenshotService.shared.syncWithPreferences()
                    }
                    CompactShortcutPreferenceRow(
                        title: CaptureOptionsStrings.text(.screenshotFullScreen, l10n.language),
                        role: .screenshotFullScreen,
                        enabledKey: DefaultsKey.screenshotFullScreenShortcutEnabled
                    ) {
                        ScreenshotService.shared.syncWithPreferences()
                    }
                    optionRow(copy.screenshotOptions,
                              destination: FeatureSettingsDestination(.captureScreenshotOptions))
                }
            }
        }
    }

    private var recordingCard: some View {
        SettingsCard(title: recorderStrings.pageTitle, headerAccessory: {
            PermissionGatedToggle(l10n.s.screenRecorderEnable, isOn: Binding(
                get: { features.isAvailable(.screenRecorder) },
                set: { enabled in
                    recorderEnabled = enabled
                    features.setAvailable([.screenRecorder], enabled)
                    ScreenCaptureService.shared.syncWithPreferences()
                    ScreenRecorderService.shared.syncWithPreferences()
                }
            ), requiring: [.screenRecording], feature: .screenRecorder)
                .labelsHidden()
                .toggleStyle(.switch)
                .help(l10n.s.screenRecorderEnable)
        }) {
            if recorderEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    CompactShortcutPreferenceRow(
                        title: recorderStrings.pageTitle,
                        role: .screenRecorder,
                        enabledKey: DefaultsKey.recorderShortcutEnabled
                    ) {
                        ScreenCaptureService.shared.syncWithPreferences()
                        ScreenRecorderService.shared.syncWithPreferences()
                    }
                    optionRow(copy.recordingOptions,
                              destination: FeatureSettingsDestination(.screenRecorder))
                }
            }
        }
    }

    private func optionRow(_ title: String,
                           destination: FeatureSettingsDestination) -> some View {
        Button {
            router.request(destination)
        } label: {
            HStack(spacing: 12) {
                Text(title).foregroundStyle(.primary)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var linksBinding: Binding<Bool> {
        Binding {
            screenshotLinksEnabled && recordingLinksEnabled
        } set: { enabled in
            screenshotLinksEnabled = enabled
            recordingLinksEnabled = enabled
            ScreenshotService.shared.syncWithPreferences()
        }
    }

    private var activeCreatedLinksCount: Int {
        let now = Date()
        return screenshotSharing.records.filter { $0.expiresAt > now }.count
            + recordingSharing.records.filter { $0.expiresAt > now }.count
    }

    private var createdLinksRow: some View {
        let count = activeCreatedLinksCount
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(copy.createdLinks)
                        .font(.body)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(count > 0 ? Color.green : Color.gray)
                            .frame(width: 7, height: 7)
                            .accessibilityHidden(true)
                        Text(CaptureOptionsStrings.activeLinksLabel(count, l10n.language))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                Text(copy.manageHelp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button(copy.manage) { showingQuickLinks = true }
                .font(.system(size: 14, weight: .semibold))
                .controlSize(.regular)
        }
    }

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
            VStack(alignment: .leading, spacing: 12) {
                SettingsToggleRow(title: screenshotStrings.shareEnabledToggle,
                                  caption: copy.linksExpire,
                                  isOn: linksBinding)
                if screenshotLinksEnabled != recordingLinksEnabled {
                    Text(copy.mixedLinkSettings)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                // Previously the management row disappeared when link creation
                // was disabled, even though earlier links remained active.
                createdLinksRow
            }
        }
    }
}


/// A single disclaimer for the two upload types, reusing the original
/// screenshot and recording privacy copy from the pre-merge settings pages.
/// Unified privacy disclosure for media links, with the same layout as the
/// About > Changelog sheet: content above, prominent Done at the bottom.
private struct CaptureSharePrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var l10n = L10n.shared

    private var items: [(symbol: String, text: String)] {
        let copy = CaptureInterfaceStrings.localized(l10n.language)
        return [
            ("photo.on.rectangle.angled", copy.privacy1),
            ("externaldrive", copy.privacy2),
            ("person.2", copy.privacy3)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(FeatureStrings.screenshot(l10n.language).sharePrivacyTitle)
                .font(.title2.bold())
                .padding(.horizontal, 24)
                .padding(.top, 20)
            VStack(alignment: .leading, spacing: 20) {
                ForEach(items.indices, id: \.self) { index in
                    privacyParagraph(symbol: items[index].symbol, text: items[index].text)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            Divider()
            HStack {
                Spacer()
                Button(l10n.s.doneButton) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(width: 500, height: 420, alignment: .topLeading)
    }

    private func privacyParagraph(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 16, alignment: .center)
                .padding(.top, 2) // Align the symbol to the first line's cap height.
            Text(text)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// One management surface for images and video, including a useful empty
/// state. The services keep their own deletion tokens and expiry cleanup.
private struct CaptureQuickLinksManageView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var screenshots = ScreenshotShareService.shared
    @ObservedObject private var recordings = RecordingShareService.shared
    @State private var deletingID: String?
    @State private var showingDeleteError = false

    private enum Link: Identifiable {
        case image(ScreenshotShareRecord)
        case video(RecordingShareRecord)

        var id: String {
            switch self {
            case .image(let record): return "image:" + record.id
            case .video(let record): return "video:" + record.id
            }
        }
        var url: URL {
            switch self {
            case .image(let record): return record.url
            case .video(let record): return record.url
            }
        }
        var expiresAt: Date {
            switch self {
            case .image(let record): return record.expiresAt
            case .video(let record): return record.expiresAt
            }
        }
        var icon: String {
            switch self {
            case .image: return "photo"
            case .video: return "video"
            }
        }
        var label: String {
            switch self {
            case .image: return CaptureInterfaceStrings.localized(L10n.shared.language).image
            case .video: return CaptureInterfaceStrings.localized(L10n.shared.language).recording
            }
        }
    }

    private var links: [Link] {
        (screenshots.records.map(Link.image) + recordings.records.map(Link.video))
            .sorted { $0.expiresAt < $1.expiresAt }
    }

    private var strings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    private var copy: CaptureInterfaceStrings { .localized(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(copy.createdLinks)
                .font(.title2.bold())
                .padding(.horizontal, 24)
                .padding(.top, 20)
            if links.isEmpty {
                ContentUnavailableView(copy.emptyLinks, systemImage: "link",
                                       description: Text(copy.emptyDescription))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(links) { link in
                    linkRow(link)
                }
                .listStyle(.inset)
            }
            Divider()
            HStack {
                Spacer()
                Button(l10n.s.doneButton) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(width: 500, height: 480, alignment: .topLeading)
        .onAppear {
            screenshots.refresh()
            recordings.refresh()
        }
        .alert(strings.deleteFailedHUD, isPresented: $showingDeleteError) {
            Button(strings.done, role: .cancel) {}
        }
    }

    private func linkRow(_ link: Link) -> some View {
        HStack(spacing: 12) {
            Image(systemName: link.icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(link.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(link.url.absoluteString)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                HStack(spacing: 4) {
                    Text(strings.expiresLabel)
                    Text(link.expiresAt, style: .relative)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button {
                switch link {
                case .image: _ = screenshots.copy(link.url)
                case .video: _ = recordings.copy(link.url)
                }
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help(strings.copyLink)
            Button {
                NSWorkspace.shared.open(link.url)
            } label: {
                Image(systemName: "arrow.up.forward.app")
            }
            .buttonStyle(.borderless)
            .help(strings.openLink)
            Button(role: .destructive) {
                delete(link)
            } label: {
                if deletingID == link.id {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "trash")
                }
            }
            .buttonStyle(.borderless)
            .disabled(deletingID != nil)
            .help(strings.deleteLink)
        }
        .padding(.vertical, 5)
    }

    private func delete(_ link: Link) {
        deletingID = link.id
        Task { @MainActor in
            do {
                switch link {
                case .image(let record): try await screenshots.delete(record)
                case .video(let record): try await recordings.delete(record)
                }
                QuickToolHUD.show(icon: "link", message: strings.linkDeletedHUD)
            } catch {
                showingDeleteError = true
            }
            deletingID = nil
        }
    }
}
