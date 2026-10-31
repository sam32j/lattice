import AppKit

extension FeatureRuntime {
    /// What each feature must re-evaluate when its availability (or a
    /// permission it depends on) changes. Most on-demand tools have no binding;
    /// Media only binds so uninstalling it can cancel work already in flight.
    static let bindings: [AppFeature: () -> Void] = [
        .switcher: {
            WindowUseTracker.shared.syncWithFeatures()
            AppSwitcher.shared.syncWithPreferences()
        },
        .dockPreview: { DockPreviewService.shared.syncWithPreferences() },
        .dockClick: { DockClickService.shared.syncWithPreferences() },
        .windowMaximizer: { WindowMaximizer.shared.syncWithPreferences() },
        .windowLayout: {
            WindowUseTracker.shared.syncWithFeatures()
            WindowLayoutService.shared.syncWithPreferences()
            PointerDisplayService.shared.syncWithPreferences()
        },
        .autoQuit: { AutoQuitService.shared.syncWithPreferences() },
        .spacesOrder: { SpacesOrderHold.shared.syncWithPreferences() },
        .scrollInverter: { ScrollInverter.shared.syncWithPreferences() },
        .scrollHorizontal: { ScrollInverter.shared.syncWithPreferences() },
        .focusFollowsMouse: { FocusFollowsMouseService.shared.syncWithPreferences() },
        .smoothScroll: { SmoothScrollService.shared.syncWithPreferences() },
        .linearScroll: { ScrollInverter.shared.syncWithPreferences() },
        .mouseAcceleration: { MouseAccelerationService.shared.syncWithPreferences() },
        .mouseNavigation: { MouseNavigationService.shared.syncWithPreferences() },
        .mouseButtonShortcuts: { MouseButtonShortcutService.shared.syncWithPreferences() },
        .middleClick: { MiddleClickService.shared.syncWithPreferences() },
        .mouseClickDebounce: { MouseClickDebounceService.shared.syncWithPreferences() },
        .keyboardDebounce: { KeyboardDebounceService.shared.syncWithPreferences() },
        .quitWindowProtection: { QuitProtectionService.shared.syncWithPreferences() },
        .superKey: { SuperKeyService.shared.syncWithPreferences() },
        .cleaningMode: { CleaningModeManager.shared.syncWithPreferences() },
        .textSnippets: {
            TextSnippetService.shared.syncWithPreferences()
            SnippetLibraryService.shared.syncWithPreferences()
        },
        .clipboardHistory: {
            ClipboardHistoryService.shared.syncWithPreferences()
            // History's page toggle also owns auto-clear timers and observers.
            ClipboardAutoClearService.shared.syncWithPreferences()
        },
        .mediaTools: {
            NotchFileToolsService.shared.syncWithPreferences()
            guard !AppFeature.mediaTools.isAvailable else { return }
            MediaService.shared.cancel()
            ScreenRecorderService.shared.closeEditors(ownedBy: .mediaTools)
        },
        .pastePlain: { PastePlainService.shared.syncWithPreferences() },
        .shelf: {
            ShelfService.shared.syncWithPreferences()
            NotchFileToolsService.shared.syncWithPreferences()
        },
        .urlCleaner: { URLCleanerService.shared.syncWithPreferences() },
        .diskImageInstaller: { DiskImageInstallerService.shared.syncWithPreferences() },
        .mixer: {
            PreciseVolumeRollerService.shared.syncWithPreferences()
            AppVolumeMixer.shared.syncWithPreferences()
            AudioInputDeviceManager.shared.syncWithPreferences()
        },
        .soundOutputSwitcher: {
            AppVolumeMixer.shared.syncWithPreferences()
            SoundOutputSwitcher.shared.syncWithPreferences()
        },
        .audioPriority: {
            // Priority owns no sibling CoreAudio listener stack. Keep the
            // shared system-device observers alive even when Volume mixer is
            // not installed, then start/stop the policy that consumes them.
            AppVolumeMixer.shared.syncWithPreferences()
            AudioInputDeviceManager.shared.syncWithPreferences()
            AudioPriorityService.shared.syncWithPreferences()
        },
        .micMute: { MicMuteService.shared.syncWithPreferences() },
        .musicBlock: { MusicLaunchBlocker.shared.syncWithPreferences() },
        .keepAwake: {
            KeepAwakeManager.shared.syncWithFeatures()
            HotkeyManager.shared.syncWithPreferences()
        },
        .brightness: { BrightnessService.shared.syncWithPreferences() },
        .extraBrightness: { ExtraBrightnessService.shared.syncWithPreferences() },
        .bluetoothSleep: { BluetoothSleepService.shared.syncWithPreferences() },
        .quickLauncher: { LatticeHubService.shared.syncWithPreferences() },
        .colorPicker: {
            ScreenCaptureService.shared.syncWithPreferences()
        },
        .screenOCR: {
            ScreenCaptureService.shared.syncWithPreferences()
            ScreenTextService.shared.syncWithPreferences()
        },
        .screenshot: {
            ScreenCaptureService.shared.syncWithPreferences()
            ScreenshotService.shared.syncWithPreferences()
            RecentCaptureService.shared.syncWithPreferences()
        },
        .screenRecorder: {
            ScreenCaptureService.shared.syncWithPreferences()
            ScreenRecorderService.shared.syncWithPreferences()
            RecentCaptureService.shared.syncWithPreferences()
        },
        .cameraPreview: { CameraPreviewService.shared.syncWithPreferences() },
        .wallpaper: { WallpaperService.shared.syncWithPreferences() },
        .radialMenu: {
            RadialMenuService.shared.syncWithPreferences()
            if !AppFeature.radialMenu.isAvailable { RadialNowPlayingService.shared.stop() }
        },
        .notch: { NotchService.shared.syncWithPreferences() },
        .notchGestures: {
            if AppFeature.notch.isAvailable { NotchService.shared.syncWithPreferences() }
        },
        .notchTimer: {
            if AppFeature.notch.isAvailable { NotchService.shared.syncWithPreferences() }
            else { NotchTimerService.shared.stop() }
        },
        .notchAccessories: {
            if !AppFeature.notchAccessories.isAvailable { NotchAccessoryService.shared.stop() }
            if AppFeature.notch.isAvailable { NotchService.shared.syncWithPreferences() }
            else { NotchAccessoryService.shared.stop() }
        },
        .notchLyrics: {
            if !NotchLyricsSupport.isEnabled() { NotchLyricsService.shared.stop() }
        },
        .notchQueue: { NotchMusicService.shared.syncQueuePreference() },
        .notchLiveEqualizer: { NotchAudioLevelService.shared.syncWithPreferences() },
        .notchNotifications: {
            if !AppFeature.notchNotifications.isAvailable { NotchNotificationService.shared.stop() }
            if AppFeature.notch.isAvailable { NotchService.shared.syncWithPreferences() }
            else { NotchNotificationService.shared.stop() }
        },
        .notchDownloads: {
            if !AppFeature.notchDownloads.isAvailable { NotchDownloadService.shared.stop() }
            if AppFeature.notch.isAvailable { NotchService.shared.syncWithPreferences() }
            else { NotchDownloadService.shared.stop() }
        },
        .notchCalendar: {
            if !AppFeature.notchCalendar.isAvailable { NotchCalendarService.shared.stop() }
            if AppFeature.notch.isAvailable { NotchService.shared.syncWithPreferences() }
            else { NotchCalendarService.shared.stop() }
        },
        .notchAgents: {
            if !AppFeature.notchAgents.isAvailable { AgentUsageService.shared.stop() }
            if AppFeature.notch.isAvailable { NotchService.shared.syncWithPreferences() }
            else { AgentUsageService.shared.stop() }
        },
        .notchWatch: {
            if !AppFeature.notchWatch.isAvailable { NotchWatchService.shared.stop() }
            if AppFeature.notch.isAvailable { NotchService.shared.syncWithPreferences() }
            else { NotchWatchService.shared.stop() }
        },
        // Leaving folds the wings it rests in, and coming back greets.
        .notchMascot: {
            if AppFeature.notch.isAvailable { NotchService.shared.syncWithPreferences() }
        },
        .scratchpad: { ScratchpadService.shared.syncWithPreferences() },
        .commandBar: { CommandBarService.shared.syncWithPreferences() },
        .cleaner: {
            CleanerScheduler.shared.syncWithPreferences()
            if !AppFeature.cleaner.isAvailable, JunkCleaner.shared.phase != .cleaning { JunkCleaner.shared.reset() }
        },
        .homebrew: { HomebrewManager.shared.syncWithFeatures() },
        .killProcess: { KillProcessService.shared.syncWithFeatures() },
        .portManager: {
            PortManagerService.shared.syncWithFeatures()
            if !AppFeature.portManager.isAvailable { KillProcessService.shared.syncWithFeatures() }
        },
        .uninstaller: {
            if !AppFeature.uninstaller.isAvailable {
                AppUninstaller.shared.reset()
                HomebrewManager.shared.syncWithFeatures()
            }
        },
        .appUpdates: {
            AppUpdatesService.shared.syncWithPreferences()
            if !AppFeature.appUpdates.isAvailable { HomebrewManager.shared.syncWithFeatures() }
        },
        .monitorCPU: { FeatureRuntime.syncMonitor() },
        .monitorGPU: { FeatureRuntime.syncMonitor() },
        .monitorMemory: { FeatureRuntime.syncMonitor() },
        .monitorNetwork: { FeatureRuntime.syncMonitor() },
        .monitorDisk: { FeatureRuntime.syncMonitor() },
        .monitorPower: { FeatureRuntime.syncMonitor() },
        .fanControl: {
            SystemMonitor.shared.planDidChange()
            let defaults = UserDefaults.standard
            let needsRecovery = defaults.bool(forKey: DefaultsKey.fanControlRecoveryNeeded)
            let hasRegisteredHelper = !(defaults.string(forKey: DefaultsKey.fanControlHelperVersion) ?? "").isEmpty
            if needsRecovery || (!AppFeature.fanControl.isAvailable && hasRegisteredHelper) {
                FanControlService.shared.syncWithPreferences()
            }
        },
    ]

    private static func syncMonitor() {
        SystemMonitor.shared.planDidChange()
        MonitorAlertService.shared.syncWithPreferences()
    }
}
