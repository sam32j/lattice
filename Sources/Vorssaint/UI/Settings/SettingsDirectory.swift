// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// One Settings page as the sidebar and the command bar present it.
struct SettingsDirectoryItem: Identifiable {
    let page: SettingsPage
    let title: String
    let icon: String
    /// Labels of options living inside the page, so a search finds a page by
    /// what it contains, in the user's language.
    var keywords: [String] = []
    /// Feature ownership for keyword rows on shared pages. `nil` means the
    /// setting belongs to the page itself and remains searchable whenever the
    /// page is visible.
    var keywordFeatures: [AppFeature?] = []
    var id: SettingsPage { page }

    init(page: SettingsPage, title: String, icon: String,
         keywords: [String] = [],
         featureKeywords: [(feature: AppFeature, titles: [String])] = []) {
        self.page = page
        self.title = title
        self.icon = icon
        self.keywords = keywords + featureKeywords.flatMap(\.titles)
        keywordFeatures = Array(repeating: nil, count: keywords.count)
            + featureKeywords.flatMap { entry in
                Array(repeating: Optional(entry.feature), count: entry.titles.count)
            }
    }
}

/// The single map of the Settings window: sections, pages, icons and search
/// keywords. The sidebar draws its tool list from these pages; the command bar
/// searches them. One list, so a page added here is findable everywhere.
enum SettingsDirectory {
    /// Shared pages whose tools cover the page without a separate overview row.
    private static let toolOnlyPages: Set<SettingsPage> = [
        .energy, .switcher, .dock, .clipboard,
    ]

    /// Keep the directory's destinations, but show the most useful groups
    /// first and separate everyday controls from the longer tool list.
    static func sidebarSections(_ s: Strings,
                                language: AppLanguage,
                                superKeySource: SuperKeySource = SuperKeyService.shared.source,
                                keyboardLightSupported: Bool = BrightnessService.keyboardLightIsSupported,
                                isAvailable: (AppFeature) -> Bool) -> [SettingsSidebarSection] {
        let hub = FeatureStrings.hub(language)
        return sections(
            s, language: language, superKeySource: superKeySource
        ).enumerated().compactMap { index, section -> SettingsSidebarSection? in
            let items = section.items.flatMap { pageItem -> [SettingsSidebarItem] in
                var rows = SettingsSidebarSupport.items(
                    page: pageItem.page, title: pageItem.title, icon: pageItem.icon,
                    preferredFeatures: pageItem.keywordFeatures.compactMap { $0 },
                    includePage: !toolOnlyPages.contains(pageItem.page),
                    isAvailable: isAvailable) { feature in
                        if feature == .clipboardHistory {
                            return FeatureStrings.commandBar(language).sourceClipboard
                        }
                        return feature.hubTitle(s, hub: hub)
                    }
                if pageItem.page == .energy, pageItem.keywordFeatures.contains(where: { $0 == .brightness }),
                   AppFeature.extraBrightness.isHardwareSupported,
                   !rows.contains(where: { $0.id == .feature(.brightness) }) {
                    rows.removeAll { $0.id == .page(.energy) }
                    rows.insert(SettingsSidebarItem(
                        id: .feature(.brightness),
                        destination: FeatureSettingsDestination(.energy, sectionAnchor: .brightness),
                        title: FeatureStrings.brightness(language).pageTitle, icon: "display.2"), at: 0)
                }
                if pageItem.page == .general {
                    rows.insert(SettingsSidebarItem(
                        id: .setting(.panelConfiguration),
                        destination: FeatureSettingsDestination(
                            .general, sectionAnchor: .panelConfiguration),
                        title: s.menuBarSection, icon: "menubar.rectangle"), at: 1)
                }
                if pageItem.page == .energy {
                    rows.removeAll { $0.id == .feature(.keepAwake) }
                }
                if pageItem.page == .monitor, AppFeature.keepAwake.isVisibleInSettings(isAvailable: isAvailable) {
                    rows.insert(SettingsSidebarItem(
                        id: .feature(.keepAwake), destination: AppFeature.keepAwake.settingsDestination,
                        title: s.keepAwakeTitle, icon: AppFeature.keepAwake.symbolName), at: 0)
                }
                return rows
            }
            guard !items.isEmpty else { return nil }
            return SettingsSidebarSection(id: index, title: section.title, items: items)
        }
    }

    static func sidebarItems(_ s: Strings,
                             language: AppLanguage,
                             superKeySource: SuperKeySource = SuperKeyService.shared.source,
                             isAvailable: (AppFeature) -> Bool) -> [SettingsSidebarItem] {
        sidebarSections(s, language: language, superKeySource: superKeySource,
                        isAvailable: isAvailable).flatMap(\.items)
    }

    /// Destination-aware rows for focused Settings and Command Bar search.
    static func searchItems(_ s: Strings,
                            language: AppLanguage,
                            superKeySource: SuperKeySource = SuperKeyService.shared.source) -> [SettingsSearchItem] {
        let pageItems = sections(s, language: language, superKeySource: superKeySource)
            .flatMap(\.items).map { item in
                SettingsSearchItem(id: .page(item.page),
                                   destination: FeatureSettingsDestination(item.page),
                                   title: item.title,
                                   icon: item.icon,
                                   keywords: item.keywords,
                                   keywordFeatures: item.keywordFeatures)
            }
        let hub = FeatureStrings.hub(language)
        let featureItems = SettingsSearchSupport.featureItems(language: language) { feature in
            feature.hubTitle(s, hub: hub)
        }
        var items = SettingsSearchSupport.combinedItems(pageItems: pageItems,
                                                        featureItems: featureItems)
        items.append(SettingsSearchItem(
            id: .setting(.panelConfiguration),
            destination: FeatureSettingsDestination(
                .general, sectionAnchor: .panelConfiguration),
            title: s.menuBarSection, icon: "menubar.rectangle",
            keywords: [SettingsFollowupStrings.text(.showMenuIcon, language),
                       FeatureStrings.generalSettings(language).menuBarIconTitle, "SF Symbols"]))
        if BrightnessService.keyboardLightIsSupported {
            items.append(SettingsSearchSupport.keyboardBrightnessShortcutItem(language: language))
        }
        return items
    }
}
