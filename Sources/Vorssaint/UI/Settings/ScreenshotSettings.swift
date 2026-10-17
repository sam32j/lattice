// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
/// Screenshot Settings page.
struct ScreenshotSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var service = ScreenshotService.shared
    @ObservedObject private var sharing = ScreenshotShareService.shared
    @AppStorage(DefaultsKey.screenshotFreeze) private var freeze = true
    @AppStorage(DefaultsKey.screenshotHideVorssaintWindows) private var hideVorssaintWindows = true
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
    @AppStorage(DefaultsKey.screenshotPreviewPosition) private var previewPositionRaw = ""
    @AppStorage(DefaultsKey.screenshotPreviewTakesFocus) private var previewTakesFocus = true
    @AppStorage(DefaultsKey.screenshotPreviewEnabled) private var previewEnabled = true
    @AppStorage(DefaultsKey.screenshotPreviewDuration) private var previewDuration =
        ScreenshotSupport.defaultConfirmationPreviewDuration
    @AppStorage(DefaultsKey.screenshotSharingEnabled) private var sharingEnabled = true
    @AppStorage(DefaultsKey.screenshotUploadDuration) private var uploadDuration = ScreenshotShareDuration.oneHour.rawValue
    @AppStorage(DefaultsKey.screenshotPinRoundedCorners) private var pinRoundedCorners = true
    @AppStorage(DefaultsKey.screenOCRRemoveLineBreaks) private var removesLineBreaks = false
    @AppStorage(DefaultsKey.screenOCRDetectQRCodes) private var detectsQRCodes = true
    @AppStorage(DefaultsKey.colorPickerFormat) private var colorFormat = "hex"
    @AppStorage(DefaultsKey.colorPickerBareHex) private var usesBareHex = false
    @State private var showingSharedLinks = false
    @State private var showingSharePrivacy = false

    private var strings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    private var workflow: CaptureWorkflowStrings { .localized(l10n.language) }

    var body: some View {
        Form {
            Section {
                CompactShortcutPreferenceRow(title: strings.pageTitle,
                                             role: .screenshot,
                                             enabledKey: DefaultsKey.screenshotShortcutEnabled) {
                    ScreenshotService.shared.syncWithPreferences()
                }
                CompactShortcutPreferenceRow(title: strings.fullScreenShortcutTitle,
                                             role: .screenshotFullScreen,
                                             enabledKey: DefaultsKey.screenshotFullScreenShortcutEnabled) {
                    ScreenshotService.shared.syncWithPreferences()
                }
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
                CompactShortcutPreferenceRow(title: strings.uploadLastCapture,
                                             role: .screenshotUpload,
                                             enabledKey: DefaultsKey.screenshotUploadShortcutEnabled) {
                    ScreenshotService.shared.syncWithPreferences()
                }
                CompactShortcutPreferenceRow(title: l10n.s.ocrName,
                                             role: .screenOCR,
                                             enabledKey: DefaultsKey.screenOCRShortcutEnabled) {
                    ScreenTextService.shared.syncWithPreferences()
                }
                CompactShortcutPreferenceRow(title: l10n.s.colorPickerName,
                                             role: .colorPicker,
                                             enabledKey: DefaultsKey.colorPickerShortcutEnabled) {
                    ScreenCaptureService.shared.syncWithPreferences()
                }
                CompactShortcutPreferenceRow(title: FeatureStrings.recentCaptures(l10n.language).title,
                                             role: .recentCaptures,
                                             enabledKey: DefaultsKey.recentCapturesShortcutEnabled) {
                    RecentCaptureService.shared.syncWithPreferences()
                }
                if !permissions.screenRecording {
                    PermissionRow(kind: .screenRecording)
                }
            } header: {
                Text(l10n.s.shortcutsPageTitle)
            }
            .settingsFormSectionAnchor(.screenshot)

            Section {
                Toggle(isOn: $freeze) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(strings.freezeToggle)
                        Text(strings.freezeCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle(strings.hideVorssaintWindowsToggle, isOn: $hideVorssaintWindows)
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
                Toggle(strings.pointerToggle, isOn: $includePointer)
                Toggle(strings.lastRegionToggle, isOn: $showLastRegion)
                Toggle(workflow.shutter, isOn: $playShutterSound)
            } header: {
                Text(workflow.selection)
            }

            Section {
                Toggle(strings.loupeStartsOnToggle, isOn: $loupeStartsOn)
                Toggle(strings.loupeRememberZoomToggle, isOn: $rememberLoupeZoom)
                if !rememberLoupeZoom {
                    Picker(strings.loupeDefaultZoomLabel, selection: $loupeDefaultZoom) {
                        ForEach(ScreenshotSupport.captureLoupeDefaultZooms, id: \.self) { zoom in
                            Text(zoom.formatted(
                                .number.precision(.fractionLength(0...1))) + "×")
                                .tag(zoom)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Picker(strings.loupeWheelZoomLabel,
                           selection: $steppedLoupeZoomByDefault) {
                        Text(strings.loupeZoomFast).tag(false)
                        Text(strings.loupeZoomStepped).tag(true)
                    }
                    .pickerStyle(.segmented)
                    Text(strings.loupeZoomOptionCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(workflow.magnifier)
            }

            Section {
                defaultActionRow
                previewPositionRow
                previewFocusRow
                Toggle(ScreenshotPinStrings.localized(l10n.language).rounded, isOn: $pinRoundedCorners)
            } header: {
                Text(workflow.preview)
            }

            Section {
                Toggle(isOn: autoCopyBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(strings.autoCopyToggle)
                        Text(strings.autoCopyCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle(isOn: addToShelfBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(strings.addToShelfToggle)
                        Text(strings.addToShelfCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!shelfIsOn)
                folderRow
                subfolderRow
                fileNameRow
                Toggle(isOn: $downscale) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(strings.downscaleToggle)
                        Text(strings.downscaleCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(workflow.destination)
            }

            Section {
                ScreenshotToolOrderControls(shortcutsEnabled: $toolShortcutsEnabled,
                                            showsTitle: false)
            } header: {
                Text(strings.toolShortcutsTitle)
            }

            Section {
                Toggle(isOn: $sharingEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(strings.shareEnabledToggle)
                        if sharingEnabled {
                            Text(strings.shareCaption)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: sharingEnabled) { _, _ in service.syncWithPreferences() }
                if sharingEnabled {
                    Picker(strings.uploadExpiry, selection: $uploadDuration) {
                        ForEach(ScreenshotShareDuration.allCases) { duration in
                            Text(duration.title(strings)).tag(duration.rawValue)
                        }
                    }
                    if !sharing.records.isEmpty {
                        Button {
                            showingSharedLinks = true
                        } label: {
                            HStack {
                                Label(strings.sharedLinksTitle, systemImage: "link")
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
            } header: {
                HStack {
                    Text(strings.shareSectionTitle)
                    Spacer()
                    Button {
                        showingSharePrivacy = true
                    } label: {
                        Label(strings.sharePrivacyButton, systemImage: "hand.raised")
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle(isOn: $removesLineBreaks) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.s.ocrRemoveLineBreaksToggle)
                        Text(l10n.s.ocrRemoveLineBreaksCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle(isOn: $detectsQRCodes) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.s.ocrQRToggle)
                        Text(l10n.s.ocrQRCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(l10n.s.ocrName)
            }
            .settingsFormSectionAnchor(.screenOCR)

            Section {
                Picker(l10n.s.colorPickerFormatLabel, selection: $colorFormat) {
                    ForEach(ColorCopyFormat.allCases) { format in
                        Text(format.label).tag(format.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                if colorFormat == ColorCopyFormat.hex.rawValue {
                    Toggle(l10n.s.colorPickerBareHexToggle, isOn: $usesBareHex)
                }
            } header: {
                Text(l10n.s.colorPickerName)
            }
            .settingsFormSectionAnchor(.colorPicker)
        }
        .formStyle(.grouped)
        .onAppear { sharing.refresh() }
        .sheet(isPresented: $showingSharedLinks) {
            ScreenshotSharedLinksView()
        }
        .sheet(isPresented: $showingSharePrivacy) {
            ScreenshotSharePrivacyView()
        }
    }

    /// The after-capture action can copy too, so the toggle reads on while
    /// either one copies. Turning it off clears both. Otherwise captures keep
    /// reaching the clipboard while the switch shows off.
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

    /// Reads off while the shelf is off, since no capture reaches it then.
    /// The choice itself is kept for when the shelf comes back.
    private var addToShelfBinding: Binding<Bool> {
        Binding {
            addToShelf && shelfIsOn
        } set: { isOn in
            addToShelf = isOn
        }
    }

    private var defaultActionRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            ScreenshotDefaultActionPicker(strings: strings, selection: $defaultActionRaw)
            if defaultActionRaw != ScreenshotDefaultAction.edit.rawValue {
                Text(strings.defaultActionCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if usesAutomaticConfirmationPreview {
                Toggle(strings.confirmationPreviewToggle, isOn: $previewEnabled)
                if previewEnabled {
                    Picker(strings.confirmationPreviewDurationLabel, selection: $previewDuration) {
                        ForEach(ScreenshotSupport.confirmationPreviewDurations, id: \.self) { seconds in
                            if seconds == 0 {
                                Text(strings.confirmationPreviewUntilDismissed).tag(0)
                            } else {
                                Text(String(format: strings.delaySecondsFormat, seconds)).tag(seconds)
                            }
                        }
                    }
                }
                Text(strings.confirmationPreviewCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var usesAutomaticConfirmationPreview: Bool {
        guard let action = ScreenshotDefaultAction(rawValue: defaultActionRaw) else { return false }
        switch action {
        case .save, .saveAndCopy, .copy: return true
        case .none, .edit: return false
        }
    }

    private var previewFocusRow: some View {
        Toggle(isOn: $previewTakesFocus) {
            VStack(alignment: .leading, spacing: 2) {
                Text(strings.previewFocusToggle)
                Text(strings.previewFocusCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var previewPositionRow: some View {
        Picker(strings.previewPositionLabel, selection: $previewPositionRaw) {
            Text(strings.previewPositionAutomatic)
                .tag(ScreenshotSupport.QuickPreviewPosition.automatic.rawValue)
            Text(strings.previewPositionTopLeft)
                .tag(ScreenshotSupport.QuickPreviewPosition.topLeft.rawValue)
            Text(strings.previewPositionTopRight)
                .tag(ScreenshotSupport.QuickPreviewPosition.topRight.rawValue)
            Text(strings.previewPositionBottomLeft)
                .tag(ScreenshotSupport.QuickPreviewPosition.bottomLeft.rawValue)
            Text(strings.previewPositionBottomRight)
                .tag(ScreenshotSupport.QuickPreviewPosition.bottomRight.rawValue)
        }
    }

    private var folderRow: some View {
        HStack {
            Text(strings.folderLabel)
            Spacer()
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
        }
    }

    private var subfolderRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(strings.subfolderLabel)
                    .lineLimit(1)
                Spacer(minLength: 12)
                if !saveSubfolder.isEmpty {
                    Text(ScreenshotSupport.expandSaveSubfolder(saveSubfolder, date: Date()))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                TextField("", text: $saveSubfolder)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
            }
            .fixedSize(horizontal: false, vertical: true)
            Text(strings.subfolderCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var fileNameRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(strings.fileNamePatternLabel)
                    .lineLimit(1)
                Spacer(minLength: 12)
                Text(fileNamePreview)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                TextField("", text: $fileNamePattern)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
            }
            .fixedSize(horizontal: false, vertical: true)
            Text(strings.fileNamePatternCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
            if ScreenshotSupport.fileNamePatternUsesNumber(fileNamePattern) {
                HStack {
                    Text(strings.fileNumberStartLabel)
                        .lineLimit(1)
                    TextField("", value: $numberStart, formatter: Self.numberFieldFormatter)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                    Stepper("", value: $numberStart, in: 0...999_999)
                        .labelsHidden()
                    Button(strings.fileNumberResetButton) {
                        nextNumber = numberStart
                    }
                    Spacer()
                    Text(String(format: strings.fileNumberNextFormat, nextNumber))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .fixedSize(horizontal: false, vertical: true)
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
