// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The central editor for every global shortcut belonging to an installed
/// feature. It writes the same preferences as each feature page, so there is
/// still one setting and one registration path for every action.
struct ShortcutsSettings: View {
    @ObservedObject private var shortcutChanges = ShortcutSettingsObserver.shared
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var superKey = SuperKeyService.shared
    /// Keyed by group too: brightness has a row in two groups, and each opens on its own.
    @State private var expandedFeatures: [FeatureGroup: Set<AppFeature>] = [:]
    @State private var showsAppShortcuts = false
    @AppStorage(DefaultsKey.radialMenuProfiles) private var radialMenuProfilesData: Data?
    @AppStorage(DefaultsKey.radialMenuEnabled) private var radialMenuEnabled = false

    private var text: ShortcutSettingsStrings { FeatureStrings.shortcuts(l10n.language) }
    private var hub: FeatureHubStrings { FeatureStrings.hub(l10n.language) }

    private var radialProfiles: [RadialMenuProfile] {
        RadialMenuSupport.decodeProfiles(radialMenuProfilesData)
    }

    private func radialMenuHasActiveShortcut(profiles: [RadialMenuProfile]) -> Bool {
        guard radialMenuEnabled else { return false }
        return profiles.contains {
            !$0.shortcut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && GlobalShortcut(storageValue: $0.shortcut) != nil
        }
    }

    private var captureRoles: [GlobalShortcutRole] {
        GlobalShortcutRole.captureRoles(in: availableRoles)
    }

    private var visibleGroups: [FeatureGroup] {
        FeatureGroup.allCases.filter { group in
            availableRoles.contains { $0.group == group }
                || (group == .windowsDock && AppFeature.windowLayout.isAvailable)
                || (group == .tools && AppFeature.radialMenu.isAvailable)
        }
    }

