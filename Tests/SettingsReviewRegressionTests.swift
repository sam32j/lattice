// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum SettingsReviewRegressionTests {
    static func run(_ suite: TestSuite) {
        PermissionRowActionPolicyTests.run(suite)
        DataPermissionsLayoutTests.run(suite)
        SettingsFollowupBehaviorTests.run(suite)
        DockClickModeTests.run(suite)
        TextRecognitionRecoveryTests.run(suite)
        VisionTextRecognitionTests.run(suite)
        ScreenTextOutcomeTests.run(suite)
        PermissionActivationTests.run(suite)
        DeferredPermissionActivationTests.run(suite)
        LockSoundServiceTests.run(suite)
        NotchVisualizerActivationTests.run(suite)
        PermissionRevocationTests.run(suite)
        CameraPermissionRevocationTests.run(suite)
        PermissionRevocationRuntimeTests.run(suite)
        PermissionRevocationTrackerTests.run(suite)
        SnippetDelayedInsertionTests.run(suite)
        BluetoothRevocationTests.run(suite)
        BluetoothPermissionTests.run(suite)
        KeyboardPermissionLifecycleTests.run(suite)
        FeaturePageOwnershipTests.run(suite)
        PageOwnedServiceLifecycleTests.run(suite)
        RemainingPageLifecycleTests.run(suite)
        FeatureOwnedWorkTests.run(suite)
        PageScheduleLifecycleTests.run(suite)
        PageCommandDiscoveryTests.run(suite)
        SettingsDestinationOwnershipTests.run(suite)
        ShortcutSettingsRefreshTests.run(suite)
        PR12DestinationTests.run(suite)
        InputSettingsControlTests.run(suite)
        KeyboardOverrideOrderTests.run(suite)
        KeepAwakePointerPermissionTests.run(suite)
        KeyboardLightShortcutAvailabilityTests.run(suite)
        MouseShortcutBackupTests.run(suite)
        CleaningModeManualAvailabilityTests.run(suite)
        AudioPriorityPresentationTests.run(suite)
        FeedbackDraftTests.run(suite)
        FeedbackWindowPresentationTests.run(suite)
        UpdateInitializationTests.run(suite)
        WindowLayoutFeedbackTests.run(suite)
        ReviewTimingTests.run(suite)
        let pages = SettingsSidebarIdentityTests.Directory.sections(.enUS, language: .enUS).flatMap(\.items)
        suite.expect(Set(pages.map(\.page)).count == pages.count,
                     "the search directory contains each page exactly once")
        let pageItems = pages.map {
            SettingsSearchItem(id: .page($0.page), destination: FeatureSettingsDestination($0.page),
                               title: $0.title, icon: $0.icon, keywords: $0.keywords,
                               keywordFeatures: $0.keywordFeatures,
                               keywordRequirements: $0.keywordRequirements, aliases: $0.aliases)
        }
        let featureItems = SettingsSearchSupport.featureItems(language: .enUS) { feature in
            feature.hubTitle(.enUS, hub: FeatureStrings.hub(.enUS), language: .enUS)
        }
        let searchItems = SettingsSearchSupport.combinedItems(pageItems: pageItems, featureItems: featureItems)
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

        let processGroups = SettingsSearchSupport.groupedMatchingItems(query: "Process", items: searchItems, isAvailable: { _ in true })
        let processGroup = processGroups.first { $0.id == SettingsPage.killProcess }
        suite.expect(processGroup != nil && (processGroup?.suggestions.isEmpty ?? false),
                     "searching 'Process' matches Process Manager without redundant child suggestions")

        let portGroups = SettingsSearchSupport.groupedMatchingItems(query: "Port", items: searchItems, isAvailable: { _ in true })
        let portGroup = portGroups.first { $0.id == SettingsPage.killProcess }
        let portTitles = portGroup?.suggestions.map { $0.title } ?? []
        suite.expect(portGroup != nil && portTitles == [FeatureStrings.killProcessList(.enUS).scopePorts],
                     "searching 'Port' matches Process Manager with single 'Ports' suggestion and no outdated indices")

        let bluetoothGroups = SettingsSearchSupport.groupedMatchingItems(query: "Bluetooth", items: searchItems, isAvailable: { _ in true })
        let bluetoothGroup = bluetoothGroups.first { group in
            group.suggestions.contains { $0.title == FeatureStrings.bluetoothSleep(.enUS).enable }
        }
        let sleepRow = bluetoothGroup?.suggestions.first { $0.title == FeatureStrings.bluetoothSleep(.enUS).enable }
        suite.expect(sleepRow != nil && bluetoothGroup?.pageItem.destination.page == .energy,
                     "searching 'Bluetooth' lists the sleep switch under Display & Energy")
        suite.expect(!bluetoothGroups.contains { $0.pageItem.id == .feature(.bluetoothSleep) },
                     "Bluetooth no longer heads a search group of its own")

        let brightness = FeatureStrings.brightness(.enUS)
        let bluetooth = FeatureStrings.bluetoothSleep(.enUS)
        func titles(_ query: String, on: Set<String>) -> [String] {
            SettingsSearchSupport.groupedMatchingItems(
                query: query, items: searchItems, isAvailable: { _ in true },
                isSettingOn: { on.contains($0) }).flatMap { $0.suggestions.map(\.title) }
        }
        suite.expect(!titles("key step", on: []).contains(brightness.keyStep)
                        && titles("key step", on: [DefaultsKey.brightnessControlEnabled]).contains(brightness.keyStep),
                     "Brightness key step is searchable only while Display Control shows it")
        suite.expect(!titles("back on", on: []).contains(bluetooth.restoreToggle)
                        && titles("back on", on: [DefaultsKey.bluetoothSleepEnabled]).contains(bluetooth.restoreToggle),
                     "Turn Bluetooth back on is searchable only while its parent switch is on")
        suite.expect(sleepRow?.icon == "dot.radiowaves.left.and.right",
                     "Bluetooth sleep keyword suggestion uses Bluetooth symbol, not display icon")
    }
}
