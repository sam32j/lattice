// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox
import os.log
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusController: StatusItemController!
    private var isTerminating = false
    private var inputSourceRestorationPending = false
    private var cancellables = Set<AnyCancellable>()
    var settingsWindow: SettingsWindow?
    private var settingsKeepsAppRegular = false
    private var feedbackWindow: NSWindow?
    private var updatePreviewWindow: NSWindow?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Before any window exists, so nothing is ever built with the wrong
        // appearance and then repainted.
        AppAppearanceController.shared.apply()
        GlobalShortcut.startObservingKeyboardLayout()
        beginStartupWatch()
        Self.boundAccessibilityWaits()
        // Pay the first AppKit process lookup before an input callback needs
        // it. Each click still resolves the current process independently.
        _ = AssistiveKeyboard.isRunning

        // Finish the on-disk rename for installs carried over from a pre-2.5
        // build, or retire a leftover old-named bundle. Returns true when we are
        // quitting to relaunch under the new name, so skip the rest of startup.
        if BundleMigration.run() { return }

        DispatchQueue.global(qos: .utility).async {
            RecorderGIFWorkspace.sweep()
        }


        // Redo a launch at login registration the system lost. The stored
        // choice is the last thing the user expressed in the app; startup
        // never turns the item off. It runs off the main thread, since
        // Service Management can stall while answering (issue #2539).
        LaunchAtLogin.repairAtStartup()

        // Switch back on any display a previous run left off. A run that ends
        // without putting one back leaves a screen dark with no app around to
        // offer it back, so the repair happens before anything else can care
        // about which displays are attached.
        BrightnessService.shared.restoreDisplaysLeftOff()

        // An accessory (LSUIElement) app gets no default main menu, so the standard
        // keyboard shortcuts (Cmd+H/M/W/Q and the Edit shortcuts Cmd+C/V/X/A) have
        // no menu items to fire and do nothing in the Settings window. Install one.
        installMainMenu()
        HorizontalWheelScrolling.install()

        statusController = StatusItemController()
        statusController.onLeftClick = { [weak self] in
            guard let self else { return }
            let anchorRect: NSRect?
            if let button = self.statusController?.statusItem?.button,
               let window = button.window {
                anchorRect = window.convertToScreen(button.bounds)
            } else {
                anchorRect = nil
            }
            LatticeHubService.shared.toggle(forceFloating: true, anchoredBelow: anchorRect)
        }
        statusController.onRightClick = { [weak self] button in
            if AppFeature.keepAwake.isAvailable
                && UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakeRightClickToggle) {
                KeepAwakeManager.shared.toggle()
            } else {
                self?.showContextMenu(from: button)
            }
        }
        statusController.onMetricClick = { [weak self] metric, button in
            self?.showMetricPanel(for: metric, anchoredTo: button)
        }
        statusController.onClipboardPreviewClick = {
            ClipboardHistoryService.shared.toggleHistoryWindow()
        }
        // The shelf drop zone chip anchors itself under the menu bar icon.
        ShelfService.shared.statusItemFrameProvider = { [weak self] in
            guard let item = self?.statusController.statusItem, item.isVisible,
                  let window = self?.statusController.button?.window else { return nil }
            let frame = window.frame
            guard StatusItemAnchorSupport.isTrustworthyStatusFrame(frame) else { return nil }
            return frame
        }

        bindManagers()

        // A marker from an earlier build may name a hotkey id this build no
        // longer owns; give it back before any feature decides what to hold,
        // except the ids the switcher is about to take over again, which stay
        // off rather than flipping on and back. It has to run before the first
        // claim of the launch — keep-awake makes one on the next line — because
        // a claim resolves what every source wants together, and a marker no
        // source has spoken for yet resolves to nothing and is handed back whole.
        SystemShortcutTakeover.recoverIfNeeded(keeping: AppSwitcher.launchTakeoverIDs())
        HotkeyManager.shared.onActivate = { KeepAwakeManager.shared.toggle() }
        HotkeyManager.shared.syncWithPreferences()

        KeepAwakeManager.shared.recoverIfNeeded {
            KeepAwakeManager.shared.activateOnLaunchIfNeeded()
        }
        FanControlService.recoverIfNeeded()
        SpacesOrderHold.recoverIfNeeded()
        // One binding per feature: only available features are touched, so a
        // feature switched off in the hub never even instantiates here.
        FeatureRuntime.shared.syncAtLaunch()
        AudioInputDeviceManager.shared.syncWithPreferences()
        DeferredPermissionActivationService.recoverIfNeeded()
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { _ in FeatureRuntime.shared.hardwareDidChange() }
            .store(in: &cancellables)
        if AppFeature.monitorPower.isAvailable, PowerSampler.hasInternalBattery {
            MaxCapacityProbe.shared.refreshIfStale()
        }
        UpdateService.shared.startAutomaticChecks()
        NotificationCenter.default.addObserver(self, selector: #selector(appBecameActive),
                                               name: NSApplication.didBecomeActiveNotification, object: nil)

        // If Accessibility is granted while the app is running, bring the input
        // features up without a relaunch.
        PermissionRevocationRuntime.observe().store(in: &cancellables)
        Permissions.shared.$accessibility
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { _ in
                FeatureRuntime.shared.sync([
                    .scrollInverter, .scrollHorizontal, .focusFollowsMouse, .smoothScroll, .linearScroll, .mouseNavigation, .switcher,
                    .dockPreview, .autoQuit, .dockClick,
                    .middleClick, .windowMaximizer, .keyboardDebounce, .windowLayout,
                    .textSnippets, .brightness, .radialMenu, .mouseButtonShortcuts,
                    .mouseClickDebounce, .superKey, .quitWindowProtection, .mixer, .musicBlock, .keepAwake, .notch,
                ])
            }
            .store(in: &cancellables)

        Permissions.shared.$screenRecording
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { _ in
                FeatureRuntime.shared.sync([.dockPreview, .screenRecorder])
            }
            .store(in: &cancellables)

        DeferredPermissionActivationService.recoverIfNeeded()

        // Keep the menu titles in step with the in-app language.
        L10n.shared.$language
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.installMainMenu() }
            .store(in: &cancellables)

        let defaults = UserDefaults.standard
        let previousVersion = defaults.string(forKey: DefaultsKey.lastLaunchedVersion)
        defaults.set(AppInfo.version, forKey: DefaultsKey.lastLaunchedVersion)
        if !startupOfPreviousRunDidNotFinish {
            DispatchQueue.main.async { [weak self] in
                self?.recoverStatusItemAfterUpdate(previousVersion: previousVersion)
            }
        }
        MediaEditorFileOpener.shared.finishLaunching()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        MediaEditorFileOpener.shared.open(urls)
    }

    /// Asking another app about its windows waits for that app to answer, and
    /// the wait allowed by default is a second and a half per question. An app
    /// that is busy saving, or stuck on a slow disk, would hold this one still
    /// for that long each time, and this app asks in places where the whole
    /// session is waiting on it. The limit is set once here, low enough that a
    /// slow answer is dropped rather than felt. The value matches what the
    /// window features already settled on for themselves. It applies to every
    /// question asked from this process, whichever element it is asked of, so
    /// it also covers the places that never set one of their own.
    private static func boundAccessibilityWaits() {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.35)
    }

    // MARK: - Startup that did not finish

    /// A start is marked as under way before anything else happens and cleared
    /// once the app has been running healthily for a while, or when it is
    /// quit properly. Finding the mark still set means the previous run died
    /// on the way up, and this one leaves the optional windows out of it.
    private var startupOfPreviousRunDidNotFinish = false

    /// How long a run has to last before its start counts as having worked.
    /// Comfortably past the point where the reported failures happened.
    private static let healthyStartupSeconds: TimeInterval = 20

    private func beginStartupWatch() {
        let defaults = UserDefaults.standard
        startupOfPreviousRunDidNotFinish = defaults.bool(forKey: DefaultsKey.startupDidNotFinish)
        defaults.set(true, forKey: DefaultsKey.startupDidNotFinish)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.healthyStartupSeconds) {
            UserDefaults.standard.removeObject(forKey: DefaultsKey.startupDidNotFinish)
        }
    }

    private func endStartupWatch() {
        UserDefaults.standard.removeObject(forKey: DefaultsKey.startupDidNotFinish)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if inputSourceRestorationPending { return .terminateLater }
        guard CommandBarService.shared.hasBorrowedInputSource else { return .terminateNow }
        inputSourceRestorationPending = true
        // Terminate-later runs a modal loop, which may be nested inside a
        // main-queue callback. Schedule in both modes before approving quit.
        RunLoop.main.perform(inModes: [.default, .modalPanel]) { [weak self] in
            CommandBarService.shared.restoreBorrowedInputSource()
            self?.inputSourceRestorationPending = false
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        isTerminating = true
        CommandBarService.shared.restoreBorrowedInputSource()
        if AppFeature.notch.isAvailable { NotchService.shared.stop(restoreCapture: false) }
        // Quitting properly means the start worked, whenever it happened.
        endStartupWatch()
        if AppFeature.brightness.isAvailable {
            BrightnessService.shared.restoreDisplaysBeforeTermination()
        }
        ExtraBrightnessService.stopIfLoaded()
        ProcessUsageService.shared.stopNetworkMonitoring(force: true)
        URLCleanerService.shared.stop()
        FocusFollowsMouseService.shared.stop()
        if AppFeature.windowMaximizer.isAvailable { WindowMaximizer.shared.stop() }
        WindowLayoutService.shared.suspend()
        KeyboardDebounceService.shared.suspend()
        MouseClickDebounceService.shared.suspend()
        TextSnippetService.shared.suspend()
        // Takes the Super key mapping back out before the process goes away.
        SuperKeyService.shared.suspend()
        // Dock's app and window switcher hotkeys persist after quit.
        AppSwitcher.shared.suspend()
        MouseButtonShortcutService.shared.suspend()
        MiddleClickService.shared.suspend()
        ScrollInverter.shared.suspend()
        SmoothScrollService.shared.suspend()
        if AppFeature.mouseAcceleration.isAvailable
            || MouseAccelerationRecovery.hasPendingEntries() {
            MouseAccelerationService.shared.stop()
        }
        MouseNavigationService.shared.suspend()
        DockPreviewService.shared.stop()
        SoundOutputSwitcher.shared.stop()
        PreciseVolumeRollerService.shared.stop()
        AppVolumeMixer.shared.stopAll()
        FanControlService.restoreBeforeTerminationIfNeeded()
        // Restore a singular preferred-microphone override. An active
        // microphone priority selection remains the system input on quit.
        AudioInputDeviceManager.shared.stop()
        // Flushes any scratchpad edit still inside the save debounce.
        ScratchpadService.shared.suspend()
        // Every macOS shortcut a feature took over goes back now, whichever
        // feature held it; not all of them suspend here.
        SystemShortcutTakeover.restoreAll()
        // The clipboard history persists through an async pipeline; the last
        // mutation (often a Clear) must land before the process dies.
        if AppFeature.clipboardHistory.isAvailable {
            ClipboardHistoryService.shared.flushBeforeTermination()
        }
        KeepAwakeManager.shared.deactivate(reason: .quit)
    }

    /// The lifeline when the menu bar icon goes missing. Opening the app again
    /// from Finder, Spotlight or Launchpad while it's already running lands here:
    /// force the icon back and pop the panel so there's immediate proof the app is
    /// alive. Without this, a hidden icon would strand the app running with no way
    /// in. (A cold launch can't happen while running, so this is the recovery path.)
    /// Reopens that Siri and Shortcuts send on their own are ignored.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        let requester = ReopenRequestSupport.currentSender()
        guard ReopenRequestSupport.isPersonOpeningApp(requester) else {
            Self.menuBarLog.log("reopen ignored from \(ReopenRequestSupport.logName(requester), privacy: .public)")
            return false
        }
        guard !flag else { return true }
        LatticeHubService.shared.toggle()
        return true
    }

    /// The screen frame of the status item button, validated as trustworthy
    /// for anchoring overlays (not an unplaced window parked at screen origin).
    var statusItemFrame: NSRect? {
        guard statusController?.statusItem.isVisible == true else { return nil }
        guard let frame = statusController?.statusItem.button?.window?.frame,
              StatusItemAnchorSupport.isTrustworthyStatusFrame(frame) else { return nil }
        return frame
    }

    private static let menuBarLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "lattice",
                                           category: "menubar")

    /// Whether the menu bar icon is actually visible on a screen, rather than
    /// present in the status bar but clipped or dropped by a crowded/notched menu
    /// bar (in which case the button still has a window, just not an on-screen one).
    private func iconIsOnScreen() -> Bool {
        // A hidden item is not on screen, whatever frame its window last had.
        guard statusController?.statusItem.isVisible == true,
              let frame = statusController?.statusItem.button?.window?.frame else { return false }
        // The band test, not mere intersection: an item macOS never places
        // keeps a full-size window at the main display's bottom-left origin,
        // which intersects that screen and read as "appeared" (#1394).
        return StatusItemPlacementSupport.isPlacedStatusFrame(frame, screenFrames: NSScreen.screens.map(\.frame))
    }

    /// What the recovery saw, in the app's own log. Whether macOS gave the
    /// rebuilt item a place is invisible from the outside, so a report of an
    /// icon that never comes back has nothing to go on without this
    /// (issue #369). Read with:
    /// log show --last 1h --predicate 'category == "menubar"'
    private func logStatusItemPlacement(_ stage: String) {
        let window = statusController?.statusItem.button?.window
        let frame = window?.frame ?? .zero
        let placement = "\(Int(frame.origin.x)),\(Int(frame.origin.y)) \(Int(frame.width))x\(Int(frame.height))"
        let screens = NSScreen.screens.map { "\(Int($0.frame.width))x\(Int($0.frame.height))" }
            .joined(separator: ",")
        let visible = statusController?.statusItem.isVisible ?? false
        let manager = Self.runningMenuBarManagerName() ?? "none"
        Self.menuBarLog.log("reshow \(stage, privacy: .public) window=\(window != nil) frame=\(placement, privacy: .public) visible=\(visible) screens=\(screens, privacy: .public) organizer=\(manager, privacy: .public)")
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    private func bindManagers() {
        KeepAwakeManager.shared.onSessionEnded = { reason in
            let strings = L10n.shared.s
            switch reason {
            case .timer:
                Notifier.post(title: strings.notifySessionEndedTitle, body: strings.notifySessionEndedBody)
            case .battery:
                Notifier.post(title: strings.notifyBatteryTitle, body: strings.notifyBatteryBody)
            default:
                break
            }
        }
    }

    // MARK: - Status item / Metrics

    func isOverStatusItem(_ point: NSPoint) -> Bool {
        statusController?.containsStatusItem(at: point) == true
    }

    private func showMetricPanel(for metric: MenuBarMetric, anchoredTo button: NSStatusBarButton) {
        let detailKind = metric.detailKind
        if NotchService.shared.acceptsSystemFeedback {
            NotchService.shared.showMetric(detailKind, toggle: true)
        } else {
            LatticeHubService.shared.toggle()
        }
    }

    @objc private func appBecameActive() {
        UpdateService.shared.checkIfStale()
        restoreAfterAppUpdateHandoff()
        if settingsWindow?.isVisible == true {
            NotificationCenter.default.post(name: LaunchAtLoginSupport.settingsRefreshRequested, object: nil)
        }
    }

    private func restoreAfterAppUpdateHandoff() {
        guard AppFeature.appUpdates.isAvailable else { return }
        let service = AppUpdatesService.shared
        service.applicationBecameActive()
        guard service.consumeUpdateHandoffReturn(),
              settingsWindow?.isVisible == true else { return }
        openSettingsWindow()
    }

    func closePopover(animated: Bool = true, after delay: TimeInterval = 0,
                      preservingNotch: Bool = false, reason: PanelCloseReason = .action,
                      completion: (() -> Void)? = nil) {
        if !preservingNotch, NotchSupport.isEnabled() { NotchService.shared.collapse() }
        completion?()
    }

    // MARK: - Context menu (right click)

    private func showContextMenu(from button: NSStatusBarButton?) {
        presentContextMenu(from: button)
    }

    private func presentContextMenu(from button: NSStatusBarButton?) {
        let strings = L10n.shared.s
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: strings.menuSettings, action: #selector(menuOpenSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: strings.menuAbout, action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: strings.menuQuit, action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        let host = statusController.menuHost(for: button)
        host.menu = menu
        host.button?.performClick(nil)
        DispatchQueue.main.async {
            host.menu = nil
        }
    }

    @objc private func menuOpenSettings() {
        openSettingsWindow()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSAttributedString(
            string: L10n.shared.s.aboutDescription,
            attributes: [.font: NSFont.systemFont(ofSize: 11)]
        )
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    // MARK: - Application menu

    /// Builds and installs the standard application menu (App / Edit / Go / Window).
    ///
    /// Because the app runs as an accessory, AppKit never gives it the default main
    /// menu a regular app gets, so `NSApp.mainMenu` stays nil and the standard key
    /// equivalents (which live on menu items) never resolve. That is why nothing
    /// happens for Cmd+H/M/W/Q or Cmd+C/V/X/A inside the Settings window. A minimal
    /// standard menu restores them. The menu bar only appears while one of the
    /// app's own windows is focused; otherwise the app is as invisible as before.
    /// Most items use the responder chain (nil target) so they act on the key
    /// window or the focused text field; About and Settings route to our handlers.
    func installMainMenu() {
        let strings = L10n.shared.s
        let mainMenu = NSMenu()

        // Application menu (the bold, app-named first menu).
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let about = NSMenuItem(title: strings.menuAbout, action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        appMenu.addItem(about)
        appMenu.addItem(.separator())

        let settings = NSMenuItem(title: strings.menuSettings, action: #selector(menuOpenSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(.separator())

        appMenu.addItem(NSMenuItem(title: strings.menuHide,
                                   action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        let hideOthers = NSMenuItem(title: strings.menuHideOthers,
                                    action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(NSMenuItem(title: strings.menuShowAll,
                                   action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: strings.menuQuit,
                                   action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // Edit menu, so text fields in Settings respond to the editing shortcuts.
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: strings.menuEdit)
        editMenuItem.submenu = editMenu

        editMenu.addItem(NSMenuItem(title: strings.menuUndo, action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: strings.menuRedo, action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: strings.menuCut, action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: strings.menuCopy, action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: strings.menuPaste, action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: strings.menuSelectAll, action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        // Drivers and other running copies of Lattice may translate side buttons
        // into menu commands before this process ever receives a raw mouse event.
        let navigationMenuItem = NSMenuItem()
        navigationMenuItem.submenu = SettingsWindow.navigationMenu(language: L10n.shared.language)
        mainMenu.addItem(navigationMenuItem)

        // Window menu (Minimize / Zoom / Close). Settings is .miniaturizable so
        // Cmd+M actually minimizes; AppKit manages enabling once windowsMenu is set.
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: strings.menuWindow)
        windowMenuItem.submenu = windowMenu

        windowMenu.addItem(NSMenuItem(title: strings.menuMinimize,
                                      action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: strings.menuZoom,
                                      action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
        windowMenu.addItem(.separator())
        windowMenu.addItem(NSMenuItem(title: strings.menuClose,
                                      action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }

    // MARK: - Windows

    func openSettingsWindow() {
        NotchService.shared.prepareForSettings()
        LatticeHubService.shared.previousApp = nil
        LatticeHubService.shared.hide()
        let isAlreadyVisible = settingsWindow?.isVisible == true
        let targetScreen = NSScreen.withMouse
        let createdWindow = settingsWindow == nil
        if settingsWindow == nil {
            let host = SettingsHostingController(rootView: SettingsView())
            // Empty on purpose: any automatic option here (.intrinsicContentSize,
            // .maxSize, .preferredContentSize) lets SwiftUI's content - which
            // varies wildly page to page, from a short toggle list to Kill
            // Process's few-hundred-row List - drive the window's size, either
            // growing it to fit content or freezing it at a stale snapshot.
            // The window's size is fully owned by SettingsWindowSupport's
            // explicit sizing below plus ordinary user drag-resize.
            host.sizingOptions = []
            let window = SettingsWindow(contentViewController: host)
            window.isMouseButtonCaptureActive = { MouseButtonShortcutService.isCaptureActive }
            // .miniaturizable so the Window menu's Minimize (Cmd+M) actually works.
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.configureGeometry(for: host.view)
            let visible = targetScreen?.visibleFrame ?? NSScreen.pointerVisibleFrame
            let size = SettingsWindowSupport.initialContentSize(
                savedHeight: UserDefaults.standard.double(forKey: DefaultsKey.settingsWindowHeight),
                availableHeight: Double(visible.height - 40))
            window.setContentSize(NSSize(width: size.width, height: size.height))
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.hidesOnDeactivate = false
            window.canHide = false
            window.delegate = self
            settingsWindow = window
        }
        settingsWindow?.title = L10n.shared.s.settingsTitle
        if let window = settingsWindow, !isAlreadyVisible {
            positionSettingsWindow(window, force: createdWindow, on: targetScreen)
        }
        if !settingsKeepsAppRegular {
            settingsKeepsAppRegular = true
            WindowActivationPolicy.retain()
        }
        if let window = settingsWindow {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        // Reopening on the very page that was showing at close never runs
        // that page's own onAppear, since its view was never removed from
        // the hierarchy; the window itself is the only reliable signal here.
        SecureInputMonitor.shared.setSettingsWindowOpen(true)
        SettingsWindowVisibility.shared.set(true)
        NotificationCenter.default.post(name: LaunchAtLoginSupport.settingsRefreshRequested, object: nil)
        if !isAlreadyVisible {
            DispatchQueue.main.async { [weak self] in
                guard let self, let window = self.settingsWindow else { return }
                self.positionSettingsWindow(window, force: false, on: targetScreen)
            }
        }
    }

    func openFeedbackWindow(kind: FeedbackKind = .bug) {
        closePopover()
        NSApp.activate(ignoringOtherApps: true)
        let visible = (NSScreen.withMouse ?? NSScreen.main)?.visibleFrame ?? NSScreen.pointerVisibleFrame
        if let window = feedbackWindow, window.isVisible {
            FeedbackWindowPresentation.present(window, from: settingsWindow, fallbackVisibleFrame: visible)
            return
        }
        let host = NSHostingController(rootView: FeedbackView(initialKind: kind) { [weak self] in
            guard let self, let window = self.feedbackWindow else { return }
            FeedbackWindowPresentation.dismiss(window)
        })
        let window: NSWindow
        if let existing = feedbackWindow {
            existing.contentViewController = host
            window = existing
        } else {
            let win = NSWindow(contentViewController: host)
            win.styleMask = [.titled, .closable, .fullSizeContentView]
            win.titleVisibility = .hidden
            win.titlebarAppearsTransparent = true
            win.isReleasedWhenClosed = false
            win.isRestorable = false
            win.delegate = self
            feedbackWindow = win
            window = win
        }
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.title = FeatureStrings.feedback(L10n.shared.language).windowTitle
        FeedbackWindowPresentation.present(window, from: settingsWindow, fallbackVisibleFrame: visible)
    }

    private func positionSettingsWindow(_ window: NSWindow, force: Bool, on targetScreen: NSScreen? = nil) {
        window.contentView?.layoutSubtreeIfNeeded()
        let screen = targetScreen.flatMap { $0.isStillAttached ? $0 : nil } ?? window.screen
        let visible = screen?.visibleFrame ?? NSScreen.pointerVisibleFrame
        let shouldCenter = force || screen?.displayID != window.screen?.displayID || !visible.intersects(window.frame)
        let margin: CGFloat = 40
        let availableWidth = max(1, visible.width - margin)
        let availableHeight = max(1, visible.height - margin)
        let minFrame = window.frameRect(forContentRect: NSRect(
            x: 0, y: 0,
            width: SettingsWindowSupport.minContentWidth,
            height: SettingsWindowSupport.minContentHeight
        )).size
        let width = min(max(window.frame.width, minFrame.width), availableWidth)
        let height = min(max(window.frame.height, minFrame.height), availableHeight)
        var frame = shouldCenter
            ? NSRect(x: visible.midX - width / 2,
                     y: visible.midY - height / 2,
                     width: width,
                     height: height)
            : NSRect(x: window.frame.minX,
                     y: window.frame.minY,
                     width: width,
                     height: height)

        if shouldCenter {
            frame.origin.x = min(max(frame.origin.x, visible.minX + margin / 2), visible.maxX - width - margin / 2)
            frame.origin.y = min(max(frame.origin.y, visible.minY + margin / 2), visible.maxY - height - margin / 2)
        }
        window.setFrame(frame.integral, display: false)
    }

    /// Only the first launch of a newer version gets this bounded check. Normal
    /// launches and activations must not disturb an arranged menu bar.
    private func recoverStatusItemAfterUpdate(previousVersion: String?) {
        guard let previousVersion, !AppInfo.isDeveloperBuild,
              let previous = UpdateServiceSupport.SemanticVersion(raw: previousVersion),
              let current = UpdateServiceSupport.SemanticVersion(raw: AppInfo.version), current > previous,
              let item = statusController?.statusItem else { return }
        let screens = NSScreen.screens.map(\.frame)
        guard !screens.isEmpty else { return }
        verifyPostUpdateStatusItem(item, screenFrames: screens,
                                   deadline: Date().addingTimeInterval(30))
    }

    private static let reshowVerifyInterval: TimeInterval = 0.8

    private func verifyPostUpdateStatusItem(_ item: NSStatusItem,
                                            screenFrames: [CGRect],
                                            deadline: Date,
                                            attemptsLeft: Int = 12,
                                            recreated: Bool = false) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.reshowVerifyInterval) { [weak self, weak item] in
            // Reopening or explicitly recovering the app replaces this item,
            // cancelling these callbacks. A sleep, display change or hidden bar
            // is not evidence of failed placement, so those stop the check too.
            guard let self, let item, self.statusController?.statusItem === item,
                  !self.isTerminating,
                  item.menu == nil, item.isVisible,
                  NSEvent.pressedMouseButtons == 0,
                  Date() < deadline,
                  !UserDefaults.standard.bool(forKey: DefaultsKey.menuBarHideIconWithMetrics),
                  NSScreen.screens.map(\.frame) == screenFrames,
                  NSMenu.menuBarVisible(),
                  NSApp.currentSystemPresentationOptions.intersection(
                    [.autoHideMenuBar, .hideMenuBar, .fullScreen]).isEmpty,
                  let session = CGSessionCopyCurrentDictionary() as? [String: Any],
                  SessionActivitySupport.isOnConsole(session),
                  !KeepAwakeAutomationSupport.isScreenLocked(sessionDictionary: session),
                  Self.runningMenuBarManagerName() == nil else { return }
            if self.iconIsOnScreen() {
                self.logStatusItemPlacement("post-update appeared")
                return
            }
            guard attemptsLeft <= 1 else {
                self.verifyPostUpdateStatusItem(item, screenFrames: screenFrames, deadline: deadline,
                                                attemptsLeft: attemptsLeft - 1, recreated: recreated)
                return
            }
            // Preserve the autosave identity and position. The more disruptive
            // reset remains exclusive to the person's explicit recovery action.
            guard !recreated else {
                self.logStatusItemPlacement("post-update still hidden")
                return
            }
            self.logStatusItemPlacement("post-update recreating")
            self.statusController?.recreateStatusItem()
            if let replacement = self.statusController?.statusItem {
                self.verifyPostUpdateStatusItem(replacement, screenFrames: screenFrames,
                                                deadline: deadline, recreated: true)
            }
        }
    }

    /// Known menu bar organizers, by bundle id; any of them can be holding
    /// the icon in its hidden section, which explains it never reappearing
    /// on this machine. The hint names whichever one is running by its own
    /// localized app name.
    private static let menuBarManagerBundlePrefixes = [
        "com.jordanbaird.Ice",
        "com.surteesstudios.Bartender",
        "com.dwarvesv.minimalbar",
        "com.mortenjust.Dozer",
    ]

    private static func runningMenuBarManagerName() -> String? {
        for app in NSWorkspace.shared.runningApplications {
            guard let bundleID = app.bundleIdentifier else { continue }
            if menuBarManagerBundlePrefixes.contains(where: { bundleID.hasPrefix($0) }) {
                return app.localizedName
            }
        }
        return nil
    }

    /// Quits and reopens the app. Full Disk Access only applies to a fresh
    /// process, so this is how the uninstaller picks up a just-granted grant.
    func relaunchApp() {
        FeatureRuntime.shared.relaunchApp()
    }















    /// Centers the update preview using its fitted content size.
    private func centerUpdatePreviewWindow(_ window: NSWindow) {
        let visible = window.screen?.visibleFrame ?? NSScreen.pointerVisibleFrame
        window.contentView?.layoutSubtreeIfNeeded()
        if let fitting = window.contentViewController?.view.fittingSize,
           fitting.width > 0, fitting.height > 0 {
            window.setContentSize(fitting)
        }
        let size = window.frame.size
        let x = min(max(visible.midX - size.width / 2, visible.minX), max(visible.minX, visible.maxX - size.width))
        let y = min(max(visible.midY - size.height / 2, visible.minY), max(visible.minY, visible.maxY - size.height))
        window.setFrameOrigin(NSPoint(x: x.rounded(), y: y.rounded()))
    }

    /// The pre-install update preview, shown before any download from BOTH the
    /// Settings install button and the menu panel's update banner (the blue
    /// button most people use), so the changelog is always seen first. In the
    /// Developer build `downloadAndInstall()` is a no-op, so confirming is safe.
    func showUpdatePreview() {
        guard case let .available(version) = UpdateService.shared.state else { return }
        closePopover()
        if let window = updatePreviewWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let host = NSHostingController(rootView: UpdatePreviewView(
            version: version,
            notes: UpdateService.shared.availableNotes,
            onUpdate: { [weak self] in
                self?.updatePreviewWindow?.close()
                UpdateService.shared.downloadAndInstall()
            },
            onCancel: { [weak self] in
                self?.updatePreviewWindow?.close()
            }
        ))
        host.sizingOptions = .preferredContentSize
        let window = NSWindow(contentViewController: host)
        window.title = L10n.shared.s.tabReleaseNotes
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.isMovableByWindowBackground = true
        window.delegate = self
        centerUpdatePreviewWindow(window)
        updatePreviewWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window, window === self.updatePreviewWindow else { return }
            self.centerUpdatePreviewWindow(window)
        }
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        if sender === settingsWindow {
            let minFrame = sender.frameRect(forContentRect: NSRect(
                x: 0, y: 0,
                width: SettingsWindowSupport.minContentWidth,
                height: SettingsWindowSupport.minContentHeight
            )).size
            return NSSize(
                width: minFrame.width,
                height: max(frameSize.height, minFrame.height)
            )
        }
        return frameSize
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === settingsWindow else { return }
        saveSettingsWindowSize(window)
    }

    func windowDidChangeOcclusionState(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === settingsWindow else { return }
        // Minimized, on another Space or covered, Settings draws for nobody too.
        SettingsWindowVisibility.shared.set(window.isVisible && window.occlusionState.contains(.visible))
    }

    /// Remembers the user-chosen Settings size (as content size, so the
    /// restore is title bar independent).
    private func saveSettingsWindowSize(_ window: NSWindow) {
        guard let size = window.contentView?.frame.size else { return }
        guard SettingsWindowSupport.isValidContentSize(width: Double(size.width),
                                                      height: Double(size.height)) else { return }
        UserDefaults.standard.set(Double(size.height), forKey: DefaultsKey.settingsWindowHeight)
    }


    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === settingsWindow {
            if let feedback = feedbackWindow,
               feedback.sheetParent === settingsWindow || feedback.parent === settingsWindow {
                FeedbackWindowPresentation.dismiss(feedback)
            }
            // Covers size changes that end without a live resize (zoom).
            saveSettingsWindowSize(window)
            if settingsKeepsAppRegular {
                settingsKeepsAppRegular = false
                WindowActivationPolicy.release()
            }
            // Whatever page was showing, its own onDisappear does not always
            // run before the window finishes closing; stop the poll from
            // here too rather than let it run until the app quits. The
            // page's own demand is left alone, so it resumes on its own the
            // moment the window reopens, on this page or any other.
            SecureInputMonitor.shared.setSettingsWindowOpen(false)
            SettingsWindowVisibility.shared.set(false)
            return
        }
        if window === feedbackWindow {
            if let parent = window.sheetParent { parent.endSheet(window) }
            window.parent?.removeChildWindow(window)
            return
        }
        if window === updatePreviewWindow {
            updatePreviewWindow = nil
        }
    }





}
