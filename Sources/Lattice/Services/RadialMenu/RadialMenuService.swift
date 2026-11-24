// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox
import SwiftUI

/// The radial menu: a wheel of user-configured actions, opened at the pointer
/// by one menu-wide keyboard shortcut, mouse button or four-finger trackpad
/// gesture, always on the primary (first) profile. A quick press of the
/// shortcut or button leaves the menu open; holding it and letting go over an
/// action runs that action. The other profiles are tabs on an arc above the
/// wheel. At rest the feature holds only the Carbon hotkey and a pre-warmed,
/// hidden panel (so the wheel appears instantly); every event monitor lives
/// only while a wheel is on screen, and switching the feature off frees it all.
final class RadialMenuService: ObservableObject {
    static let shared = RadialMenuService()

    /// Wheels from root to the currently shown submenu; the last entry is on
    /// screen. Empty means no session.
    @Published private(set) var stack: [[RadialMenuItem]] = []
    /// The profiles this session opened with, in tab order. Settings changes
    /// mid-session wait for the next one.
    @Published private(set) var sessionProfiles: [RadialMenuProfile] = []
    @Published private(set) var activeProfileIndex = 0
    /// Names of the submenus that were descended into, for the hub's back hint.
    @Published private(set) var trail: [String] = []
    @Published private(set) var highlightedIndex: Int?
    /// The profile tab under the pointer, by profile index.
    @Published private(set) var hoveredTabIndex: Int?
    /// Bumped on every profile switch, so the chips fold away and the new
    /// profile's fly out.
    @Published private(set) var profileSwitchCount = 0
    /// The profile just switched to, which the hub names for a moment.
    @Published private(set) var flashedProfileName: String?
    @Published private(set) var nowPlayingState = RadialNowPlayingState.nothingPlaying
    /// True while the session still owns its shortcut or mouse button; the
    /// release decides what happens (`RadialMenuSupport.releaseAction`).
    @Published private(set) var holdPhase = false
    /// True when macOS refused the shortcut (taken by another app).
    @Published private(set) var registrationFailed = false
    /// True while the app is actually able to watch for the chosen mouse
    /// button. Off means the button can never open the wheel, whatever the
    /// setting says, and the settings screen can say so instead of leaving
    /// the user guessing.
    @Published private(set) var isWatchingMouseButton = false
    /// The panel's side this session, larger when the tab arc is shown.
    @Published private(set) var panelSide = RadialMenuLayout.panelSize

    /// Drives the wheel's arrival and departure: false while the panel is
    /// being placed, true once it is on screen, and false again the moment a
    /// session starts closing, which is what lets the wheel shrink away
    /// instead of blinking out.
    @Published private(set) var visible = false

    var activeProfile: RadialMenuProfile? {
        sessionProfiles.indices.contains(activeProfileIndex) ? sessionProfiles[activeProfileIndex] : nil
    }

    private let hotkey = QuickToolHotkey(id: 1700)
    private var panel: NSPanel?
    private var wheelCenter: CGPoint = .zero
    private var openPointerLocation: CGPoint = .zero
    private var pointerActivated = false
    private var sessionShortcut: GlobalShortcut?
    /// A shortcut with no modifiers ends its hold on the Carbon key-up.
    private var sessionAwaitsKeyUp = false
    private var sessionUsesSuperKey = false
    private var sessionID = 0
    private var holdStartedAt: TimeInterval = 0
    /// Set while a session was summoned by a mouse button and it is still
    /// down; releasing it decides like releasing the shortcut.
    private var holdButton: Int64?
    private var holdSafety: DispatchWorkItem?
    private var tabDwell: DispatchWorkItem?
    private var flashToken = 0
    /// Where the view drew each profile tab on its arc, by profile index:
    /// the angle range of the band's centre line.
    private var tabSpans: [Int: ClosedRange<Double>] = [:]
    private var scrollSteps = RadialProfileScrollAccumulator()
    private var mouseTap: CFMachPort?
    private var mouseTapSource: CFRunLoopSource?
    private var eventMonitors: [Any] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var promptedForAccessibility = false
    private let dismissal = PanelDismissal()

    private init() {
        hotkey.onPress = { [weak self] in self?.hotkeyPressed() }
        hotkey.onRelease = { [weak self] in self?.hotkeyReleased() }
        // A filter tap owned by a switched-away login session keeps its place
        // in the chain, so the account on screen waits out this tap's timeout
        // on every extra-button click it makes (issue #1075). Hand the tap
        // back on resign and build it again from preferences on the way in.
        // The open wheel goes with it: this tap is the only thing that sees a
        // held summoner released, so a wheel still up when the tap is handed
        // back would come back stuck in hold phase with no release coming.
        SessionActivity.shared.onChange { [weak self] active in
            if !active { self?.endSession() }
            self?.syncMouseTap()
        }
    }

    var sessionActive: Bool { !stack.isEmpty && !dismissal.isActive }

    private var currentItems: [RadialMenuItem] { stack.last ?? [] }

    // MARK: - Lifecycle

