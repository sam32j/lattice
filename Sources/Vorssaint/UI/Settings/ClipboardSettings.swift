// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct ClipboardSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var history = ClipboardHistoryService.shared
    @ObservedObject private var permissions = Permissions.shared
    @State private var clearingIDs: [UUID: Date]?
    @AppStorage(DefaultsKey.pastePlainEnabled) private var pastePlainEnabled = false
    @AppStorage(DefaultsKey.clipboardHistoryEnabled) private var enabled = false
    @AppStorage(DefaultsKey.clipboardHistoryLimit) private var limit = 50
    @AppStorage(DefaultsKey.clipboardHistoryRetentionDays) private var retentionDays = 0
    @AppStorage(DefaultsKey.clipboardHistoryFilterSensitiveText) private var skipSensitive = false
    @AppStorage(DefaultsKey.clipboardHistoryIncludeImagesFiles) private var includeImagesFiles = true
    @AppStorage(DefaultsKey.clipboardHistoryShortcutEnabled) private var shortcutEnabled = true
    @AppStorage(DefaultsKey.clipboardHistoryLayout) private var historyLayout = ClipboardHistoryLayout.list
    @AppStorage(DefaultsKey.clipboardHistoryMenuBarPreview) private var menuBarPreview = false
    @AppStorage(DefaultsKey.clipboardHistoryMenuBarPreviewLength)
    private var menuBarPreviewLength = Defaults.defaultClipboardMenuBarPreviewLength
    @AppStorage(DefaultsKey.panelUtilityClipboard) private var showInPanel = true
    @AppStorage(DefaultsKey.clipboardAutoClearOnDelay) private var autoClearOnDelay = false
    @AppStorage(DefaultsKey.clipboardAutoClearDelay)
    private var autoClearDelay = Defaults.defaultClipboardAutoClearDelay
    @AppStorage(DefaultsKey.clipboardAutoClearOnSleep) private var autoClearOnSleep = false
    @AppStorage(DefaultsKey.clipboardAutoClearOnDisplaySleep) private var autoClearOnDisplaySleep = false
    @AppStorage(DefaultsKey.clipboardAutoClearOnScreenLock) private var autoClearOnScreenLock = false

    private var text: ClipboardFeatureStrings {
        FeatureStrings.clipboard(l10n.language)
    }

    private var retentionText: ClipboardRetentionStrings {
        FeatureStrings.clipboardRetention(l10n.language)
    }

    var body: some View {
        Form {
            Group {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                    SettingsRow(symbol: AppFeature.clipboardHistory.symbolName, title: SettingsOwnershipStrings.enable(text.title, l10n.language),
                        caption: SettingsOwnershipStrings.text(.clipboardCaption, l10n.language)) {
                    Toggle("", isOn: $enabled).labelsHidden()
                        .onChange(of: enabled) { _, _ in
                            FeatureRuntime.shared.sync([.clipboardHistory])
                            FeatureRuntime.shared.finishAvailabilityChange()
                        }
                    }
                    if enabled {
                        ShortcutPreferenceRow(role: .clipboard, label: UtilitySettingsCopy.open(text.title, l10n.language),
                            additionalConflict: WindowLayoutService.shared.shortcutConflictTitle) {
                            ClipboardHistoryService.shared.syncHotkey()
                        }
                        .padding(.leading, settingsRowTextInset)
                        IslandDestinationSettings(destination: .clipboard)
                            .padding(.leading, settingsRowTextInset)
                    }
                    }
                }
                .settingsFormSectionAnchor(.clipboardHistory)

                clipboardShortcutSection.disabled(!enabled)
                clipboardMenuBarPreviewSection

                Section {
                    Toggle(text.includeImagesFiles, isOn: $includeImagesFiles)
                        .disabled(!enabled)
                    Text(text.includeImagesFilesCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle(text.skipSensitive, isOn: $skipSensitive)
                        .disabled(!enabled)
                    Text(text.skipSensitiveCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ClipboardIgnoredAppsList()
                        .disabled(!enabled)
                    Picker(text.limit, selection: $limit) {
                        ForEach(Defaults.allowedClipboardHistoryLimits, id: \.self) { value in
                            Text(value == 0 ? text.limitUnlimited : "\(value)").tag(value)
                        }
                    }
                    .disabled(!enabled)
                    Picker(retentionText.title, selection: $retentionDays) {
                        ForEach(Defaults.allowedClipboardHistoryRetentionDays, id: \.self) { value in
                            Text(retentionText.label(days: value)).tag(value)
                        }
                    }
                    .disabled(!enabled)
                    Text(retentionText.caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Toggle(text.showInPanel, isOn: $showInPanel)
                }.disabled(!enabled)

                clipboardAutoClearSection.disabled(!enabled)
            }

            if AppFeature.pastePlain.isPresentInControls() {
                Section {
                    Text(l10n.s.pastePlainCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ShortcutPreferenceRow(role: .pastePlain) {
                        FeatureRuntime.shared.sync([.pastePlain])
                    }
                    if pastePlainEnabled { ClipboardPlainPasteStatus() }
                    if pastePlainEnabled, !permissions.accessibility {
                        PermissionRow(kind: .accessibility)
                    }
                } header: {
                    Text(l10n.s.pastePlainName)
                }
                .settingsFormSectionAnchor(.pastePlain)
                .disabled(!enabled)
            }

            clipboardStatsSection.disabled(!enabled)
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .controlSize(.regular)
        .onAppear {
            limit = Defaults.sanitizedClipboardHistoryLimit(limit)
            retentionDays = Defaults.sanitizedClipboardHistoryRetentionDays(retentionDays)
            autoClearDelay = Defaults.sanitizedClipboardAutoClearDelay(autoClearDelay)
            menuBarPreviewLength = Defaults.sanitizedClipboardMenuBarPreviewLength(menuBarPreviewLength)
        }
        .onChange(of: limit) { _, value in
            let sanitized = Defaults.sanitizedClipboardHistoryLimit(value)
            if sanitized != value { limit = sanitized }
            ClipboardHistoryService.shared.trimToLimit()
        }
        .onChange(of: retentionDays) { _, value in
            let sanitized = Defaults.sanitizedClipboardHistoryRetentionDays(value)
            if sanitized != value { retentionDays = sanitized }
            ClipboardHistoryService.shared.trimToLimit()
        }
        // No syncWithPreferences() here, unlike the auto-clear toggles: the
        // running poll reads this value from UserDefaults on every tick, so a
        // new delay takes effect on the next one. Syncing would just tear the
        // timer down and restart the wait.
        .onChange(of: autoClearDelay) { _, value in
            let sanitized = Defaults.sanitizedClipboardAutoClearDelay(value)
            if sanitized != value { autoClearDelay = sanitized }
        }
        .onChange(of: menuBarPreviewLength) { _, value in
            let sanitized = Defaults.sanitizedClipboardMenuBarPreviewLength(value)
            if sanitized != value { menuBarPreviewLength = sanitized }
        }
    }

    @ViewBuilder
    private var clipboardShortcutSection: some View {
        Section(text.shortcut) {
            if enabled, shortcutEnabled, history.shortcutRegistrationFailed {
                Text(l10n.s.shortcutUnavailable)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Text(text.shortcutCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker(text.historyLayout, selection: $historyLayout) {
                Text(text.historyLayoutList).tag(ClipboardHistoryLayout.list)
                Text(text.historyLayoutCards).tag(ClipboardHistoryLayout.cards)
            }
            .pickerStyle(.segmented)
            Button {
                ClipboardHistoryService.shared.showHistoryWindow()
            } label: {
                Label(text.shortcut, systemImage: "doc.on.clipboard")
            }
            .disabled(history.entries.isEmpty)
        }
    }

    @ViewBuilder
    private var clipboardMenuBarPreviewSection: some View {
        Section {
            Toggle(text.menuBarPreview, isOn: $menuBarPreview)
                .disabled(!enabled)
            HStack {
                Text(text.menuBarPreviewLength)
                Spacer()
                TextField("", value: $menuBarPreviewLength, formatter: Self.menuBarPreviewLengthFormatter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                    .multilineTextAlignment(.trailing)
                Text(text.menuBarPreviewLengthSuffix)
                    .foregroundStyle(.secondary)
            }
            .disabled(!enabled || !menuBarPreview)
            Text(text.menuBarPreviewCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private static let menuBarPreviewLengthFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = NSNumber(value: Defaults.allowedClipboardMenuBarPreviewLengthRange.lowerBound)
        formatter.maximum = NSNumber(value: Defaults.allowedClipboardMenuBarPreviewLengthRange.upperBound)
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    @ViewBuilder
    private var clipboardAutoClearSection: some View {
        Section {
            HStack {
                Toggle(text.autoClearEnable, isOn: $autoClearOnDelay)
                    .onChange(of: autoClearOnDelay) { _, _ in
                        ClipboardAutoClearService.shared.syncWithPreferences()
                    }
                TextField("", value: $autoClearDelay, formatter: Self.delayFieldFormatter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .disabled(!autoClearOnDelay)
                Text(text.autoClearSecondsSuffix)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Toggle(text.autoClearOnSleep, isOn: $autoClearOnSleep)
                .onChange(of: autoClearOnSleep) { _, _ in
                    ClipboardAutoClearService.shared.syncWithPreferences()
                }
            Toggle(text.autoClearOnDisplaySleep, isOn: $autoClearOnDisplaySleep)
                .onChange(of: autoClearOnDisplaySleep) { _, _ in
                    ClipboardAutoClearService.shared.syncWithPreferences()
                }
            Toggle(text.autoClearOnScreenLock, isOn: $autoClearOnScreenLock)
                .onChange(of: autoClearOnScreenLock) { _, _ in
                    ClipboardAutoClearService.shared.syncWithPreferences()
                }
            Text(text.autoClearCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private static let delayFieldFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = NSNumber(value: Defaults.allowedClipboardAutoClearDelayRange.lowerBound)
        formatter.maximum = NSNumber(value: Defaults.allowedClipboardAutoClearDelayRange.upperBound)
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    private var clipboardStatsSection: some View {
            Section {
                HStack {
                    Text("\(history.pinnedEntries.count)")
                    Text(text.pinned)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(history.recentEntries.count)")
                    Text(text.recent)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(text.clearRecent) {
                        clearingIDs = history.recentEntriesSnapshot
                    }
                    .disabled(history.recentEntries.isEmpty)
                    .modifier(ClipboardClearRecentConfirmation(entryIDs: $clearingIDs))
                }
            }
    }
}
