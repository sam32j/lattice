// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

enum UtilitySettingsTests {
    static func run(_ expect: (Bool, String) -> Void) {
        expect(AppFeature.scratchpad.settingsDestination
               == FeatureSettingsDestination(.scratchpad, sectionAnchor: .scratchpad),
               "selecting Scratchpad opens its dedicated page in Clipboard and Files")
        expect(AppFeature.cleaningMode.settingsDestination
               == FeatureSettingsDestination(.keyboard, sectionAnchor: .cleaningMode),
               "selecting Cleaning Mode opens its Keyboard section")
        expect(AppFeature.micMute.settingsDestination
               == FeatureSettingsDestination(.audioInput, sectionAnchor: .micMute),
               "selecting Mic Mute opens its Audio Input section")
        expect(AppFeature.mixer.settingsDestination
               == FeatureSettingsDestination(.audioOutput, sectionAnchor: .mixer),
               "selecting Volume Mixer opens its Audio Output section")
        expect(AppFeature.quickLauncher.settingsDestination
               == FeatureSettingsDestination(.shortcuts, sectionAnchor: .quickLauncher)
               && AppFeature.cameraPreview.settingsDestination
               == FeatureSettingsDestination(.shortcuts, sectionAnchor: .cameraPreview),
               "shortcut-only tools open their exact Keyboard Shortcuts rows")
        expect(!AppFeature.quickToggles.hasNavigableSettingsDestination,
               "Quick Toggles keeps its panel actions without exposing a redundant preferences page")
        expect(AppFeature.wallpaper.settingsDestination
               == FeatureSettingsDestination(.energy, sectionAnchor: .wallpaper),
               "Wallpaper links open its own Energy and Display preferences")
        for feature in [AppFeature.focusFollowsMouse, .keyboardDebounce] {
            let item = SettingsSearchItem(id: .feature(feature), destination: feature.settingsDestination,
                                          title: feature.rawValue, icon: feature.symbolName, feature: feature)
            let route = SettingsSearchSupport.route(for: item, isAvailable: { _ in false })
            expect(route.destination == feature.settingsDestination && route.targetFeature == nil,
                   "a disabled input control routes to its permanent preferences rather than a missing hub row")
        }
    }
}
