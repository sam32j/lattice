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
               == FeatureSettingsDestination(.audioInput, sectionAnchor: .micMute),
               "selecting Mic Mute opens its Audio Input section")
        expect(AppFeature.mixer.settingsDestination
               == FeatureSettingsDestination(.audioOutput, sectionAnchor: .mixer),
               "selecting Volume Mixer opens its Audio Output section")
        expect(AppFeature.quickLauncher.settingsDestination
               == FeatureSettingsDestination(.launcherGrid)
               && AppFeature.cameraPreview.settingsDestination
               == FeatureSettingsDestination(.cameraPreview),
               "shortcut-only tools open their exact Keyboard Shortcuts rows")
        expect(!AppFeature.allCases.contains { $0.rawValue == "quickToggles" },
               "Quick Toggles is not independently installable")
        typealias Action = MenuPanelSectionGateContract.QuickToggleAction
        expect(Action.darkMode.feature == .brightness && Action.ejectDisks.feature == .commandBar,
               "appearance follows Displays while eject follows Command Bar installation")
        let domain = "vorss.tests.action-owners.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        for feature in AppFeature.allCases { defaults.set(false, forKey: feature.availabilityKey) }
        defaults.set(false, forKey: DefaultsKey.featureAvailable("quickToggles"))
        defaults.set(true, forKey: DefaultsKey.brightnessControlEnabled)
        expect(Action.allCases.filter { $0.feature.isAvailable(in: defaults) }
               == [.darkMode, .keyboardLight, .displayOff],
               "Displays actions stay reachable even when the retired Quick Toggles flag is off")
        defaults.set(false, forKey: DefaultsKey.brightnessControlEnabled)
        defaults.set(true, forKey: AppFeature.commandBar.availabilityKey)
        expect(Action.ejectDisks.feature.isAvailable(in: defaults)
               && !Action.darkMode.feature.isAvailable(in: defaults),
               "Command Bar keeps eject available without reinstalling Displays")
        expect(RadialMenuQuickToggle.allCases.allSatisfy { radial in
            Action(rawValue: radial.rawValue)?.feature == radial.feature
        }, "radial menu and panel actions follow the same installation owner")
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
