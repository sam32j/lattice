// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Stable page-owned feature identities. Availability controls behavior while
/// settings remain reachable, and disabling preserves saved configuration.
enum AppFeature: String, CaseIterable {
    // Windows and Dock
    case switcher, dockPreview, dockClick, windowMaximizer, windowLayout, autoQuit, spacesOrder
    // Mouse and keyboard
    case scrollInverter, scrollHorizontal, focusFollowsMouse, smoothScroll, linearScroll, mouseAcceleration, mouseNavigation, mouseButtonShortcuts, middleClick,
         mouseClickDebounce, keyboardDebounce, textSnippets, superKey, quitWindowProtection
    // Clipboard and files
    case clipboardHistory, pastePlain, shelf, urlCleaner,
         diskImageInstaller
    // Sound
    case mixer, soundOutputSwitcher, audioPriority, micMute, musicBlock
    // Energy and display
    case keepAwake, brightness, extraBrightness, bluetoothSleep
    // Tools
    case quickLauncher, colorPicker, screenOCR, cleaningMode, mediaTools,
         cleaner, uninstaller, homebrew, appUpdates, screenshot, cameraPreview, radialMenu, scratchpad,
         commandBar, screenRecorder, wallpaper, killProcess, portManager, videoDownloader
    // Dynamic Island, then its extensions
    case notch, notchCalendar, notchNotifications, notchGestures, notchTimer, notchAccessories, notchLyrics,
         notchQueue, notchLiveEqualizer, notchDownloads, notchAgents, notchWatch, notchMascot
    // System monitor, one entry per metric family (temperatures live with
    // their parent metric: CPU temp with CPU, battery temp with power).
    case monitorCPU, monitorGPU, monitorMemory, monitorNetwork, monitorDisk, monitorPower, connectedDevices, fanControl
}

/// Hub sections, in display order.
enum FeatureGroup: String, CaseIterable {
    case windowsDock, mouseKeyboard, clipboardFiles, sound, energyDisplay, tools, dynamicIsland, monitor
}

/// System permissions surfaced by the hub's transparency portal.
enum AppPermission: String, CaseIterable {
    case accessibility, screenRecording, audioCapture, fullDiskAccess, filesAndFolders, notifications,
         automationFinder, automationTerminal, automationPlayback, microphone, camera, appManagement, calendar, bluetooth
}

enum PermissionPollingSupport {
    static func interval(visibleSurfaceCount: Int,
                         accessibilityIsNeeded: Bool,
                         screenRecordingIsNeeded: Bool,
                         accessibilityIsGranted: Bool,
                         screenRecordingIsGranted: Bool) -> TimeInterval? {
        guard visibleSurfaceCount > 0 || accessibilityIsNeeded || screenRecordingIsNeeded else {
            return nil
        }
        if visibleSurfaceCount > 0
            || (accessibilityIsNeeded && !accessibilityIsGranted)
            || (screenRecordingIsNeeded && !screenRecordingIsGranted) {
            return 2.5
        }
        return 60
    }
}

extension AppFeature {
    /// Whether an engaged feature needs permission changes while it sits in
    /// the background. One-shot tools ask and refresh at the moment they run;
    /// polling for those just because their tile is installed wastes wakeups.
    func monitorsPermissionChanges(edgeSnapDisabledZones: String? = nil,
                                   boolFor: (String) -> Bool) -> Bool {
        switch self {
        case .windowLayout:
            return boolFor(DefaultsKey.windowLayoutShortcutsEnabled)
                || boolFor(DefaultsKey.windowGestureEnabled)
                || (boolFor(DefaultsKey.windowEdgeSnapEnabled)
                    && !WindowEdgeSnapZone.enabledZones(
                        from: edgeSnapDisabledZones
                    ).isEmpty)
        // Watch asks when an area is chosen and checks on every reading. The
        // companion uses no permission at all.
        case .screenOCR, .cleaningMode, .screenshot, .commandBar, .screenRecorder, .wallpaper, .notchWatch,
             .notchMascot:
            return false
        default:
            return true
        }
    }

    var monitorsPermissionChanges: Bool {
        monitorsPermissionChanges(
            edgeSnapDisabledZones: UserDefaults.standard.string(
                forKey: DefaultsKey.windowEdgeSnapDisabledZones
            ),
            boolFor: UserDefaults.standard.bool(forKey:)
        )
    }

