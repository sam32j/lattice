// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
/// Screenshot Settings page.
struct ScreenshotSettings: View {
    @ObservedObject var l10n = L10n.shared
    @ObservedObject private var service = ScreenshotService.shared
    @ObservedObject private var sharing = ScreenshotShareService.shared
    @AppStorage(DefaultsKey.screenshotEnabled) var screenshotEnabled = true
    @AppStorage(DefaultsKey.screenshotFreeze) private var freeze = true
    @AppStorage(DefaultsKey.screenshotIncludePointer) private var includePointer = false
    @AppStorage(DefaultsKey.screenshotShowLastRegion) private var showLastRegion = true
    @AppStorage(DefaultsKey.screenshotPlayShutterSound) private var playShutterSound = true
    @AppStorage(DefaultsKey.screenshotLoupeStartsOn) private var loupeStartsOn = false
    @AppStorage(DefaultsKey.screenshotLoupeRememberZoom) private var rememberLoupeZoom = false
    @AppStorage(DefaultsKey.screenshotLoupeDefaultZoom) private var loupeDefaultZoom = 1.0
    @AppStorage(DefaultsKey.screenshotDownscale) private var downscale = false
    @AppStorage(DefaultsKey.screenshotSaveAutomatically) private var saveAutomatically = false
    @AppStorage(DefaultsKey.screenshotOpenEditorAfterCapture) private var openEditorAfterCapture = false
    @AppStorage(DefaultsKey.screenshotToolShortcutsEnabled) private var toolShortcutsEnabled = true
    @AppStorage(DefaultsKey.screenshotCopyToClipboard) private var copyToClipboard = false
    @AppStorage(DefaultsKey.screenshotAddToShelf) private var addToShelf = false
    @AppStorage(DefaultsKey.shelfEnabled) private var shelfEnabled = false
    @AppStorage(AppFeature.shelf.availabilityKey) private var shelfAvailable = false
    @AppStorage(DefaultsKey.screenshotSharingEnabled) var sharingEnabled = true
    @AppStorage(DefaultsKey.screenshotUploadDuration) private var uploadDuration = ScreenshotShareDuration.oneHour.rawValue
    @State private var showingSharedLinks = false
    @State private var showingSharePrivacy = false
    @State private var toolsExpanded = false

    var strings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    private var workflow: CaptureWorkflowStrings { .localized(l10n.language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    captureBehaviorCard
                        .settingsSectionAnchor(.screenshot, cornerRadius: 16)
                    zoomCard
                    afterCaptureCard
                    destinationCard
                    keyboardShortcutsCard
                    toolsCard
                }
                .disabled(!screenshotInstalled)
                .opacity(screenshotInstalled ? 1 : 0.55)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .settingsExpansionAnimation(value: [rememberLoupeZoom, toolsExpanded])
    }


    // MARK: - Capture behavior

    private var captureBehaviorCard: some View {
        SettingsCard(title: strings.captureBehaviorSection) {
            VStack(alignment: .leading, spacing: 14) {
                SettingsToggleRow(title: workflow.shutter,
                                  isOn: $playShutterSound)

                SettingsToggleRow(title: strings.hidePointerToggle,
                                  isOn: Binding(get: { !includePointer },
                                                set: { includePointer = !$0 }))

                SettingsToggleRow(title: strings.lastRegionToggle,
                                  isOn: $showLastRegion)

                SettingsToggleRow(title: strings.freezeToggle,
                                  isOn: $freeze)
            }
        }
    }

    // MARK: - Zoom

