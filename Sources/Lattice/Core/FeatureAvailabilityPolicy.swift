// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

extension AppFeature {
    var availabilityKey: String { DefaultsKey.featureAvailable(rawValue) }

    var isBeta: Bool { self == .fanControl || self == .killProcess }

    var isMouseFeature: Bool {
        switch self {
        case .scrollInverter, .scrollHorizontal, .focusFollowsMouse, .smoothScroll, .linearScroll,
             .mouseAcceleration, .mouseNavigation, .mouseButtonShortcuts, .middleClick, .mouseClickDebounce:
            return true
        default:
            return false
        }
    }

    var isKeyboardFeature: Bool {
        switch self {
        case .keyboardDebounce, .superKey, .quitWindowProtection, .cleaningMode:
            return true
        default:
            return false
        }
    }


    /// Input controls use their own switches; other features use installation
    /// preferences, retaining existing installations across app updates.
    var isAvailable: Bool {
        isAvailable(in: .standard)
    }

    func isAvailable(in defaults: UserDefaults, hardwareSupported: Bool? = nil) -> Bool {
        guard hardwareSupported ?? isHardwareSupported else { return false }
        if self == .pastePlain {
            return AppFeature.clipboardHistory.isAvailable(in: defaults) && isToggledOn(in: defaults)
        }
        if self == .fanControl {
            if let explicit = defaults.object(forKey: availabilityKey) as? Bool {
                return explicit
            }
            return isToggledOn(in: defaults)
        }
        if self == .radialMenu {
            return defaults.bool(forKey: availabilityKey)
                && defaults.bool(forKey: DefaultsKey.radialMenuEnabled)
        }
        if isToggleOwned {
            return isToggledOn(in: defaults)
        }
        switch self {
        case .colorPicker, .screenOCR:
            return AppFeature.screenshot.isAvailable(in: defaults)
        default:
            return defaults.bool(forKey: availabilityKey)
        }
    }

    /// Permanent input controls remain discoverable when their switch is off.
    /// Runtime availability still describes whether their behavior should run.
    func isPresentInControls(in defaults: UserDefaults = .standard, hardwareSupported: Bool? = nil) -> Bool {
        guard hardwareSupported ?? isHardwareSupported else { return false }
        if self == .pastePlain { return AppFeature.clipboardHistory.isAvailable(in: defaults) }
        return retainsControlWhenOff || isAvailable(in: defaults)
    }

    /// Configuration remains reachable while behavior is off. Unsupported
    /// hardware and children of an uninstalled owner are never advertised.
    func isVisibleInSettings(isAvailable: (AppFeature) -> Bool) -> Bool {
        guard isHardwareSupported else { return false }
        if self == .pastePlain { return isAvailable(.clipboardHistory) }
        return isToggleOwned || isManagedOnDedicatedPage || isAvailable(self)
    }

