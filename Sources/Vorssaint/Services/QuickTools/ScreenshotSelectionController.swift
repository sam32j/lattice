// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox
import SwiftUI

/// The capture surface: one borderless panel per screen, above everything,
/// where the user drags a region, clicks a window or confirms a full screen.
///
/// With freeze on (the default) every display is photographed first and the
/// panels show that still image while the area is chosen. With freeze off the
/// panels are transparent and pixels are captured at confirmation time.
///
/// More than one feature picks an area this way, so the surface says what the
/// area is for and only one session is ever on screen.
final class ScreenshotSelectionController {

    struct Capture {
        let image: CGImage
        /// Pixels per point of the source display, for 1x export math.
        let scale: CGFloat
        /// The captured area in Cocoa global coordinates.
        let anchorRect: CGRect
    }

    /// What the caller wants out of the same gesture. The screenshot tool
    /// wants pixels; the recorder wants to know WHERE, and takes its own
    /// pixels afterwards, for as long as the person keeps recording.
    enum Mode {
        case image
        case geometry
        case color
    }

    enum Outcome {
        case captured(Capture)
        case region(RecorderSupport.Region)
        case scrollingRegion(RecorderSupport.Region)
        case color(NSColor)
        case cancelled
        case failed
    }

    private var panels: [ScreenshotOverlayPanel] = []
    private weak var waitingRecordingPanel: ScreenshotOverlayPanel?
    private var waitingRecordingWindowID: CGWindowID?
    private var waitingControls: RecorderWaitingControls?

    var protectedWindowIDs: Set<CGWindowID> {
        Set(panels.compactMap { $0.windowNumber > 0 ? CGWindowID($0.windowNumber) : nil })
    }

    /// The overlays are part of the capture, so they stay excluded even when
    /// the session is not registered anywhere yet.
    private var captureExcludedWindowIDs: Set<CGWindowID> {
        otherProtectedWindowIDs().union(protectedWindowIDs)
    }
    private var keyMonitor: Any?
    private var flagsMonitor: Any?
    private var globalKeyMonitor: Any?
    private var completion: ((Outcome) -> Void)?
    private var freeze: Bool
    private var includePointer: Bool
    private let showLastRegion: Bool
    private var hideVorssaintWindows: Bool
    private var previousFrontmostApp: NSRunningApplication?
    private let otherProtectedWindowIDs: () -> Set<CGWindowID>
    private let baseMode: Mode
    private let supportsScrollingCapture: Bool
    private let screenCaptureOptions: ScreenCaptureSelectionOptions?
    private var capturePolicy: ScreenshotSupport.UnifiedCapturePolicy
    /// Bumped whenever the source is re-photographed, so a capture that a
    /// later tool change already replaced never reaches the panels.
    private var sourceGeneration = 0
    private var sourceRefreshPending = false
    /// Old pixels and window choices remain visible during refresh, but cannot
    /// be used by either pointer actions or keyboard confirmations.
    fileprivate var acceptsCaptureInput: Bool {
        !finished && !sourceRefreshPending && !panels.contains { $0.overlayView.isCapturePending }
    }
    fileprivate let requiresDraggedRegion: Bool
    private var finished = false
    private var cursorPushed = false
    /// Read by the overlays so a late event finds a session that is over.
    fileprivate var isOver: Bool { finished }
    fileprivate var spaceIsDown = false
    fileprivate private(set) var selectionInProgress = false
    fileprivate func setSelectionInProgress(_ active: Bool) {
        let previous = selectionInProgress
        selectionInProgress = active
        panels.forEach {
            $0.overlayView.refreshGuideVisibility()
            $0.overlayView.refreshFullScreenControlVisibility()
        }
        if active != previous {
            screenCaptureOptions?.onSelectionProgressChange?(active)
        }
    }
    fileprivate var scrollingCaptureEnabled = false {
        didSet {
            panels.forEach {
                $0.overlayView.refreshCaptureGuide()
                $0.overlayView.refreshFullScreenControlVisibility()
                $0.overlayView.needsDisplay = true
            }
        }
    }
    fileprivate var offersScrollingCapture: Bool {
        supportsScrollingCapture && activeTool == .screenshot && activeMode == .image
    }
    fileprivate var offersFullScreenCapture: Bool {
        acceptsCaptureInput && activeMode == .image
            && ScreenshotSupport.fullScreenCaptureControlIsAvailable(
                selectedTool: activeTool,
                standaloneScreenshot: screenCaptureOptions == nil,
                requiresDraggedRegion: requiresDraggedRegion,
                scrollingCaptureEnabled: scrollingCaptureEnabled)
    }
    fileprivate var acceptsWindowClick: Bool {
        acceptsCaptureInput && activeMode != .color && !requiresDraggedRegion && !scrollingCaptureEnabled
    }
    fileprivate var isPickingColor: Bool { activeMode == .color }
    /// The panel `repeatLastRegion()` would act on, or nil when there is
    /// nothing to repeat: the guide hint and the action read the same
    /// property so the bar cannot promise a key that does nothing.
    private var repeatTargetPanel: ScreenshotOverlayPanel? {
        guard let last = Self.lastRegion else { return nil }
        return panels.first { $0.displayID == last.displayID }
    }
    fileprivate var offersRepeatLastRegion: Bool {
        ScreenshotSupport.offersRepeatLastRegion(
            isPickingColor: isPickingColor,
            storedRegionDisplayIsAvailable: repeatTargetPanel != nil)
    }
    fileprivate var loupeEnabled = false {
        didSet {
            panels.forEach {
                $0.overlayView.refreshCaptureGuide()
                $0.overlayView.refreshPointerState()
            }
        }
    }
    fileprivate var loupeZoom: CGFloat {
        didSet {
            UserDefaults.standard.set(Double(loupeZoom),
                                      forKey: DefaultsKey.screenshotLoupeLastZoom)
            panels.forEach { $0.overlayView.needsDisplay = true }
        }
    }
    fileprivate var currentPointerLocation: CGPoint?

    /// The last confirmed region, per display, so R repeats it instantly.
    private static var lastRegion: (displayID: CGDirectDisplayID, viewRect: CGRect)?
    /// Holds the initial screenshot cropped to the confirmed region for seamless scrolling capture preview handoff.
    nonisolated(unsafe) static var lastInitialCapture: CGImage?

    /// True while a session owns the screen. Two surfaces at once would stack
    /// dim over dim and split the keyboard between them, so whichever feature
    /// asks second is turned away.
    private(set) static var isSessionOnScreen = false
    private static weak var activeSession: ScreenshotSelectionController?

    /// Step mode needs the physical wheel event immediately. Fast mode keeps
    /// the normal smooth-scroll packet train, which is what gives it its
    /// deliberately accelerated sweep through the zoom range.
    static func steppedLoupeNeedsRawWheel(optionPressed: Bool) -> Bool {
        guard activeSession?.loupeEnabled == true else { return false }
        return ScreenshotSupport.captureLoupeUsesSteppedZoom(
            steppedByDefault: UserDefaults.standard.bool(
                forKey: DefaultsKey.screenshotLoupeSteppedZoomByDefault),
            optionPressed: optionPressed)
    }

    private let strings = FeatureStrings.screenshot(L10n.shared.language)
    /// Named at the head of the hint bar so the surface never leaves the
    /// person guessing what the area they are about to pick is for.
    private let purpose: String?

    init(freeze: Bool,
         includePointer: Bool,
         showLastRegion: Bool,
         hideVorssaintWindows: Bool = true,
         protectedWindowIDs: @escaping () -> Set<CGWindowID> = { [] },
         purpose: String? = nil,
         mode: Mode = .image,
         supportsScrollingCapture: Bool = false,
         requiresDraggedRegion: Bool = false,
         screenCaptureOptions: ScreenCaptureSelectionOptions? = nil) {
        self.freeze = freeze
        self.includePointer = includePointer
        self.showLastRegion = showLastRegion
        self.hideVorssaintWindows = hideVorssaintWindows
        self.otherProtectedWindowIDs = protectedWindowIDs
        self.purpose = purpose
        self.baseMode = mode
        self.supportsScrollingCapture = supportsScrollingCapture
        self.requiresDraggedRegion = requiresDraggedRegion
        self.screenCaptureOptions = screenCaptureOptions
        let defaults = UserDefaults.standard
        self.loupeZoom = ScreenshotSupport.captureLoupeInitialZoom(
            rememberLast: defaults.bool(forKey: DefaultsKey.screenshotLoupeRememberZoom),
            defaultZoom: CGFloat(defaults.double(forKey: DefaultsKey.screenshotLoupeDefaultZoom)),
            lastZoom: CGFloat(defaults.double(forKey: DefaultsKey.screenshotLoupeLastZoom)))
        self.capturePolicy = ScreenshotSupport.UnifiedCapturePolicy(
            freeze: freeze,
            includePointer: includePointer,
            hideVorssaintWindows: hideVorssaintWindows,
            keepsContentWindowsOut: hideVorssaintWindows
                || screenCaptureOptions?.selectedTool == .recording,
            usesGeometry: mode == .geometry)
        defaults.set(Double(loupeZoom), forKey: DefaultsKey.screenshotLoupeLastZoom)
    }

    fileprivate var activeTool: ScreenCaptureTool? { screenCaptureOptions?.selectedTool }

    fileprivate var activeMode: Mode {
        switch activeTool {
        case .recording: return .geometry
        case .color: return .color
        case .screenshot, .text: return .image
        case .none: return baseMode
        }
    }

    func begin(completion: @escaping (Outcome) -> Void) {
        Self.isSessionOnScreen = true
        Self.activeSession = self
        self.completion = completion
        self.previousFrontmostApp = NSWorkspace.shared.frontmostApplication
        screenCaptureOptions?.onSelectionChange = { [weak self] in
            self?.screenCaptureToolDidChange()
        }
        if freeze {
            Task { @MainActor [weak self] in
                guard let self else { return }
                let images = await ScreenshotCaptureEngine.captureAllDisplays(
                    includePointer: self.includePointer,
                    hideVorssaintWindows: self.hideVorssaintWindows,
                    protectedWindowIDs: self.captureExcludedWindowIDs)
                guard !images.isEmpty else {
                    self.finish(.failed)
                    return
                }
                self.present(frozenImages: images)
            }
        } else {
            present(frozenImages: [:])
        }
    }

