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
    private var dialogFrames: [CGWindowID: (source: CGRect, visible: CGRect)] = [:]

    struct Capture {
        let id: UUID
        let image: CGImage
        /// Pixels per point of the source display, for 1x export math.
        let scale: CGFloat
        /// The captured area in Cocoa global coordinates.
        let anchorRect: CGRect
        let annotations: [ScreenshotSupport.Annotation]
        /// The saved edit generation, without flattening the editable original.
        let renderedImage: CGImage?

        init(id: UUID = UUID(), image: CGImage, scale: CGFloat, anchorRect: CGRect = .zero, annotations: [ScreenshotSupport.Annotation] = [], renderedImage: CGImage? = nil) {
            self.id = id
            self.image = image
            self.scale = scale
            self.anchorRect = anchorRect
            self.annotations = annotations
            self.renderedImage = renderedImage
        }

        var presentationCapture: Capture {
            Capture(id: id, image: renderedImage ?? image, scale: scale, anchorRect: anchorRect)
        }
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
    private var captureFocus: ScreenshotCaptureFocusSession?
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
    private lazy var multiWindowShiftMonitor = ScreenshotMultiWindowShiftMonitor(
        canConfirm: { [weak self] in
            guard let self else { return false }
            return self.acceptsCaptureInput && !self.panels.contains { $0.overlayView.isDragging }
        }, released: { [weak self] in self?.confirmSelectedWindows() })
    private var globalKeyMonitor: Any?
    private var completion: ((Outcome) -> Void)?
    private var freeze: Bool
    private var includePointer: Bool
    private let showLastRegion: Bool
    private var excludingAppWindows: Bool
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
        selectionInProgress = active
        panels.forEach {
            $0.overlayView.refreshGuideVisibility()
            $0.overlayView.refreshFullScreenControlVisibility()
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
         excludingAppWindows: Bool = false,
         protectedWindowIDs: @escaping () -> Set<CGWindowID> = { [] },
         purpose: String? = nil,
         mode: Mode = .image,
         supportsScrollingCapture: Bool = false,
         requiresDraggedRegion: Bool = false,
         screenCaptureOptions: ScreenCaptureSelectionOptions? = nil) {
        self.freeze = freeze
        self.includePointer = includePointer
        self.showLastRegion = showLastRegion
        self.excludingAppWindows = excludingAppWindows
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
            keepsContentWindowsOut: screenCaptureOptions?.selectedTool == .recording,
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
        captureFocus = ScreenshotCaptureFocusSession()
        if AppFeature.screenOCR.isAvailable { VisionTextRecognition.prepare() }
        Self.isSessionOnScreen = true
        Self.activeSession = self
        self.completion = completion
        screenCaptureOptions?.onSelectionChange = { [weak self] in
            self?.screenCaptureToolDidChange()
        }
        if freeze {
            Task { @MainActor [weak self] in
                guard let self else { return }
                let images = await ScreenshotCaptureEngine.captureAllDisplays(
                    includePointer: self.includePointer,
                    excludingAppWindows: self.excludingAppWindows,
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
            excludingAppWindows: excludingAppWindows,
            protectedWindowIDs: captureExcludedWindowIDs)
        let generation = sourceGeneration
        Task { @MainActor [weak self] in
            let refined = await ScreenshotSystemDialogCapture.refine(pickable)
            guard let self, !self.finished, self.sourceGeneration == generation else { return }
            self.dialogFrames = Dictionary(uniqueKeysWithValues: zip(pickable, refined).compactMap { source, visible in
                source.bounds == visible.bounds ? nil : (source.id, (source: source.bounds, visible: visible.bounds))
            })
            self.presentPanels(frozenImages: frozenImages, pickable: refined)
        }
    }

    private func presentPanels(frozenImages: [CGDirectDisplayID: CGImage],
                               pickable: [(id: CGWindowID, bounds: CGRect)]) {
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
        guard !finished else { return }
        panels.forEach {
            $0.orderFrontRegardless()
            $0.displayIfNeeded()
        }
        CATransaction.flush()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            guard let self, !self.finished else { return }
            if let keyPanel = self.keyPanelUnderMouse() ?? self.panels.first {
                self.captureFocus?.acquire(keyPanel)
            }
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
                screenshotIncludePointer: defaults.bool(forKey: DefaultsKey.screenshotIncludePointer))
            if !nextPolicy.sharesSource(with: capturePolicy) {
                adoptCapturePolicy(nextPolicy)
            }
        }
        selectedWindows.removeAll()
        multiWindowShiftMonitor.stop()
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
            excludingAppWindows: excludingAppWindows,
            protectedWindowIDs: captureExcludedWindowIDs).map { window in
                guard let cached = dialogFrames[window.id], cached.source == window.bounds else { return window }
                return (id: window.id, bounds: cached.visible)
            }
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
        let hideWindows = excludingAppWindows
        let excludedIDs = captureExcludedWindowIDs
        Task { @MainActor [weak self] in
            let images = await ScreenshotCaptureEngine.captureAllDisplays(
                includePointer: false,
                excludingAppWindows: hideWindows,
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
            guard event.window is ScreenshotOverlayPanel || event.window === self.waitingControls?.panel else { return event }
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
        if hasSelectedWindows { multiWindowShiftMonitor.start() }
        else { multiWindowShiftMonitor.stop() }
        panels.forEach {
            $0.overlayView.refreshCaptureGuide()
            $0.overlayView.needsDisplay = true
        }
    }

    fileprivate func clearSelectedWindows() {
        selectedWindows.removeAll()
        multiWindowShiftMonitor.stop()
        panels.forEach {
            $0.overlayView.refreshCaptureGuide()
            $0.overlayView.needsDisplay = true
        }
    }

    fileprivate func confirmSelectedWindows() {
        guard acceptsCaptureInput, !selectedWindows.isEmpty else { return }
        multiWindowShiftMonitor.stop()
        let windowEntries = Array(selectedWindows.values)
        guard let firstPanel = windowEntries.first?.panel else { return }
        markCapturePending()

        let windowIDs = windowEntries.map(\.window.windowID)
        let scale = firstPanel.pixelScale
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        let entriesByID = Dictionary(uniqueKeysWithValues: windowEntries.map { ($0.window.windowID, $0) })
        let frames = Dictionary(uniqueKeysWithValues: windowEntries.map { entry in
            let cocoa = ScreenshotSupport.cocoaRect(fromFlippedView: entry.window.frame,
                                                    screenFrame: entry.panel.screenFrame)
            return (entry.window.windowID, CGRect(x: cocoa.minX, y: mainHeight - cocoa.maxY,
                                                 width: cocoa.width, height: cocoa.height))
        })

        let unionBounds = frames.values.reduce(CGRect.null) { $0.union($1) }

        Task { @MainActor [weak self] in
            guard let self else { return }
            let capture = await ScreenshotCaptureEngine.captureMultipleWindows(
                windowIDs, scale: scale, frames: frames, resolveCapture: { id, independent in
                    guard let entry = entriesByID[id] else { return nil }
                    let panel = entry.panel
                    let canCrop = ScreenshotSupport.canUseFrozenWindowCapture(windowID: id,
                        frame: entry.window.frame, viewSize: panel.screenFrame.size,
                        windows: panel.overlayView.windows)
                    let visibleDialog = ScreenshotSystemDialogCapture.normalize(independent, windowID: id)
                    return ScreenshotSupport.resolvedWindowCapture(visibleDialog,
                        frozenImage: canCrop ? panel.frozenImage : nil, viewFrame: entry.window.frame,
                        viewSize: panel.screenFrame.size, fallbackScale: panel.pixelScale)
                })
            guard let finalCapture = capture else {
                self.finish(.failed)
                return
            }
            self.finish(.captured(Capture(
                image: finalCapture.image,
                scale: finalCapture.scale,
                anchorRect: ScreenshotSupport.cocoaRect(fromWindowServer: unionBounds,
                                                       mainScreenHeight: mainHeight))))
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
        panel.makeKey()
        let region = region(fromView: rect, on: panel, windowID: windowID)
        RecorderOverlayController.shared.prepareRecording(anchorRect: region.anchorRect,
            pixelSize: region.pixelSize, immediate: false)
        waitingControls = RecorderWaitingControls(audio: options.recorderAudio,
            start: { [weak self] in self?.startWaitingRecording() },
            cancel: { [weak self] in self?.finish(.cancelled) })
        waitingControls?.show(in: region.anchorRect, screen: panel.screenFrame)
        setSelectionInProgress(false)
        refreshCursorState()
        return true
    }

    private func resetWaitingRecording() {
        waitingControls?.hide()
        waitingControls = nil
        waitingRecordingPanel = nil
        waitingRecordingWindowID = nil
        refreshCursorState()
    }

    fileprivate func refreshCursorState() {
        panels.forEach { panel in
            panel.invalidateCursorRects(for: panel.overlayView)
            panel.resetCursorRects()
        }
        if let keyPanel = keyPanelUnderMouse() ?? panels.first {
            keyPanel.overlayView.activeCursor.set()
        }
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
            let independent = await ScreenshotCaptureEngine.captureWindow(
                windowID, scale: panel.pixelScale)
            let visibleDialog = ScreenshotSystemDialogCapture.normalize(independent, windowID: windowID)
            let canCrop = ScreenshotSupport.canUseFrozenWindowCapture(windowID: windowID,
                frame: frame, viewSize: panel.screenFrame.size, windows: panel.overlayView.windows)
            let capture = ScreenshotSupport.resolvedWindowCapture(visibleDialog,
                frozenImage: canCrop ? panel.frozenImage : nil, viewFrame: frame,
                viewSize: panel.screenFrame.size, fallbackScale: panel.pixelScale)

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
        retirePanels()
        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard var image = await ScreenshotCaptureEngine.captureDisplay(
                displayID,
                includePointer: self.includePointer,
                excludingAppWindows: self.excludingAppWindows,
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

    /// A panel takes every press until its window is really gone, and AppKit
    /// fades it out after `orderOut`, so a quick click or the first scroll
    /// after a capture landed on the leaving panel. A session never shows its
    /// panels again, so they let go of the mouse first. Set alone, the flag
    /// reaches the window server only with the next commit, too late for a
    /// panel already fading, so the flush sends it before the panels leave.
    private func retirePanels() {
        panels.forEach { $0.ignoresMouseEvents = true }
        CATransaction.flush()
        panels.forEach { $0.orderOut(nil) }
    }

    deinit {
        captureFocus?.release(completion: {})
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
        multiWindowShiftMonitor.stop()
        screenCaptureOptions?.onSelectionChange = nil
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }
        // Keep panels visible during focus handoff, but let pointer events
        // through immediately rather than blocking the returning application.
        markCapturePending()
        panels.forEach { $0.ignoresMouseEvents = true }
        CATransaction.flush()
        let complete = { [self] in
            retirePanels()
            completeFinish(outcome)
        }
        if let captureFocus { captureFocus.release(completion: complete) } else { complete() }
    }

    private func completeFinish(_ outcome: Outcome) {
        captureFocus = nil
        Self.isSessionOnScreen = false
        if Self.activeSession === self { Self.activeSession = nil }
        panels.removeAll()
        if cursorPushed {
            NSCursor.pop()
            cursorPushed = false
        }
        NSCursor.arrow.set()
        let completion = completion
        self.completion = nil
        completion?(outcome)
    }
}

// MARK: - Panel

/// Full-screen borderless panel for one display.
private final class ScreenshotOverlayPanel: ScreenshotCapturePanel {
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
        super.init(screenRect: screen.frame)
        isReleasedWhenClosed = false
        isOpaque = frozenImage != nil
        backgroundColor = frozenImage != nil ? .black : .clear
        hasShadow = false
        level = CapturePresentationPolicy.overlayLevel
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = false
        animationBehavior = .none

        // The frozen still sits in its own view UNDER the chrome: a backing
        // layer configured before the view joins a window can lose its
        // contents, and the chrome's dim must paint over the image anyway.
        let container = ScreenshotOverlayContainerView(frame: CGRect(origin: .zero, size: screen.frame.size))
        container.wantsLayer = true
        let imageView = NSImageView(frame: container.bounds)
        imageView.wantsLayer = true
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
        view.wantsLayer = true
        view.autoresizingMask = [.width, .height]
        container.addSubview(view)
        overlayViewStorage = view
        contentView = container
    }

    /// New pixels for a tool that needs its own photograph, without the
    /// panel ever leaving the screen.
    func update(frozenImage: CGImage?, windows: [ScreenshotSupport.PickableWindow]) {
        self.frozenImage = frozenImage
        isOpaque = frozenImage != nil
        backgroundColor = frozenImage != nil ? .black : .clear
        backdropView.image = frozenImage.map { NSImage(cgImage: $0, size: screenFrame.size) }
        overlayView.update(frozenImage: frozenImage, windows: windows)
    }

    override func becomeKey() {
        super.becomeKey()
        overlayView.activeCursor.set()
    }

    /// Tool chrome lives in hosting views whose ideal size is a small bar.
    /// Accepting that size pulls this window in from every edge.
    override func setFrame(_ frameRect: NSRect, display displayFlag: Bool) {
        super.setFrame(Self.frameCoveringScreen(screenFrame, insteadOf: frameRect), display: displayFlag)
    }

    private static func frameCoveringScreen(_ screen: NSRect, insteadOf requested: NSRect) -> NSRect {
        guard !screen.isEmpty else { return requested }
        let drifted = abs(requested.width - screen.width) > 1
            || abs(requested.height - screen.height) > 1
            || abs(requested.minX - screen.minX) > 1
            || abs(requested.minY - screen.minY) > 1
        return drifted ? screen : requested
    }
}

private class ScreenshotOverlayContainerView: NSView {
    private var activeCursor: NSCursor {
        (window as? ScreenshotOverlayPanel)?.overlayView.activeCursor ?? .crosshair
    }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: activeCursor)
    }

    override func cursorUpdate(with event: NSEvent) {
        activeCursor.set()
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
    fileprivate var windows: [ScreenshotSupport.PickableWindow]
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
    private var fullScreenControlHovered = false

    private var dragOrigin: CGPoint? { didSet { refreshChromeContrast() } }
    private var lastDragPoint: CGPoint = .zero
    private var selection: CGRect = .zero { didSet { refreshChromeContrast() } }
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
        let host = PassThroughHostingView(fixedFrameRootView: CaptureGuideView(
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

    fileprivate var activeCursor: NSCursor {
        controller?.isWaitingForRecording == true ? .arrow : .crosshair
    }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: activeCursor)
    }

    override func cursorUpdate(with event: NSEvent) {
        activeCursor.set()
    }

    override func layout() {
        super.layout()
        let targetHeight: CGFloat = screenCaptureOptions != nil
            ? (screenCaptureOptions?.showsCaptureMenu == false ? 82 : 146)
            : 72
        guideHost.frame = ScreenshotCapturePanel.guideFrame(in: bounds, preferredHeight: targetHeight)
        let availableWidth = max(1, bounds.width - 32)
        let fullScreenFitting = fullScreenHost.fittingSize
        let fullScreenWidth = min(max(fullScreenFitting.width, 1), availableWidth)
        let fullScreenHeight = max(fullScreenFitting.height, 32)
        let topInset = ScreenshotSupport.fullScreenCaptureControlTopInset(
            screenChromeHeight: panel?.topChromeHeight ?? 0)
        fullScreenHost.frame = CGRect(x: bounds.midX - fullScreenWidth / 2,
                                      y: topInset,
                                      width: fullScreenWidth,
                                      height: fullScreenHeight)
        refreshChromeContrast()
    }

    private func refreshChromeContrast() {
        if guideModel.isAreaDragging != isDragging { guideModel.isAreaDragging = isDragging }
        let guideOverlap = CapturePresentationPolicy.overlaps(chrome: guideHost.frame, selection: selection)
        if guideModel.overlapsSelection != guideOverlap { guideModel.overlapsSelection = guideOverlap }
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
        activeCursor.set()
        pointerHasMoved = true
        controller?.currentPointerLocation = nil
        updatePointerHover(convert(event.locationInWindow, from: nil))
        refreshFullScreenControlVisibility()
        needsDisplay = true
    }

    override func mouseEntered(with event: NSEvent) {
        activeCursor.set()
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
        activeCursor.set()
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
        activeCursor.set()
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
        guard let panel else {
            guideHost.isHidden = true
            return
        }
        let global = controller?.currentPointerLocation ?? NSEvent.mouseLocation
        let pointerOnDisplay = NSMouseInRect(global, panel.screenFrame, false)
        guideHost.isHidden = !pointerOnDisplay || isCapturePending
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
        // SwiftUI owns the pill's hover tracking, while AppKit owns the
        // window highlight. Re-evaluate the latter on the same transition.
        refreshPointerState()
    }

    private func resetFullScreenControlHover() {
        guard fullScreenControlHovered else { return }
        fullScreenControlHovered = false
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext,
              let controller,
              let panel
        else { return }
        let dimAlpha = ScreenshotSupport.selectionDimAlpha(isFrozen: frozenImage != nil, isDragging: isDragging)
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
                    drawWindowHighlight(context, rect: entry.window.frame, cornerRadius: windowRadius)
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
            // Screen recording selection:
            // 1. Selection border: 1pt white line with subtle shadow (no blue glow)
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -0.5), blur: 2.5, color: CGColor(gray: 0, alpha: 0.4))
            let borderPath = CGPath(rect: selection.insetBy(dx: -0.5, dy: -0.5), transform: nil)
            context.addPath(borderPath)
            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(1)
            context.strokePath()
            context.restoreGState()

            // 2. Tabs: 4 edge pills and 4 corner L-brackets
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -0.5), blur: 3, color: CGColor(gray: 0, alpha: 0.45))

            // Edge pills
            for handle in [ScreenshotSupport.Handle.top, .bottom, .left, .right] {
                let point = handle.position(in: selection)
                let rect: CGRect
                let radius: CGFloat = 2.5
                switch handle {
                case .top, .bottom:
                    rect = CGRect(x: point.x - 13, y: point.y - 2.5, width: 26, height: 5)
                case .left, .right:
                    rect = CGRect(x: point.x - 2.5, y: point.y - 13, width: 5, height: 26)
                default:
                    continue
                }
                let pillPath = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
                context.addPath(pillPath)
                context.setFillColor(NSColor.white.cgColor)
                context.fillPath()
                context.addPath(pillPath)
                context.setStrokeColor(CGColor(gray: 0.1, alpha: 0.2))
                context.setLineWidth(0.5)
                context.strokePath()
            }

            // Corner L-brackets
            let arm: CGFloat = 18.0
            let r: CGFloat = 3.0
            for handle in [ScreenshotSupport.Handle.topLeft, .topRight, .bottomLeft, .bottomRight] {
                let p = CGMutablePath()
                switch handle {
                case .topLeft:
                    p.move(to: CGPoint(x: selection.minX + arm, y: selection.minY))
                    p.addArc(tangent1End: CGPoint(x: selection.minX, y: selection.minY),
                             tangent2End: CGPoint(x: selection.minX, y: selection.minY + arm), radius: r)
                    p.addLine(to: CGPoint(x: selection.minX, y: selection.minY + arm))
                case .topRight:
                    p.move(to: CGPoint(x: selection.maxX - arm, y: selection.minY))
                    p.addArc(tangent1End: CGPoint(x: selection.maxX, y: selection.minY),
                             tangent2End: CGPoint(x: selection.maxX, y: selection.minY + arm), radius: r)
                    p.addLine(to: CGPoint(x: selection.maxX, y: selection.minY + arm))
                case .bottomLeft:
                    p.move(to: CGPoint(x: selection.minX + arm, y: selection.maxY))
                    p.addArc(tangent1End: CGPoint(x: selection.minX, y: selection.maxY),
                             tangent2End: CGPoint(x: selection.minX, y: selection.maxY - arm), radius: r)
                    p.addLine(to: CGPoint(x: selection.minX, y: selection.maxY - arm))
                case .bottomRight:
                    p.move(to: CGPoint(x: selection.maxX - arm, y: selection.maxY))
                    p.addArc(tangent1End: CGPoint(x: selection.maxX, y: selection.maxY),
                             tangent2End: CGPoint(x: selection.maxX, y: selection.maxY - arm), radius: r)
                    p.addLine(to: CGPoint(x: selection.maxX, y: selection.maxY - arm))
                default:
                    continue
                }
                context.addPath(p)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                context.setLineWidth(3.0)
                context.setStrokeColor(NSColor.white.cgColor)
                context.strokePath()
            }
            context.restoreGState()
        } else {
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
        }

        let width = Int(selection.width.rounded())
        let height = Int(selection.height.rounded())
        drawBadge("\(width) × \(height)",
                  near: CGPoint(x: selection.midX, y: selection.maxY + 10))
    }

    private func drawWindowHighlight(_ context: CGContext, rect: CGRect, cornerRadius: CGFloat = 10) {
        let path = CGPath(roundedRect: rect.insetBy(dx: 1.0, dy: 1.0),
                          cornerWidth: max(0, cornerRadius - 1),
                          cornerHeight: max(0, cornerRadius - 1),
                          transform: nil)
        context.addPath(path)
        context.setStrokeColor(CGColor(srgbRed: 0.35, green: 0.65, blue: 1.0, alpha: 0.90))
        context.setLineWidth(2.0)
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