    /// The feature's own enable keys; any one being true means the feature is
    /// engaged. Empty means the feature works on demand (a panel tile, a
    /// context-menu action), so being available already counts as engaged for
    /// the permissions portal.
    var enabledKeys: [String] {
        switch self {
        case .switcher: return [DefaultsKey.switcherEnabled]
        case .dockPreview: return [DefaultsKey.dockPreviewEnabled]
        case .dockClick: return [DefaultsKey.dockClickMinimize,
                                 DefaultsKey.dockClickHide,
                                 DefaultsKey.dockClickCycleWindows]
        case .windowMaximizer: return [DefaultsKey.windowMaximizeEnabled]
        case .autoQuit: return [DefaultsKey.autoQuitEnabled]
        case .spacesOrder: return [DefaultsKey.spacesOrderEnabled]
        case .scrollInverter: return [DefaultsKey.scrollInverterEnabled,
                                      DefaultsKey.scrollInverterHorizontalEnabled]
        case .scrollHorizontal: return [DefaultsKey.scrollHorizontalEnabled]
        case .focusFollowsMouse: return [DefaultsKey.focusFollowsMouseEnabled]
        case .smoothScroll: return [DefaultsKey.smoothScrollEnabled]
        case .linearScroll: return [DefaultsKey.linearScrollEnabled]
        case .mouseAcceleration: return [DefaultsKey.mouseAccelerationDisabled]
        case .mouseNavigation: return [DefaultsKey.mouseNavigationEnabled]
        case .mouseButtonShortcuts: return [DefaultsKey.mouseButtonShortcutsEnabled,
                                            DefaultsKey.mouseSpacesGestureEnabled]
        case .middleClick: return [DefaultsKey.middleClickEnabled]
        case .keyboardDebounce: return [DefaultsKey.keyboardDebounceEnabled]
        case .quitWindowProtection:
            return [DefaultsKey.quitProtectionQuitEnabled, DefaultsKey.quitProtectionCloseEnabled]
        case .textSnippets: return [DefaultsKey.textSnippetsEnabled, DefaultsKey.snippetLibraryEnabled]
        case .superKey: return [DefaultsKey.superKeyEnabled]
        case .mouseClickDebounce: return [DefaultsKey.mouseClickDebounceEnabled]
        case .notchGestures: return [DefaultsKey.notchGesturesEnabled]
        case .notchTimer: return [DefaultsKey.notchTimerEnabled]
        case .notchAccessories: return [DefaultsKey.notchAccessoriesEnabled]
        case .notchLyrics: return [DefaultsKey.notchLyricsEnabled]
        case .notchQueue: return [DefaultsKey.notchQueueEnabled]
        case .notchLiveEqualizer: return [DefaultsKey.notchLiveEqualizer]
        case .notchDownloads: return [DefaultsKey.notchDownloadsEnabled]
        case .notchNotifications: return [DefaultsKey.notchNotificationsEnabled]
        case .notchCalendar: return [DefaultsKey.notchCalendarEnabled]
        case .notchAgents: return [DefaultsKey.notchAgentsEnabled]
        case .notchWatch: return [DefaultsKey.notchWatchEnabled]
        case .notchMascot: return [DefaultsKey.notchMascotEnabled]
        case .notch: return [DefaultsKey.notchEnabled]
        case .radialMenu: return [DefaultsKey.radialMenuEnabled]
        case .clipboardHistory: return [DefaultsKey.clipboardHistoryEnabled]
        case .pastePlain: return [DefaultsKey.pastePlainEnabled]
        case .shelf: return [DefaultsKey.shelfEnabled]
        case .urlCleaner: return [DefaultsKey.urlCleanerEnabled]
        case .soundOutputSwitcher: return [DefaultsKey.soundOutputSwitcherEnabled]
        case .audioPriority: return [DefaultsKey.audioPriorityOutputEnabled,
                                     DefaultsKey.audioPriorityInputEnabled]
        case .musicBlock: return [DefaultsKey.musicBlockEnabled]
        case .brightness: return [DefaultsKey.brightnessControlEnabled]
        case .extraBrightness: return [DefaultsKey.extraBrightnessEnabled]
        case .fanControl: return [DefaultsKey.panelShowFanControl]
        case .bluetoothSleep: return [DefaultsKey.bluetoothSleepEnabled]
        case .cleaningMode: return [DefaultsKey.cleaningModeShortcutEnabled]
        case .videoDownloader: return [DefaultsKey.videoDownloaderEnabled]
        case .windowLayout, .diskImageInstaller, .mixer, .micMute, .keepAwake,
             .quickLauncher, .colorPicker, .screenOCR, .mediaTools,
             .cleaner, .uninstaller, .homebrew, .appUpdates, .screenshot, .cameraPreview, .scratchpad,
             .commandBar, .screenRecorder, .wallpaper, .killProcess, .portManager,
             .monitorCPU, .monitorGPU, .monitorMemory, .monitorNetwork, .monitorDisk, .monitorPower,
             .connectedDevices:
            return []
        }
    }

    /// Turn on the feature's main behavior at install time. Features with
    /// several independent controls start with one useful behavior, except
    /// audio priority, whose output and input controls work together. The
    /// live equalizer stays off: it asks for system audio recording on the
    /// first song, so only the user's own switch turns it on.
    private var initialEnableKeys: [String] {
        switch self {
        case .windowLayout: return [DefaultsKey.windowLayoutShortcutsEnabled]
        case .audioPriority: return enabledKeys
        case .notchLiveEqualizer: return []
        default: return enabledKeys.first.map { [$0] } ?? []
        }
    }

    /// Registered defaults are visible through `object(forKey:)`, so only the
    /// persistent domain can tell a fresh install from a saved off choice.
    func enableOnFirstInstall(in defaults: UserDefaults, savedValues: [String: Any]) {
        guard !isToggleOwned else { return }
        let choices = self == .windowLayout
            ? [DefaultsKey.windowLayoutShortcutsEnabled, DefaultsKey.windowDirectionalEnabled,
               DefaultsKey.pointerDisplayEnabled, DefaultsKey.windowEdgeSnapEnabled,
               DefaultsKey.windowGestureEnabled]
            : enabledKeys
        guard !choices.contains(where: { savedValues[$0] != nil }) else { return }
        for key in initialEnableKeys {
            defaults.set(true, forKey: key)
        }
    }

}