    private func present(frozenImages: [CGDirectDisplayID: CGImage]) {
        guard !finished else { return }
        let pickable = ScreenshotCaptureEngine.pickableWindows(
            hideVorssaintWindows: hideVorssaintWindows,
            protectedWindowIDs: captureExcludedWindowIDs)
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0

        for screen in NSScreen.screens {
            let displayID = screen.displayID
            if freeze, frozenImages[displayID] == nil { continue }
            let windows = Self.pickableWindows(pickable,
                                               on: screen.frame,
                                               mainScreenHeight: mainHeight)

            let panel = ScreenshotOverlayPanel(screen: screen,
                                               frozenImage: frozenImages[displayID],
                                               windows: windows,
                                               controller: self,
                                               strings: strings,
                                               purpose: purpose,
                                               screenCaptureOptions: screenCaptureOptions)
            if showLastRegion, let last = Self.lastRegion, last.displayID == displayID {
                panel.overlayView.ghostRect = last.viewRect
            }
            // Prime pointer state BEFORE display so initial frame already punches out hovered window
            panel.overlayView.refreshPointerState()
            panel.contentView?.layoutSubtreeIfNeeded()
            panel.display()
            panels.append(panel)
        }
        guard !panels.isEmpty else {
            finish(.failed)
            return
        }
        // Each guide was built inside its panel's initializer, before that
        // panel joined `panels`, so the repeat hint could not see the display
        // holding the stored region yet.
        panels.forEach { $0.overlayView.refreshCaptureGuide() }
        screenCaptureOptions?.offersRepeatLastRegion = offersRepeatLastRegion
        installKeyMonitor()
        // Give key ownership to only one destination. Opening and immediately
        // resigning a full-screen key panel can flash the surrounding chrome.
        screenCaptureOptions?.onPresentationReady?()
        guard !finished else { return }
        NSApp.activate(ignoringOtherApps: true)
        panels.forEach { $0.orderFrontRegardless() }
        if let keyPanel = keyPanelUnderMouse() ?? panels.first {
            keyPanel.makeKeyAndOrderFront(nil)
        }
        panels.forEach { panel in
            panel.invalidateCursorRects(for: panel.overlayView)
            panel.resetCursorRects()
        }
        if isPickingColor
            || UserDefaults.standard.bool(forKey: DefaultsKey.screenshotLoupeStartsOn) {
            // Opt-in: the session opens with the magnifier already up,
            // instead of waiting for the Z toggle.
            toggleLoupe()
        }
        if !cursorPushed {
            NSCursor.crosshair.push()
            cursorPushed = true
        }
        NSCursor.crosshair.set()
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return event }
            if !event.modifierFlags.contains(.shift), self.hasSelectedWindows {
                self.confirmSelectedWindows()
            }
            return event
        }
    }

    private func screenCaptureToolDidChange() {
        resetWaitingRecording()
        if activeTool != .recording && !RecorderOverlayController.shared.isRecording {
            RecorderOverlayController.shared.stop()
        }
        if let activeTool {
            let defaults = UserDefaults.standard
            let nextPolicy = ScreenshotSupport.unifiedCapturePolicy(
                for: activeTool,
                screenshotFreeze: defaults.bool(forKey: DefaultsKey.screenshotFreeze),
                screenshotIncludePointer: defaults.bool(forKey: DefaultsKey.screenshotIncludePointer),
                screenshotHideVorssaintWindows: defaults.bool(
                    forKey: DefaultsKey.screenshotHideVorssaintWindows))
            if !nextPolicy.sharesSource(with: capturePolicy) {
                adoptCapturePolicy(nextPolicy)
            }
        }
        selectedWindows.removeAll()
        scrollingCaptureEnabled = false
        loupeEnabled = isPickingColor
        screenCaptureOptions?.offersRepeatLastRegion = offersRepeatLastRegion
        if isPickingColor, !freeze { loadLiveLoupeImages() }
        panels.forEach { $0.overlayView.captureToolDidChange() }
        if selectionInProgress { setSelectionInProgress(false) }
    }

    /// The chooser stays on screen while the tool changes, so a tool that
    /// needs other pixels gets them behind the panels instead of taking the
    /// surface down and putting an identical one back up.
    private func adoptCapturePolicy(_ policy: ScreenshotSupport.UnifiedCapturePolicy) {
        capturePolicy = policy
        freeze = policy.freeze
        includePointer = policy.includePointer
        hideVorssaintWindows = policy.hideVorssaintWindows
        sourceRefreshPending = true
        sourceGeneration += 1
        let generation = sourceGeneration
        guard policy.freeze else {
            applySource(frozenImages: [:])
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let images = await ScreenshotCaptureEngine.captureAllDisplays(
                includePointer: policy.includePointer,
                hideVorssaintWindows: policy.hideVorssaintWindows,
                protectedWindowIDs: self.captureExcludedWindowIDs)
            guard !self.finished, self.sourceGeneration == generation else { return }
            self.applySource(frozenImages: images)
        }
    }

    /// All visible displays must belong to the current tool before selection
    /// resumes. A missing frame cannot safely fall back to the previous tool.
    private func applySource(frozenImages: [CGDirectDisplayID: CGImage]) {
        guard !freeze || panels.allSatisfy({ frozenImages[$0.displayID] != nil }) else {
            finish(.failed)
            return
        }
        let pickable = ScreenshotCaptureEngine.pickableWindows(
            hideVorssaintWindows: hideVorssaintWindows,
            protectedWindowIDs: captureExcludedWindowIDs)
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        for panel in panels {
            let image = freeze ? frozenImages[panel.displayID] : nil
            panel.update(frozenImage: image,
                         windows: Self.pickableWindows(pickable,
                                                       on: panel.screenFrame,
                                                       mainScreenHeight: mainHeight))
        }
        sourceRefreshPending = false
        panels.forEach {
            $0.overlayView.refreshPointerState()
            $0.overlayView.refreshFullScreenControlVisibility()
        }
    }

    func placeFullScreenControlBelowNotch(screenFrame: CGRect, surfaceHeight: CGFloat) {
        for panel in panels {
            panel.overlayView.setNotchCaptureControlsHeight(
                panel.screenFrame == screenFrame ? surfaceHeight : nil)
        }
    }

    private static func pickableWindows(_ entries: [(id: CGWindowID, bounds: CGRect)],
                                        on screenFrame: CGRect,
                                        mainScreenHeight: CGFloat)
        -> [ScreenshotSupport.PickableWindow] {
        entries.map { entry -> ScreenshotSupport.PickableWindow in
            let cocoa = ScreenshotSupport.cocoaRect(fromWindowServer: entry.bounds,
                                                    mainScreenHeight: mainScreenHeight)
            let viewRect = ScreenshotSupport.flippedViewRect(fromCocoa: cocoa,
                                                             screenFrame: screenFrame)
            return ScreenshotSupport.PickableWindow(windowID: entry.id, frame: viewRect)
        }.filter { $0.frame.intersects(CGRect(origin: .zero, size: screenFrame.size)) }
    }

    /// Live selection stays transparent, but the loupe still needs source
    /// pixels. Capture them once after the overlays exist; ScreenCaptureKit
    /// excludes this app's own panels, so the screen itself remains live.
    private func loadLiveLoupeImages() {
        let generation = sourceGeneration
        let hideWindows = hideVorssaintWindows
        let excludedIDs = captureExcludedWindowIDs
        Task { @MainActor [weak self] in
            let images = await ScreenshotCaptureEngine.captureAllDisplays(
                includePointer: false,
                hideVorssaintWindows: hideWindows,
                protectedWindowIDs: excludedIDs)
            guard let self, !self.finished, self.sourceGeneration == generation else { return }
            for panel in self.panels {
                panel.overlayView.updateLoupeImage(images[panel.displayID])
            }
        }
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self else { return event }
            let inNotch = self.screenCaptureOptions?.controlsInNotch == true
                && event.window === NotchService.shared.presentationWindow
            guard event.window is ScreenshotOverlayPanel || event.window === self.waitingControls?.panel || inNotch else { return event }
            if self.waitingRecordingPanel != nil {
                // The selected area still owns input until Start, not the app
                // that happened to be behind it. Only recording controls apply.
                guard event.type == .keyDown else { return nil }
                switch Int(event.keyCode) {
                case kVK_Escape: self.finish(.cancelled)
                case kVK_Return, kVK_ANSI_KeypadEnter: self.startWaitingRecording()
                default:
                    guard !event.isARepeat else { return nil }
                    if Self.isScrollingCaptureKey(event) { self.screenCaptureOptions?.recorderAudio.systemAudio.toggle() }
                    else if Self.isMicrophoneKey(event) { self.screenCaptureOptions?.recorderAudio.microphone.toggle() }
                    else if Self.matchesShortcutKey(event, character: "c", physicalKeyCode: kVK_ANSI_C) {
                        RecorderOverlayController.shared.toggleCamera()
                    } else if Self.matchesShortcutKey(event, character: "k", physicalKeyCode: kVK_ANSI_K) {
                        RecorderOverlayController.shared.keysEnabled.toggle()
                    }
                }
                return nil
            }
            if inNotch {
                guard event.window?.attachedSheet == nil, !(event.window?.firstResponder is NSText),
                      !ShortcutCapture.isCapturing else { return event }
                let movesSelection = event.keyCode == UInt16(kVK_Space)
                    && (self.spaceIsDown || self.panelUnderMouse()?.overlayView.isDragging == true)
                if self.screenCaptureOptions?.hasFocusedControl == true,
                   event.keyCode != UInt16(kVK_Escape), !movesSelection { return event }
            }
            if event.type == .keyUp {
                guard event.keyCode == UInt16(kVK_Space), self.spaceIsDown else { return event }
                self.spaceIsDown = false
                return nil
            }
            switch Int(event.keyCode) {
            case kVK_Escape:
                self.finish(.cancelled)
            case kVK_Return, kVK_ANSI_KeypadEnter:
                self.confirmSelectionWithKeyboard()
            case _ where Self.matchesShortcutKey(event, character: "f", physicalKeyCode: kVK_ANSI_F):
                guard !self.hasSelectedWindows, self.offersFullScreenCapture else { return event }
                self.captureFullDisplayUnderMouse()
            case kVK_Space:
                if let panel = self.panelUnderMouse(), panel.overlayView.isDragging {
                    // Holding Space moves the in-progress selection.
                    self.spaceIsDown = true
                } else { return event }
            case _ where Self.isRepeatRegionKey(event):
                guard !self.hasSelectedWindows else { return event }
                self.repeatLastRegion()
            case _ where Self.isScrollingCaptureKey(event):
                guard !self.hasSelectedWindows else { return event }
                if self.activeTool == .recording {
                    self.screenCaptureOptions?.recorderAudio.systemAudio.toggle()
                } else {
                    self.toggleScrollingCapture()
                }
            case _ where Self.isMicrophoneKey(event):
                guard !self.hasSelectedWindows else { return event }
                if self.activeTool == .recording {
                    self.screenCaptureOptions?.recorderAudio.microphone.toggle()
                }
            case _ where self.activeTool == .recording && Self.matchesShortcutKey(event, character: "c", physicalKeyCode: kVK_ANSI_C):
                if !event.isARepeat { RecorderOverlayController.shared.toggleCamera() }
            case _ where self.activeTool == .recording && Self.matchesShortcutKey(event, character: "k", physicalKeyCode: kVK_ANSI_K):
                if !event.isARepeat { RecorderOverlayController.shared.keysEnabled.toggle() }
            case _ where Self.isLoupeKey(event):
                guard !self.hasSelectedWindows else { return event }
                self.toggleLoupe()
            case _ where Self.isCopyColorKey(event):
                guard self.loupeAcceptsKeyboardActions else { return event }
                self.copyLoupeColor()
            case _ where Self.isNudgeKey(event):
                guard self.loupeAcceptsKeyboardActions else { return event }
                self.nudgePointer(keyCode: Int(event.keyCode),
                                  fast: event.modifierFlags.contains(.shift))
            default:
                if selectCaptureTool(for: event) { return nil }
                return event
            }
            return nil
        }
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == UInt16(kVK_Escape) else { return }
            self?.finish(.cancelled)
        }
    }

    private func selectCaptureTool(for event: NSEvent) -> Bool {
        if Self.matchesShortcutKey(event, character: "r", physicalKeyCode: kVK_ANSI_R) {
            guard !hasSelectedWindows else { return true }
            toggleCaptureAndRecordMode()
            return true
        }
        return false
    }

    /// The loupe toggle follows the typed character, with the physical slot
    /// as a fallback: the Z key sits elsewhere on some keyboard layouts and
    /// the localized hints promise the letter itself.
    private static func isLoupeKey(_ event: NSEvent) -> Bool {
        matchesShortcutKey(event, character: "z", physicalKeyCode: kVK_ANSI_Z)
    }

    private static func isScrollingCaptureKey(_ event: NSEvent) -> Bool {
        matchesShortcutKey(event, character: "s", physicalKeyCode: kVK_ANSI_S)
    }

    private static func isMicrophoneKey(_ event: NSEvent) -> Bool {
        matchesShortcutKey(event, character: "m", physicalKeyCode: kVK_ANSI_M)
    }

    private static func isRepeatRegionKey(_ event: NSEvent) -> Bool {
        matchesShortcutKey(event, character: "x", physicalKeyCode: kVK_ANSI_X)
    }


    private static func isCopyColorKey(_ event: NSEvent) -> Bool {
        event.keyCode == UInt16(kVK_Tab)
    }

    fileprivate func performRepeatLastRegion() {
        if offersRepeatLastRegion {
            repeatLastRegion()
        }
    }

    fileprivate func toggleCaptureAndRecordMode() {
        guard let screenCaptureOptions else { return }
        let nextTool: ScreenCaptureTool = screenCaptureOptions.selectedTool == .recording ? .screenshot : .recording
        if screenCaptureOptions.availableTools.contains(nextTool) {
            screenCaptureOptions.select(nextTool)
        }
    }

    fileprivate func toggleScrollingCapture() {
        guard offersScrollingCapture else { return }
        scrollingCaptureEnabled.toggle()
        panels.forEach {
            $0.overlayView.refreshCaptureGuide()
            $0.overlayView.refreshPointerState()
        }
    }

    fileprivate func toggleLoupe() {
        loupeEnabled.toggle()
        // Live mode has no frozen shot to sample. Pixels are fetched only
        // when the loupe actually turns on, and fresh each time, so it
        // magnifies what is on screen now instead of the session's opening
        // frame and idle sessions never pay for a capture.
        if loupeEnabled, !freeze {
            loadLiveLoupeImages()
        }
        panels.forEach {
            $0.overlayView.refreshCaptureGuide()
            $0.overlayView.needsDisplay = true
        }
    }

    fileprivate func adjustLoupeZoom(by scrollDelta: CGFloat,
                                     stepped: Bool,
                                     isContinuous: Bool) {
        loupeZoom = stepped
            ? ScreenshotSupport.captureLoupeSteppedZoom(loupeZoom, adjustedBy: scrollDelta)
            : ScreenshotSupport.captureLoupeFastZoom(loupeZoom, adjustedBy: scrollDelta,
                                                     isContinuous: isContinuous)
    }


    /// Accept either the character promised by the shortcut hint or its
    /// physical ANSI key. The latter keeps shortcuts reachable on layouts
    /// whose printable character is non-Latin.
    private static func matchesShortcutKey(_ event: NSEvent,
                                           character: String,
                                           physicalKeyCode: Int) -> Bool {
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty
        else { return false }
        return event.charactersIgnoringModifiers?.lowercased() == character
            || Int(event.keyCode) == physicalKeyCode
    }

    private static func isNudgeKey(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty
        else { return false }
        return [kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow]
            .contains(Int(event.keyCode))
    }

    private var loupeAcceptsKeyboardActions: Bool {
        acceptsCaptureInput && loupeEnabled && !panels.contains(where: { $0.overlayView.isDragging })
    }

    private func copyLoupeColor() {
        guard loupeAcceptsKeyboardActions else { return }
        // The readout, ring and copy all sample the same loupe image. In live
        // selection that image is the snapshot loaded when the loupe opens;
        // toggling Z refreshes it without letting C copy a different frame
        // from the one currently drawn.
        panelUnderMouse()?.overlayView.copyLoupeColorUnderPointer()
    }

    /// Arrow keys nudge the pointer by exactly one device pixel (ten with
    /// Shift) while the loupe is up and no drag is in flight; nudging under
    /// a held button would resize the selection behind the person's back.
    /// The pointer may cross onto a neighbouring display; only when no
    /// display contains the target does it stop at the current edge.
    /// Warping generates no mouse event, so the overlays are refreshed by
    /// hand with the position just warped to.
    private func nudgePointer(keyCode: Int, fast: Bool) {
        guard loupeAcceptsKeyboardActions else { return }
        var dx: CGFloat = 0
        var dy: CGFloat = 0
        switch keyCode {
        case kVK_LeftArrow: dx = -1
        case kVK_RightArrow: dx = 1
        case kVK_UpArrow: dy = 1
        case kVK_DownArrow: dy = -1
        default: return
        }
        let location = currentPointerLocation ?? NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(location, $0.frame, false) })
            ?? NSScreen.withMouse else { return }
        let delta = ScreenshotSupport.captureLoupeNudge(dx: dx,
                                                        dy: dy,
                                                        fast: fast,
                                                        scale: screen.backingScaleFactor)
        var target = CGPoint(x: location.x + delta.x, y: location.y + delta.y)
        if !NSScreen.screens.contains(where: { NSMouseInRect(target, $0.frame, false) }) {
            // The pointer spans [minX, maxX) x (minY, maxY], as NSMouseInRect counts it.
            let frame = screen.frame
            let pixel = 1 / max(screen.backingScaleFactor, 1)
            target = CGPoint(
                x: min(max(target.x, frame.minX), frame.maxX - pixel),
                y: min(max(target.y, frame.minY + pixel), frame.maxY))
        }
        currentPointerLocation = target
        let mainHeight = NSScreen.withMenuBar?.frame.height ?? 0
        CGWarpMouseCursorPosition(CGPoint(x: target.x, y: mainHeight - target.y))
        panels.forEach { $0.overlayView.refreshPointerState(mouseLocation: target) }
    }

    private func panelUnderMouse() -> ScreenshotOverlayPanel? {
        let location = currentPointerLocation ?? NSEvent.mouseLocation
        return panels.first { NSMouseInRect(location, $0.screenFrame, false) } ?? panels.first
    }

    private func keyPanelUnderMouse() -> ScreenshotOverlayPanel? {
        panelUnderMouse()
    }

    fileprivate var selectedWindows: [CGWindowID: (window: ScreenshotSupport.PickableWindow, panel: ScreenshotOverlayPanel)] = [:]
    var hasSelectedWindows: Bool { !selectedWindows.isEmpty }

    fileprivate func toggleSelectedWindow(_ window: ScreenshotSupport.PickableWindow, on panel: ScreenshotOverlayPanel) {
        guard activeMode != .geometry else { return }
        if selectedWindows[window.windowID] != nil {
            selectedWindows.removeValue(forKey: window.windowID)
        } else {
            selectedWindows[window.windowID] = (window, panel)
        }
        panels.forEach {
            $0.overlayView.refreshCaptureGuide()
            $0.overlayView.needsDisplay = true
        }
    }

    fileprivate func clearSelectedWindows() {
        selectedWindows.removeAll()
        panels.forEach {
            $0.overlayView.refreshCaptureGuide()
            $0.overlayView.needsDisplay = true
        }
    }

    fileprivate func confirmSelectedWindows() {
        guard acceptsCaptureInput, !selectedWindows.isEmpty else { return }
        let windowEntries = Array(selectedWindows.values)
        guard let firstPanel = windowEntries.first?.panel else { return }
        markCapturePending()

        let windowIDs = windowEntries.map(\.window.windowID)
        let scale = firstPanel.pixelScale

        var unionViewFrame = windowEntries[0].window.frame
        for entry in windowEntries.dropFirst() {
            if entry.panel === firstPanel {
                unionViewFrame = unionViewFrame.union(entry.window.frame)
            } else {
                let cocoa = ScreenshotSupport.cocoaRect(fromFlippedView: entry.window.frame, screenFrame: entry.panel.screenFrame)
                let view = ScreenshotSupport.flippedViewRect(fromCocoa: cocoa, screenFrame: firstPanel.screenFrame)
                unionViewFrame = unionViewFrame.union(view)
            }
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            var capture = await ScreenshotCaptureEngine.captureMultipleWindows(
                windowIDs, scale: scale)
            let isBlank = capture.map { ScreenshotSupport.isImageBlank($0.image) } ?? true
            if isBlank {
                let pixelRect = ScreenshotSupport.imagePixelRect(
                    fromView: unionViewFrame,
                    viewSize: firstPanel.screenFrame.size,
                    imageSize: firstPanel.frozenImageSize ?? firstPanel.pixelSize)
                if let fallbackCrop = firstPanel.frozenImage?.cropping(to: pixelRect) {
                    capture = (fallbackCrop, firstPanel.pixelScale)
                }
            }
            guard let finalCapture = capture else {
                self.finish(.failed)
                return
            }
            self.finish(.captured(Capture(
                image: finalCapture.image,
                scale: finalCapture.scale,
                anchorRect: ScreenshotSupport.cocoaRect(
                    fromFlippedView: unionViewFrame,
                    screenFrame: firstPanel.screenFrame))))
        }
    }

    // MARK: - Confirmations (called by the views)

    private func prepareWaitingRecording(_ rect: CGRect, on panel: ScreenshotOverlayPanel,
                                         windowID: CGWindowID?) -> Bool {
        guard activeTool == .recording,
              !(UserDefaults.standard.object(forKey: DefaultsKey.recorderImmediateStartAfterSelection) as? Bool ?? true),
              let options = screenCaptureOptions else { return false }
        waitingRecordingPanel = panel
        waitingRecordingWindowID = windowID
        panel.overlayView.setRecordingDraft(rect)
        panels.forEach {
            $0.overlayView.refreshGuideVisibility()
            $0.overlayView.refreshFullScreenControlVisibility()
        }
        NotchService.shared.endCaptureControls()
        panel.makeKey()
        let region = region(fromView: rect, on: panel, windowID: windowID)
        RecorderOverlayController.shared.prepareRecording(anchorRect: region.anchorRect,
            pixelSize: region.pixelSize, immediate: false)
        waitingControls = RecorderWaitingControls(audio: options.recorderAudio,
            start: { [weak self] in self?.startWaitingRecording() },
            cancel: { [weak self] in self?.finish(.cancelled) })
        waitingControls?.show(in: region.anchorRect, screen: panel.screenFrame)
        setSelectionInProgress(false)
        return true
    }

    private func resetWaitingRecording() {
        waitingControls?.hide()
        waitingControls = nil
        waitingRecordingPanel = nil
        waitingRecordingWindowID = nil
    }

    fileprivate var isWaitingForRecording: Bool { waitingRecordingPanel != nil }

    fileprivate func updateWaitingRecording(_ rect: CGRect, on panel: ScreenshotOverlayPanel) {
        guard waitingRecordingPanel === panel else { return }
        waitingRecordingWindowID = nil // A manually adjusted window becomes an area capture.
        let region = region(fromView: rect, on: panel, windowID: nil)
        RecorderOverlayController.shared.updateRegion(anchorRect: region.anchorRect, pixelSize: region.pixelSize)
        waitingControls?.show(in: region.anchorRect, screen: panel.screenFrame)
    }

    private func startWaitingRecording() {
        guard acceptsCaptureInput, let panel = waitingRecordingPanel,
              let rect = panel.overlayView.recordingDraft?.rect else { return }
        Self.lastRegion = (panel.displayID, rect)
        finish(.region(region(fromView: rect, on: panel, windowID: waitingRecordingWindowID)))
    }

    private func confirmSelectionWithKeyboard() {
        if isPickingColor {
            guard acceptsCaptureInput, !panels.contains(where: { $0.overlayView.isDragging }),
                  let panel = panelUnderMouse() else { return }
            let location = currentPointerLocation ?? NSEvent.mouseLocation
            let point = CGPoint(x: location.x - panel.screenFrame.minX,
                                y: panel.screenFrame.maxY - location.y)
            confirmColor(at: point, on: panel)
        } else if hasSelectedWindows {
            confirmSelectedWindows()
        } else if acceptsWindowClick {
            captureFullDisplayUnderMouse()
        }
    }

    /// The surfaces stop answering the pointer the instant a picture starts
    /// being taken. They are either about to leave the screen or already gone,
    /// and the rest of the gesture must not begin a second capture.
    private func markCapturePending() {
        panels.forEach { $0.overlayView.isCapturePending = true }
    }

    /// The picked area as the recorder needs it: whole even pixels of the
    /// source display, plus the same area in Cocoa points so a panel can be
    /// anchored to it. The point rectangle is derived from the SNAPPED pixels,
    /// so what gets recorded and what the person was shown never disagree.
    private func region(fromView viewRect: CGRect,
                        on panel: ScreenshotOverlayPanel,
                        windowID: CGWindowID?) -> RecorderSupport.Region {
        let displayPixels = CGRect(origin: .zero, size: panel.pixelSize)
        let raw = ScreenshotSupport.imagePixelRect(fromView: viewRect,
                                                   viewSize: panel.screenFrame.size,
                                                   imageSize: panel.pixelSize)
        let snapped = RecorderSupport.snappedPixelRect(raw, in: displayPixels)
        let scale = panel.pixelScale > 0 ? panel.pixelScale : 1
        let snappedView = CGRect(x: snapped.origin.x / scale,
                                 y: snapped.origin.y / scale,
                                 width: snapped.width / scale,
                                 height: snapped.height / scale)
        return RecorderSupport.Region(
            displayID: panel.displayID,
            windowID: windowID,
            pixelRect: snapped,
            anchorRect: ScreenshotSupport.cocoaRect(fromFlippedView: snappedView,
                                                    screenFrame: panel.screenFrame),
            scale: scale)
    }

    fileprivate func confirmRegion(_ viewRect: CGRect, on panel: ScreenshotOverlayPanel) {
        guard acceptsCaptureInput, activeMode != .color,
              viewRect.width >= 1, viewRect.height >= 1 else { return }
        if prepareWaitingRecording(viewRect, on: panel, windowID: nil) { return }
        markCapturePending()
        Self.lastRegion = (panel.displayID, viewRect)
        if activeMode == .geometry {
            finish(.region(region(fromView: viewRect, on: panel, windowID: nil)))
            return
        }
        if scrollingCaptureEnabled {
            let reg = region(fromView: viewRect, on: panel, windowID: nil)
            let pixelRect = ScreenshotSupport.imagePixelRect(
                fromView: viewRect,
                viewSize: panel.screenFrame.size,
                imageSize: panel.frozenImageSize ?? panel.pixelSize)
            Self.lastInitialCapture = panel.frozenImage?.cropping(to: pixelRect)
            finish(.scrollingRegion(reg))
            return
        }
        let pixelRect = ScreenshotSupport.imagePixelRect(
            fromView: viewRect,
            viewSize: panel.screenFrame.size,
            imageSize: panel.frozenImageSize ?? panel.pixelSize)
        if let frozen = panel.frozenImage {
            guard let cropped = frozen.cropping(to: pixelRect) else {
                finish(.failed)
                return
            }
            finish(.captured(Capture(
                image: cropped,
                scale: panel.pixelScale,
                anchorRect: ScreenshotSupport.cocoaRect(
                    fromFlippedView: viewRect,
                    screenFrame: panel.screenFrame))))
        } else {
            captureLive(displayID: panel.displayID,
                        pixelRect: pixelRect,
                        scale: panel.pixelScale,
                        anchorRect: ScreenshotSupport.cocoaRect(
                            fromFlippedView: viewRect,
                            screenFrame: panel.screenFrame))
        }
    }

    fileprivate func confirmWindow(_ windowID: CGWindowID,
                                   frame: CGRect,
                                   on panel: ScreenshotOverlayPanel) {
        guard acceptsCaptureInput, activeMode != .color else { return }
        if prepareWaitingRecording(frame, on: panel, windowID: windowID) { return }
        markCapturePending()
        if activeMode == .geometry {
            finish(.region(region(fromView: frame, on: panel, windowID: windowID)))
            return
        }
        if scrollingCaptureEnabled {
            let reg = region(fromView: frame, on: panel, windowID: windowID)
            let pixelRect = ScreenshotSupport.imagePixelRect(
                fromView: frame,
                viewSize: panel.screenFrame.size,
                imageSize: panel.frozenImageSize ?? panel.pixelSize)
            Self.lastInitialCapture = panel.frozenImage?.cropping(to: pixelRect)
            finish(.scrollingRegion(reg))
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            var capture = await ScreenshotCaptureEngine.captureWindow(
                windowID, scale: panel.pixelScale)

            // If window-specific capture failed or delivered an empty/blank image (e.g. out-of-process Metal, Chromium, or Mission Control),
            // fall back to cropping the window area directly from the frozen display image.
            let isBlank = capture.map { ScreenshotSupport.isImageBlank($0.image) } ?? true
            if isBlank {
                let pixelRect = ScreenshotSupport.imagePixelRect(
                    fromView: frame,
                    viewSize: panel.screenFrame.size,
                    imageSize: panel.frozenImageSize ?? panel.pixelSize)
                if let fallbackCrop = panel.frozenImage?.cropping(to: pixelRect) {
                    capture = (fallbackCrop, panel.pixelScale)
                }
            }

            guard let finalCapture = capture else {
                self.finish(.failed)
                return
            }
            self.finish(.captured(Capture(
                image: finalCapture.image,
                scale: finalCapture.scale,
                anchorRect: ScreenshotSupport.cocoaRect(
                    fromFlippedView: frame,
                    screenFrame: panel.screenFrame))))
        }
    }

    private func captureFullDisplayUnderMouse() {
        guard acceptsCaptureInput, activeMode != .color else { return }
        guard let panel = panelUnderMouse() else { return }
        captureFullDisplay(on: panel)
    }

    fileprivate func captureFullScreenFromControl(on panel: ScreenshotOverlayPanel) {
        guard offersFullScreenCapture else { return }
        captureFullDisplay(on: panel)
    }

    private func captureFullDisplay(on panel: ScreenshotOverlayPanel) {
        if prepareWaitingRecording(CGRect(origin: .zero, size: panel.screenFrame.size), on: panel, windowID: nil) { return }
        markCapturePending()
        if activeMode == .geometry {
            let whole = CGRect(origin: .zero, size: panel.screenFrame.size)
            finish(.region(region(fromView: whole, on: panel, windowID: nil)))
            return
        }
        if let frozen = panel.frozenImage {
            finish(.captured(Capture(image: frozen,
                                     scale: panel.pixelScale,
                                     anchorRect: panel.screenFrame)))
        } else {
            captureLive(displayID: panel.displayID,
                        pixelRect: nil,
                        scale: panel.pixelScale,
                        anchorRect: panel.screenFrame)
        }
    }

    private func repeatLastRegion() {
        guard offersRepeatLastRegion,
              let last = Self.lastRegion,
              let panel = repeatTargetPanel
        else { return }
        confirmRegion(last.viewRect, on: panel)
    }

    fileprivate func confirmColor(at viewPoint: CGPoint, on panel: ScreenshotOverlayPanel) {
        guard acceptsCaptureInput, activeMode == .color,
              let image = panel.frozenImage ?? panel.overlayView.loupeImage else { return }
        let point = ScreenshotSupport.imagePixelPoint(
            fromView: viewPoint,
            viewSize: panel.screenFrame.size,
            imageSize: CGSize(width: image.width, height: image.height))
        let x = min(max(Int(point.x.rounded(.down)), 0), image.width - 1)
        let y = min(max(Int(point.y.rounded(.down)), 0), image.height - 1)
        guard let color = QuickToolsSupport.sampledColor(in: image, x: x, y: y)
        else {
            finish(.failed)
            return
        }
        markCapturePending()
        finish(.color(color))
    }

    /// Live-mode confirmation: the panels leave the screen, the display is
    /// photographed, and only then does the session end. The brief hide is
    /// what the capture must not contain.
    private func captureLive(displayID: CGDirectDisplayID,
                             pixelRect: CGRect?,
                             scale: CGFloat,
                             anchorRect: CGRect) {
        panels.forEach { $0.orderOut(nil) }
        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard var image = await ScreenshotCaptureEngine.captureDisplay(
                displayID,
                includePointer: self.includePointer,
                hideVorssaintWindows: self.hideVorssaintWindows,
                protectedWindowIDs: self.captureExcludedWindowIDs)
            else {
                self.finish(.failed)
                return
            }
            if let pixelRect {
                let clamped = ScreenshotSupport.clamp(
                    pixelRect,
                    to: CGRect(x: 0, y: 0, width: image.width, height: image.height))
                guard let cropped = image.cropping(to: clamped) else {
                    self.finish(.failed)
                    return
                }
                image = cropped
            }
            self.finish(.captured(Capture(image: image,
                                          scale: scale,
                                          anchorRect: anchorRect)))
        }
    }

    func cancel() {
        finish(.cancelled)
    }

    deinit {
        // A session that goes away without ending would otherwise leave the
        // screen marked as taken and every capture feature dead until the app
        // is restarted. The wrong flag is always the one that lets a capture
        // start, never the one that blocks it.
        if cursorPushed {
            NSCursor.pop()
            cursorPushed = false
        }
        if !finished {
            Self.isSessionOnScreen = false
            if Self.activeSession === self { Self.activeSession = nil }
        }
    }

    private func finish(_ outcome: Outcome) {
        guard !finished else { return }
        waitingControls?.hide()
        waitingControls = nil
        waitingRecordingPanel = nil
        if activeTool == .recording {
            if case .region = outcome {} else { RecorderOverlayController.shared.stop() }
        }
        finished = true
        selectedWindows.removeAll()
        Self.isSessionOnScreen = false
        if Self.activeSession === self { Self.activeSession = nil }
        screenCaptureOptions?.onSelectionChange = nil
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
            self.flagsMonitor = nil
        }
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }
        // A gesture can still have events on the way, so the surfaces are made
        // inert before they leave the screen: whatever arrives after this
        // point finds nothing left to act on.
        markCapturePending()
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        if cursorPushed {
            NSCursor.pop()
            cursorPushed = false
        }
        NSCursor.arrow.set()
        if let previous = previousFrontmostApp, previous.bundleIdentifier != Bundle.main.bundleIdentifier {
            previous.activate(options: [])
        }
        self.previousFrontmostApp = nil
        let completion = completion
        self.completion = nil
        completion?(outcome)
    }
}

