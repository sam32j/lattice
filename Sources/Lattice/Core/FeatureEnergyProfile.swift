import Foundation

/// The honest, curated cost label each feature earns in the hub: what the
/// feature keeps alive WHILE IT IS ON. Uninstalled features load nothing at
/// all, which is the hub's own promise. Static by design ; pretending to
/// measure per-feature cost live would be theater.
enum FeatureEnergyProfile: String {
    /// Nothing at rest: on-demand tools, shortcut-driven actions and
    /// system-notification listeners.
    case idle
    /// A mouse event tap (scrolls, clicks or pointer moves).
    case mouse
    /// A pointer gesture that works with either a trackpad or mouse.
    case pointer
    /// A keyboard event tap.
    case keyboard
    /// Both input taps.
    case inputs
    /// Samples or polls on an interval while active or visible.
    case periodic
}

extension AppFeature {
    var energyProfile: FeatureEnergyProfile {
        switch self {
        case .scrollInverter, .scrollHorizontal, .focusFollowsMouse, .smoothScroll, .linearScroll, .windowMaximizer, .middleClick,
             .mouseNavigation, .mouseButtonShortcuts, .mouseClickDebounce,
             .dockPreview, .dockClick, .shelf:
            return .mouse
        case .keyboardDebounce, .quitWindowProtection, .musicBlock:
            return .keyboard
        // The switcher's tap also takes clicks and scrolls, and the Super key
        // stamps its modifiers on mouse presses from a second tap.
        case .switcher, .superKey, .textSnippets, .autoQuit:
            return .inputs
        case .windowLayout:
            let edgeSnapRuns = UserDefaults.standard.bool(forKey: DefaultsKey.windowEdgeSnapEnabled)
                && !WindowEdgeSnapZone.enabledZones(
                    from: UserDefaults.standard.string(
                        forKey: DefaultsKey.windowEdgeSnapDisabledZones)
                ).isEmpty
            let pointerTapRuns = UserDefaults.standard.bool(forKey: DefaultsKey.windowGestureEnabled)
                || edgeSnapRuns
            let modifierTapRuns = UserDefaults.standard.bool(forKey: DefaultsKey.windowDirectionalEnabled)
                && UserDefaults.standard.string(forKey: DefaultsKey.windowDirectionalShortcut)
                    .flatMap(WindowDirectionalTrigger.init(storageValue:))
                    .map { if case .modifiers = $0 { return true }; return false } == true
            if modifierTapRuns { return .inputs }
            return pointerTapRuns ? .pointer : .idle
        case .radialMenu:
            // A side button or the trackpad tap on any wheel keeps an input
            // tap running; shortcut-only costs nothing at rest.
            return RadialMenuSupport.opensFromMouseOrTrackpad(
                UserDefaults.standard.data(forKey: DefaultsKey.radialMenuProfiles))
                ? .mouse : .idle
        case .notchNotifications, .notchGestures, .notchTimer, .notchQueue, .notchDownloads: return .idle
        // It reads only while something is being watched, and stops on its own.
        case .notchWatch: return .idle
        // A blink every few seconds and a visit every few minutes, both
        // drawn by Core Animation, with one timer waiting for the next visit.
        case .notchMascot: return .periodic
        case .notchAccessories: return .periodic
        // Log changes arrive as file events; a timer keeps countdowns and
        // limits current while the section is on.
        case .notch, .notchCalendar, .notchLyrics, .notchLiveEqualizer, .notchAgents: return .periodic
        case .clipboardHistory, .urlCleaner, .extraBrightness,
             .monitorCPU, .monitorGPU, .monitorMemory,
             .monitorNetwork, .monitorDisk, .monitorPower, .connectedDevices:
            return .periodic
        case .mixer:
            return UserDefaults.standard.bool(forKey: DefaultsKey.preciseVolumeRollerEnabled)
                ? .keyboard : .idle
        case .brightness:
            // Following the pointer and a finer step answer the
            // brightness keys from a tap. Like Accessibility, the island's own
            // notices are counted under the island.
            let defaults = UserDefaults.standard
            return defaults.bool(forKey: DefaultsKey.brightnessKeysEnabled)
                || BrightnessKeyStepActivation.effective(in: defaults) != .standard
                ? .keyboard : .idle
        case .mouseAcceleration, .spacesOrder, .pastePlain, .soundOutputSwitcher, .audioPriority, .micMute,
             .bluetoothSleep, .keepAwake, .quickLauncher, .colorPicker,
             .screenOCR, .cleaningMode, .mediaTools, .cleaner, .uninstaller, .homebrew, .screenshot,
             .cameraPreview, .scratchpad, .commandBar, .screenRecorder, .wallpaper, .fanControl,
             .diskImageInstaller, .killProcess, .portManager, .videoDownloader:
            return .idle
        case .appUpdates:
            // The list is on demand; only a background schedule keeps a timer.
            return AppUpdatesSupport.CheckFrequency.sanitized(
                UserDefaults.standard.string(forKey: DefaultsKey.appUpdatesCheckFrequency)) == .off
                ? .idle : .periodic
        }
    }
}
