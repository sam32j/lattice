// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

extension AppFeature {
    static func features(in group: FeatureGroup) -> [AppFeature] {
        allCases.filter { $0.group == group }
    }

    static func hubFeatures(in group: FeatureGroup) -> [AppFeature] {
        features(in: group).filter {
            $0 != .colorPicker && $0 != .screenOCR && !$0.isToggleOwned && !$0.isManagedOnDedicatedPage
        }
    }

    /// All features shown and counted as installable features in the Hub.
    static var hubInstallableFeatures: [AppFeature] {
        FeatureGroup.allCases.flatMap { hubFeatures(in: $0) }
    }

    /// The Dynamic Island's extensions: everything else in its group. They
    /// do nothing without the island, so uninstalling it offers to take them
    /// along.
    static var dynamicIslandExtensions: [AppFeature] {
        features(in: .dynamicIsland).filter { $0 != .notch }
    }

    /// Agents reads local session histories, and the companion changes the
    /// resting island. Both are separate choices when installing the island.
    static var dynamicIslandInitialExtensions: [AppFeature] {
        dynamicIslandExtensions.filter { $0 != .notchMascot && $0 != .notchAgents }
    }

    var initialInstallGroup: [AppFeature] {
        if self == .notch { return [self] + Self.dynamicIslandInitialExtensions }
        if self == .screenshot { return [.screenshot, .colorPicker, .screenOCR] }
        return [self]
    }

    /// Switches the Features page may offer to uninstall once they turn out
    /// never used. Each one does nothing until its own switch is on, and no
    /// other feature leans on it while it is off. Features that lend a part
    /// of themselves elsewhere stay out even when off: the Dynamic Island,
    /// the shelf behind the island's file tray, the radial menu, and the
    /// switcher and text snippets that feed the Command Bar.
    static let offeredWhenNeverSwitchedOn: [AppFeature] = [
        .dockPreview, .dockClick, .windowMaximizer, .autoQuit,
    ]

    /// Installed features from that list whose switches are off and were never
    /// saved on this Mac: installed, but not once turned on. A switch turned
    /// on and back off is saved, so a feature someone used keeps its place.
    static func neverSwitchedOn(isAvailable: (AppFeature) -> Bool,
                                boolFor: (String) -> Bool,
                                isSaved: (String) -> Bool) -> [AppFeature] {
        offeredWhenNeverSwitchedOn.filter { feature in
            isAvailable(feature)
                && !feature.enabledKeys.isEmpty
                && !feature.enabledKeys.contains(where: boolFor)
                && !feature.enabledKeys.contains { isSaved($0) }
        }
    }

    /// Whether a Mac that never chose this feature has it installed. Most
    /// people updating never saved an availability, so this list IS their
    /// install: moving a feature out of it uninstalls it for all of them,
    /// which is why a test pins it. The switch has no default on purpose, so
    /// every new feature is placed here by decision. New features belong on
    /// the opt-in side: an update should never grow the panel and Settings on
    /// its own, and the Features page and release notes are where they get
    /// installed. A feature split out of an existing one needs a migration
    /// that copies its parent's availability instead.
    var installedByDefault: Bool {
        switch self {
        case .switcher, .dockPreview, .dockClick, .windowMaximizer, .windowLayout, .autoQuit,
             .scrollInverter, .smoothScroll, .mouseAcceleration, .mouseNavigation, .mouseButtonShortcuts,
             .middleClick, .mouseClickDebounce, .keyboardDebounce, .textSnippets, .superKey,
             .quitWindowProtection,
             .clipboardHistory, .pastePlain, .shelf, .urlCleaner,
             .mixer, .soundOutputSwitcher, .micMute, .musicBlock,
             .keepAwake, .brightness, .extraBrightness, .bluetoothSleep,
             .quickLauncher, .colorPicker, .screenOCR, .cleaningMode, .mediaTools,
             .cleaner, .uninstaller, .homebrew, .appUpdates, .screenshot, .cameraPreview, .radialMenu,
             .scratchpad, .commandBar, .screenRecorder,
             .notch, .notchCalendar, .notchNotifications, .notchGestures, .notchTimer, .notchAccessories,
             .notchLyrics, .notchQueue, .notchLiveEqualizer, .notchDownloads, .notchAgents, .notchWatch,
             .monitorCPU, .monitorGPU, .monitorMemory, .monitorNetwork, .monitorDisk, .monitorPower,
             .connectedDevices:
            return true
        case .focusFollowsMouse, .scrollHorizontal, .linearScroll, .diskImageInstaller, .audioPriority,
             .wallpaper, .killProcess, .portManager, .videoDownloader, .fanControl, .notchMascot, .spacesOrder:
            return false
        }
    }

    /// Registered defaults keep every feature an update already had and leave
    /// opt-in features and explicit betas uninstalled.
    static var availabilityDefaults: [String: Any] {
        Dictionary(uniqueKeysWithValues: allCases.map { ($0.availabilityKey, $0.installedByDefault) })
    }

}