// MARK: - Panel

/// Full-screen borderless panel for one display.
private final class ScreenshotOverlayPanel: OverlayPanel {
    let screenFrame: CGRect
    let displayID: CGDirectDisplayID
    /// Height reserved by macOS chrome at the top of this display. The
    /// full-screen action stays below it even when there is no notch surface.
    let topChromeHeight: CGFloat
    private(set) var frozenImage: CGImage?
    let pixelScale: CGFloat
    private(set) var overlayViewStorage: ScreenshotOverlayView!
    private var backdropView: NSImageView!

    var overlayView: ScreenshotOverlayView { overlayViewStorage }

    var frozenImageSize: CGSize? {
        frozenImage.map { CGSize(width: $0.width, height: $0.height) }
    }

    /// Display size in pixels, for live-mode crop math.
    var pixelSize: CGSize {
        CGSize(width: screenFrame.width * pixelScale, height: screenFrame.height * pixelScale)
    }

    init(screen: NSScreen,
         frozenImage: CGImage?,
         windows: [ScreenshotSupport.PickableWindow],
         controller: ScreenshotSelectionController,
         strings: ScreenshotFeatureStrings,
         purpose: String?,
         screenCaptureOptions: ScreenCaptureSelectionOptions?) {
        screenFrame = screen.frame
        displayID = screen.displayID
        topChromeHeight = max(screen.safeAreaInsets.top,
                              screen.frame.maxY - screen.visibleFrame.maxY)
        self.frozenImage = frozenImage
        pixelScale = screen.backingScaleFactor
        super.init(contentRect: screen.frame,
                   styleMask: [.borderless],
                   backing: .buffered,
                   defer: false)
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = false
        animationBehavior = .none

        // The frozen still sits in its own view UNDER the chrome: a backing
        // layer configured before the view joins a window can lose its
        // contents, and the chrome's dim must paint over the image anyway.
        let container = ScreenshotOverlayContainerView(frame: CGRect(origin: .zero, size: screen.frame.size))
        let imageView = NSImageView(frame: container.bounds)
        imageView.image = frozenImage.map { NSImage(cgImage: $0, size: screen.frame.size) }
        imageView.imageScaling = .scaleAxesIndependently
        imageView.autoresizingMask = [.width, .height]
        container.addSubview(imageView)
        backdropView = imageView
        let view = ScreenshotOverlayView(frame: CGRect(origin: .zero, size: screen.frame.size),
                                         frozenImage: frozenImage,
                                         loupeImage: frozenImage,
                                         windows: windows,
                                         controller: controller,
                                         panel: self,
                                         strings: strings,
                                         purpose: purpose,
                                         screenCaptureOptions: screenCaptureOptions)
        view.autoresizingMask = [.width, .height]
        container.addSubview(view)
        overlayViewStorage = view
        contentView = container
    }

