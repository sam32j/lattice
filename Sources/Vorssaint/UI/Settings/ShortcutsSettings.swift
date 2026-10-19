// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The central editor for every global shortcut belonging to an installed
/// feature. It writes the same preferences as each feature page, so there is
/// still one setting and one registration path for every action.
struct ShortcutsSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var superKey = SuperKeyService.shared
    /// Keyed by group too: brightness has a row in two groups, and each opens on its own.
    @State private var expandedFeatures: [FeatureGroup: Set<AppFeature>] = [.tools: [.screenshot]]
    @State private var showsAppShortcuts = false

    private var text: ShortcutSettingsStrings { FeatureStrings.shortcuts(l10n.language) }
    private var hub: FeatureHubStrings { FeatureStrings.hub(l10n.language) }

    private var availableRoles: [GlobalShortcutRole] {
        GlobalShortcutRole.availableRoles(isAvailable: { $0.isAvailable }).filter {
            !$0.isKeyboardBrightness || BrightnessService.keyboardLightIsSupported
        }
    }

    private var captureRoles: [GlobalShortcutRole] {
        GlobalShortcutRole.captureRoles(in: availableRoles)
    }

    private var visibleGroups: [FeatureGroup] {
        FeatureGroup.allCases.filter { group in
            availableRoles.contains { $0.group == group }
                || (group == .windowsDock && AppFeature.windowLayout.isAvailable)
        }
    }

    var body: some View {
        Form {
            Section {
                Text(l10n.s.shortcutsPageCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
    private func featureRows(_ feature: AppFeature, in group: FeatureGroup) -> some View {
        let roles = availableRoles.filter { $0.feature == feature && $0.group == group }
        let count = feature == .windowLayout
            ? WindowLayoutAction.shortcutActions.count + roles.count
            : roles.count
        if feature == .radialMenu {
            RadialMenuShortcutsRow(text: text)
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
            contextLabel: showsFeatureContext && title != featureTitle ? featureTitle : nil,
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

/// Each wheel answers to the shortcut saved in its own profile, and the radial
/// menu's role key only seeds the first wheel until one is saved. A recorder for
/// that key would then show a combination no wheel uses and change nothing, so
/// the row lists what the wheels answer to and leaves the change to the Radial
/// menu page.
private struct RadialMenuShortcutsRow: View {
    @ObservedObject private var l10n = L10n.shared
    let text: ShortcutSettingsStrings

    var body: some View {
        let role = GlobalShortcutRole.radialMenu
        let shortcuts = RadialMenuSupport.profileShortcuts()
        let active = !shortcuts.isEmpty
            && role.requiredEnableKeys.allSatisfy { UserDefaults.standard.bool(forKey: $0) }
        HStack(alignment: .top, spacing: 8) {
            ShortcutRowLabel(title: role.title(l10n.s),
                             symbolName: role.feature.symbolName,
                             contextLabel: nil,
                             statusText: active ? text.active : text.inactive,
                             statusIsActive: active)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(shortcuts.isEmpty
                     ? l10n.s.shortcutNone
                     : shortcuts.map(\.displayString).joined(separator: "\n"))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                Button(FeatureStrings.radialMenu(l10n.language).manageButton) {
                    SettingsRouter.shared.request(role.feature.settingsDestination,
                                                  sidebarFeature: role.feature)
                }
            }
        }
    }
}
