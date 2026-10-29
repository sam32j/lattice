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
        if page == .monitor || page == .dock || page == .windowLayout || page == .clipboard || page == .wallpaper || page == .screenshot || page == .screenRecorder || page == .shortcuts || page == .mouse || page == .keyboard || page == .audioInput || page == .audioOutput || page == .scratchpad {
            return [pageItem]
        }
        var rows = includePage ? [pageItem] : []
        var seenFeatures: Set<AppFeature> = []
        let candidateFeatures = preferredFeatures.isEmpty ? AppFeature.allCases : preferredFeatures
        for feature in candidateFeatures {
            guard seenFeatures.insert(feature).inserted else { continue }
            let destination = feature.settingsDestination
            guard destination.page == page, destination.sectionAnchor != nil,
                  feature != .extraBrightness,
                  feature != .wallpaper,
                  (feature == .brightness || feature == .bluetoothSleep || feature == .switcher || feature.isVisibleInSettings(isAvailable: isAvailable)) else { continue }
            rows.append(SettingsSidebarItem(id: .feature(feature),
                                            destination: destination,
                                            title: featureTitle(feature),
                                            icon: feature.symbolName))
        }
        if rows.isEmpty { rows.append(pageItem) }
        return rows
    }

    static func fallbackDestination(for destination: FeatureSettingsDestination,
                                    in items: [SettingsSidebarItem]) -> FeatureSettingsDestination? {
        guard destination.sectionAnchor != nil,
              !items.contains(where: { $0.destination == destination }) else { return nil }
        switch destination.page {
        case .general:
            return FeatureSettingsDestination(.general)
        case .mouse, .keyboard, .audioInput, .audioOutput, .scratchpad:
            return items.contains { $0.id == .page(destination.page) }
                ? nil : FeatureSettingsDestination(destination.page)
        case .energy:
            if destination.sectionAnchor == .extraBrightness, items.contains(where: { $0.id == .feature(.brightness) }) { return nil }
            return items.first { $0.destination.page == destination.page }?.destination
        default:
            return nil
        }
    }

    static func selection(for destination: FeatureSettingsDestination,
                          in items: [SettingsSidebarItem],
                          preferredID: SettingsSidebarItem.ID? = nil)
        -> SettingsSidebarItem.ID? {
        if destination.page == .energy, destination.sectionAnchor == .extraBrightness,
           items.contains(where: { $0.id == .feature(.brightness) }) { return .feature(.brightness) }
        if let preferredID,
           items.contains(where: { $0.id == preferredID && $0.destination == destination }) {
            return preferredID
        }
        if destination.sectionAnchor != nil,
           let tool = items.first(where: { $0.destination == destination }) {
            return tool.id
        }
        if case .notchWidget = destination.page { return .page(.notch) }
        if destination.page == .notchCompanion || destination.page == .notchMascot { return .page(.notch) }
        if items.contains(where: { $0.id == .page(destination.page) }) {
            return .page(destination.page)
        }
        return items.first(where: { $0.destination.page == destination.page })?.id
    }
}
