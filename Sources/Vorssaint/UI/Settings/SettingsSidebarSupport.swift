// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// A page or a directly selectable tool in the flat Settings sidebar.
struct SettingsSidebarItem: Identifiable {
    enum ID: Hashable {
        case page(SettingsPage)
        case feature(AppFeature)
        case setting(SettingsSectionAnchor)
    }

    let id: ID
    let destination: FeatureSettingsDestination
    let title: String
    let icon: String
}

/// A stable category in the sidebar; its title follows the selected language.
struct SettingsSidebarSection: Identifiable {
    let id: Int
    let title: String
    let items: [SettingsSidebarItem]
}

/// Builds one row per tool, even when several tools share one Settings card.
enum SettingsSidebarSupport {
    static func items(page: SettingsPage, title: String, icon: String,
                      preferredFeatures: [AppFeature], includePage: Bool,
                      isAvailable: (AppFeature) -> Bool,
                      featureTitle: (AppFeature) -> String) -> [SettingsSidebarItem] {
        guard FeatureVisibilitySupport.isPageVisible(page, isAvailable: isAvailable) else { return [] }
        let pageItem = SettingsSidebarItem(id: .page(page),
                                           destination: FeatureSettingsDestination(page),
                                           title: title, icon: icon)
        if page == .screenshot || page == .screenRecorder || page == .shortcuts || page == .mouse || page == .keyboard || page == .audioInput || page == .audioOutput || page == .scratchpad {
            return [pageItem]
        }
        var rows = includePage ? [pageItem] : []
        var seenFeatures: Set<AppFeature> = []
        for feature in preferredFeatures + AppFeature.allCases {
            guard seenFeatures.insert(feature).inserted else { continue }
            let destination = feature.settingsDestination
            guard destination.page == page, destination.sectionAnchor != nil,
                  isAvailable(feature) else { continue }
            rows.append(SettingsSidebarItem(id: .feature(feature),
                                            destination: destination,
                                            title: featureTitle(feature),
                                            icon: feature.symbolName))
        }
        if rows.isEmpty { rows.append(pageItem) }
        return rows
    }

    /// Splits window and control rows, and takes input, file and sound tools
    /// out of Utilities, so the sidebar groups them as the Features page does.
    /// Rows of other groups, or of no feature, stay where they are.
    static func featureGroupRows(windowsControls: [SettingsSidebarItem],
                                 utilities: [SettingsSidebarItem])
        -> (windowsDock: [SettingsSidebarItem], mouseKeyboard: [SettingsSidebarItem],
            files: [SettingsSidebarItem], sound: [SettingsSidebarItem],
            utilities: [SettingsSidebarItem]) {
        func group(_ item: SettingsSidebarItem) -> FeatureGroup? {
            if case .feature(let feature) = item.id { return feature.group }
            if item.destination.page == .mouse || item.destination.page == .keyboard { return .mouseKeyboard }
            if item.destination.page == .textSnippets { return .clipboardFiles }
            return AppFeature.allCases.first { $0.settingsDestination == item.destination }?.group
        }
        func moved(_ target: FeatureGroup) -> [SettingsSidebarItem] {
            utilities.filter { group($0) == target }
        }
        return (windowsControls.filter { group($0) == .windowsDock },
                windowsControls.filter { group($0) != .windowsDock } + moved(.mouseKeyboard),
                moved(.clipboardFiles), moved(.sound),
                utilities.filter { ![.mouseKeyboard, .clipboardFiles, .sound].contains(group($0)) })
    }

    static func fallbackDestination(for destination: FeatureSettingsDestination,
                                    in items: [SettingsSidebarItem]) -> FeatureSettingsDestination? {
        guard destination.sectionAnchor != nil,
              !items.contains(where: { $0.destination == destination }) else { return nil }
        switch destination.page {
        case .general:
            return FeatureSettingsDestination(.general)
        case .mouse:
            return FeatureSettingsDestination(.mouse)
        case .keyboard:
            return FeatureSettingsDestination(.keyboard)
        case .audioInput:
            return FeatureSettingsDestination(.audioInput)
        case .audioOutput:
            return FeatureSettingsDestination(.audioOutput)
        case .scratchpad:
            return FeatureSettingsDestination(.scratchpad)
        case .energy:
            return items.first { $0.destination.page == destination.page }?.destination
        default:
            return nil
        }
    }

    static func selection(for destination: FeatureSettingsDestination,
                          in items: [SettingsSidebarItem],
                          preferredID: SettingsSidebarItem.ID? = nil)
        -> SettingsSidebarItem.ID? {
        if let preferredID,
           items.contains(where: { $0.id == preferredID && $0.destination == destination }) {
            return preferredID
        }
        if destination.sectionAnchor != nil,
           let tool = items.first(where: { $0.destination == destination }) {
            return tool.id
        }
        if items.contains(where: { $0.id == .page(destination.page) }) {
            return .page(destination.page)
        }
        return items.first(where: { $0.destination.page == destination.page })?.id
    }
}