    var body: some View {
        Form {
            ForEach(visibleGroups, id: \.self) { group in
                Section(groupTitle(group)) {
                    ForEach(featuresWithShortcuts(in: group), id: \.self) { feature in
                        if feature == .screenshot {
                            captureGroupRows
                        } else {
                            featureRows(feature, in: group)
                        }
                    }
                }
            }

            if AppFeature.commandBar.isAvailable {
                Section {
                    Button {
                        showsAppShortcuts = true
                    } label: {
                        Label(FeatureStrings.commandBar(l10n.language).appCenterTitle,
                              systemImage: "app.badge")
                    }
                    Text(FeatureStrings.commandBar(l10n.language).appCenterCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showsAppShortcuts) {
            CommandBarAppShortcutsView()
        }
    }

    private func featuresWithShortcuts(in group: FeatureGroup) -> [AppFeature] {
        AppFeature.allCases.filter { feature in
            // The screenshot slot anchors the combined capture group; the
            // other capture tools render inside it instead of on their own.
            if feature == .screenshot { return group == .tools && !captureRoles.isEmpty }
            if GlobalShortcutRole.captureFeatures.contains(feature) { return false }
            if feature == .windowLayout {
                return group == .windowsDock && feature.isAvailable
            }
            if feature == .radialMenu {
                return group == .tools && feature.isAvailable
            }
            return availableRoles.contains { $0.feature == feature && $0.group == group }
        }
    }

    /// One group for every capture tool's shortcut. Rows keep each tool's own
    /// icon; the group carries the shared page's name and symbol.
    @ViewBuilder
    private var captureGroupRows: some View {
        let roles = captureRoles
        disclosureHeader(
            title: FeatureStrings.screenshot(l10n.language).screenCaptureTitle,
            symbolName: AppFeature.screenshot.symbolName,
            isActive: featureHasActiveShortcut(.screenshot, roles: roles),
            count: roles.count,
            isExpanded: expansionBinding(for: .screenshot, in: .tools))
        if expandedFeatures[.tools, default: []].contains(.screenshot) {
            ForEach(roles) { role in
                roleRow(role, showsFeatureContext: false)
                    .disclosureIndent()
            }
        }
    }

    @ViewBuilder
    private var radialMenuGroupRows: some View {
        let profiles = radialProfiles
        disclosureHeader(
            title: FeatureStrings.radialMenu(l10n.language).pageTitle,
            symbolName: AppFeature.radialMenu.symbolName,
            isActive: radialMenuHasActiveShortcut(profiles: profiles),
            count: profiles.count,
            isExpanded: expansionBinding(for: .radialMenu, in: .tools)
        )
        if expandedFeatures[.tools, default: []].contains(.radialMenu) {
            ForEach(profiles) { profile in
                CentralRadialMenuShortcutRow(
                    profile: profile,
                    allProfiles: profiles,
                    isRadialEnabled: radialMenuEnabled,
                    text: text,
                    showsSuperKeyAlternative: superKey.isRunning,
                    superKeyModifiers: superKey.modifiers
                )
                .disclosureIndent()
            }
        }
    }

    @ViewBuilder
    private func featureRows(_ feature: AppFeature, in group: FeatureGroup) -> some View {
        let roles = availableRoles.filter { $0.feature == feature && $0.group == group }
        let count = feature == .windowLayout
            ? WindowLayoutAction.shortcutActions.count + roles.count
            : (feature == .radialMenu ? radialProfiles.count : roles.count)
        if feature == .radialMenu {
            radialMenuGroupRows
        } else if count > 1 {
            featureHeader(feature, roles: roles, count: count, in: group)
            if expandedFeatures[group, default: []].contains(feature) {
                if feature == .windowLayout {
                    WindowLayoutShortcutActivation()
                    ForEach(WindowLayoutAction.shortcutActions) { action in
                        CentralWindowLayoutShortcutRow(
                            action: action,
                            showsSuperKeyAlternative: superKey.isRunning,
                            superKeyModifiers: superKey.modifiers,
                            text: text
                        )
                        .disclosureIndent()
                    }
                    ForEach(roles) { role in
                        roleRow(role, showsFeatureContext: false)
                            .disclosureIndent()
                    }
                } else {
                    ForEach(roles) { role in
                        roleRow(role, showsFeatureContext: false)
                            .disclosureIndent()
                    }
                }
            }
        } else if let role = roles.first {
            if feature.settingsDestination.page == .shortcuts,
               let anchor = feature.settingsDestination.sectionAnchor {
                roleRow(role).settingsSectionAnchor(anchor)
            } else {
                roleRow(role)
            }
        }
    }

    private func featureHeader(_ feature: AppFeature, roles: [GlobalShortcutRole],
                               count: Int, in group: FeatureGroup) -> some View {
        disclosureHeader(
            title: featureTitle(feature, roles: roles),
            symbolName: featureSymbol(feature, roles: roles),
            isActive: featureHasActiveShortcut(feature, roles: roles),
            count: count,
            isExpanded: expansionBinding(for: feature, in: group))
    }

    private func featureTitle(_ feature: AppFeature, roles: [GlobalShortcutRole]) -> String {
        if !roles.isEmpty, roles.allSatisfy(\.isKeyboardBrightness) {
            return FeatureStrings.brightness(l10n.language).keyboardLight
        }
        return feature.hubTitle(l10n.s, hub: hub)
    }

    private func featureSymbol(_ feature: AppFeature, roles: [GlobalShortcutRole]) -> String {
        !roles.isEmpty && roles.allSatisfy(\.isKeyboardBrightness)
            ? "keyboard" : feature.symbolName
    }

    private func disclosureHeader(title: String,
                                  symbolName: String,
                                  isActive: Bool,
                                  count: Int,
                                  isExpanded: Binding<Bool>) -> some View {
        DisclosureHeaderRow(isExpanded: isExpanded) {
            ShortcutRowLabel(
                title: title,
                symbolName: symbolName,
                contextLabel: nil,
                statusText: isActive ? text.active : text.inactive,
                statusIsActive: isActive
            )
            Spacer()
            Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.primary.opacity(0.06)))
        }
    }

    private func roleRow(_ role: GlobalShortcutRole,
                         showsFeatureContext: Bool = true) -> some View {
        let title = role.title(l10n.s)
        let featureTitle = role.feature.hubTitle(l10n.s, hub: hub)
        let active = role.savedShortcut.isValid && role.requiredEnableKeys.allSatisfy {
            UserDefaults.standard.bool(forKey: $0)
        }
        return ShortcutPreferenceRow(
            role: role,
            label: title,
            symbolName: role.isKeyboardBrightness ? "keyboard" : role.feature.symbolName,
            contextLabel: showsFeatureContext && role != .snippetLibrary && title != featureTitle ? featureTitle : nil,
            statusText: active ? text.active : text.inactive,
            statusIsActive: active,
            showsSuperKeyAlternative: superKey.isRunning,
            superKeyModifiers: superKey.modifiers,
            includeInactiveConflicts: true,
            additionalConflict: { shortcut in
                guard AppFeature.windowLayout.isAvailable else { return nil }
                return WindowLayoutService.shared.shortcutConflictTitle(shortcut, excluding: nil)
            },
            onChange: {
                FeatureRuntime.shared.sync(role.availabilityFeatures)
            }
        )
    }

    private func expansionBinding(for feature: AppFeature, in group: FeatureGroup) -> Binding<Bool> {
        Binding {
            expandedFeatures[group, default: []].contains(feature)
        } set: { expanded in
            if expanded {
                expandedFeatures[group, default: []].insert(feature)
            } else {
                expandedFeatures[group, default: []].remove(feature)
            }
        }
    }

    private func featureHasActiveShortcut(_ feature: AppFeature,
                                          roles: [GlobalShortcutRole]) -> Bool {
        if feature == .windowLayout,
           UserDefaults.standard.bool(forKey: DefaultsKey.windowLayoutShortcutsEnabled),
           WindowLayoutAction.shortcutActions.contains(where: { $0.savedShortcut != nil }) {
            return true
        }
        return roles.contains { role in
            role.savedShortcut.isValid
                && role.requiredEnableKeys.allSatisfy { UserDefaults.standard.bool(forKey: $0) }
        }
    }

    private func groupTitle(_ group: FeatureGroup) -> String {
        switch group {
        case .windowsDock: return hub.groupWindowsDock
        case .mouseKeyboard: return hub.groupMouseKeyboard
        case .clipboardFiles: return hub.groupClipboardFiles
        case .sound: return hub.groupSound
        case .energyDisplay: return hub.groupEnergyDisplay
        case .tools: return hub.groupTools
        case .dynamicIsland: return FeatureStrings.notch(l10n.language).title
        case .monitor: return hub.groupMonitor
        }
    }
}

/// The radial menu's shortcut row provides a synced keyboard shortcut setter
/// for each profile, keeping both settings surfaces in two-way sync.
private struct CentralRadialMenuShortcutRow: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var superKey = SuperKeyService.shared
    let profile: RadialMenuProfile
    let allProfiles: [RadialMenuProfile]
    let isRadialEnabled: Bool
    let text: ShortcutSettingsStrings
    let showsSuperKeyAlternative: Bool
    let superKeyModifiers: GlobalShortcutModifiers