    /// New pixels for a tool that needs its own photograph, without the
    /// panel ever leaving the screen.
    func update(frozenImage: CGImage?, windows: [ScreenshotSupport.PickableWindow]) {
        self.frozenImage = frozenImage
        isOpaque = false
        backgroundColor = .clear
        backdropView.image = frozenImage.map { NSImage(cgImage: $0, size: screenFrame.size) }
        overlayView.update(frozenImage: frozenImage, windows: windows)
    }

    override var canBecomeKey: Bool { true }
    override func becomeKey() {
        super.becomeKey()
        NSCursor.crosshair.set()
    }
}

private class ScreenshotOverlayContainerView: NSView {
    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }
}

// MARK: - View

/// Draws the frozen background, the dim, the selection, window highlights
/// and the magnifier; owns all mouse interaction. Flipped so
/// geometry matches image pixels (top-left origin) with no sign juggling.
private final class ScreenshotOverlayView: NSView {
    private var pointerHasMoved = false
    private var frozenImage: CGImage?
    fileprivate var loupeImage: CGImage?
    private var windows: [ScreenshotSupport.PickableWindow]
    /// Both are held weakly on purpose. The session hands its result over
    /// after the panels leave the screen, so the controller is already gone
    /// while the window server still delivers the tail of a gesture here.
    private weak var controller: ScreenshotSelectionController?
    private weak var panel: ScreenshotOverlayPanel?
    private let strings: ScreenshotFeatureStrings
    private let purpose: String?
    private let screenCaptureOptions: ScreenCaptureSelectionOptions?
    private let guideModel = CaptureGuideViewModel()
    private let guideHost: PassThroughHostingView<CaptureGuideView>
    private let fullScreenHost: PassThroughHostingView<FullScreenCaptureButton>
    private var notchCaptureControlsHeight: CGFloat?
    private var fullScreenControlHovered = false
    private var deferredNotchCaptureControlsHeight: CGFloat?
    private var hasDeferredNotchCaptureControlsHeight = false

    private var dragOrigin: CGPoint?
    private var lastDragPoint: CGPoint = .zero
    private var selection: CGRect = .zero
    fileprivate private(set) var recordingDraft: RecorderSelectionDraft?
    private var hoverPoint: CGPoint = .zero
    private var pointerIsInside = false
    private var hoveredWindow: ScreenshotSupport.PickableWindow?
    private let highlightWindows = true
    /// The value just copied with C, shown briefly in the loupe's info bar
    /// because the regular HUD sits under these shielding-level panels.
    private var copiedValue: String?
    private var copiedValueReset: DispatchWorkItem?
    var ghostRect: CGRect?
    var isCapturePending = false {
        didSet {
            refreshGuideVisibility()
            refreshFullScreenControlVisibility()
            needsDisplay = true
        }
    }

    var isDragging: Bool { dragOrigin != nil }

    /// A surface whose session is over answers nothing, so the rest of a
    /// gesture can neither reach a controller that is gone nor start a second
    /// capture behind the one already running.
    private var acceptsPointerInput: Bool {
        controller?.acceptsCaptureInput == true && ScreenshotSupport.selectionAcceptsPointerInput(
            sessionIsOver: controller?.isOver ?? true,
            capturePending: isCapturePending)
    }

