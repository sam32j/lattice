// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum UtilitySettingsTests {
    static func run(_ expect: (Bool, String) -> Void) {
        expect(AppFeature.scratchpad.settingsDestination
               == FeatureSettingsDestination(.scratchpad, sectionAnchor: .scratchpad),
               "selecting Scratchpad opens its dedicated page in Clipboard and Files")
        expect(AppFeature.cleaningMode.settingsDestination
               == FeatureSettingsDestination(.keyboard, sectionAnchor: .cleaningMode),
               "selecting Cleaning Mode opens its Keyboard section")
        expect(AppFeature.micMute.settingsDestination
               == FeatureSettingsDestination(.audio, sectionAnchor: .micMute),
               "selecting Mic Mute opens the Input segment of Audio")
        expect(AppFeature.mixer.settingsDestination
               == FeatureSettingsDestination(.audio, sectionAnchor: .mixer),
               "selecting Volume Mixer opens the Output segment of Audio")
        expect(AppFeature.quickLauncher.settingsDestination
               == FeatureSettingsDestination(.general)
               && AppFeature.cameraPreview.settingsDestination
               == FeatureSettingsDestination(.general, sectionAnchor: .cameraPreview),
               "Lattice Hub and Camera Preview open General settings")
        expect(!AppFeature.allCases.contains { $0.rawValue == "quickToggles" },
               "Quick Toggles is not independently installable")
        expect(Action.allCases.allSatisfy { $0.isAvailable },
               "quick actions are built-in and independent from Command Bar or Displays")
        expect(RadialMenuQuickToggle.allCases.allSatisfy { $0.isAvailable },
               "radial menu quick toggles remain available independently")
        expect(AppFeature.wallpaper.settingsDestination
               == FeatureSettingsDestination(.energy, sectionAnchor: .wallpaper),
               "Wallpaper links open its section in Displays preferences")
        for feature in [AppFeature.focusFollowsMouse, .keyboardDebounce] {
            let item = SettingsSearchItem(id: .feature(feature), destination: feature.settingsDestination,
                                          title: feature.rawValue, icon: feature.symbolName, feature: feature)
            let route = SettingsSearchSupport.route(for: item, isAvailable: { _ in false })
            expect(route.destination == feature.settingsDestination && route.targetFeature == nil,
                   "a disabled input control routes to its permanent preferences rather than a missing hub row")
        }
    }
}