    @State private var errorText: String?
    @State private var isRecording = false

    private var radialText: RadialMenuFeatureStrings {
        FeatureStrings.radialMenu(l10n.language)
    }

    private var shortcut: GlobalShortcut? {
        GlobalShortcut(storageValue: profile.shortcut)
    }

    private var isActive: Bool {
        isRadialEnabled && shortcut != nil
    }

    private var superKeyAlternative: String? {
        guard showsSuperKeyAlternative, let shortcut else { return nil }
        return shortcut.superKeyAlternative(
            sourceLabel: FeatureStrings.superKey(l10n.language).sourceLabel(superKey.source),
            superKeyModifiers: superKeyModifiers
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 8) {
                ShortcutRowLabel(
                    title: profile.displayName(radialText),
                    symbolName: AppFeature.radialMenu.symbolName,
                    contextLabel: nil,
                    statusText: isActive ? text.active : text.inactive,
                    statusIsActive: isActive
                )
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    CompactShortcutBindingRecorder(
                        recordingID: "central-radial-profile-\(profile.id.uuidString)",
                        shortcut: shortcut,
                        isEnabled: true,
                        width: 140,
                        emptyTitle: l10n.s.shortcutNone,
                        canClear: shortcut != nil,
                        canReset: false,
                        errorText: $errorText,
                        onClear: {
                            errorText = nil
                            saveShortcut("")
                        },
                        onReset: {},
                        onCapture: { newShortcut in
                            if let owner = RadialMenuSupport.conflictTitle(
                                for: newShortcut,
                                excluding: profile.id,
                                in: allProfiles,
                                radialText: radialText,
                                strings: l10n.s,
                                additionalConflict: { SettingsShortcutConflicts.title(for: $0, language: l10n.language) }
                            ) {
                                errorText = String(format: l10n.s.shortcutConflictFormat, owner)
                                return
                            }
                            errorText = nil
                            saveShortcut(newShortcut.storageValue)
                        },
                        onRecordingChange: { isRecording = $0 }
                    )
                    if let alternative = superKeyAlternative {
                        Text(String(format: text.superKeyAlternativeFormat, alternative))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(alternative)
                    }
                }
            }
            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if isRecording {
                Text(ShortcutRecordingCaption.text(l10n.s, canClear: true))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func saveShortcut(_ storageValue: String) {
        RadialMenuSupport.updateShortcut(storageValue, for: profile.id)
        FeatureRuntime.shared.sync([.radialMenu])
    }
}

/// Conflicts shared by the central and per-profile radial shortcut editors.
enum SettingsShortcutConflicts {
    static func title(for shortcut: GlobalShortcut, language: AppLanguage) -> String? {
        if AppFeature.windowLayout.isAvailable,
           let title = WindowLayoutService.shared.shortcutConflictTitle(shortcut) {
            return title
        }
        guard AppFeature.commandBar.isAvailable,
              let row = CommandBarRowShortcuts.key(for: shortcut, in: CommandBarService.shared.rowShortcuts)
        else { return nil }
        return CommandBarService.shared.entryTitle(forStableKey: row)
            ?? FeatureStrings.commandBar(language).namedTitle
    }
}