    var group: FeatureGroup {
        switch self {
        case .switcher, .dockPreview, .dockClick, .windowMaximizer, .windowLayout, .autoQuit, .spacesOrder:
            return .windowsDock
        case .scrollInverter, .scrollHorizontal, .focusFollowsMouse, .smoothScroll, .linearScroll, .mouseAcceleration, .mouseNavigation, .mouseButtonShortcuts, .middleClick,
             .keyboardDebounce, .superKey, .quitWindowProtection, .mouseClickDebounce, .cleaningMode:
            return .mouseKeyboard
        case .clipboardHistory, .pastePlain, .shelf, .urlCleaner,
             .diskImageInstaller, .textSnippets, .scratchpad:
            return .clipboardFiles
        case .mixer, .soundOutputSwitcher, .audioPriority, .micMute, .musicBlock:
            return .sound
        case .keepAwake, .brightness, .extraBrightness, .bluetoothSleep, .wallpaper:
            return .energyDisplay
        case .quickLauncher, .colorPicker, .screenOCR, .mediaTools,
             .cleaner, .uninstaller, .homebrew, .appUpdates, .screenshot, .cameraPreview, .radialMenu,
             .commandBar, .screenRecorder, .killProcess, .portManager, .videoDownloader:
            return .tools
        case .notch, .notchCalendar, .notchNotifications, .notchGestures, .notchTimer, .notchAccessories,
             .notchLyrics, .notchQueue, .notchLiveEqualizer, .notchDownloads, .notchAgents, .notchWatch,
             .notchMascot:
            return .dynamicIsland
        case .monitorCPU, .monitorGPU, .monitorMemory, .monitorNetwork, .monitorDisk, .monitorPower,
             .connectedDevices, .fanControl:
            return .monitor
        }
    }

    var symbolName: String {
        switch self {
        case .switcher: return "rectangle.on.rectangle"
        case .dockPreview: return "dock.rectangle"
        case .dockClick: return "dock.arrow.down.rectangle"
        case .windowMaximizer: return "arrow.up.left.and.arrow.down.right"
        case .windowLayout: return "rectangle.3.group"
        case .autoQuit: return "xmark.rectangle"
        case .spacesOrder: return "rectangle.split.3x1"
        case .scrollInverter: return "arrow.up.arrow.down"
        case .scrollHorizontal: return "arrow.triangle.swap"
        case .focusFollowsMouse: return "cursorarrow.and.square.on.square.dashed"
        case .smoothScroll: return "cursorarrow.motionlines"
        case .linearScroll: return "arrow.up.and.down.text.horizontal"
        case .mouseAcceleration: return "cursorarrow.rays"
        case .mouseNavigation: return "arrow.left.arrow.right"
        case .mouseButtonShortcuts: return "button.programmable"
        case .middleClick: return "hand.tap"
        case .keyboardDebounce: return "keyboard"
        case .textSnippets: return "text.append"
        case .superKey:
            return SuperKeySource.sanitized(
                UserDefaults.standard.string(forKey: DefaultsKey.superKeySource)
            ).systemImage
        case .mouseClickDebounce: return "cursorarrow.click"
        case .quitWindowProtection: return "shield.lefthalf.filled"
        case .clipboardHistory: return "doc.on.clipboard"
        case .pastePlain: return "doc.plaintext"
        case .shelf: return "tray.full"
        case .urlCleaner: return "link"
        case .diskImageInstaller: return "externaldrive.badge.plus"
        case .mixer: return "speaker.wave.2"
        case .soundOutputSwitcher: return "hifispeaker"
        case .audioPriority: return "list.number"
        case .micMute: return "mic.slash"
        case .musicBlock: return "music.note"
        case .keepAwake: return "bolt.fill"
        case .brightness: return "display.2"
        case .extraBrightness: return "sun.max.fill"
        case .bluetoothSleep: return "wave.3.right.circle"
        case .quickLauncher: return "square.grid.2x2"
        case .colorPicker: return "eyedropper"
        case .screenOCR: return "text.viewfinder"
        case .cleaningMode: return "bubbles.and.sparkles"
        case .mediaTools: return "rectangle.compress.vertical"
        case .cleaner: return "sparkles"
        case .uninstaller: return "externaldrive.badge.minus"
        case .homebrew: return "shippingbox"
        case .appUpdates: return "square.and.arrow.down.badge.clock"
        case .screenshot: return "camera.viewfinder"
        case .screenRecorder: return "record.circle"
        case .cameraPreview: return "person.crop.square.badge.camera"
        case .wallpaper: return "rectangle.inset.filled.and.cursorarrow"
        case .notchGestures: return "hand.draw"
        case .notchTimer: return "timer"
        case .notchAccessories: return "battery.25percent"
        case .notchLyrics: return "quote.bubble"
        case .notchQueue: return "list.bullet"
        case .notchLiveEqualizer: return "waveform"
        case .notchDownloads: return "arrow.down.circle"
        case .notchNotifications: return "bell"
        case .notchCalendar: return "calendar"
        case .notchAgents: return "sparkles"
        case .notchWatch: return "eye"
        case .notchMascot: return "face.smiling"
        case .notch: return "macbook"
        case .radialMenu: return "circle.grid.cross"
        case .scratchpad: return "note.text"
        case .commandBar: return "command"
        case .killProcess: return "xmark.octagon"
        case .portManager: return "network"
        case .videoDownloader: return "arrow.down.circle.dotted"
        case .monitorCPU: return "cpu"
        case .monitorGPU: return "rectangle.connected.to.line.below"
        case .monitorMemory: return "memorychip"
        case .monitorNetwork: return "network"
        case .monitorDisk: return "internaldrive"
        case .monitorPower: return "bolt.fill"
        case .connectedDevices: return "cable.connector"
        case .fanControl: return "fanblades.fill"
        }
    }

}