    func syncWithPreferences() {
        // The trackpad gesture is recognized by the middle click's contact
        // reader, and the Mouse Buttons drag to switch Spaces steps off a
        // button this menu claims; both follow the menu's settings.
        defer {
            MiddleClickService.shared.syncWithPreferences()
            MouseButtonShortcutService.shared.syncWithPreferences()
        }
        let defaults = UserDefaults.standard
        let enabled = AppFeature.radialMenu.isAvailable
            && defaults.bool(forKey: DefaultsKey.radialMenuEnabled)
        guard enabled else {
            suspend()
            registrationFailed = false
            return
        }

        let shortcut = GlobalShortcut.saved(for: DefaultsKey.radialMenuShortcut,
                                            fallback: .radialMenuDefault, in: defaults)
        if shortcut.isValid {
            registrationFailed = !hotkey.sync(enabled: true, shortcut: shortcut,
                                              storageKey: DefaultsKey.radialMenuShortcut,
                                              takesOver: GlobalShortcutRole.radialMenu.supportsTakeOver)
        } else {
            hotkey.unregister()
            registrationFailed = false
        }

        syncMouseTap()
        // First render of a hosting view costs real time; pay it now so the
        // wheel appears the instant the shortcut fires.
        ensurePanel().contentView?.layoutSubtreeIfNeeded()
    }

    func suspend() {
        hotkey.unregister()
        tearDownMouseTap()
        endSession()
        panel = nil
    }

    // MARK: - Mouse button trigger (a tap so the click never also reaches the
    // app under the pointer; alive only while a button is configured, torn
    // down with the feature)

    /// Whether the button tap has a job right now. The feature check is here
    /// rather than only in `syncWithPreferences`, because the resign handler
    /// calls the sync directly and so never passes that guard.
    private func mouseTapWanted() -> Bool {
        let defaults = UserDefaults.standard
        return RadialMenuSupport.claimedMouseButton(defaults: defaults) != nil
            && AppFeature.radialMenu.isAvailable
            && defaults.bool(forKey: DefaultsKey.radialMenuEnabled)
    }

