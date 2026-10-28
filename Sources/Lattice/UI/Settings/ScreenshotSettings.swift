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
    @AppStorage(DefaultsKey.screenshotSaveFolder) private var saveFolder = ""
    @AppStorage(DefaultsKey.screenshotSaveSubfolder) private var saveSubfolder = ""
    @AppStorage(DefaultsKey.screenshotFileNamePattern) private var fileNamePattern = ""
    @AppStorage(DefaultsKey.screenshotFileNumberStart) private var numberStart = 1
    @AppStorage(DefaultsKey.screenshotFileNumberNext) private var nextNumber = 1
    @AppStorage(DefaultsKey.screenshotIncludePointer) private var includePointer = false
    @AppStorage(DefaultsKey.screenshotShowLastRegion) private var showLastRegion = true
    @AppStorage(DefaultsKey.screenshotPlayShutterSound) private var playShutterSound = true
    @AppStorage(DefaultsKey.screenshotHighlightWindows) private var highlightWindows = true
    @AppStorage(DefaultsKey.screenshotLoupeStartsOn) private var loupeStartsOn = false
    @AppStorage(DefaultsKey.screenshotLoupeRememberZoom) private var rememberLoupeZoom = false
    @AppStorage(DefaultsKey.screenshotLoupeDefaultZoom) private var loupeDefaultZoom = 1.0
    @AppStorage(DefaultsKey.screenshotLoupeSteppedZoomByDefault)
    private var steppedLoupeZoomByDefault = false
    @AppStorage(DefaultsKey.screenshotDownscale) private var downscale = false
    @AppStorage(DefaultsKey.screenshotDelay) private var delay = 0
    @AppStorage(DefaultsKey.screenshotDefaultAction) private var defaultActionRaw = ""
    @AppStorage(DefaultsKey.screenshotToolShortcutsEnabled) private var toolShortcutsEnabled = true
    @AppStorage(DefaultsKey.screenshotCopyToClipboard) private var copyToClipboard = false
    @AppStorage(DefaultsKey.screenshotAddToShelf) private var addToShelf = false
    @AppStorage(DefaultsKey.shelfEnabled) private var shelfEnabled = false
    @AppStorage(AppFeature.shelf.availabilityKey) private var shelfAvailable = false
    @AppStorage(DefaultsKey.screenshotPreviewTakesFocus) private var previewTakesFocus = true
    @AppStorage(DefaultsKey.screenshotPreviewEnabled) private var previewEnabled = true
    @AppStorage(DefaultsKey.screenshotPreviewDuration) private var previewDuration =
        ScreenshotSupport.defaultConfirmationPreviewDuration
    @AppStorage(DefaultsKey.screenshotSharingEnabled) var sharingEnabled = true
    @AppStorage(DefaultsKey.screenshotUploadDuration) private var uploadDuration = ScreenshotShareDuration.oneHour.rawValue
    @AppStorage(DefaultsKey.screenshotPinRoundedCorners) private var pinRoundedCorners = true
    @State private var showingSharedLinks = false
    @State private var showingSharePrivacy = false

    var strings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    private var workflow: CaptureWorkflowStrings { .localized(l10n.language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                shortcutsCard
                    .settingsSectionAnchor(.screenshot, cornerRadius: 16)

                Group {
                    selectionCard
                    magnifierCard
                    previewCard
                    destinationCard
                    toolsCard
                    sharingCard
                }
                .disabled(!screenshotInstalled)
                .opacity(screenshotInstalled ? 1 : 0.55)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .onAppear { sharing.refresh() }
        .sheet(isPresented: $showingSharedLinks) {
            ScreenshotSharedLinksView()
        }
        .sheet(isPresented: $showingSharePrivacy) {
            ScreenshotSharePrivacyView()
        }
        .settingsExpansionAnimation(value: [rememberLoupeZoom, usesAutomaticConfirmationPreview, previewEnabled,
            sharingEnabled, sharing.records.isEmpty, ScreenshotSupport.fileNamePatternUsesNumber(fileNamePattern)])
    }


    // MARK: - Selection

    private var selectionCard: some View {
        SettingsCard(title: workflow.selection) {
            VStack(alignment: .leading, spacing: 14) {
                SettingsToggleRow(title: strings.freezeToggle,
                                  caption: strings.freezeCaption,
                                  isOn: $freeze)


                SettingsControlRow(title: strings.delayLabel) {
                    Picker(strings.delayLabel, selection: $delay) {
                        ForEach(ScreenshotSupport.allowedDelays, id: \.self) { seconds in
                            if seconds == 0 {
                                Text(strings.delayOff).tag(0)
                            } else {
                                Text(String(format: strings.delaySecondsFormat, seconds)).tag(seconds)
                            }
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }

                SettingsToggleRow(title: strings.highlightWindowsToggle,
                                  caption: strings.highlightWindowsCaption,
                                  isOn: $highlightWindows)

                SettingsToggleRow(title: strings.pointerToggle,
                                  isOn: $includePointer)

                SettingsToggleRow(title: strings.lastRegionToggle,
                                  isOn: $showLastRegion)

                SettingsToggleRow(title: workflow.shutter,
                                  isOn: $playShutterSound)
            }
        }
    }

    // MARK: - Magnifier

    private var magnifierCard: some View {
        SettingsCard(title: workflow.magnifier) {
            VStack(alignment: .leading, spacing: 14) {
                SettingsToggleRow(title: strings.loupeStartsOnToggle,
                                  isOn: $loupeStartsOn)

                SettingsToggleRow(title: strings.loupeRememberZoomToggle,
                                  isOn: $rememberLoupeZoom)

                if !rememberLoupeZoom {
                    SettingsControlRow(title: strings.loupeDefaultZoomLabel) {
                        Picker(strings.loupeDefaultZoomLabel, selection: $loupeDefaultZoom) {
                            ForEach(ScreenshotSupport.captureLoupeDefaultZooms, id: \.self) { zoom in
                                Text(zoom.formatted(
                                    .number.precision(.fractionLength(0...1))) + "×")
                                    .tag(zoom)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }

                SettingsControlRow(title: strings.loupeWheelZoomLabel,
                                   caption: strings.loupeZoomOptionCaption) {
                    Picker(strings.loupeWheelZoomLabel,
                           selection: $steppedLoupeZoomByDefault) {
                        Text(strings.loupeZoomFast).tag(false)
                        Text(strings.loupeZoomStepped).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
            }
        }
    }

    // MARK: - Preview & Actions

    private var previewCard: some View {
        SettingsCard(title: workflow.preview) {
            VStack(alignment: .leading, spacing: 14) {
                SettingsControlRow(title: strings.defaultActionLabel,
                                   caption: defaultActionRaw != ScreenshotDefaultAction.edit.rawValue ? strings.defaultActionCaption : nil) {
                    ScreenshotDefaultActionPicker(strings: strings, selection: $defaultActionRaw)
                        .labelsHidden()
                        .fixedSize()
                }

                if usesAutomaticConfirmationPreview {
                    SettingsToggleRow(title: strings.confirmationPreviewToggle,
                                      caption: previewEnabled ? strings.confirmationPreviewCaption : nil,
                                      isOn: $previewEnabled)

                    if previewEnabled {
                        SettingsControlRow(title: strings.confirmationPreviewDurationLabel) {
                            Picker(strings.confirmationPreviewDurationLabel, selection: $previewDuration) {
                                ForEach(ScreenshotSupport.confirmationPreviewDurations, id: \.self) { seconds in
                                    if seconds == 0 {
                                        Text(strings.confirmationPreviewUntilDismissed).tag(0)
                                    } else {
                                        Text(String(format: strings.delaySecondsFormat, seconds)).tag(seconds)
                                    }
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                    }
                }

                SettingsControlRow(title: strings.previewPositionLabel) {
                    CapturePreviewPositionPicker()
                        .labelsHidden()
                        .fixedSize()
                }

                SettingsToggleRow(title: strings.previewFocusToggle,
                                  caption: strings.previewFocusCaption,
                                  isOn: $previewTakesFocus)

                SettingsToggleRow(title: ScreenshotPinStrings.localized(l10n.language).rounded,
                                  isOn: $pinRoundedCorners)
            }
        }
    }

    // MARK: - Destination

    private var destinationCard: some View {
        SettingsCard(title: workflow.destination) {
            VStack(alignment: .leading, spacing: 14) {
                SettingsToggleRow(title: strings.autoCopyToggle,
                                  caption: strings.autoCopyCaption,
                                  isOn: autoCopyBinding)

                SettingsToggleRow(title: strings.addToShelfToggle,
                                  caption: strings.addToShelfCaption,
                                  isOn: addToShelfBinding)
                    .disabled(!shelfIsOn)

                folderRow
                subfolderRow
                fileNameRow

                SettingsToggleRow(title: strings.downscaleToggle,
                                  caption: strings.downscaleCaption,
                                  isOn: $downscale)
            }
        }
    }

    // MARK: - Tools

    private var toolsCard: some View {
        SettingsCard(title: strings.toolShortcutsTitle) {
            ScreenshotToolOrderControls(shortcutsEnabled: $toolShortcutsEnabled,
                                        showsTitle: false)
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

    private var autoCopyBinding: Binding<Bool> {
        Binding {
            copyToClipboard || defaultAction.copiesToClipboard
        } set: { isOn in
            copyToClipboard = isOn
            if !isOn { defaultActionRaw = defaultAction.withoutCopy.rawValue }
        }
    }

    private var defaultAction: ScreenshotDefaultAction {
        ScreenshotDefaultAction(rawValue: defaultActionRaw) ?? .none
    }

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

    private var usesAutomaticConfirmationPreview: Bool {
        guard let action = ScreenshotDefaultAction(rawValue: defaultActionRaw) else { return false }
        switch action {
        case .save, .saveAndCopy, .copy: return true
        case .none, .edit: return false
        }
    }

    private var folderRow: some View {
        SettingsControlRow(title: strings.folderLabel) {
            HStack(spacing: 8) {
                Text(currentFolderName)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !saveFolder.isEmpty {
                    Button {
                        saveFolder = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.borderless)
                    .screenshotSafeHelp(l10n.s.shortcutReset)
                }
                Button(strings.folderChoose) {
                    chooseFolder()
                }
                .controlSize(.small)
            }
        }
    }

    private var subfolderRow: some View {
        SettingsControlRow(title: strings.subfolderLabel,
                           caption: saveSubfolder.isEmpty ? strings.subfolderCaption : "\(strings.subfolderCaption)\n→ \(ScreenshotSupport.expandSaveSubfolder(saveSubfolder, date: Date()))") {
            TextField("", text: $saveSubfolder)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
        }
    }

    private var fileNameRow: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsControlRow(title: strings.fileNamePatternLabel,
                               caption: "\(strings.fileNamePatternCaption)\n→ \(fileNamePreview)") {
                TextField("", text: $fileNamePattern)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }

            if ScreenshotSupport.fileNamePatternUsesNumber(fileNamePattern) {
                SettingsControlRow(title: strings.fileNumberStartLabel,
                                   caption: String(format: strings.fileNumberNextFormat, nextNumber)) {
                    HStack(spacing: 6) {
                        TextField("", value: $numberStart, formatter: Self.numberFieldFormatter)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                        Stepper("", value: $numberStart, in: 0...999_999)
                            .labelsHidden()
                        Button(strings.fileNumberResetButton) {
                            nextNumber = numberStart
                        }
                        .controlSize(.small)
                    }
                }
                .onChange(of: numberStart) { _, newValue in
                    nextNumber = newValue
                }
            }
        }
    }

    private static let numberFieldFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0
        formatter.maximum = 999_999
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    private var fileNamePreview: String {
        let trimmed = fileNamePattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ScreenshotSupport.fileName(prefix: strings.fileNamePrefix, date: Date())
        }
        return ScreenshotSupport.expandFileNamePattern(trimmed, date: Date(), number: nextNumber) + ".png"
    }

    private var currentFolderName: String {
        let manager = FileManager.default
        if !saveFolder.isEmpty {
            let expanded = (saveFolder as NSString).expandingTildeInPath
            var isDirectory: ObjCBool = false
            if manager.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue {
                return manager.displayName(atPath: expanded)
            }
        }
        let desktop = manager.urls(for: .desktopDirectory, in: .userDomainMask).first
        return desktop.map { manager.displayName(atPath: $0.path) } ?? "Desktop"
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            saveFolder = url.path
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

private struct ScreenshotSharedLinksView: View {
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

struct ScreenshotDefaultActionPicker: View {
    let strings: ScreenshotFeatureStrings
    @Binding var selection: String

    var body: some View {
        Picker(strings.defaultActionLabel, selection: $selection) {
            Text(strings.defaultActionNone).tag(ScreenshotDefaultAction.none.rawValue)
            Text(strings.saveButton).tag(ScreenshotDefaultAction.save.rawValue)
            Text(strings.defaultActionSaveAndCopy).tag(ScreenshotDefaultAction.saveAndCopy.rawValue)
            Text(strings.copyButton).tag(ScreenshotDefaultAction.copy.rawValue)
            Text(strings.editButton).tag(ScreenshotDefaultAction.edit.rawValue)
        }
    }
}
