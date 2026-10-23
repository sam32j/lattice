// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct ShelfSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var shelf = ShelfService.shared
    @AppStorage(DefaultsKey.shelfEnabled) private var enabled = false
    @AppStorage(DefaultsKey.shelfShortcutEnabled) private var shortcutEnabled = true
    @AppStorage(DefaultsKey.shelfShortcutAddsFinderSelection) private var shortcutAddsFinderSelection = false
    @AppStorage(DefaultsKey.shelfShakeToOpen) private var shake = true
    @AppStorage(DefaultsKey.shelfDropZoneEnabled) private var dropZone = true
    @AppStorage(DefaultsKey.shelfDockPlacement) private var dockPlacement = ShelfDockPlacement.menuBar.rawValue
    @AppStorage(DefaultsKey.notchEnabled) private var islandEnabled = false
    @AppStorage(DefaultsKey.notchShelf) private var islandFileCache = true
    @AppStorage(DefaultsKey.notchHiddenModules) private var islandHiddenModules = ""
    @AppStorage(DefaultsKey.shelfEdgeDragEnabled) private var edgeDrag = false
    @AppStorage(DefaultsKey.shelfCloseAfterDrop) private var closeAfterDrop = false
    @AppStorage(DefaultsKey.shelfRemoveAfterDrop) private var removeAfterDrop = true
    @AppStorage(DefaultsKey.shelfClearOnClose) private var clearOnClose = false
    @State private var showingAppPicker = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsControlRow(title: SettingsOwnershipStrings.enable(SettingsOwnershipStrings.text(.fileCache, l10n.language), l10n.language),
                        caption: SettingsOwnershipStrings.text(.cacheCaption, l10n.language)) {
                        HStack(spacing: 6) {
                            if enabled && !islandOn {
                                Image(systemName: "info.circle").foregroundStyle(.secondary)
                                    .frame(width: 21, height: 21)
                                    .overlay { StatusTooltip(message: UtilitySettingsCopy.fileCacheHint(l10n.language)) }
                                    .accessibilityLabel(UtilitySettingsCopy.fileCacheHint(l10n.language))
                            }
                            Toggle("", isOn: $enabled).labelsHidden()
                                .onChange(of: enabled) { _, _ in
                                    FeatureRuntime.shared.sync([.shelf])
                                    FeatureRuntime.shared.finishAvailabilityChange()
                                }
                        }
                    }
                    if enabled {
                        IslandDestinationSettings(destination: .files)
                            .padding(.leading, settingsRowTextInset)
                    }
                    ShortcutPreferenceRow(role: .shelf, label: UtilitySettingsCopy.globalShortcut(l10n)) {
                        ShelfService.shared.syncHotkey()
                    }
                    .disabled(!enabled)
                }
            }

                Section {
                    if shortcutEnabled, shelf.hotkeyRegistrationFailed {
                        Text(l10n.s.shortcutUnavailable)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if shortcutEnabled {
                        VStack(alignment: .leading, spacing: 3) {
                            Toggle(l10n.s.shelfShortcutFinderSelection, isOn: $shortcutAddsFinderSelection)
                            Text(l10n.s.shelfShortcutFinderSelectionCaption)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if shortcutAddsFinderSelection {
                                Text(l10n.s.finderAutomationNote)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Toggle(l10n.s.shelfShakeToggle, isOn: $shake)
                            .onChange(of: shake) { _, _ in
                                ShelfService.shared.syncDragMonitor()
                            }
                        Text(l10n.s.shelfShakeCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Toggle(l10n.s.shelfDropZoneToggle, isOn: $dropZone)
                            .onChange(of: dropZone) { _, _ in
                                ShelfService.shared.syncDragMonitor()
                            }
                        Text(dockPlacement == ShelfDockPlacement.topCenter.rawValue && !islandOn
                             ? l10n.s.shelfDropZoneCaptionTopCenter : l10n.s.shelfDropZoneCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if dropZone {
                        VStack(alignment: .leading, spacing: 3) {
                            Picker(l10n.s.shelfDockPlacement, selection: $dockPlacement) {
                                Text(l10n.s.shelfDockMenuBar).tag(ShelfDockPlacement.menuBar.rawValue)
                                Text(l10n.s.shelfDockTopCenter).tag(ShelfDockPlacement.topCenter.rawValue)
                            }
                            .disabled(islandOn)
                            .onChange(of: dockPlacement) { _, _ in
                                ShelfService.shared.syncDockedShelf()
                            }
                            if islandOn {
                                Text(l10n.s.shelfDockIslandNote)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Toggle(l10n.s.shelfEdgeToggle, isOn: $edgeDrag)
                            .onChange(of: edgeDrag) { _, _ in
                                ShelfService.shared.syncDragMonitor()
                            }
                        Text(l10n.s.shelfEdgeCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        ShelfService.shared.summon()
                    } label: {
                        Label(l10n.s.shelfOpenNow, systemImage: "tray.and.arrow.down")
                    }
                }.disabled(!enabled)

                Section(l10n.s.shelfBehaviorTitle) {
                    VStack(alignment: .leading, spacing: 3) {
                        Toggle(l10n.s.shelfCloseAfterDrop, isOn: $closeAfterDrop)
                        Text(l10n.s.shelfCloseAfterDropCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Toggle(l10n.s.shelfRemoveAfterDrop, isOn: $removeAfterDrop)
                        Text(l10n.s.shelfRemoveAfterDropCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Toggle(l10n.s.shelfClearOnClose, isOn: $clearOnClose)
                        Text(l10n.s.shelfClearOnCloseCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }.disabled(!enabled)

                Section(l10n.s.shelfExclusionsTitle) {
                    if sortedExclusions.isEmpty {
                        Text(l10n.s.shelfExclusionsEmpty)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedExclusions, id: \.self) { bundleID in
                            HStack(spacing: 9) {
                                Image(nsImage: InstalledApps.icon(for: bundleID))
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                Text(InstalledApps.name(for: bundleID))
                                Spacer()
                                Button {
                                    shelf.removeAutomaticExclusion(bundleID)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Button {
                        showingAppPicker = true
                    } label: {
                        Label(l10n.s.autoQuitAddApp, systemImage: "plus")
                    }
                    Text(l10n.s.shelfExclusionsCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }.disabled(!enabled)
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .controlSize(.regular)
        .sheet(isPresented: $showingAppPicker) {
            appPickerSheet
        }
    }

    private var islandOn: Bool {
        islandEnabled && islandFileCache && NotchSupport.isEnabled()
            && !islandHiddenModules.split(separator: ",").contains(Substring(IslandDestination.files.rawValue))
    }

    private var sortedExclusions: [String] {
        shelf.automaticExclusions.sorted {
            InstalledApps.name(for: $0)
                .localizedCaseInsensitiveCompare(InstalledApps.name(for: $1)) == .orderedAscending
        }
    }

    private var appPickerSheet: some View {
        let excluded = Set(shelf.automaticExclusions)
        return AppPickerView {
            showingAppPicker = false
        } onSelect: { url in
            showingAppPicker = false
            guard let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
            shelf.addAutomaticExclusion(bundleID)
        } loadApps: {
            InstalledApps.installedBundleApplications(excluding: excluded)
        }
    }

}