    private func syncMouseTap() {
        // Accessibility is asked of the system and not of `Permissions.shared`,
        // whose answer is a poll up to `PermissionPollingSupport.interval` old.
        // The re-arm hands a tap it declines to put back to this sync to be
        // stopped, and a stale grant here would install it straight back.
        guard SessionActivitySupport.tapShouldRun(
            featureWanted: mouseTapWanted(),
            accessibilityGranted: AXIsProcessTrusted(),
            sessionIsActive: SessionActivity.shared.isActive
        ) else {
            tearDownMouseTap()
            // A wheel held open by the button would never see its release
            // now; it closes rather than waiting for a click to end it.
            if sessionActive, holdPhase, holdButton != nil { endSession() }
            return
        }
        // A tap the system disabled (Accessibility revoked and regranted)
        // never revives on its own; rebuild it instead of keeping the corpse.
        if let mouseTap, !CGEvent.tapIsEnabled(tap: mouseTap) {
            tearDownMouseTap()
        }
        guard mouseTap == nil else { return }
        let mask = (CGEventMask(1) << CGEventType.otherMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.otherMouseUp.rawValue)
        guard let tap = InputEventTap.create(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let service = Unmanaged<RadialMenuService>.fromOpaque(userInfo).takeUnretainedValue()
                return service.handleMouseTap(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }
        mouseTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        mouseTapSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        InputEventTap.enable(tap: tap, enable: true)
        if !isWatchingMouseButton { isWatchingMouseButton = true }
    }

    private func tearDownMouseTap() {
        if let mouseTap {
            InputEventTap.enable(tap: mouseTap, enable: false)
            CFMachPortInvalidate(mouseTap)
        }
        if let mouseTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), mouseTapSource, .commonModes)
        }
        mouseTap = nil
        mouseTapSource = nil
        if isWatchingMouseButton { isWatchingMouseButton = false }
    }

    private func handleMouseTap(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // This tap's callback runs on the main run loop, so the session
            // flag is read where it is written. A tap put straight back is a
            // tap put back into whatever session is on screen now, which is
            // the stall the gate exists to end (issue #1075). Accessibility is
            // asked for the same reason as the sync: this tap swallows the
            // click, so a revoked grant has to end it rather than put it back.
            if SessionActivitySupport.tapShouldRun(
                featureWanted: mouseTapWanted(),
                accessibilityGranted: AXIsProcessTrusted(),
                sessionIsActive: SessionActivity.shared.isActive
            ), let mouseTap {
                InputEventTap.enable(tap: mouseTap, enable: true)
            } else {
                // Invalidating the port from its own callback stack is unsafe;
                // finish this callback fail-open, then release the tap.
                DispatchQueue.main.async { [weak self] in self?.syncMouseTap() }
            }
            return Unmanaged.passUnretained(event)
        }
        // While a Settings capture row is listening (Mouse Buttons, or this
        // menu's own recorder), the press belongs to it, even this wheel's
        // own summoner.
        if MouseButtonShortcutService.isCaptureActive {
            return Unmanaged.passUnretained(event)
        }
        let button = event.getIntegerValueField(.mouseEventButtonNumber)
        // The release of the button holding the wheel open ends the hold even
        // if the setting moved to another button meanwhile: its down was
        // consumed, so its up is too.
        if type == .otherMouseUp, holdPhase, holdButton == button {
            endHoldPhase()
            return nil
        }
        // Every press and release of every extra button lands here, so the
        // cheap question comes first: one stored string, never the profiles.
        guard RadialMenuSupport.claimedMouseButton() == button else {
            return Unmanaged.passUnretained(event)
        }

        // The source lives on the main run loop, so this already runs on
        // main; acting synchronously keeps a quick click ordered (the down
        // opens the wheel before its own up arrives). The claimed button is
        // the wheel's alone: both halves of every click are consumed, so the
        // app under the pointer never sees half a gesture.
        if type == .otherMouseDown {
            if sessionActive {
                // A second trigger closes the menu, whichever opened it.
                endSession()
            } else {
                beginSession(hold: true, heldButton: button)
            }
        }
        return nil
    }

    // MARK: - Session

    private func hotkeyPressed() {
        // Carbon hot keys never autorepeat, so a press during a session is
        // always the user asking to close, even with the modifiers still
        // held from the summoning chord.
        if sessionActive {
            endSession()
            return
        }
        beginSession(hold: true)
    }

    /// The shortcut's key coming up. A modifier-free shortcut ends its hold
    /// here. A chord ends it here when its key was only tapped, or when its
    /// modifiers are already gone; otherwise the modifiers end it as they
    /// lift, through the flags monitor.
    private func hotkeyReleased() {
        guard sessionActive, holdPhase, holdButton == nil else { return }
        if sessionAwaitsKeyUp {
            endHoldPhase()
        } else if let shortcut = sessionShortcut,
                  RadialMenuSupport.chordKeyUpEndsHold(
                      heldFor: ProcessInfo.processInfo.systemUptime - holdStartedAt,
                      usesSuperKey: sessionUsesSuperKey,
                      modifiersHeld: shortcut.requiredModifiersHeld(in: NSEvent.modifierFlags),
                      superKeyHeld: superKeyStillHeld) {
            endHoldPhase()
        }
    }

    private var superKeyStillHeld: Bool {
        sessionUsesSuperKey && SuperKeyService.isEngaged && SuperKeyService.shared.isHeld
    }

    /// The four-finger tap or click: opens a sticky menu on the primary
    /// profile, or closes any open one, like a second press of its shortcut.
    /// `gesture` is the one recognised; queued before a change of setting,
    /// it no longer opens anything once the menu answers another gesture.
    func toggleFromTrackpad(_ gesture: RadialMenuTrackpadGesture) {
        guard gesture != .off, RadialMenuSupport.effectiveTrackpadGesture() == gesture else { return }
        if sessionActive {
            endSession()
            return
        }
        beginSession(hold: false)
    }

    private func beginSession(hold: Bool, heldButton: Int64? = nil) {
        let defaults = UserDefaults.standard
        let profiles = RadialMenuSupport.decodeProfiles(
            defaults.data(forKey: DefaultsKey.radialMenuProfiles), defaults: defaults)
        guard RadialProfileTabs.canOpen(availableItemCounts: profiles.map { availableItems($0.items).count }),
              let primary = profiles.first else {
            NSSound.beep()
            return
        }
        // Summoned again mid-close, the wheel is taken back rather than left
        // to be emptied by the closing it was already in the middle of.
        dismissal.cancel { forgetSession() }
        // Small and clear until the panel is placed, so the wheel has somewhere
        // to grow from.
        visible = false
        sessionProfiles = profiles
        activeProfileIndex = 0
        hoveredTabIndex = nil
        flashedProfileName = nil
        tabSpans = [:]
        scrollSteps.reset()
        let items = availableItems(primary.items)
        refreshNowPlaying(for: items)

        let shortcut = GlobalShortcut.saved(for: DefaultsKey.radialMenuShortcut,
                                            fallback: .radialMenuDefault, in: defaults)
        let keyboardHold = hold && heldButton == nil
        sessionShortcut = keyboardHold ? shortcut : nil
        sessionAwaitsKeyUp = keyboardHold && shortcut.modifiers.isEmpty
        sessionUsesSuperKey = keyboardHold
            && SuperKeyService.isEngaged && SuperKeyService.shared.isHeld
        holdButton = hold ? heldButton : nil
        holdPhase = hold
        holdStartedAt = ProcessInfo.processInfo.systemUptime
        sessionID &+= 1
        let activeSessionID = sessionID
        if sessionUsesSuperKey {
            SuperKeyService.shared.onHoldEnded = { [weak self] released in
                guard let self,
                      self.sessionUsesSuperKey,
                      self.sessionID == activeSessionID else { return }
                // No pointer event may mistake a queued cancellation for a
                // physical release before the deferred resolution runs.
                self.sessionShortcut = nil
                DispatchQueue.main.async {
                    guard self.sessionUsesSuperKey,
                          self.sessionID == activeSessionID else { return }
                    if released {
                        self.endHoldPhase()
                    } else {
                        self.endSession()
                    }
                }
            }
        }
        if sessionAwaitsKeyUp { armHoldSafety(sessionID: activeSessionID) }
        stack = [items]
        trail = []
        highlightedIndex = nil
        pointerActivated = false
        openPointerLocation = NSEvent.mouseLocation

        // Always at the pointer, kept whole on its screen, tabs included.
        let side = RadialMenuLayout.panelSize(showsTabs: profiles.count > 1)
        panelSide = side
        let visibleFrame = NSScreen.pointerVisibleFrame
        wheelCenter = clampedCenter(NSEvent.mouseLocation, side: side, in: visibleFrame)

        let panel = ensurePanel()
        panel.setFrame(NSRect(x: wheelCenter.x - side / 2, y: wheelCenter.y - side / 2,
                              width: side, height: side),
                       display: false)
        WheelMotion.present(panel)
        installMonitors(for: panel)
        refreshHighlight()
        // On the next turn, so the wheel has been drawn small once and has a
        // state to grow out of.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.sessionActive, self.sessionID == activeSessionID else { return }
            self.visible = true
        }
    }

    private func refreshNowPlaying(for items: [RadialMenuItem]) {
        if RadialMenuSupport.containsNowPlaying(items) {
            let nowPlaying = RadialNowPlayingService.shared
            nowPlaying.dismissDetails()
            nowPlaying.refresh { [weak self] state in self?.nowPlayingState = state }
        } else {
            nowPlayingState = .nothingPlaying
        }
    }

    private func endSession() {
        // A closing already under way finishes on its own.
        if dismissal.isActive { return }
        removeMonitors()
        stopTrackingSuperKeyHold()
        cancelHoldTimers()
        guard let panel, panel.isVisible, !stack.isEmpty else {
            forgetSession()
            return
        }
        // The wheel keeps its slices while it shrinks: emptying the stack now
        // would leave a bare disc fading out where a menu used to be.
        visible = false
        dismissal.begin(panel) { [weak self] in self?.forgetSession() }
    }

    /// Everything a session leaves behind, dropped once the wheel is gone.
    private func forgetSession() {
        visible = false
        panel?.orderOut(nil)
        stack = []
        sessionProfiles = []
        activeProfileIndex = 0
        trail = []
        highlightedIndex = nil
        hoveredTabIndex = nil
        flashedProfileName = nil
        tabSpans = [:]
        holdPhase = false
        holdButton = nil
        sessionShortcut = nil
        sessionAwaitsKeyUp = false
        cancelHoldTimers()
        if !AppFeature.radialMenu.isAvailable
            || !UserDefaults.standard.bool(forKey: DefaultsKey.radialMenuEnabled) {
            panel = nil
        }
    }

    /// Wheels only show what can actually run today: tools whose feature was
    /// uninstalled in the hub disappear instead of leaving a dead slice.
    private func availableItems(_ items: [RadialMenuItem]) -> [RadialMenuItem] {
        items.compactMap { item in
            var item = item
            if let tool = item.tool, !tool.isRunnable() { return nil }
            if item.kind == .quickToggle,
               let action = item.quickToggle, !action.isAvailable { return nil }
            if item.kind == .windowLayout, !AppFeature.windowLayout.isAvailable { return nil }
            if item.kind == .submenu {
                item.children = availableItems(item.children)
                if item.children.isEmpty { return nil }
            }
            return item
        }
    }

    private func clampedCenter(_ wanted: CGPoint, side: CGFloat, in frame: NSRect) -> CGPoint {
        let half = side / 2
        guard frame.width > side, frame.height > side else { return wanted }
        return CGPoint(x: min(max(wanted.x, frame.minX + half), frame.maxX - half),
                       y: min(max(wanted.y, frame.minY + half), frame.maxY - half))
    }

