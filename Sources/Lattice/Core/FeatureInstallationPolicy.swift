// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

extension AppFeature {
    /// Always-reachable Settings pages do not require off rows in the app menu.
    var retainsControlWhenOff: Bool {
        switch self {
        case .clipboardHistory, .shelf, .textSnippets, .urlCleaner, .cameraPreview,
             .diskImageInstaller, .quickLauncher, .scratchpad: return false
        default: return isToggleOwned
        }
    }

    /// Controls owned by a Settings page, not a separately installed hub item.
    var isToggleOwned: Bool {
        if isMouseFeature || isKeyboardFeature { return true }
        switch self {
        case .dockClick, .spacesOrder, .windowMaximizer, .autoQuit, .pastePlain,
             .brightness, .bluetoothSleep, .extraBrightness, .fanControl,
             .clipboardHistory, .shelf, .textSnippets, .urlCleaner, .cameraPreview,
             .diskImageInstaller, .quickLauncher, .scratchpad:
            return true
        default: return false
        }
    }

    /// Features with dedicated page-level install/enable controls, excluded from the Features hub.
    var isManagedOnDedicatedPage: Bool {
        if group == .monitor { return true }
        switch self {
        case .clipboardHistory, .shelf, .textSnippets, .urlCleaner, .cameraPreview,
             .diskImageInstaller, .quickLauncher, .scratchpad,
             .screenshot, .screenRecorder,
             .mixer, .soundOutputSwitcher, .audioPriority, .micMute, .musicBlock,
             .wallpaper, .windowLayout, .switcher, .dockPreview,
             .notch, .notchTimer, .notchCalendar, .notchNotifications, .notchDownloads, .notchAgents, .notchWatch,
             .notchMascot, .notchGestures, .notchLyrics, .notchQueue, .notchLiveEqualizer, .notchAccessories:
            return true
        default:
            return false
        }
    }

    func isToggledOn(in defaults: UserDefaults = .standard) -> Bool {
        switch self {
        case .scrollInverter:
            return defaults.bool(forKey: DefaultsKey.scrollInverterEnabled)
                || defaults.bool(forKey: DefaultsKey.scrollInverterHorizontalEnabled)
        case .bluetoothSleep:
            return defaults.bool(forKey: DefaultsKey.bluetoothSleepEnabled)
        case .brightness:
            return defaults.bool(forKey: DefaultsKey.brightnessControlEnabled)
        case .scrollHorizontal:
            return defaults.bool(forKey: DefaultsKey.scrollHorizontalEnabled)
        case .focusFollowsMouse:
            return defaults.bool(forKey: DefaultsKey.focusFollowsMouseEnabled)
        case .smoothScroll:
            return defaults.bool(forKey: DefaultsKey.smoothScrollEnabled)
        case .linearScroll:
            return defaults.bool(forKey: DefaultsKey.linearScrollEnabled)
        case .mouseAcceleration:
            return defaults.bool(forKey: DefaultsKey.mouseAccelerationDisabled)
        case .mouseNavigation:
            return defaults.bool(forKey: DefaultsKey.mouseNavigationEnabled)
        case .mouseButtonShortcuts:
            return defaults.bool(forKey: DefaultsKey.mouseButtonShortcutsEnabled)
                || defaults.bool(forKey: DefaultsKey.mouseSpacesGestureEnabled)
        case .middleClick:
            return defaults.bool(forKey: DefaultsKey.middleClickEnabled)
        case .mouseClickDebounce:
            return defaults.bool(forKey: DefaultsKey.mouseClickDebounceEnabled)
        case .keyboardDebounce:
            return defaults.bool(forKey: DefaultsKey.keyboardDebounceEnabled)
        case .superKey:
            return defaults.bool(forKey: DefaultsKey.superKeyEnabled)
        case .quitWindowProtection:
            return defaults.bool(forKey: DefaultsKey.quitProtectionQuitEnabled)
                || defaults.bool(forKey: DefaultsKey.quitProtectionCloseEnabled)
        case .cleaningMode:
            guard defaults.bool(forKey: DefaultsKey.cleaningModeShortcutEnabled) else { return false }
            if let raw = defaults.string(forKey: DefaultsKey.cleaningModeShortcut) {
                return GlobalShortcut(storageValue: raw)?.isValid == true
            }
            return GlobalShortcut.cleaningModeDefault.isValid
        case .textSnippets:
            return defaults.bool(forKey: DefaultsKey.textSnippetsEnabled)
        case .cameraPreview, .diskImageInstaller, .quickLauncher, .scratchpad:
            return defaults.bool(forKey: availabilityKey)
        default:
            return enabledKeys.contains { defaults.bool(forKey: $0) }
        }
    }
}