    func update(frozenImage: CGImage?, windows: [ScreenshotSupport.PickableWindow]) {
        self.frozenImage = frozenImage
        self.loupeImage = frozenImage
        self.windows = windows
        refreshPointerState()
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    /// With the controls in Dynamic Island, the island's panel holds key
    /// focus for its shortcuts and this surface never becomes key on its own.
    /// AppKit would then spend the first click making the window key and
    /// swallow it, so the first drag drew nothing. Claim it instead.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    init(frame: CGRect,
         frozenImage: CGImage?,
         loupeImage: CGImage?,
         windows: [ScreenshotSupport.PickableWindow],
         controller: ScreenshotSelectionController,
         panel: ScreenshotOverlayPanel,
         strings: ScreenshotFeatureStrings,
         purpose: String?,
         screenCaptureOptions: ScreenCaptureSelectionOptions?) {
        self.frozenImage = frozenImage
        self.loupeImage = loupeImage
        self.windows = windows
        self.controller = controller
        self.panel = panel
        self.strings = strings
        self.purpose = purpose
        self.screenCaptureOptions = screenCaptureOptions
        guideModel.offersScrollingCapture = controller.offersScrollingCapture
        guideModel.offersRepeatLastRegion = controller.offersRepeatLastRegion
        guideModel.requiresDraggedRegion = controller.requiresDraggedRegion
        guideModel.scrollingCaptureEnabled = controller.scrollingCaptureEnabled
        guideModel.loupeEnabled = controller.loupeEnabled
        guideModel.selectedWindowsCount = controller.selectedWindows.count
        let host = PassThroughHostingView(interactiveRootView: CaptureGuideView(
            strings: strings,
            purpose: purpose,
            model: guideModel,
            screenCaptureOptions: screenCaptureOptions,
            onFullScreen: { [weak controller, weak panel] in
                guard let controller, let panel else { return }
                controller.captureFullScreenFromControl(on: panel)
            },
            onToggleScrolling: { [weak controller] in
                controller?.toggleScrollingCapture()
            },
            onToggleLoupe: { [weak controller] in
                controller?.toggleLoupe()
            },
            onRepeatLastRegion: { [weak controller] in
                controller?.performRepeatLastRegion()
            },
            onToggleMode: { [weak controller] in
                controller?.toggleCaptureAndRecordMode()
            },
            onCancel: { [weak controller] in
                controller?.cancel()
            }))
        guideHost = host
        let hoverRelay = FullScreenControlHoverRelay()
        let fullScreen = PassThroughHostingView(interactiveRootView: FullScreenCaptureButton(
            action: { [weak controller, weak panel] in
                guard let controller, let panel else { return }
                controller.captureFullScreenFromControl(on: panel)
            },
            hoverChanged: { hoverRelay.update($0) }))
        fullScreenHost = fullScreen
        fullScreenHost.isHidden = true
        super.init(frame: frame)
        guideModel.onHoverChanged = { [weak self] isHovered in
            guard let self else { return }
            self.guideHost.isHovered = isHovered
            self.updatePointerHover(self.hoverPoint)
            self.needsDisplay = true
        }
        hoverRelay.changed = { [weak self] in self?.fullScreenControlHoverChanged($0) }
        let tracking = NSTrackingArea(rect: .zero,
                                      options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited,
                                                .cursorUpdate, .inVisibleRect],
                                      owner: self)
        addTrackingArea(tracking)
        addSubview(guideHost)
        refreshGuideVisibility()
        refreshFullScreenControlVisibility()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func layout() {
        super.layout()
        let width = min(620, max(280, bounds.width - 32))
        let targetHeight: CGFloat = screenCaptureOptions != nil
            ? (screenCaptureOptions?.showsCaptureMenu == false ? 82 : 146)
            : 72
        guideHost.frame = CGRect(x: bounds.midX - width / 2,
                                 y: bounds.maxY - targetHeight - 32,
                                 width: width,
                                 height: targetHeight)
        let availableWidth = max(1, bounds.width - 32)
        let fullScreenFitting = fullScreenHost.fittingSize
        let fullScreenWidth = min(max(fullScreenFitting.width, 1), availableWidth)
        let fullScreenHeight = max(fullScreenFitting.height, 32)
        let topInset = ScreenshotSupport.fullScreenCaptureControlTopInset(
            screenChromeHeight: panel?.topChromeHeight ?? 0,
            notchControlsHeight: notchCaptureControlsHeight)
        fullScreenHost.frame = CGRect(x: bounds.midX - fullScreenWidth / 2,
                                      y: topInset,
                                      width: fullScreenWidth,
                                      height: fullScreenHeight)
    }

    /// An explicit location covers pointer warps, whose new position may not
    /// be visible through NSEvent.mouseLocation yet when this runs.
    func refreshPointerState(mouseLocation: CGPoint? = nil) {
        guard let panel else { return }
        let global = mouseLocation ?? controller?.currentPointerLocation ?? NSEvent.mouseLocation
        let point = CGPoint(x: global.x - panel.screenFrame.minX,
                            y: panel.screenFrame.maxY - global.y)
        pointerIsInside = bounds.contains(point)
        if pointerIsInside {
            updatePointerHover(point)
        } else {
            hoveredWindow = nil
        }
        refreshFullScreenControlVisibility()
        needsDisplay = true
    }

    func updateLoupeImage(_ image: CGImage?) {
        loupeImage = image
        needsDisplay = true
    }

    func setRecordingDraft(_ rect: CGRect) {
        recordingDraft = RecorderSelectionDraft(rect: rect)
        selection = rect
        dragOrigin = nil
        needsDisplay = true
    }