    private var zoomCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 2) {
                Text(strings.zoomSection).font(.headline)
                Text(strings.zoomHelp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 14) {
                    SettingsToggleRow(title: strings.loupeStartsOnToggle,
                                      isOn: $loupeStartsOn)
                    SettingsToggleRow(title: strings.zoomReset,
                                      isOn: Binding(get: { !rememberLoupeZoom },
                                                    set: { rememberLoupeZoom = !$0 }))
                    if !rememberLoupeZoom {
                        SettingsControlRow(title: strings.loupeDefaultZoomLabel) {
                            Picker(strings.loupeDefaultZoomLabel, selection: $loupeDefaultZoom) {
                                ForEach(ScreenshotSupport.captureLoupeDefaultZooms.indices, id: \.self) { index in
                                    Text([strings.zoomLow, strings.zoomMedium, strings.zoomHigh,
                                          strings.zoomMaximum][index])
                                        .tag(ScreenshotSupport.captureLoupeDefaultZooms[index])
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
    }

    // MARK: - After capture

    private var afterCaptureCard: some View {
        SettingsCard(title: strings.afterCaptureSection) {
            VStack(alignment: .leading, spacing: 14) {
                SettingsToggleRow(title: strings.afterCaptureCopy,
                                  isOn: $copyToClipboard)
                SettingsToggleRow(title: strings.afterCaptureSave,
                                  isOn: $saveAutomatically)
                SettingsToggleRow(title: strings.afterCaptureShelf,
                                  isOn: addToShelfBinding)
                    .disabled(!shelfIsOn)
                SettingsToggleRow(title: strings.afterCaptureEditor,
                                  isOn: $openEditorAfterCapture)
            }
        }
    }

    // MARK: - Export & Format

    private var destinationCard: some View {
        SettingsCard(title: CaptureOptionsStrings.text(.screenshotExportFormat, l10n.language)) {
            SettingsToggleRow(title: strings.downscaleToggle,
                              isOn: $downscale)
        }
    }

    // MARK: - Keyboard shortcuts

    private var keyboardShortcutsCard: some View {
        SettingsCard(title: CaptureOptionsStrings.text(.keyboardShortcuts, l10n.language)) {
            VStack(alignment: .leading, spacing: 10) {
                CompactShortcutPreferenceRow(title: strings.editLastCapture,
                                             role: .screenshotLastCapture,
                                             enabledKey: DefaultsKey.screenshotLastCaptureShortcutEnabled) {
                    ScreenshotService.shared.syncWithPreferences()
                }
                CompactShortcutPreferenceRow(title: strings.editClipboardImage,
                                             role: .screenshotClipboard,
                                             enabledKey: DefaultsKey.screenshotClipboardShortcutEnabled) {
                    ScreenshotService.shared.syncWithPreferences()
                }
            }
        }
    }

    // MARK: - Tools

    private var toolsCard: some View {
        SettingsCard {
            DisclosureGroup(strings.toolShortcutsTitle, isExpanded: $toolsExpanded) {
                ScreenshotToolOrderControls(shortcutsEnabled: $toolShortcutsEnabled,
                                            showsTitle: false)
                    .padding(.top, 10)
            }
        }
    }

    // MARK: - Sharing

    private var sharingCard: some View {
        SettingsCard(title: strings.shareSectionTitle, headerAccessory: {
            Button {
                showingSharePrivacy = true
            } label: {
                Label(strings.sharePrivacyButton, systemImage: "hand.raised")
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }) {
            VStack(alignment: .leading, spacing: 14) {
                SettingsToggleRow(title: strings.shareEnabledToggle,
                                  caption: sharingEnabled ? strings.shareCaption : nil,
                                  isOn: $sharingEnabled)
                    .onChange(of: sharingEnabled) { _, _ in service.syncWithPreferences() }

                if sharingEnabled {
                    SettingsControlRow(title: strings.uploadExpiry) {
                        Picker(strings.uploadExpiry, selection: $uploadDuration) {
                            ForEach(ScreenshotShareDuration.allCases) { duration in
                                Text(duration.title(strings)).tag(duration.rawValue)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }

                    if !sharing.records.isEmpty {
                        Button {
                            showingSharedLinks = true
                        } label: {
                            HStack {
                                Text(strings.sharedLinksTitle)
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

    // MARK: - Bindings & Helpers

    private var shelfIsOn: Bool {
        shelfEnabled && shelfAvailable
    }

    private var addToShelfBinding: Binding<Bool> {
        Binding {
            addToShelf && shelfIsOn
        } set: { isOn in
            addToShelf = isOn
        }
    }


}

struct ScreenshotSharePrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var l10n = L10n.shared
    let actionTitle: String?
    let onAction: (() -> Void)?

    init(actionTitle: String? = nil, onAction: (() -> Void)? = nil) {
        self.actionTitle = actionTitle
        self.onAction = onAction
    }

    private var strings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(strings.sharePrivacyTitle, systemImage: "hand.raised")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(actionTitle ?? strings.done) {
                    dismiss()
                    guard let onAction else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onAction()
                    }
                }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    privacyParagraph(symbol: "photo", text: strings.sharePrivacyData)
                    privacyParagraph(symbol: "externaldrive", text: strings.sharePrivacyStorage)
                    privacyParagraph(symbol: "person.2", text: strings.sharePrivacyAccess)
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

struct ScreenshotSharedLinksView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var sharing = ScreenshotShareService.shared
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

    private func linkRow(_ record: ScreenshotShareRecord) -> some View {
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
                copy(record.url)
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

    private func copy(_ url: URL) {
        sharing.copy(url)
    }

    private func delete(_ record: ScreenshotShareRecord) {
        deletingID = record.id
        Task {
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