#if LATTICE_DEVELOPMENT
    /// A session's look without a panel, input or timers, for the rendering
    /// probe only.
    func showRenderingPreview(profiles: [RadialMenuProfile], highlighted: Int?, hoveredTab: Int?) {
        sessionProfiles = profiles
        activeProfileIndex = 0
        stack = [profiles.first.map { availableItems($0.items) } ?? []]
        highlightedIndex = highlighted
        hoveredTabIndex = hoveredTab
        panelSide = RadialMenuLayout.panelSize(showsTabs: profiles.count > 1)
        visible = true
    }
#endif

    // MARK: - Profiles

    /// Tab, Shift-Tab and scrolling: the next or previous profile, wrapping.
    func switchProfile(by step: Int) {
        guard sessionActive, sessionProfiles.count > 1 else { return }
        switchProfile(to: RadialProfileTabs.index(from: activeProfileIndex, step: step,
                                                  count: sessionProfiles.count))
    }

    /// Shows another profile's wheel: highlight cleared, back at its root,
    /// the pointer re-armed. A hold in progress carries on, so letting go
    /// then decides against the new wheel.
    func switchProfile(to index: Int) {
        guard sessionActive, sessionProfiles.indices.contains(index) else { return }
        cancelTabDwell()
        guard index != activeProfileIndex else { return }
        activeProfileIndex = index
        let profile = sessionProfiles[index]
        let items = availableItems(profile.items)
        refreshNowPlaying(for: items)
        stack = [items]
        trail = []
        highlightedIndex = nil
        // A tab the pointer rested on before the switch is no longer its
        // aim; letting go now decides against the new wheel.
        hoveredTabIndex = nil
        pointerActivated = false
        openPointerLocation = NSEvent.mouseLocation
        profileSwitchCount &+= 1
        let name = profile.displayName(FeatureStrings.radialMenu(L10n.shared.language))
        flashedProfileName = name
        flashToken &+= 1
        let token = flashToken
        DispatchQueue.main.asyncAfter(deadline: .now() + RadialMenuSupport.profileNameFlash) { [weak self] in
            guard let self, self.flashToken == token else { return }
            self.flashedProfileName = nil
        }
        NSAccessibility.post(element: panel ?? NSApp as Any,
                             notification: .announcementRequested,
                             userInfo: [.announcement: name,
                                        .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    /// The view reports where it drew the tabs, so the pointer can rest on
    /// one at release or long enough to switch.
    func updateTabSpans(_ spans: [Int: ClosedRange<Double>]) {
        tabSpans = spans
    }

    private func tabIndex(at pointer: CGPoint) -> Int? {
        guard !tabSpans.isEmpty else { return nil }
        return RadialProfileTabs.tabIndex(dx: pointer.x - wheelCenter.x, dyUp: pointer.y - wheelCenter.y,
                                          spans: tabSpans, radius: RadialMenuLayout.tabArcRadius,
                                          capHeight: RadialMenuLayout.tabPillHeight)
    }

    // MARK: - Selection

    private func refreshHighlight() {
        let pointer = NSEvent.mouseLocation
        if !pointerActivated {
            let dx = pointer.x - openPointerLocation.x
            let dy = pointer.y - openPointerLocation.y
            // Until the pointer really travels, it owns nothing: a trackpad
            // tremor must not erase a highlight the arrow keys picked.
            guard (dx * dx + dy * dy).squareRoot() >= RadialMenuLayout.moveActivationDistance else {
                return
            }
            pointerActivated = true
        }
        if let tab = tabIndex(at: pointer) {
            if highlightedIndex != nil { highlightedIndex = nil }
            setHoveredTab(tab)
            return
        }
        setHoveredTab(nil)
        let index = RadialMenuGeometry.highlightedIndex(dx: pointer.x - wheelCenter.x,
                                                        dyUp: pointer.y - wheelCenter.y,
                                                        deadZoneRadius: RadialMenuLayout.deadZoneRadius,
                                                        itemCount: currentItems.count)
        if index != highlightedIndex { highlightedIndex = index }
    }

    /// Resting on another profile's tab while holding switches to it after
    /// a short dwell.
    private func setHoveredTab(_ tab: Int?) {
        guard tab != hoveredTabIndex else { return }
        hoveredTabIndex = tab
        cancelTabDwell()
        guard holdPhase, let tab, tab != activeProfileIndex else { return }
        let session = sessionID
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.sessionID == session, self.holdPhase,
                  self.hoveredTabIndex == tab else { return }
            self.switchProfile(to: tab)
        }
        tabDwell = work
        DispatchQueue.main.asyncAfter(deadline: .now() + RadialMenuSupport.tabDwell, execute: work)
    }

    private func cancelTabDwell() {
        tabDwell?.cancel()
        tabDwell = nil
    }

    private var preselection: RadialMenuPreselection {
        if hoveredTabIndex != nil { return .profileTab }
        guard let index = highlightedIndex, currentItems.indices.contains(index) else { return .none }
        return currentItems[index].kind == .submenu ? .submenu : .slot
    }

    /// The wheel view's tap. Where the click lands decides: past the wheel's
    /// edge dismisses, the hub steps back, a highlighted slice runs, and the
    /// rest (a slice direction the pointer has not armed yet) does nothing.
    func activatePointer() {
        guard sessionActive else { return }
        let pointer = NSEvent.mouseLocation
        if let tab = tabIndex(at: pointer) {
            switchProfile(to: tab)
            enterStickyPhase()
            return
        }
        let dx = pointer.x - wheelCenter.x
        let dyUp = pointer.y - wheelCenter.y
        let distance = (dx * dx + dyUp * dyUp).squareRoot()
        if distance > RadialMenuLayout.wheelDiameter / 2 {
            endSession()
        } else if distance < RadialMenuLayout.deadZoneRadius {
            stepBack()
        } else if let index = highlightedIndex {
            select(index)
        }
    }

    func select(_ index: Int) {
        guard sessionActive, currentItems.indices.contains(index) else { return }
        let item = currentItems[index]
        if item.kind == .submenu {
            stack.append(item.children)
            trail.append(item.name)
            highlightedIndex = nil
            // A hold-release over a submenu lands here; browsing children is
            // a sticky affair by nature. Re-arming the pointer keeps a
            // double-click from running the child that happens to sit in the
            // parent slice's direction.
            enterStickyPhase()
            pointerActivated = false
            openPointerLocation = NSEvent.mouseLocation
            return
        }
        endSession()
        run(item)
    }

    /// Esc or a click on the hub: leave the submenu, then the wheel.
    func stepBack() {
        guard sessionActive else { return }
        if stack.count > 1 {
            stack.removeLast()
            trail.removeLast()
            highlightedIndex = nil
            refreshHighlight()
        } else {
            endSession()
        }
    }

    private func rotateHighlight(by delta: Int) {
        let count = currentItems.count
        guard count > 0 else { return }
        let current = highlightedIndex ?? (delta > 0 ? -1 : 0)
        highlightedIndex = ((current + delta) % count + count) % count
        if hoveredTabIndex != nil { setHoveredTab(nil) }
    }

    // MARK: - Monitors (session-scoped, removed the moment the wheel closes)

    private func installMonitors(for panel: NSPanel) {
        removeMonitors()

        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self, weak panel] event in
            guard let self, let panel, event.window === panel else { return event }
            return self.handleKeyDown(event) ? nil : event
        }) { eventMonitors.append(monitor) }

        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            self?.handleFlagsChanged(event.modifierFlags)
            return event
        }) { eventMonitors.append(monitor) }

        if let monitor = NSEvent.addLocalMonitorForEvents(matching: RadialMenuSupport.sessionMoveMask,
                                                          handler: { [weak self] event in
            self?.pointerMoved()
            return event
        }) { eventMonitors.append(monitor) }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: RadialMenuSupport.sessionMoveMask,
                                                           handler: { [weak self] _ in
            self?.pointerMoved()
        }) { eventMonitors.append(monitor) }

        // Scrolling over the menu steps through the profiles.
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel, handler: { [weak self, weak panel] event in
            guard let self, let panel, event.window === panel else { return event }
            self.handleScroll(event)
            return nil
        }) { eventMonitors.append(monitor) }

        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: clicks, handler: { [weak self, weak panel] event in
            guard let self, let panel, panel.isVisible else { return event }
            if event.window !== panel, !Self.pointerInside(panel) {
                self.endSession()
            }
            return event
        }) { eventMonitors.append(monitor) }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: clicks, handler: { [weak self, weak panel] event in
            guard let self, let panel, panel.isVisible else { return }
            if event.windowNumber != panel.windowNumber, !Self.pointerInside(panel) {
                self.endSession()
            }
        }) { eventMonitors.append(monitor) }

        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier
            else { return }
            self.endSession()
        })
        // A four-finger swipe still switches Spaces or full-screen apps while
        // the menu is open; the menu goes with the Space it was opened on.
        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.endSession()
        })
    }

    private func removeMonitors() {
        eventMonitors.forEach { NSEvent.removeMonitor($0) }
        eventMonitors = []
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { center.removeObserver($0) }
        workspaceObservers = []
    }

    private static func pointerInside(_ panel: NSPanel) -> Bool {
        panel.frame.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation)
    }

    private func pointerMoved() {
        guard sessionActive else { return }
        if holdPhase, holdButton == nil {
            if sessionAwaitsKeyUp {
                // A key-up lost to a focus change mid-hold: the key is no
                // longer down, so the hold ends as sticky, never as a run.
                if let shortcut = sessionShortcut,
                   !CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(shortcut.keyCode)) {
                    enterStickyPhase()
                }
            } else {
                // A chord release can slip past the flags monitor when it
                // lands between the press and the monitor's install; the next
                // pointer move settles it. Button-held sessions end through
                // the tap instead.
                handleFlagsChanged(NSEvent.modifierFlags)
            }
        }
        refreshHighlight()
    }

    private func handleScroll(_ event: NSEvent) {
        guard sessionActive else { return }
        if event.phase == .began { scrollSteps.reset() }
        let step = scrollSteps.step(deltaX: event.scrollingDeltaX,
                                    deltaY: event.scrollingDeltaY,
                                    isContinuous: event.hasPreciseScrollingDeltas,
                                    isMomentum: !event.momentumPhase.isEmpty,
                                    now: ProcessInfo.processInfo.systemUptime)
        if step != 0 { switchProfile(by: step) }
    }

    private func handleFlagsChanged(_ flags: NSEvent.ModifierFlags) {
        guard sessionActive, holdPhase, !sessionAwaitsKeyUp, let shortcut = sessionShortcut else { return }
        guard !RadialMenuSupport.shortcutIsStillHeld(
            modifiersHeld: shortcut.requiredModifiersHeld(in: flags),
            superKeyHeld: superKeyStillHeld,
            keyHeld: CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(shortcut.keyCode))
        ) else { return }
        endHoldPhase()
    }

    /// The summoner came up: what is picked runs, a quick press stays open,
    /// a longer hold over nothing closes.
    private func endHoldPhase() {
        guard sessionActive, holdPhase else { return }
        let heldFor = ProcessInfo.processInfo.systemUptime - holdStartedAt
        switch RadialMenuSupport.releaseAction(heldFor: heldFor, preselection: preselection) {
        case .run, .openSubmenu:
            guard let index = highlightedIndex else { return enterStickyPhase() }
            select(index)
        case .switchProfile:
            if let tab = hoveredTabIndex { switchProfile(to: tab) }
            enterStickyPhase()
        case .stayOpen:
            enterStickyPhase()
        case .close:
            endSession()
        }
    }

    private func enterStickyPhase() {
        holdPhase = false
        holdButton = nil
        sessionAwaitsKeyUp = false
        cancelHoldTimers()
        stopTrackingSuperKeyHold()
    }

    private func armHoldSafety(sessionID session: Int) {
        holdSafety?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.sessionID == session, self.holdPhase else { return }
            self.enterStickyPhase()
        }
        holdSafety = work
        DispatchQueue.main.asyncAfter(deadline: .now() + RadialMenuSupport.holdSafetyTimeout, execute: work)
    }

    private func cancelHoldTimers() {
        holdSafety?.cancel()
        holdSafety = nil
        cancelTabDwell()
    }

    private func stopTrackingSuperKeyHold() {
        guard sessionUsesSuperKey else { return }
        sessionUsesSuperKey = false
        SuperKeyService.shared.onHoldEnded = nil
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        switch Int(event.keyCode) {
        case kVK_Escape:
            stepBack()
            return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if let index = highlightedIndex { select(index) }
            return true
        case kVK_Tab:
            switchProfile(by: event.modifierFlags.contains(.shift) ? -1 : 1)
            return true
        case kVK_LeftArrow, kVK_UpArrow:
            // While held, the arrows only move the pick: letting go runs it.
            rotateHighlight(by: -1)
            return true
        case kVK_RightArrow, kVK_DownArrow:
            rotateHighlight(by: 1)
            return true
        default:
            if let character = event.charactersIgnoringModifiers?.first,
               let digit = character.wholeNumberValue, (1...9).contains(digit),
               currentItems.indices.contains(digit - 1) {
                select(digit - 1)
                return true
            }
            return false
        }
    }

    // MARK: - Actions

    private func run(_ item: RadialMenuItem) {
        switch item.kind {
        case .app:
            let url = URL(fileURLWithPath: (item.payload as NSString).expandingTildeInPath)
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                if error != nil { DispatchQueue.main.async { NSSound.beep() } }
            }
        case .file:
            let path = (item.payload as NSString).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: path) else {
                NSSound.beep()
                return
            }
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        case .url:
            if let normalized = RadialMenuSupport.normalizedURL(item.payload),
               let url = URL(string: normalized) {
                NSWorkspace.shared.open(url)
            }
        case .shortcut:
            if let shortcut = GlobalShortcut(storageValue: item.payload) {
                postWhenModifiersReleased(attempt: 0) { Self.postShortcut(shortcut) }
            }
        case .media:
            if let key = item.mediaKey {
                if key == .nowPlaying {
                    RadialNowPlayingService.shared.presentDetails(at: wheelCenter)
                } else {
                    postWhenModifiersReleased(attempt: 0) { Self.postMediaKey(key) }
                }
            }
        case .tool:
            if let tool = item.tool { run(tool) }
        case .quickToggle:
            if let action = item.quickToggle { run(action) }
        case .windowLayout:
            if let action = item.windowLayoutAction { run(action) }
        case .submenu:
            break
        }
    }

    private func run(_ tool: RadialMenuTool) {
        guard tool.isRunnable() else { return }
        // The same beat the quick panel gives screen-touching tools, so the
        // wheel is really gone before anything captures or presents.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            switch tool {
            case .screenshot: ScreenshotService.shared.capture()
            case .screenRecorder: ScreenRecorderService.shared.toggle()
            case .colorPicker, .screenOCR: return
            case .micMute: MicMuteService.shared.toggle()
            case .clipboardHistory: ClipboardHistoryService.shared.showHistoryWindow()
            case .quickLauncher: LatticeHubService.shared.show()
            case .cameraPreview: CameraPreviewService.shared.show()
            case .scratchpad: ScratchpadService.shared.show()
            case .shelf: ShelfService.shared.summon()
            case .cleaner: Self.openSettings(at: .cleaner)
            case .uninstaller: Self.openSettings(at: .uninstaller)
            case .appUpdates:
                AppUpdatesService.shared.check()
                Self.openSettings(at: .appUpdates)
            case .cleaningMode: CleaningModeManager.shared.activate()
            case .keepAwake: KeepAwakeManager.shared.toggle()
            }
        }
    }

    private static func openSettings(at page: SettingsPage) {
        SettingsRouter.shared.page = page
        appDelegate()?.openSettingsWindow()
    }

    private func run(_ action: RadialMenuQuickToggle) {
        guard action.isAvailable else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let toggles = QuickTogglesService.shared
            switch action {
            case .darkMode: toggles.toggleDarkMode()
            case .emptyTrash: toggles.emptyTrash()
            case .ejectDisks: toggles.ejectAllDisks()
            case .hiddenFiles: toggles.toggleHiddenFiles()
            case .desktopIcons: toggles.toggleDesktopIcons()
            case .lockScreen: toggles.lockScreen()
            case .displayOff: toggles.turnDisplayOff()
            case .screenSaver: toggles.startScreenSaver()
            }
        }
    }

    private func run(_ action: WindowLayoutAction) {
        guard AppFeature.windowLayout.isAvailable, ensureAccessibilityPermission() else { return }
        // Let the non-activating wheel disappear before resolving the window
        // that was active behind it, matching the delay used by visual tools.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if case .failure = WindowLayoutService.shared.apply(action) { NSSound.beep() }
        }
    }

    // MARK: - Accessibility-gated actions (asked once and in context)

    private func ensureAccessibilityPermission() -> Bool {
        guard AXIsProcessTrusted() else {
            if promptedForAccessibility {
                NSSound.beep()
            } else {
                promptedForAccessibility = true
                Permissions.shared.requestAccessibility()
            }
            return false
        }
        return true
    }

    /// Waits for the summoning chord to leave the keyboard before posting, or
    /// the synthetic key merges with the still-held modifiers (checked every
    /// 15 ms for up to ~1.5 s, with an extra beat once clean).
    private func postWhenModifiersReleased(attempt: Int, then post: @escaping () -> Void) {
        guard ensureAccessibilityPermission() else { return }
        let held = CGEventSource.flagsState(.combinedSessionState)
            .intersection([.maskCommand, .maskAlternate, .maskShift, .maskControl])
        if held.isEmpty || attempt >= 100 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: post)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.015) { [weak self] in
            self?.postWhenModifiersReleased(attempt: attempt + 1, then: post)
        }
    }

    private static func postShortcut(_ shortcut: GlobalShortcut) {
        guard let keyDown = CGEvent(keyboardEventSource: nil,
                                    virtualKey: CGKeyCode(shortcut.keyCode), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil,
                                  virtualKey: CGKeyCode(shortcut.keyCode), keyDown: false)
        else { return }
        // The flags a real press carries, so a shortcut on an arrow or an F
        // key is recognised beyond the app in front as well (issue #401).
        keyDown.flags = shortcut.syntheticEventFlags
        keyUp.flags = shortcut.syntheticEventFlags
        keyDown.post(tap: .cghidEventTap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            keyUp.post(tap: .cghidEventTap)
        }
    }

    /// Posts the aux-button pair the physical media keys produce, so whatever
    /// player owns the media keys reacts exactly as if F8 was pressed.
    private static func postMediaKey(_ key: RadialMenuMediaKey) {
        guard let auxKeyType = key.auxKeyType else { return }
        postAuxKey(auxKeyType, down: true)
        postAuxKey(auxKeyType, down: false)
    }

    private static func postAuxKey(_ type: Int32, down: Bool) {
        let stateFlags: NSEvent.ModifierFlags = down
            ? NSEvent.ModifierFlags(rawValue: 0xA00)
            : NSEvent.ModifierFlags(rawValue: 0xB00)
        let data1 = (Int(type) << 16) | ((down ? 0xA : 0xB) << 8)
        guard let event = NSEvent.otherEvent(with: .systemDefined,
                                             location: .zero,
                                             modifierFlags: stateFlags,
                                             timestamp: ProcessInfo.processInfo.systemUptime,
                                             windowNumber: 0,
                                             context: nil,
                                             subtype: 8,
                                             data1: data1,
                                             data2: -1)
        else { return }
        event.cgEvent?.post(tap: .cghidEventTap)
    }

    // MARK: - Panel

    /// Borderless panels refuse key status by default, and the wheel wants it
    /// for Esc, arrows, digits and the hold-release detection.
    private final class KeyableWheelPanel: OverlayPanel {
        override var canBecomeKey: Bool { true }
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let size = RadialMenuLayout.panelSizeWithTabs
        let panel = KeyableWheelPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                                      styleMask: [.borderless, .nonactivatingPanel],
                                      backing: .buffered,
                                      defer: false)
        panel.title = "Lattice"
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        let host = NSHostingController(rootView: RadialMenuView())
        // The panel's size changes per session (the tab arc needs room); the
        // service sets it, and the view follows instead of resizing it.
        host.sizingOptions = []
        panel.contentViewController = host
        self.panel = panel
        return panel
    }
}

