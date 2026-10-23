import Foundation

/// Only verified missing capabilities revoke activation. Optional capabilities
/// never disable an unrelated master, and restoring permission never arms one.
enum PermissionRevocationPolicy {
    struct Changes {
        var affected: Set<AppFeature> = []
        var uninstall: Set<AppFeature> = []
        var endsCleaningLock = false
    }

    static func revalidated(_ reported: [SettingsPermission: Bool],
                            verify: (SettingsPermission) -> Bool) -> [SettingsPermission: Bool] {
        Dictionary(uniqueKeysWithValues: reported.keys.map { ($0, verify($0)) })
    }

    static func apply(_ verified: [SettingsPermission: Bool], in defaults: UserDefaults) -> Changes {
        var result = Changes()
        let essential: [SettingsPermission: [AppFeature]] = [
            .accessibility: [.scrollInverter, .scrollHorizontal, .focusFollowsMouse, .smoothScroll,
                .linearScroll, .mouseNavigation, .mouseButtonShortcuts, .middleClick, .mouseClickDebounce,
                .keyboardDebounce, .superKey, .quitWindowProtection, .textSnippets, .pastePlain,
                .dockClick, .windowMaximizer, .windowLayout, .autoQuit, .radialMenu, .musicBlock,
                .notch, .switcher, .dockPreview, .cleaningMode],
            .screenRecording: [.switcher, .dockPreview, .screenshot, .screenRecorder, .notchWatch],
            .camera: [.cameraPreview], .calendar: [.notchCalendar], .bluetooth: [.notchAccessories],
        ]
        func disable(_ keys: [String], feature: AppFeature) {
            for key in keys where defaults.bool(forKey: key) {
                defaults.set(false, forKey: key)
                result.affected.insert(feature)
            }
        }
        for (permission, features) in essential where verified[permission] == false {
            for feature in features {
                let keys = feature == .textSnippets ? [DefaultsKey.textSnippetsEnabled] : feature.enabledKeys
                disable(keys, feature: feature)
                if keys.isEmpty { result.uninstall.insert(feature) }
            }
        }
        if verified[.screenRecording] == false {
            disable([DefaultsKey.screenshotEnabled], feature: .screenshot)
            disable([DefaultsKey.screenRecorderEnabled], feature: .screenRecorder)
        }
        if verified[.accessibility] == false {
            result.endsCleaningLock = true
            disable([DefaultsKey.brightnessKeysEnabled], feature: .brightness)
            if BrightnessKeyStepActivation.pause(in: defaults) { result.affected.insert(.brightness) }
            disable([DefaultsKey.keepAwakeMouseJiggleEnabled], feature: .keepAwake)
            disable([DefaultsKey.notchDismissNativeNotifications], feature: .notchNotifications)
            // Saved tuning remains intact; restoration alone never rearms it.
        }
        if verified[.microphone] == false { disable([DefaultsKey.recorderMicrophone], feature: .screenRecorder) }
        return result
    }
}
