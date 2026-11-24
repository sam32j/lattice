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
    /// Keyed by page too: brightness has rows on two pages (Display and
    /// Keyboard), and each opens on its own.
    @State private var expandedFeatures: [String: Set<AppFeature>] = [:]
    @State private var showsAppShortcuts = false

    private var text: ShortcutSettingsStrings { FeatureStrings.shortcuts(l10n.language) }
    private var hub: FeatureHubStrings { FeatureStrings.hub(l10n.language) }

    private var captureRoles: [GlobalShortcutRole] {
        GlobalShortcutRole.captureRoles(in: availableRoles)
    }

    /// The Settings sidebar's own sections, in its order, each with the
    /// pages it lists. Shortcuts are grouped by the page that owns their
    /// feature, so this page always reads like the sidebar beside it.
    private var sidebarSections: [ShortcutSection] {
        SettingsDirectory.sections(l10n.s, language: l10n.language).map { section in
            ShortcutSection(title: section.title, pages: section.items.map(\.page))
        }
    }

    /// Where a shortcut lives: its feature's Settings page. Keyboard
    /// backlight keys sit with the keyboard settings, whatever feature
    /// drives them.
    private func page(for role: GlobalShortcutRole) -> SettingsPage {
        role.isKeyboardBrightness ? .keyboard : page(for: role.feature)
    }

    private func page(for feature: AppFeature) -> SettingsPage {
        GlobalShortcutRole.captureFeatures.contains(feature) ? .screenshot : feature.settingsDestination.page
    }

    /// The section listing `page`; a feature without a page of its own in
    /// the sidebar joins the last section before Lattice's own.
    private func section(for page: SettingsPage, in sections: [ShortcutSection]) -> ShortcutSection? {
        sections.first { $0.pages.contains(page) } ?? sections.dropLast().last
    }

    /// One row group per feature and page, in sidebar page order and then
    /// the catalog's order, under the section that lists the page.
    private func entries(in sections: [ShortcutSection]) -> [(section: ShortcutSection, features: [ShortcutEntry])] {
        var bySection: [ShortcutSection: [ShortcutEntry]] = [:]
        func add(_ feature: AppFeature, page: SettingsPage) {
            guard let target = section(for: page, in: sections) else { return }
            let entry = ShortcutEntry(feature: feature, page: page)
            if !(bySection[target]?.contains(entry) ?? false) { bySection[target, default: []].append(entry) }
        }
        for feature in AppFeature.allCases {
            if feature == .screenshot {
                if !captureRoles.isEmpty { add(feature, page: .screenshot) }
                continue
            }
            if GlobalShortcutRole.captureFeatures.contains(feature) { continue }
            if feature == .windowLayout {
                if feature.isAvailable { add(feature, page: page(for: feature)) }
                continue
            }
            for role in availableRoles where role.feature == feature {
                add(feature, page: page(for: role))
            }
        }
        return sections.compactMap { section in
            guard let features = bySection[section], !features.isEmpty else { return nil }
            let order = { (entry: ShortcutEntry) -> Int in
                section.pages.firstIndex(of: entry.page) ?? section.pages.count
            }
            let sorted = features.enumerated().sorted { lhs, rhs in
                (order(lhs.element), lhs.offset) < (order(rhs.element), rhs.offset)
            }.map(\.element)
            return (section, sorted)
        }
    }

    var body: some View {
        let sections = sidebarSections
        Form {
            ForEach(entries(in: sections), id: \.section) { entry in
                Section(entry.section.title) {
                    ForEach(entry.features, id: \.self) { item in
                        if item.feature == .screenshot {
                            captureGroupRows(in: item.expansionKey)
                        } else {
                            featureRows(item.feature, on: item.page, in: item.expansionKey)
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

    /// One group for every capture tool's shortcut. Rows keep each tool's own
    /// icon; the group carries the shared page's name and symbol.
    @ViewBuilder
    private func captureGroupRows(in group: String) -> some View {
        let roles = captureRoles
        disclosureHeader(
            title: FeatureStrings.screenshot(l10n.language).screenCaptureTitle,
            symbolName: AppFeature.screenshot.symbolName,
            isActive: featureHasActiveShortcut(.screenshot, roles: roles),
            count: roles.count,
            isExpanded: expansionBinding(for: .screenshot, in: group))
        if expandedFeatures[group, default: []].contains(.screenshot) {
            ForEach(roles) { role in
                roleRow(role, showsFeatureContext: false)
                    .disclosureIndent()
            }
        }
    }

    @ViewBuilder
    private func featureRows(_ feature: AppFeature, on featurePage: SettingsPage,
                             in group: String) -> some View {
        let roles = availableRoles.filter { $0.feature == feature && page(for: $0) == featurePage }
        let count = feature == .windowLayout
            ? WindowLayoutAction.shortcutActions.count + roles.count
            : roles.count
        if count > 1 {
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
                               count: Int, in group: String) -> some View {
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
        let featureTitle = role.feature.hubTitle(l10n.s, hub: hub)
        // Here the row names the feature; its own page keeps the longer
        // "Open Camera Preview with shortcut".
        let title = role == .cameraPreview ? featureTitle : role.title(l10n.s)
        let active = role.savedShortcut.isValid && role.requiredEnableKeys.allSatisfy {
            UserDefaults.standard.bool(forKey: $0)
        }
        return ShortcutPreferenceRow(
            role: role,
            label: title,
            symbolName: role == .darkMode ? "circle.lefthalf.filled" : (role == .ejectDisks ? "eject" : (role.isKeyboardBrightness ? "keyboard" : role.feature.symbolName)),
            contextLabel: showsFeatureContext && role != .snippetLibrary && title != featureTitle ? featureTitle : nil,
            statusText: active ? text.active : text.inactive,
            statusIsActive: active,
            showsSuperKeyAlternative: superKey.isRunning,
            superKeyModifiers: superKey.modifiers,
            additionalConflict: { shortcut in
                guard AppFeature.windowLayout.isAvailable else { return nil }
                return WindowLayoutService.shared.shortcutConflictTitle(shortcut, excluding: nil)
            },
            onChange: {
                FeatureRuntime.shared.sync(role.availabilityFeatures)
                if role == .darkMode || role == .ejectDisks {
                    QuickTogglesService.shared.syncWithPreferences()
                }
            }
        )
    }

    private func expansionBinding(for feature: AppFeature, in group: String) -> Binding<Bool> {
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
}

/// A Settings sidebar section, as the Shortcuts page groups by it.
private struct ShortcutSection: Hashable {
    let title: String
    let pages: [SettingsPage]
}

/// A feature's shortcuts as listed on one Settings page.
private struct ShortcutEntry: Hashable {
    let feature: AppFeature
    let page: SettingsPage

    /// Remembers which disclosures are open, per page.
    var expansionKey: String { String(describing: page) }
}

/// Conflicts the radial menu's shortcut row checks beyond the Lattice roles.
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