/// The wheel's own arrival and departure. Reduce Motion is the only switch
/// over it: this is how the menu opens now, not a preference.
private enum WheelMotion {
    static var isEnabled: Bool { !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// Ordered while still transparent, so the wheel is never seen at full
    /// strength for a frame before the fade starts.
    static func present(_ panel: NSPanel) {
        panel.ignoresMouseEvents = false
        guard isEnabled else {
            panel.alphaValue = 1
            panel.orderFrontRegardless()
            panel.makeKey()
            return
        }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    /// Fades out, then hands back so the caller can order the panel away:
    /// only the caller knows whether a new session claimed it meanwhile.
    ///
    /// The keyboard is given back on the first frame, not the last. This panel
    /// takes key status without activating the app, and closing it is usually
    /// the prelude to typing into whatever is underneath; a window that is
    /// only fading out must not eat that. Ordering out and straight back in is
    /// what drops key status, and the pair lands in a single commit, so
    /// nothing blinks.
    static func dismiss(_ panel: NSPanel, completion: @escaping () -> Void) {
        guard isEnabled, panel.isVisible else {
            completion()
            return
        }
        if panel.isKeyWindow {
            panel.orderOut(nil)
            panel.orderFrontRegardless()
        }
        panel.ignoresMouseEvents = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.13
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { completion() }
    }
}

/// The bookkeeping a fading wheel needs: only one closing at a time, and a
/// closing that a new summon overtook must never order the panel away
/// underneath it.
final class PanelDismissal {
    /// True while the panel is only a picture: its monitors and its keyboard
    /// are already gone, so the wheel counts as closed from here.
    private(set) var isActive = false
    private var token = 0

    /// Fades the panel away and orders it out, then runs `finish` once, unless
    /// a new session claimed the panel first.
    func begin(_ panel: NSPanel, finish: @escaping () -> Void) {
        isActive = true
        token &+= 1
        let started = token
        WheelMotion.dismiss(panel) { [weak self] in
            guard let self, self.isActive, self.token == started else { return }
            self.isActive = false
            panel.orderOut(nil)
            finish()
        }
    }

    /// A new summon takes the panel back, so the closing it interrupted
    /// finishes here and now instead of landing on the new one.
    func cancel(finish: () -> Void) {
        guard isActive else { return }
        isActive = false
        token &+= 1
        finish()
    }
}
