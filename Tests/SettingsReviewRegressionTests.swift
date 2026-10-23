// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum SettingsReviewRegressionTests {
    static func run(_ suite: TestSuite) {
        PermissionActivationTests.run(suite)
        PermissionRevocationTests.run(suite)
        BluetoothPermissionTests.run(suite)
        KeyboardPermissionLifecycleTests.run(suite)
        FeaturePageOwnershipTests.run(suite)
        PageOwnedServiceLifecycleTests.run(suite)
        SettingsDestinationOwnershipTests.run(suite)
        ShortcutSettingsRefreshTests.run(suite)
        InputSettingsControlTests.run(suite)
        KeyboardOverrideOrderTests.run(suite)
        KeepAwakePointerPermissionTests.run(suite)
        RadialProfileActivationTests.run(suite)
        AudioPriorityPresentationTests.run(suite)
        FeedbackDraftTests.run(suite)
        let pages = SettingsSidebarIdentityTests.Directory.sections(.enUS, language: .enUS).flatMap(\.items)
        suite.expect(Set(pages.map(\.page)).count == pages.count,
                     "the search directory contains each page exactly once")
        let pageItems = pages.map {
            SettingsSearchItem(id: .page($0.page), destination: FeatureSettingsDestination($0.page),
                               title: $0.title, icon: $0.icon, keywords: $0.keywords,
                               keywordFeatures: $0.keywordFeatures)
        }
        let awakeGroups = SettingsSearchSupport.groupedMatchingItems(
            query: Strings.enUS.keepAwakeTitle, items: pageItems, isAvailable: { _ in true })
        suite.expect(awakeGroups.contains { $0.id == .energy },
                     "the unique Energy search group retains Stay Awake keywords")
        for feature in AppFeature.allCases where feature.isManagedOnDedicatedPage {
            let item = SettingsSearchItem(id: .feature(feature), destination: feature.settingsDestination,
                                          title: feature.rawValue, icon: feature.symbolName, feature: feature)
            let route = SettingsSearchSupport.route(for: item, isAvailable: { _ in false })
            suite.expect(route.destination == feature.settingsDestination && route.targetFeature == nil,
                         "uninstalled \(feature) search opens its owning install control")
        }
        let page = SettingsSearchItem(id: .page(.dock), destination: FeatureSettingsDestination(.dock),
                                      title: "Dock", icon: "dock.rectangle",
                                      keywords: ["Preview delay"], keywordFeatures: [.dockPreview])
        let groups = SettingsSearchSupport.groupedMatchingItems(
            query: "Preview delay", items: [page], isAvailable: { _ in false })
        suite.expect(groups.first?.suggestions.first.map {
            SettingsSearchSupport.route(for: $0, isAvailable: { _ in false }).destination
        } == AppFeature.dockPreview.settingsDestination,
        "an off dedicated feature remains searchable by its settings keywords")
    }
}
