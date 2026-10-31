// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

extension AppFeature {
    /// Which permissions the feature can use at all. Whether it is using them
    /// RIGHT NOW is answered by `activeFeatures(using:)`, which also applies
    /// the dynamic rules (simple-mode switcher needs no screen recording, the
    /// monitor only notifies when an alert is on, and so on).
    var permissions: [AppPermission] {
        switch self {
        case .notchGestures: return []
        case .notchTimer: return []
        case .notchAccessories: return [.bluetooth]
        case .notchLyrics, .notchQueue: return []
        // Session logs and the saved limits sit in the home folder, outside
        // every protected location, and no sign-in or keychain item is used.
        case .notchAgents: return []
        // It only draws, and hears of what happens from the island itself.
        case .notchMascot: return []
        // The bars read the player's own audio output, which macOS gates
        // behind the same permission the mixer and the recorder ask for.
        case .notchLiveEqualizer: return [.audioCapture]
        case .notchDownloads: return [.filesAndFolders]
        // The chosen area is read with the screen capture other tools use,
        // and the alert becomes a notification where the island is hidden.
        case .notchWatch: return [.screenRecording, .notifications]
        case .notchNotifications: return [.accessibility]
        case .notchCalendar: return [.calendar]
        case .notch: return [.accessibility, .automationPlayback]
        case .mouseAcceleration, .spacesOrder:
            return []
        case .scrollInverter, .scrollHorizontal, .focusFollowsMouse, .smoothScroll, .linearScroll, .mouseNavigation, .mouseButtonShortcuts, .middleClick,
             .keyboardDebounce, .textSnippets, .superKey, .mouseClickDebounce,
             .dockClick, .windowMaximizer, .windowLayout,
             .autoQuit, .quitWindowProtection, .cleaningMode, .pastePlain, .radialMenu:
            return [.accessibility]
        // Accessibility powers menu/window actions; only Empty Trash asks Finder.
        case .commandBar:
            return [.accessibility, .automationFinder]
        case .switcher: return [.accessibility, .screenRecording]
        case .dockPreview: return [.accessibility, .screenRecording]
        case .screenOCR: return [.screenRecording]
        case .screenshot: return [.screenRecording]
        // The sound of the Mac is read through an audio grant of its own.
        // Microphone access stays contextual, and Accessibility only keeps
        // typing timing.
        case .screenRecorder: return [.screenRecording, .accessibility, .audioCapture, .microphone]
        case .cameraPreview: return [.camera]
        case .keepAwake: return [.accessibility]
        case .brightness: return [.accessibility]
        case .cleaner: return [.fullDiskAccess, .notifications]
        case .uninstaller: return [.fullDiskAccess, .automationFinder]
        case .homebrew: return [.automationTerminal, .appManagement]
        case .appUpdates: return [.notifications, .appManagement]
        case .diskImageInstaller: return [.appManagement]
        case .mixer: return [.audioCapture, .accessibility]
        case .musicBlock: return [.accessibility]
        case .monitorCPU, .monitorMemory, .monitorDisk: return [.notifications]
        case .monitorPower: return [.notifications, .bluetooth]
        case .clipboardHistory, .shelf, .urlCleaner,
             .soundOutputSwitcher, .audioPriority,
             .extraBrightness, .bluetoothSleep, .quickLauncher, .colorPicker, .micMute, .mediaTools,
             .scratchpad, .wallpaper, .monitorGPU, .monitorNetwork, .connectedDevices, .fanControl, .killProcess,
             .portManager, .videoDownloader:
            return []
        }
    }