    func copyLoupeColorUnderPointer() {
        guard let loupeImage else { return }
        let point = isDragging ? lastDragPoint : hoverPoint
        let pixelPoint = ScreenshotSupport.imagePixelPoint(
            fromView: point,
            viewSize: bounds.size,
            imageSize: CGSize(width: loupeImage.width, height: loupeImage.height))
        let sample = loupePixelColor(in: loupeImage, at: pixelPoint)
        guard let color = sample.color,
              let value = ColorSamplerService.shared.copyQuietly(color)
        else { return }
        copiedValue = value
        copiedValueReset?.cancel()
        let reset = DispatchWorkItem { [weak self] in
            self?.copiedValue = nil
            self?.needsDisplay = true
        }
        copiedValueReset = reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: reset)
        needsDisplay = true
    }

    func refreshCaptureGuide() {
        guard let controller else { return }
        guideModel.offersScrollingCapture = controller.offersScrollingCapture
        guideModel.offersRepeatLastRegion = controller.offersRepeatLastRegion
        guideModel.requiresDraggedRegion = controller.requiresDraggedRegion
        guideModel.scrollingCaptureEnabled = controller.scrollingCaptureEnabled
        guideModel.loupeEnabled = controller.loupeEnabled
        guideModel.selectedWindowsCount = controller.selectedWindows.count
        needsLayout = true
    }

    func captureToolDidChange() {
        recordingDraft = nil
        dragOrigin = nil
        selection = .zero
        hoveredWindow = nil
        refreshGuideVisibility()
        refreshCaptureGuide()
        refreshFullScreenControlVisibility()
        needsLayout = true
        needsDisplay = true
        refreshPointerState()
    }

    // MARK: Mouse

    override func mouseMoved(with event: NSEvent) {
        NSCursor.crosshair.set()
        pointerHasMoved = true
        controller?.currentPointerLocation = nil
        updatePointerHover(convert(event.locationInWindow, from: nil))
        refreshFullScreenControlVisibility()
        needsDisplay = true
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.crosshair.set()
        refreshPointerState()
        refreshGuideVisibility()
        refreshFullScreenControlVisibility()
    }


    // System chrome can take pointer ownership without the pointer leaving
    // this display. Re-evaluate the real location so the chooser does not
    // disappear over the Dock, menu bar or its own interactive controls.
    override func mouseExited(with event: NSEvent) {
        refreshPointerState()
        refreshGuideVisibility()
        refreshFullScreenControlVisibility()
    }

    override func scrollWheel(with event: NSEvent) {
        guard acceptsPointerInput, let controller, controller.loupeEnabled else {
            super.scrollWheel(with: event)
            return
        }
        let steppedByDefault = UserDefaults.standard.bool(
            forKey: DefaultsKey.screenshotLoupeSteppedZoomByDefault)
        let stepped = ScreenshotSupport.captureLoupeUsesSteppedZoom(
            steppedByDefault: steppedByDefault,
            optionPressed: event.modifierFlags.contains(.option))
        let wheelDelta: CGFloat
        if let cgEvent = event.cgEvent {
            wheelDelta = ScreenshotSupport.captureLoupeWheelDelta(
                scrollingDelta: event.scrollingDeltaY,
                lineDelta: cgEvent.getIntegerValueField(.scrollWheelEventDeltaAxis1),
                fixedPointDelta: cgEvent.getDoubleValueField(
                    .scrollWheelEventFixedPtDeltaAxis1))
        } else {
            wheelDelta = event.scrollingDeltaY
        }
        controller.adjustLoupeZoom(
            by: wheelDelta,
            stepped: stepped,
            isContinuous: event.hasPreciseScrollingDeltas)
    }

    override func mouseDown(with event: NSEvent) {
        NSCursor.crosshair.set()
        guard acceptsPointerInput else { return }
        controller?.currentPointerLocation = nil
        let point = convert(event.locationInWindow, from: nil)
        if controller?.isWaitingForRecording == true {
            recordingDraft?.begin(at: point)
            return
        }
        pointerIsInside = true
        hoverPoint = point
        dragOrigin = point
        controller?.setSelectionInProgress(true)
        lastDragPoint = point
        selection = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        NSCursor.crosshair.set()
        if controller?.isWaitingForRecording == true {
            if recordingDraft?.drag(to: convert(event.locationInWindow, from: nil), within: bounds) == true,
               let rect = recordingDraft?.rect, let panel {
                selection = rect
                controller?.updateWaitingRecording(rect, on: panel)
                needsDisplay = true
            }
            return
        }
        guard acceptsPointerInput, let controller, let origin = dragOrigin else { return }
        controller.currentPointerLocation = nil
        let point = convert(event.locationInWindow, from: nil)
        pointerIsInside = true
        hoverPoint = point
        if controller.isPickingColor {
            lastDragPoint = point
            needsDisplay = true
            return
        }
        if controller.spaceIsDown, selection.width > 0 {
            // Space pans the selection instead of resizing it.
            let delta = CGPoint(x: point.x - lastDragPoint.x, y: point.y - lastDragPoint.y)
            selection.origin.x += delta.x
            selection.origin.y += delta.y
            dragOrigin = CGPoint(x: origin.x + delta.x, y: origin.y + delta.y)
        } else {
            selection = ScreenshotSupport.selectionRect(
                from: origin,
                to: point,
                square: event.modifierFlags.contains(.shift),
                fromCenter: event.modifierFlags.contains(.option))
        }
        selection = ScreenshotSupport.clamp(selection, to: bounds)
        if controller.activeTool == .recording, let panel {
            let anchor = ScreenshotSupport.cocoaRect(fromFlippedView: selection, screenFrame: panel.screenFrame)
            let scale = panel.screen?.backingScaleFactor ?? 1
            RecorderOverlayController.shared.updateRegion(anchorRect: anchor,
                pixelSize: CGSize(width: selection.width * scale, height: selection.height * scale))
        }
        lastDragPoint = point
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard acceptsPointerInput, let controller, let panel else { return }
        if controller.isWaitingForRecording { recordingDraft?.end(); return }
        let point = convert(event.locationInWindow, from: nil)
        guard let origin = dragOrigin else { return }
        dragOrigin = nil
        controller.spaceIsDown = false

        if controller.isPickingColor {
            selection = .zero
            controller.confirmColor(at: point, on: panel)
            return
        }

        let clicked = ScreenshotSupport.isClick(from: origin, to: point)
        if clicked {
            if controller.acceptsWindowClick,
               let target = ScreenshotSupport.window(at: point, in: windows) {
                if controller.activeMode != .geometry && controller.activeTool != .recording && event.modifierFlags.contains(.shift) {
                    controller.toggleSelectedWindow(target, on: panel)
                } else if controller.hasSelectedWindows {
                    if controller.selectedWindows[target.windowID] != nil {
                        controller.confirmSelectedWindows()
                    } else {
                        controller.clearSelectedWindows()
                        controller.confirmWindow(target.windowID, frame: target.frame, on: panel)
                    }
                } else {
                    controller.confirmWindow(target.windowID, frame: target.frame, on: panel)
                }
            } else if controller.hasSelectedWindows {
                // Clicked blank area without Shift
            }
            if recordingDraft == nil { selection = .zero }
            needsDisplay = true
            controller.setSelectionInProgress(false)
            refreshGuideVisibility()
            return
        }
        guard selection.width >= 2, selection.height >= 2 else {
            selection = .zero
            controller.setSelectionInProgress(false)
            needsDisplay = true
            refreshGuideVisibility()
            return
        }
        controller.confirmRegion(selection, on: panel)
    }

    func refreshGuideVisibility() {
        if controller?.isWaitingForRecording == true { guideHost.isHidden = true; return }
        guard screenCaptureOptions?.controlsInNotch != true, let panel else {
            guideHost.isHidden = true
            return
        }
        let global = controller?.currentPointerLocation ?? NSEvent.mouseLocation
        let pointerOnDisplay = NSMouseInRect(global, panel.screenFrame, false)
        guideHost.isHidden = !pointerOnDisplay || isCapturePending
    }

    func setNotchCaptureControlsHeight(_ height: CGFloat?) {
        // The island collapses on its own timer. Do not move the action out
        // from under a pointer that is already aiming at it; apply the latest
        // surface geometry as soon as the pointer leaves instead.
        if fullScreenControlHovered {
            deferredNotchCaptureControlsHeight = height
            hasDeferredNotchCaptureControlsHeight = true
            return
        }
        notchCaptureControlsHeight = height
        needsLayout = true
    }

    func refreshFullScreenControlVisibility() {
        if controller?.isWaitingForRecording == true { fullScreenHost.isHidden = true; return }
        guard let panel else {
            fullScreenHost.isHidden = true
            resetFullScreenControlHover()
            return
        }
        let global = controller?.currentPointerLocation ?? NSEvent.mouseLocation
        let hidden = !ScreenshotSupport.fullScreenCaptureControlIsVisible(
            isAvailable: controller?.offersFullScreenCapture ?? false,
            pointerOnDisplay: NSMouseInRect(global, panel.screenFrame, false),
            selectionInProgress: controller?.selectionInProgress ?? true,
            capturePending: isCapturePending)
        fullScreenHost.isHidden = hidden
        if hidden { resetFullScreenControlHover() }
    }

    private func pointerIsOverFullScreenControl(_ point: CGPoint) -> Bool {
        !fullScreenHost.isHidden && fullScreenHost.frame.contains(point)
    }

    private func pointerIsOverTab(_ point: CGPoint) -> Bool {
        !guideHost.isHidden && guideHost.frame.contains(point) && guideHost.isHovered
    }

    private func updatePointerHover(_ point: CGPoint) {
        pointerIsInside = true
        hoverPoint = point
        let overControls = pointerIsOverFullScreenControl(point) || pointerIsOverTab(point)
        hoveredWindow = highlightWindows && controller?.acceptsWindowClick == true
                && !overControls
            ? ScreenshotSupport.window(at: point, in: windows)
            : nil
    }

    private func fullScreenControlHoverChanged(_ hovered: Bool) {
        fullScreenControlHovered = hovered
        if !hovered { applyDeferredNotchCaptureControlsHeight() }
        // SwiftUI owns the pill's hover tracking, while AppKit owns the
        // window highlight. Re-evaluate the latter on the same transition.
        refreshPointerState()
    }

    private func resetFullScreenControlHover() {
        guard fullScreenControlHovered else { return }
        fullScreenControlHovered = false
        applyDeferredNotchCaptureControlsHeight()
    }

    private func applyDeferredNotchCaptureControlsHeight() {
        if hasDeferredNotchCaptureControlsHeight {
            notchCaptureControlsHeight = deferredNotchCaptureControlsHeight
            deferredNotchCaptureControlsHeight = nil
            hasDeferredNotchCaptureControlsHeight = false
            needsLayout = true
        }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext,
              let controller,
              let panel
        else { return }
        // Opening controls in the notch should not darken the whole desktop.
        // Keep selection feedback, without the initial full-screen dim/tint.
        let notchChooser = screenCaptureOptions?.controlsInNotch == true
        let dimAlpha = ScreenshotSupport.selectionDimAlpha(notchControls: notchChooser,
                                                          isFrozen: frozenImage != nil, isDragging: isDragging)
        if frozenImage == nil {
            context.setFillColor(CGColor(gray: 0, alpha: 0.005))
            context.fill(bounds)
        }
        context.setFillColor(CGColor(gray: 0, alpha: dimAlpha))
        if selection.width > 0, selection.height > 0 {
            context.beginPath()
            context.addRect(bounds)
            context.addPath(CGPath(roundedRect: selection,
                                   cornerWidth: 8,
                                   cornerHeight: 8,
                                   transform: nil))
            context.fillPath(using: .evenOdd)
            drawSelectionChrome(context, pixelScale: panel.pixelScale)
        } else if dragOrigin == nil, (hoveredWindow != nil || controller.hasSelectedWindows) {
            context.beginPath()
            context.addRect(bounds)
            let windowRadius: CGFloat = 10
            if controller.hasSelectedWindows {
                for (_, entry) in controller.selectedWindows where entry.panel === panel {
                    let path = CGPath(roundedRect: entry.window.frame, cornerWidth: windowRadius, cornerHeight: windowRadius, transform: nil)
                    context.addPath(path)
                }
            }
            if let hovered = hoveredWindow, controller.selectedWindows[hovered.windowID] == nil {
                let path = CGPath(roundedRect: hovered.frame, cornerWidth: windowRadius, cornerHeight: windowRadius, transform: nil)
                context.addPath(path)
            }
            context.fillPath(using: .evenOdd)

            var activePunchedIDs = Set(controller.selectedWindows.values.filter { $0.panel === panel }.map { $0.window.windowID })
            if let hovered = hoveredWindow, controller.selectedWindows[hovered.windowID] == nil {
                activePunchedIDs.insert(hovered.windowID)
            }
            for targetID in activePunchedIDs {
                let windowsInFront = windows.prefix(while: { $0.windowID != targetID })
                for foreground in windowsInFront where !activePunchedIDs.contains(foreground.windowID) {
                    context.setFillColor(CGColor(gray: 0, alpha: dimAlpha))
                    let path = CGPath(roundedRect: foreground.frame, cornerWidth: windowRadius, cornerHeight: windowRadius, transform: nil)
                    context.addPath(path)
                    context.fillPath()
                }
            }
            if let hovered = hoveredWindow, controller.selectedWindows[hovered.windowID] == nil {
                drawWindowHighlight(context, rect: hovered.frame, cornerRadius: windowRadius)
            }
            if controller.hasSelectedWindows {
                for (_, entry) in controller.selectedWindows where entry.panel === panel {
                    drawWindowCheckmark(context, for: entry.window)
                }
            }
        } else {
            context.fill(bounds)
        }

        if controller.loupeEnabled, !controller.spaceIsDown, pointerIsInside {
            let point = isDragging ? lastDragPoint : hoverPoint
            drawAuxiliaryCrosshair(context, at: point)
            if let loupeImage {
                drawCaptureLoupe(context,
                                 image: loupeImage,
                                 near: point,
                                 zoom: controller.loupeZoom)
            }
        }

        if let ghostRect, dragOrigin == nil, selection == .zero {
            drawGhost(context, rect: ghostRect)
        }
    }

    private func drawAuxiliaryCrosshair(_ context: CGContext, at point: CGPoint) {
        context.saveGState()

        // Subtle dark under-stroke for contrast on light backgrounds
        context.setStrokeColor(CGColor(gray: 0, alpha: 0.35))
        context.setLineWidth(2)
        context.move(to: CGPoint(x: bounds.minX, y: point.y))
        context.addLine(to: CGPoint(x: bounds.maxX, y: point.y))
        context.move(to: CGPoint(x: point.x, y: bounds.minY))
        context.addLine(to: CGPoint(x: point.x, y: bounds.maxY))
        context.strokePath()

        // 1pt bright line over top
        context.setStrokeColor(CGColor(srgbRed: 0.35, green: 0.65, blue: 1.0, alpha: 0.95))
        context.setLineWidth(1)
        context.move(to: CGPoint(x: bounds.minX, y: point.y))
        context.addLine(to: CGPoint(x: bounds.maxX, y: point.y))
        context.move(to: CGPoint(x: point.x, y: bounds.minY))
        context.addLine(to: CGPoint(x: point.x, y: bounds.maxY))
        context.strokePath()

        context.restoreGState()
    }

    private func drawSelectionChrome(_ context: CGContext, pixelScale: CGFloat) {
        if recordingDraft != nil {
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -0.5), blur: 3, color: CGColor(gray: 0, alpha: 0.35))
            for handle in ScreenshotSupport.Handle.allCases {
                let point = handle.position(in: selection)
                let rect: CGRect
                let radius: CGFloat
                switch handle {
                case .top, .bottom:
                    rect = CGRect(x: point.x - 14, y: point.y - 3, width: 28, height: 6)
                    radius = 3
                case .left, .right:
                    rect = CGRect(x: point.x - 3, y: point.y - 14, width: 6, height: 28)
                    radius = 3
                case .topLeft, .topRight, .bottomLeft, .bottomRight:
                    rect = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
                    radius = 2.5
                }
                let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
                context.addPath(path)
                context.setFillColor(NSColor.white.cgColor)
                context.fillPath()
                context.addPath(path)
                context.setStrokeColor(CGColor(gray: 0.1, alpha: 0.25))
                context.setLineWidth(0.75)
                context.strokePath()
            }
            context.restoreGState()
        }
        let outer = CGPath(roundedRect: selection.insetBy(dx: -1.5, dy: -1.5),
                           cornerWidth: 9,
                           cornerHeight: 9,
                           transform: nil)
        let inner = CGPath(roundedRect: selection.insetBy(dx: -0.5, dy: -0.5),
                           cornerWidth: 8,
                           cornerHeight: 8,
                           transform: nil)
        context.saveGState()
        context.setShadow(offset: .zero,
                          blur: 9,
                          color: CGColor(srgbRed: 0.18, green: 0.55, blue: 1, alpha: 0.55))
        context.addPath(outer)
        context.setStrokeColor(CGColor(srgbRed: 0.18, green: 0.55, blue: 1, alpha: 0.98))
        context.setLineWidth(3)
        context.strokePath()
        context.restoreGState()
        context.addPath(inner)
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.95))
        context.setLineWidth(1)
        context.strokePath()

        let width = Int(selection.width.rounded())
        let height = Int(selection.height.rounded())
        drawBadge("\(width) × \(height)",
                  near: CGPoint(x: selection.midX, y: selection.maxY + 10))
    }

    private func drawWindowHighlight(_ context: CGContext, rect: CGRect, cornerRadius: CGFloat = 10) {
        let path = CGPath(roundedRect: rect.insetBy(dx: 1.25, dy: 1.25),
                          cornerWidth: max(0, cornerRadius - 1),
                          cornerHeight: max(0, cornerRadius - 1),
                          transform: nil)
        context.addPath(path)
        context.setFillColor(CGColor(srgbRed: 0.35, green: 0.62, blue: 1, alpha: 0.14))
        context.fillPath()
        context.addPath(path)
        context.setStrokeColor(CGColor(srgbRed: 0.35, green: 0.62, blue: 1, alpha: 0.95))
        context.setLineWidth(2.5)
        context.strokePath()
    }

    private func drawWindowCheckmark(_ context: CGContext, for window: ScreenshotSupport.PickableWindow) {
        let frame = window.frame
        let windowsInFront = windows.prefix(while: { $0.windowID != window.windowID })
        let candidates: [CGPoint] = [
            CGPoint(x: frame.minX + 24, y: frame.minY + 24),
            CGPoint(x: frame.maxX - 24, y: frame.minY + 24),
            CGPoint(x: frame.minX + 24, y: frame.maxY - 24),
            CGPoint(x: frame.maxX - 24, y: frame.maxY - 24),
            CGPoint(x: frame.midX, y: frame.midY)
        ]
        var badgeCenter = candidates[0]
        for candidate in candidates {
            if !windowsInFront.contains(where: { $0.frame.contains(candidate) }) {
                badgeCenter = candidate
                break
            }
        }

        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 2), blur: 6, color: CGColor(gray: 0, alpha: 0.4))
        let badgeRect = CGRect(x: badgeCenter.x - 12, y: badgeCenter.y - 12, width: 24, height: 24)
        context.setFillColor(CGColor(srgbRed: 0.04, green: 0.52, blue: 1.0, alpha: 1.0))
        context.fillEllipse(in: badgeRect)

        context.setStrokeColor(CGColor(gray: 1, alpha: 0.95))
        context.setLineWidth(1.5)
        context.strokeEllipse(in: badgeRect)
        context.restoreGState()

        context.saveGState()
        context.setStrokeColor(CGColor(gray: 1, alpha: 1.0))
        context.setLineWidth(2.2)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.beginPath()
        context.move(to: CGPoint(x: badgeCenter.x - 5, y: badgeCenter.y))
        context.addLine(to: CGPoint(x: badgeCenter.x - 1.5, y: badgeCenter.y + 3.5))
        context.addLine(to: CGPoint(x: badgeCenter.x + 5, y: badgeCenter.y - 3.5))
        context.strokePath()
        context.restoreGState()
    }

    private func drawGhost(_ context: CGContext, rect: CGRect) {
        context.saveGState()
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.65))
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [5, 4])
        context.stroke(rect)
        context.restoreGState()
    }

    // MARK: Pixel loupe

    private func drawCaptureLoupe(_ context: CGContext,
                                  image: CGImage,
                                  near point: CGPoint,
                                  zoom: CGFloat) {
        let imageSize = CGSize(width: image.width, height: image.height)
        let pixelPoint = ScreenshotSupport.imagePixelPoint(
            fromView: point,
            viewSize: bounds.size,
            imageSize: imageSize)
        let sampleSide = ScreenshotSupport.captureLoupeSampleSide(zoom: zoom)
        let source = ScreenshotSupport.cropLoupeSampleRect(
            around: pixelPoint,
            imageSize: imageSize,
            sideLength: sampleSide)
        guard let sample = image.cropping(to: source) else { return }

        let side = ScreenshotSupport.captureLoupeFrameSide
        let gap: CGFloat = 6
        let coordHeight: CGFloat = 22
        let colorHeight: CGFloat = 24
        let totalHeight = side + gap + coordHeight + gap + colorHeight

        let block = captureLoupeFrame(
            near: point,
            size: CGSize(width: side, height: totalHeight))
        let frame = CGRect(x: block.minX, y: block.minY, width: side, height: side)
        let path = CGPath(roundedRect: frame,
                          cornerWidth: 9,
                          cornerHeight: 9,
                          transform: nil)
        context.saveGState()
        context.addPath(path)
        context.clip()
        context.interpolationQuality = .none
        // CGImage draws bottom-up inside the flipped overlay, so mirror only
        // this destination to keep the magnified pixels upright.
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        let flippedFrame = CGRect(x: frame.minX,
                                  y: bounds.height - frame.maxY,
                                  width: frame.width,
                                  height: frame.height)
        context.draw(sample, in: flippedFrame)
        context.restoreGState()

        // Reticle
        let target = ScreenshotSupport.captureLoupeTargetPixelRect(
            around: pixelPoint,
            source: source,
            frame: frame)
        let ring = target.insetBy(dx: -1, dy: -1)
        let reticle = CGMutablePath()
        reticle.addRect(ring)
        let arms = [
            (CGPoint(x: ring.midX, y: frame.minY), CGPoint(x: ring.midX, y: ring.minY)),
            (CGPoint(x: ring.midX, y: ring.maxY), CGPoint(x: ring.midX, y: frame.maxY)),
            (CGPoint(x: frame.minX, y: ring.midY), CGPoint(x: ring.minX, y: ring.midY)),
            (CGPoint(x: ring.maxX, y: ring.midY), CGPoint(x: frame.maxX, y: ring.midY)),
        ]
        for (start, end) in arms where end.x > start.x || end.y > start.y {
            reticle.move(to: start)
            reticle.addLine(to: end)
        }

        context.saveGState()
        context.addPath(path)
        context.clip()
        if ScreenshotSupport.captureLoupeGridVisible(
            frameSide: side, sampleSide: max(source.width, source.height)) {
            drawLoupeGrid(context, frame: frame, source: source)
        }
        context.addPath(reticle)
        context.setStrokeColor(CGColor(gray: 0, alpha: 0.76))
        context.setLineWidth(3)
        context.strokePath()
        context.addPath(reticle)
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.92))
        context.setLineWidth(1)
        context.strokePath()
        context.restoreGState()

        context.saveGState()
        context.addPath(path)
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.95))
        context.setLineWidth(1.5)
        context.strokePath()
        context.restoreGState()

        // 2. Coordinate box stacked vertically
        let coordRect = CGRect(x: block.minX,
                               y: frame.maxY + gap,
                               width: side,
                               height: coordHeight)
        drawLoupeCoordinateBox(context, in: coordRect, at: point)

        // 3. Color box stacked vertically (fixed width)
        let colorRect = CGRect(x: block.minX,
                               y: coordRect.maxY + gap,
                               width: side,
                               height: colorHeight)
        drawLoupeColorBox(context,
                          in: colorRect,
                          image: image,
                          pixelPoint: pixelPoint)
    }

    /// Pixel grid: a faint line between every pair of sampled
    /// pixels, so each cell reads as the single screen pixel it magnifies.
    private func drawLoupeGrid(_ context: CGContext, frame: CGRect, source: CGRect) {
        let columns = Int(source.width)
        let rows = Int(source.height)
        guard columns > 1, rows > 1 else { return }
        context.saveGState()
        context.setStrokeColor(CGColor(gray: 0, alpha: 0.28))
        context.setLineWidth(1)
        for column in 1..<columns {
            let x = frame.minX + CGFloat(column) * frame.width / CGFloat(columns)
            context.move(to: CGPoint(x: x, y: frame.minY))
            context.addLine(to: CGPoint(x: x, y: frame.maxY))
        }
        for row in 1..<rows {
            let y = frame.minY + CGFloat(row) * frame.height / CGFloat(rows)
            context.move(to: CGPoint(x: frame.minX, y: y))
            context.addLine(to: CGPoint(x: frame.maxX, y: y))
        }
        context.strokePath()
        context.restoreGState()
    }

    private func loupePixelColor(in image: CGImage,
                                 at pixelPoint: CGPoint) -> (color: NSColor?, point: CGPoint) {
        let x = min(max(Int(pixelPoint.x.rounded(.down)), 0), image.width - 1)
        let y = min(max(Int(pixelPoint.y.rounded(.down)), 0), image.height - 1)
        let point = CGPoint(x: x, y: y)
        return (QuickToolsSupport.sampledColor(in: image, x: x, y: y), point)
    }

    private func drawLoupeCoordinateBox(_ context: CGContext, in rect: CGRect, at point: CGPoint) {
        let path = CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil)
        context.saveGState()
        context.addPath(path)
        context.setFillColor(CGColor(gray: 0.08, alpha: 0.90))
        context.fillPath()
        context.addPath(path)
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.14))
        context.setLineWidth(1)
        context.strokePath()
        context.restoreGState()

        let text = "X: \(Int(point.x))   Y: \(Int(point.y))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let textSize = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: rect.midX - textSize.width / 2,
                              y: rect.midY - textSize.height / 2),
                  withAttributes: attributes)
    }

    private func drawLoupeColorBox(_ context: CGContext,
                                   in rect: CGRect,
                                   image: CGImage,
                                   pixelPoint: CGPoint) {
        let path = CGPath(roundedRect: rect, cornerWidth: 7, cornerHeight: 7, transform: nil)
        context.saveGState()
        context.addPath(path)
        context.setFillColor(CGColor(gray: 0.08, alpha: 0.90))
        context.fillPath()
        context.addPath(path)
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.14))
        context.setLineWidth(1)
        context.strokePath()
        context.restoreGState()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]

        if let copiedValue {
            let text = "✓ \(copiedValue)"
            let size = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: rect.midX - size.width / 2,
                                  y: rect.midY - size.height / 2),
                      withAttributes: attributes)
            return
        }

        let sample = loupePixelColor(in: image, at: pixelPoint)
        var swatch: NSColor?
        var value = ""
        if let color = sample.color,
           let srgb = color.usingColorSpace(.sRGB) {
            swatch = srgb
            value = ColorSamplerService.shared.formattedValue(color) ?? ""
        }

        let valueSize = value.size(withAttributes: attributes)
        let swatchSide: CGFloat = swatch == nil ? 0 : 12
        let swatchGap: CGFloat = 6
        let tabText = "tab"
        let tabAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: NSColor(white: 0.9, alpha: 0.95),
        ]
        let tabTextSize = tabText.size(withAttributes: tabAttributes)
        let tabBadgeWidth = tabTextSize.width + 6
        let tabBadgeHeight: CGFloat = 13
        let gapToTab: CGFloat = 8

        let contentWidth = swatchSide + swatchGap + valueSize.width + gapToTab + tabBadgeWidth
        var cursor = rect.midX - contentWidth / 2

        if let swatch {
            let swatchRect = CGRect(x: cursor,
                                    y: rect.midY - swatchSide / 2,
                                    width: swatchSide,
                                    height: swatchSide)
            context.saveGState()
            context.setFillColor(swatch.cgColor)
            context.fill(swatchRect)
            context.setStrokeColor(CGColor(gray: 1, alpha: 0.85))
            context.setLineWidth(1)
            context.stroke(swatchRect)
            context.restoreGState()
            cursor += swatchSide + swatchGap
        }

        value.draw(at: CGPoint(x: cursor, y: rect.midY - valueSize.height / 2),
                   withAttributes: attributes)
        cursor += valueSize.width + gapToTab

        let tabBadgeRect = CGRect(x: cursor,
                                  y: rect.midY - tabBadgeHeight / 2,
                                  width: tabBadgeWidth,
                                  height: tabBadgeHeight)
        let tabPath = CGPath(roundedRect: tabBadgeRect, cornerWidth: 3, cornerHeight: 3, transform: nil)
        context.saveGState()
        context.addPath(tabPath)
        context.setFillColor(CGColor(gray: 1, alpha: 0.16))
        context.fillPath()
        context.restoreGState()

        tabText.draw(at: CGPoint(x: tabBadgeRect.midX - tabTextSize.width / 2,
                                 y: tabBadgeRect.midY - tabTextSize.height / 2),
                     withAttributes: tabAttributes)
    }

    private func captureLoupeFrame(near point: CGPoint, size: CGSize) -> CGRect {
        let gap: CGFloat = 16
        let inset: CGFloat = 8
        var origin = CGPoint(x: point.x + gap,
                             y: point.y - size.height - gap)
        if origin.x + size.width > bounds.maxX - inset {
            origin.x = point.x - size.width - gap
        }
        if origin.y < bounds.minY + inset {
            origin.y = point.y + gap
        }
        origin.x = min(max(origin.x, bounds.minX + inset),
                       bounds.maxX - size.width - inset)
        origin.y = min(max(origin.y, bounds.minY + inset),
                       bounds.maxY - size.height - inset)
        return CGRect(origin: origin, size: size)
    }

    // MARK: Text chrome

    private func drawBadge(_ text: String, near point: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let size = text.size(withAttributes: attributes)
        var rect = CGRect(x: point.x - size.width / 2 - 7,
                          y: point.y - 3,
                          width: size.width + 14,
                          height: size.height + 6)
        rect.origin.x = max(6, min(rect.origin.x, bounds.maxX - rect.width - 6))
        rect.origin.y = max(6, min(rect.origin.y, bounds.maxY - rect.height - 6))
        let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
        NSColor(white: 0, alpha: 0.72).setFill()
        path.fill()
        text.draw(at: CGPoint(x: rect.minX + 7, y: rect.minY + 3), withAttributes: attributes)
    }

}