    /// Features that are available, engaged and using `permission` right now.
    /// Readers are injectable so the logic stays testable without touching
    /// real UserDefaults.
    static func activeFeatures(using permission: AppPermission,
                               isAvailable: (AppFeature) -> Bool,
                               boolFor: (String) -> Bool,
                               stringFor: (String) -> String?,
                               dataFor: (String) -> Data? = { _ in nil }) -> [AppFeature] {
        allCases.filter { feature in
            guard feature.permissions.contains(permission), isAvailable(feature) else { return false }
            let keys = feature.enabledKeys
            guard keys.isEmpty || keys.contains(where: boolFor) else { return false }
            switch (feature, permission) {
            case (.notch, .automationPlayback):
                return !(stringFor(DefaultsKey.notchHiddenModules) ?? "").split(separator: ",").contains("music")
            case (.switcher, .screenRecording):
                return !boolFor(DefaultsKey.switcherSimpleMode)
            case (.notchWatch, .screenRecording):
                return isAvailable(.notch) && boolFor(DefaultsKey.notchEnabled)
                    && !(stringFor(DefaultsKey.notchHiddenModules) ?? "").split(separator: ",").contains("watch")
            case (.notchNotifications, .accessibility):
                return isAvailable(.notch) && boolFor(DefaultsKey.notchEnabled)
                    && !(stringFor(DefaultsKey.notchHiddenModules) ?? "").split(separator: ",").contains("notifications")
            case (.notchDownloads, .filesAndFolders):
                return isAvailable(.notch) && boolFor(DefaultsKey.notchEnabled)
                    && dataFor(DefaultsKey.notchDownloadsFolderBookmark) != nil
                    && !(stringFor(DefaultsKey.notchHiddenModules) ?? "").split(separator: ",").contains("downloads")
            case (.notchCalendar, .calendar):
                return isAvailable(.notch) && boolFor(DefaultsKey.notchEnabled)
                    && !(stringFor(DefaultsKey.notchHiddenModules) ?? "").split(separator: ",").contains("calendar")
            case (.notch, .accessibility):
                return (boolFor(DefaultsKey.notchVolume) && isAvailable(.mixer))
                    || (boolFor(DefaultsKey.notchKeyboardLight) && isAvailable(.brightness))
                    || (boolFor(DefaultsKey.notchBrightness) && isAvailable(.brightness)
                        && boolFor(DefaultsKey.brightnessControlEnabled))
                    || (boolFor(DefaultsKey.notchClipboardWindow) && isAvailable(.clipboardHistory))
                    || (boolFor(DefaultsKey.notchSnippetsWindow) && isAvailable(.textSnippets))
            case (.radialMenu, .accessibility):
                if let profiles = dataFor(DefaultsKey.radialMenuProfiles) {
                    return RadialMenuSupport.needsAccessibility(RadialMenuSupport.decodeProfiles(profiles))
                }
                return RadialMenuSupport.needsAccessibility(
                    RadialMenuSupport.decode(dataFor(DefaultsKey.radialMenuItems)))
                    || RadialMenuMouseTrigger.sanitized(
                        stringFor(DefaultsKey.radialMenuMouseButton)) != .off
            case (.keepAwake, .accessibility):
                return boolFor(DefaultsKey.keepAwakeMouseJiggleEnabled)
            case (.mixer, .accessibility):
                return boolFor(DefaultsKey.preciseVolumeRollerEnabled)
            case (.brightness, .accessibility):
                return boolFor(DefaultsKey.brightnessKeysEnabled)
                    || BrightnessKeyStepActivation.effective(raw: stringFor(DefaultsKey.brightnessKeyStep),
                        paused: boolFor(DefaultsKey.brightnessKeyStepPaused)) != .standard
            case (.monitorCPU, .notifications):
                return boolFor(DefaultsKey.monitorAlertCPU) || boolFor(DefaultsKey.monitorAlertCPUTemperature)
            case (.monitorMemory, .notifications):
                return boolFor(DefaultsKey.monitorAlertMemory)
            case (.monitorDisk, .notifications):
                return boolFor(DefaultsKey.monitorAlertDisk)
            case (.monitorPower, .notifications):
                return boolFor(DefaultsKey.monitorAlertBattery)
                    || boolFor(DefaultsKey.monitorAlertBatteryTemperature)
            case (.monitorPower, .bluetooth): return boolFor(DefaultsKey.monitorPwrPeripherals)
            case (.notchAccessories, .bluetooth):
                return isAvailable(.notch) && isAvailable(.monitorPower) && boolFor(DefaultsKey.notchEnabled)
            case (.appUpdates, .notifications):
                return AppUpdatesSupport.CheckFrequency
                    .sanitized(stringFor(DefaultsKey.appUpdatesCheckFrequency)) != .off
                    && boolFor(DefaultsKey.appUpdatesNotify)
            case (.cleaner, .notifications):
                return (stringFor(DefaultsKey.cleanerScheduleFrequency) ?? "off") != "off"
                    && boolFor(DefaultsKey.cleanerScheduleNotify)
            case (.notchLiveEqualizer, .audioCapture):
                return isAvailable(.notch) && boolFor(DefaultsKey.notchEnabled)
                    && !(stringFor(DefaultsKey.notchHiddenModules) ?? "").split(separator: ",").contains("music")
            case (.screenRecorder, .audioCapture):
                return boolFor(DefaultsKey.recorderSystemAudio)
            case (.screenRecorder, .microphone):
                return boolFor(DefaultsKey.recorderMicrophone)
            default:
                return true
            }
        }
    }

    /// Monitor alert keys and the metric feature each one belongs to. An
    /// alert only counts while its metric is available in the hub.
    static let monitorAlertPairs: [(key: String, feature: AppFeature)] = [
        (DefaultsKey.monitorAlertCPU, .monitorCPU),
        (DefaultsKey.monitorAlertCPUTemperature, .monitorCPU),
        (DefaultsKey.monitorAlertBatteryTemperature, .monitorPower),
        (DefaultsKey.monitorAlertMemory, .monitorMemory),
        (DefaultsKey.monitorAlertDisk, .monitorDisk),
        (DefaultsKey.monitorAlertBattery, .monitorPower),
    ]

    static func anyMonitorAlertEnabled(isAvailable: (AppFeature) -> Bool,
                                       boolFor: (String) -> Bool) -> Bool {
        monitorAlertPairs.contains { boolFor($0.key) && isAvailable($0.feature) }
    }

    /// Runtime convenience over the injectable core.
    static func activeFeatures(using permission: AppPermission,
                               defaults: UserDefaults = .standard) -> [AppFeature] {
        activeFeatures(using: permission,
                       isAvailable: { $0.isAvailable(in: defaults) },
                       boolFor: { defaults.bool(forKey: $0) },
                       stringFor: { defaults.string(forKey: $0) },
                       dataFor: { defaults.data(forKey: $0) })
    }
}

extension AppPermission {
    var symbolName: String {
        switch self {
        case .accessibility: return "accessibility"
        case .screenRecording: return "rectangle.dashed.badge.record"
        case .fullDiskAccess: return "externaldrive.badge.person.crop"
        case .filesAndFolders: return "folder.badge.person.crop"
        case .notifications: return "bell.badge"
        case .automationFinder, .automationTerminal, .automationPlayback: return "gearshape.2"
        case .audioCapture: return "waveform"
        case .microphone: return "mic"
        case .calendar: return "calendar"
        case .camera: return "camera"
        case .appManagement: return "app.badge"
        case .bluetooth: return "antenna.radiowaves.left.and.right"
        }
    }
}