private final class FullScreenControlHoverRelay {
    var changed: ((Bool) -> Void)?
    func update(_ hovered: Bool) { changed?(hovered) }
}

private final class PassThroughHostingView<Content: View>: NSHostingView<Content> {
    var passesThrough = true
    var acceptsFirstClick = false
    var isHovered = false
    /// Capture actions remain clickable while the Dynamic Island panel owns
    /// key focus. Keep that policy attached to the interactive host itself so
    /// a caller cannot accidentally forget one half of the setup.
    convenience init(interactiveRootView rootView: Content) {
        self.init(rootView: rootView)
        passesThrough = false
        acceptsFirstClick = true
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        acceptsFirstClick || super.acceptsFirstMouse(for: event)
    }
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !passesThrough else { return nil }
        if !isHovered {
            return nil
        }
        return super.hitTest(point)
    }
    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .crosshair)
    }
    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }
}

private struct FullScreenCaptureButton: View {
    let action: () -> Void
    let hoverChanged: (Bool) -> Void
    @ObservedObject private var l10n = L10n.shared
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(FeatureStrings.screenshot(l10n.language).fullScreenCaptureButton,
                  systemImage: "rectangle.inset.filled")
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 14)
                .frame(minHeight: 32)
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .foregroundStyle(.primary)
        .background(CaptureChromeBackdrop(
            material: .regularMaterial,
            shape: Capsule(style: .continuous)))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(isHovered ? 0.34 : 0.12),
                              lineWidth: isHovered ? 1.5 : 1)
        }
        .scaleEffect(isHovered ? 1.02 : 1)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover {
            isHovered = $0
            hoverChanged($0)
        }
        .shadow(color: .black.opacity(0.20), radius: 12, y: 5)
        .help(FeatureStrings.screenshot(l10n.language).fullScreenShortcutTitle)
        .accessibilityLabel(FeatureStrings.screenshot(l10n.language).fullScreenCaptureButton)
    }
}

/// The backing plate the capture chrome draws behind its text.
///
/// The shared `HUDBackdrop` cannot serve here: its material blends with what
/// sits behind the window, and this chrome lives inside the overlay window,
/// which is opaque while it shows the frozen still. Blending there would read
/// the live desktop instead of the still the person is aiming at. The plate is
/// the part that fixes contrast anyway, so keep the material these panels
/// already draw and add only the plate over it.
private struct CaptureChromeBackdrop<S: Shape>: View {
    let material: Material
    let shape: S

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Reduced transparency already gives an opaque material, so the plate
    /// steps aside; otherwise it carries the same calibration the shared
    /// backdrop documents.
    private var plateOpacity: Double {
        guard !reduceTransparency else { return 0 }
        return HUDBackdrop.plateOpacity(dark: colorScheme == .dark)
    }

    var body: some View {
        shape.fill(material)
            .overlay(shape.fill(colorScheme == .dark ? Color.black : Color.white)
                        .opacity(plateOpacity))
    }
}

final class CaptureGuideViewModel: ObservableObject {
    @Published var offersScrollingCapture = false
    @Published var offersRepeatLastRegion = false
    @Published var requiresDraggedRegion = false
    @Published var scrollingCaptureEnabled = false
    @Published var loupeEnabled = false
    @Published var selectedWindowsCount = 0
    var onHoverChanged: ((Bool) -> Void)?
    @Published var isHovered = false {
        didSet {
            if oldValue != isHovered {
                onHoverChanged?(isHovered)
            }
        }
    }
}

private struct CaptureGuideView: View {
    let strings: ScreenshotFeatureStrings
    let purpose: String?
    @ObservedObject var model: CaptureGuideViewModel
    let screenCaptureOptions: ScreenCaptureSelectionOptions?
    let onFullScreen: () -> Void
    let onToggleScrolling: () -> Void
    let onToggleLoupe: () -> Void
    let onRepeatLastRegion: () -> Void
    let onToggleMode: () -> Void
    let onCancel: () -> Void

    var body: some View {
        if let screenCaptureOptions {
            UnifiedCaptureGuideContent(strings: strings,
                                       options: screenCaptureOptions,
                                       model: model,
                                       onFullScreen: onFullScreen,
                                       onToggleScrolling: onToggleScrolling,
                                       onToggleLoupe: onToggleLoupe,
                                       onRepeatLastRegion: onRepeatLastRegion,
                                       onToggleMode: onToggleMode,
                                       onCancel: onCancel)
                .allowsHitTesting(true)
        } else {
            standardGuide
        }
    }

    private var standardGuide: some View {
        HStack(spacing: 8) {
            Button(action: onCancel) {
                HStack(spacing: 5) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("esc")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(CaptureChromeBackdrop(
                    material: .regularMaterial,
                    shape: RoundedRectangle(cornerRadius: 14, style: .continuous)))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.18), radius: 12, y: 5)
            }
            .buttonStyle(.plain)
            .focusable(false)

            HStack(spacing: 7) {
                Text(subtitle)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                CaptureKeyHint(key: "X",
                               icon: "rectangle.dashed",
                               isEnabled: model.offersRepeatLastRegion,
                               action: model.offersRepeatLastRegion ? onRepeatLastRegion : nil)
                CaptureKeyHint(key: "F", icon: "rectangle.inset.filled", action: onFullScreen)
                if model.offersScrollingCapture {
                    CaptureKeyHint(key: "S",
                                   icon: "rectangle.stack",
                                   isActive: model.scrollingCaptureEnabled,
                                   action: onToggleScrolling)
                }
                CaptureKeyHint(key: "Z",
                               icon: "plus.magnifyingglass",
                               isActive: model.loupeEnabled,
                               action: onToggleLoupe)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(CaptureChromeBackdrop(material: .ultraThinMaterial,
                                              shape: Capsule(style: .continuous)))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
            .contentShape(Capsule(style: .continuous))
            .onTapGesture {}
        }
        .onHover { hovering in
            model.isHovered = hovering
        }
        .allowsHitTesting(true)
    }

    private var title: String {
        guard let purpose, !purpose.isEmpty else { return strings.hintDrag }
        return purpose
    }

    private var subtitle: String {
        if model.selectedWindowsCount > 0 {
            return CaptureWorkflowStrings.localized(L10n.shared.language).selectedWindows(model.selectedWindowsCount)
        }
        return strings.hintDrag + "  ·  " + strings.hintClick
    }
}

private struct UnifiedCaptureGuideContent: View {
    let strings: ScreenshotFeatureStrings
    @ObservedObject var options: ScreenCaptureSelectionOptions
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject var model: CaptureGuideViewModel
    let onFullScreen: () -> Void
    let onToggleScrolling: () -> Void
    let onToggleLoupe: () -> Void
    let onRepeatLastRegion: () -> Void
    let onToggleMode: () -> Void
    let onCancel: () -> Void

    @State private var isTopHovered = false
    @State private var isEscapeHovered = false
    @State private var isGuideHovered = false
    @State private var isModeHovered = false

    private func updateHover() {
        model.isHovered = isTopHovered || isEscapeHovered || isGuideHovered || isModeHovered
    }

    private var isMultiWindowMode: Bool { model.selectedWindowsCount > 0 }

    var body: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            topControlBar
                .onHover { hovering in
                    isTopHovered = hovering
                    updateHover()
                }
            HStack(spacing: 8) {
                escapeHint
                    .onHover { hovering in
                        isEscapeHovered = hovering
                        updateHover()
                    }
                contextualGuide
                    .onHover { hovering in
                        isGuideHovered = hovering
                        updateHover()
                    }
                modeSwitchHint
                    .onHover { hovering in
                        isModeHovered = hovering
                        updateHover()
                    }
            }
        }
    }

    @ViewBuilder
    private var topControlBar: some View {
        if options.selectedTool == .recording {
            RecorderSelectionAudioControls(options: options.recorderAudio)
                .opacity(options.selectedTool == .recording ? 1 : 0)
                .allowsHitTesting(options.selectedTool == .recording)
                .accessibilityHidden(options.selectedTool != .recording)
        } else if model.offersScrollingCapture && options.selectedTool == .screenshot {
            scrollToggleBar
        }
    }

    private var scrollToggleBar: some View {
        let isEnabled = !isMultiWindowMode
        return Button(action: onToggleScrolling) {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 11, weight: .semibold))
                Text(CaptureWorkflowStrings.localized(l10n.language).scroll)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(
                !isEnabled
                    ? Color.secondary.opacity(0.4)
                    : (model.scrollingCaptureEnabled ? Color.white : Color.primary)
            )
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background(
                !isEnabled
                    ? Color.primary.opacity(0.02)
                    : (model.scrollingCaptureEnabled ? Color.accentColor : Color.primary.opacity(0.06)),
                in: Capsule(style: .continuous)
            )
            .overlay {
                if isEnabled && model.scrollingCaptureEnabled {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                }
            }
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(!isEnabled)
        .padding(3)
        .background(CaptureChromeBackdrop(material: .regularMaterial,
                                          shape: Capsule(style: .continuous)))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
    }

    private var contextualGuide: some View {
        let isEnabled = !isMultiWindowMode
        return HStack(spacing: 7) {
            subtitleView
            if options.selectedTool != .color {
                CaptureKeyHint(key: "X",
                               icon: "rectangle.dashed",
                               isEnabled: model.offersRepeatLastRegion && isEnabled,
                               action: model.offersRepeatLastRegion && isEnabled ? onRepeatLastRegion : nil)
                CaptureKeyHint(key: "F",
                               icon: "rectangle.inset.filled",
                               isEnabled: isEnabled,
                               action: isEnabled ? onFullScreen : nil)
                CaptureKeyHint(key: "Z",
                               icon: "plus.magnifyingglass",
                               isActive: model.loupeEnabled,
                               isEnabled: isEnabled,
                               action: isEnabled ? onToggleLoupe : nil)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(CaptureChromeBackdrop(material: .ultraThinMaterial,
                                          shape: Capsule(style: .continuous)))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
        .contentShape(Capsule(style: .continuous))
        .onTapGesture {
            // Absorb clicks on the bar text / background so it doesn't start a drag or hide the tab
        }
    }

    private var escapeHint: some View {
        Button(action: onCancel) {
            HStack(spacing: 5) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                Text("esc")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(CaptureChromeBackdrop(
                material: .regularMaterial,
                shape: RoundedRectangle(cornerRadius: 14, style: .continuous)))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    private var modeSwitchHint: some View {
        let isRecording = options.selectedTool == .recording
        let iconName = isRecording ? "camera.viewfinder" : "record.circle"
        let isEnabled = !isMultiWindowMode
        return Button(action: onToggleMode) {
            HStack(spacing: 5) {
                Image(systemName: iconName)
                    .font(.system(size: 11, weight: .semibold))
                Text("R")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isEnabled ? Color.secondary : Color.secondary.opacity(0.35))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(CaptureChromeBackdrop(
                material: .regularMaterial,
                shape: RoundedRectangle(cornerRadius: 14, style: .continuous)))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isEnabled ? 0.10 : 0.04), lineWidth: 1)
            }
            .shadow(color: .black.opacity(isEnabled ? 0.18 : 0.05), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(!isEnabled)
    }

    @ViewBuilder
    private var subtitleView: some View {
        switch options.selectedTool {
        case .screenshot:
            if model.selectedWindowsCount > 0 {
                Text(CaptureWorkflowStrings.localized(L10n.shared.language).selectedWindows(model.selectedWindowsCount))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } else {
                HStack(spacing: 4) {
                    Text(strings.hintDrag)
                        .foregroundColor(.secondary)
                    Text("·")
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(strings.hintClick)
                        .foregroundColor(model.scrollingCaptureEnabled ? .secondary.opacity(0.35) : .secondary)
                }
                .font(.system(size: 10.5, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }
        case .recording:
            let clickText = CaptureWorkflowStrings.localized(l10n.language).recordWindow
            HStack(spacing: 4) {
                Text(strings.hintDrag)
                    .foregroundColor(.secondary)
                Text("·")
                    .foregroundColor(.secondary.opacity(0.5))
                Text(clickText)
                    .foregroundColor(.secondary)
            }
            .font(.system(size: 10.5, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        case .text:
            Text(l10n.s.ocrCaption)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        case .color:
            Text(l10n.s.colorPickerCaption)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

private struct CaptureKeyHint: View {
    let key: String
    let icon: String
    var isActive: Bool = false
    var isEnabled: Bool = true
    var action: (() -> Void)? = nil
    @State private var isHovered = false

    var body: some View {
        let content = HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(
            !isEnabled
                ? Color.secondary.opacity(0.4)
                : (isActive ? Color.white : (isHovered && action != nil ? Color.primary : Color.secondary))
        )
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(
            !isEnabled
                ? Color.primary.opacity(0.02)
                : (isActive
                    ? Color.accentColor
                    : Color.primary.opacity(isHovered && action != nil ? 0.12 : 0.06)),
            in: Capsule(style: .continuous)
        )
        .overlay {
            if isEnabled && isActive {
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
            }
        }

        if isEnabled, let action {
            Button(action: action) {
                content
            }
            .buttonStyle(.plain)
            .focusable(false)
            .onHover { isHovered = $0 }
        } else {
            content
        }
    }
}

private struct RecorderSelectionAudioControls: View {
    @ObservedObject var options: RecorderSelectionAudioOptions
    @ObservedObject private var l10n = L10n.shared

    private var strings: RecorderFeatureStrings { FeatureStrings.recorder(l10n.language) }

    var body: some View {
        HStack(spacing: 6) {
            Button {
                options.systemAudio.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(strings.systemAudioTrackLabel)
                        .font(.system(size: 10.5, weight: .medium))
                }
                .foregroundStyle(options.systemAudio ? Color.white : Color.secondary)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(
                    options.systemAudio
                        ? Color.accentColor
                        : Color.primary.opacity(0.06),
                    in: Capsule(style: .continuous)
                )
                .overlay {
                    if options.systemAudio {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                    }
                }
            }
            .buttonStyle(.plain)
            .focusable(false)

            Button {
                options.microphone.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(strings.microphoneTrackLabel)
                        .font(.system(size: 10.5, weight: .medium))
                }
                .foregroundStyle(options.microphone ? Color.white : Color.secondary)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(
                    options.microphone
                        ? Color.accentColor
                        : Color.primary.opacity(0.06),
                    in: Capsule(style: .continuous)
                )
                .overlay {
                    if options.microphone {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                    }
                }
            }
            .buttonStyle(.plain)
            .focusable(false)
            .contextMenu { RecorderInputSourceMenu(camera: false) }

            RecorderOverlayInputControls()
        }
        .padding(3)
        .background(CaptureChromeBackdrop(material: .regularMaterial,
                                          shape: Capsule(style: .continuous)))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
    }
}
