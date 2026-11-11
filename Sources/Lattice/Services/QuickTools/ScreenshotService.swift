// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ImageIO
import UniformTypeIdentifiers

/// The screenshot tool: freeze-first area, window and full screen capture
/// with an annotation editor, pinned floating captures and direct clipboard
/// or file output. Purely on demand and needs Screen Recording, requested
/// contextually on first use. The shared screen-capture service owns the
/// general shortcut and hands completed pictures back here.
final class ScreenshotService: ObservableObject {
    static let shared = ScreenshotService()

    @Published private(set) var fullScreenShortcutRegistrationFailed = false
    @Published private(set) var lastCaptureShortcutRegistrationFailed = false
    @Published private(set) var clipboardShortcutRegistrationFailed = false

    /// Used for associating the latest preview and Shelf task with its capture.
    private var latestCaptureToken = UUID()
    /// Real history identity survives changes to shortcut/retention settings.
    /// The token above identifies a preview/Shelf task, not the history UUID.
    private var latestCaptureHistoryID: UUID?

    private let lastCaptureHotkey = QuickToolHotkey(id: 22)
    private let fullScreenHotkey = QuickToolHotkey(id: 23)
    private let clipboardHotkey = QuickToolHotkey(id: 24)
    private var session: ScreenshotSelectionController?
    private var preview: ScreenshotQuickPreviewController?
    private var editors: [ScreenshotEditorController] = []
    /// Only editors launched from a capture/preview return to a fresh preview.
    private struct EditorReturnPreview {
        let capture: ScreenshotSelectionController.Capture
        let saved: SaveOutcome?
    }
    private var editorReturnPreviews: [ObjectIdentifier: EditorReturnPreview] = [:]
    private var directCaptureTask: Task<Void, Never>?
    private var autoCopyTask: Task<Void, Never>?
    private var autoCopyCaptureID: UUID?
    private var autoCopyGeneration = 0
    private var autoShelfTasks: [UUID: Task<Void, Never>] = [:]
    /// Only the latest capture still has a preview that can discard it.
    /// Older captures stay on the shelf without a growing item registry.
    private var autoShelvedItem: (capture: UUID, item: UUID)?
    private var scrollingTask: Task<Void, Never>?
    private var scrollingCaptureID: UUID?
    private var scrollingFinishSignal: ScreenshotScrollingCapture.FinishSignal?

    private enum CaptureMode {
        case standard
        case fullScreen
        case scrolling
    }


    /// The surfaces that make up the act of capturing. The quick preview is
    /// here rather than with the content windows because it dismisses itself
    /// after a few seconds: back-to-back captures would otherwise photograph
    /// the previous capture's toast.
    private var workflowWindowIDs: Set<CGWindowID> {
        var ids = session?.protectedWindowIDs ?? []
        if NotchSupport.isEnabled() { ids.formUnion(NotchService.shared.protectedWindowIDs) }
        ids.formUnion(preview?.protectedWindowIDs ?? [])
        ids.formUnion(ScreenCaptureService.shared.protectedWindowIDs)
        if let number = QuickToolHUD.currentWindowNumber, number > 0 {
            ids.insert(CGWindowID(number))
        }
        ids.formUnion(QuickToolHUD.scrollingWindowIDs)
        return ids
    }

    /// Ordinary windows somebody left on screen, which the "Hide Lattice
    /// windows" preference owns.
    private var contentWindowIDs: Set<CGWindowID> {
        var ids: Set<CGWindowID> = []
        for editor in editors {
            ids.formUnion(editor.protectedWindowIDs)
        }
        ids.formUnion(ScreenshotPinController.shared.protectedWindowIDs)
        ids.formUnion(ScreenshotQuickLookController.shared.protectedWindowIDs)
        return ids
    }

    private var protectedWindowIDs: Set<CGWindowID> {
        protectedWindowIDsForCapture(keepingContentOut: false)
    }

    func protectedWindowIDsForCapture(keepingContentOut: Bool) -> Set<CGWindowID> {
        ScreenshotCapturePolicy.protectedWindowIDs(
            workflowWindowIDs: workflowWindowIDs,
            contentWindowIDs: contentWindowIDs,
            keepingContentOut: keepingContentOut)
    }

    private var strings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(L10n.shared.language)
    }

    private init() {
        DispatchQueue.global(qos: .utility).async {
            ScreenshotSupport.removeTemporaryDragDirectories()
        }
        fullScreenHotkey.onPress = { [weak self] in self?.captureFullScreen() }
        lastCaptureHotkey.onPress = { [weak self] in self?.openLastCapture() }
        clipboardHotkey.onPress = { [weak self] in self?.openClipboardImage() }
    }

    func syncWithPreferences() {
        guard AppFeature.screenshot.isAvailable else {
            fullScreenShortcutRegistrationFailed = false
            lastCaptureShortcutRegistrationFailed = false
            clipboardShortcutRegistrationFailed = false
            fullScreenHotkey.unregister()
            lastCaptureHotkey.unregister()
            clipboardHotkey.unregister()
            ScreenshotLastCaptureStore.clear()
            teardownSurfaces()
            return
        }
        let defaults = UserDefaults.standard
        let fullScreenEnabled = defaults.bool(
            forKey: DefaultsKey.screenshotFullScreenShortcutEnabled)
        let fullScreenShortcut = GlobalShortcut.saved(
            for: DefaultsKey.screenshotFullScreenShortcut,
            fallback: .screenshotFullScreenDefault)
        fullScreenShortcutRegistrationFailed = !fullScreenHotkey.sync(
            enabled: fullScreenEnabled,
            shortcut: fullScreenShortcut,
            storageKey: DefaultsKey.screenshotFullScreenShortcut)
        let lastCaptureEnabled = defaults.bool(
            forKey: DefaultsKey.screenshotLastCaptureShortcutEnabled)
        let lastCaptureShortcut = GlobalShortcut.saved(
            for: DefaultsKey.screenshotLastCaptureShortcut,
            fallback: .screenshotLastCaptureDefault)
        lastCaptureShortcutRegistrationFailed = !lastCaptureHotkey.sync(
            enabled: lastCaptureEnabled,
            shortcut: lastCaptureShortcut,
            storageKey: DefaultsKey.screenshotLastCaptureShortcut)
        let clipboardEnabled = defaults.bool(
            forKey: DefaultsKey.screenshotClipboardShortcutEnabled)
        let clipboardShortcut = GlobalShortcut.saved(
            for: DefaultsKey.screenshotClipboardShortcut,
            fallback: .screenshotClipboardDefault)
        clipboardShortcutRegistrationFailed = !clipboardHotkey.sync(
            enabled: clipboardEnabled,
            shortcut: clipboardShortcut,
            storageKey: DefaultsKey.screenshotClipboardShortcut)
        syncLatestCapture(with: defaults)
    }

    /// Only Edit latest screenshot needs the persisted original capture.
    private func syncLatestCapture(with defaults: UserDefaults) {
        if !ScreenshotSharingSupport.retainsLatestCapture(in: defaults) {
            ScreenshotLastCaptureStore.clear()
        }
    }

    func suspend() {
        fullScreenHotkey.unregister()
        lastCaptureHotkey.unregister()
        clipboardHotkey.unregister()
    }

    /// Hub-off means gone: open editors, pins and a selection in progress
    /// all leave the screen.
    private func teardownSurfaces() {
        directCaptureTask?.cancel()
        directCaptureTask = nil
        autoCopyTask?.cancel()
        autoCopyTask = nil
        autoCopyGeneration += 1
        cancelAutoShelf()
        scrollingTask?.cancel()
        scrollingTask = nil
        scrollingCaptureID = nil
        scrollingFinishSignal = nil
        QuickToolHUD.dismissScrollingCapture()
        session?.cancel()
        session = nil
        preview?.close()
        preview = nil
        editorReturnPreviews.removeAll()
        for editor in editors {
            editor.close()
        }
        editors.removeAll()
        ScreenshotPinController.shared.closeAll()
    }

    // MARK: - Entry

    /// Starts a capture immediately; an active selection is left alone.
    func capture() {
        ScreenCaptureService.shared.capture(initial: .screenshot)
    }

    func captureScrolling() {
        startCapture(.scrolling)
    }

    func captureFullScreen() {
        startCapture(.fullScreen)
    }

    private func startCapture(_ mode: CaptureMode) {
        // Repeating the same action finishes a long capture at the current
        // point. It can never open a second selection or capture task.
        if scrollingTask != nil {
            QuickToolHUD.markScrollingCaptureFinishing()
            scrollingFinishSignal?.request()
            return
        }
        // Another feature may already own the capture surface (copying text
        // off the screen picks an area the same way).
        guard session == nil, directCaptureTask == nil,
              !ScreenshotSelectionController.isSessionOnScreen else { return }
        guard Permissions.shared.screenRecording else {
            Permissions.shared.requestScreenRecording()
            return
        }
        beginCapture(mode)
    }

    private func beginCapture(_ mode: CaptureMode) {
        if mode == .fullScreen {
            beginFullScreenCapture()
        } else {
            beginSelection(mode)
        }
    }

    private func beginSelection(_ mode: CaptureMode) {
        guard session == nil, !ScreenshotSelectionController.isSessionOnScreen else { return }
        preview?.close()
        preview = nil
        let defaults = UserDefaults.standard
        let controller = ScreenshotSelectionController(
            freeze: mode == .scrolling
                ? false
                : defaults.bool(forKey: DefaultsKey.screenshotFreeze),
            includePointer: defaults.bool(forKey: DefaultsKey.screenshotIncludePointer),
            showLastRegion: defaults.bool(forKey: DefaultsKey.screenshotShowLastRegion),
            protectedWindowIDs: { [weak self] in self?.protectedWindowIDs ?? [] },
            purpose: mode == .scrolling ? strings.scrollingCaptureTitle : nil,
            mode: mode == .scrolling ? .geometry : .image,
            supportsScrollingCapture: mode == .standard)
        session = controller
        controller.begin { [weak self] outcome in
            guard let self else { return }
            self.session = nil
            switch outcome {
            case .captured(let capture):
                self.route(capture)
            case .region(let region):
                guard mode == .scrolling else { break }
                self.captureScrolling(region)
            case .scrollingRegion(let region):
                self.captureScrolling(region)
            case .color:
                break
            case .cancelled:
                break
            case .failed:
                QuickToolHUD.show(icon: "camera.viewfinder", message: self.strings.captureFailed)
            }
        }
    }

    func receiveUnifiedCapture(_ capture: ScreenshotSelectionController.Capture) {
        route(capture)
    }

    func receiveUnifiedScrollingRegion(_ region: RecorderSupport.Region) {
        captureScrolling(region)
    }

    private func beginFullScreenCapture() {
        guard directCaptureTask == nil, !ScreenshotSelectionController.isSessionOnScreen else {
            return
        }
        preview?.close()
        preview = nil
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) })
                ?? NSScreen.main,
              screen.displayID != 0 else {
            QuickToolHUD.show(icon: "camera.viewfinder", message: strings.captureFailed)
            return
        }
        let displayID = screen.displayID
        let scale = screen.backingScaleFactor
        let frame = screen.frame
        let includePointer = UserDefaults.standard.bool(forKey: DefaultsKey.screenshotIncludePointer)

        let protectedIDs = protectedWindowIDs
        directCaptureTask = Task { @MainActor [weak self] in
            let image = await ScreenshotCaptureEngine.captureDisplay(
                displayID,
                includePointer: includePointer,
                protectedWindowIDs: protectedIDs)
            guard let self, !Task.isCancelled else { return }
            self.directCaptureTask = nil
            guard let image else {
                QuickToolHUD.show(icon: "camera.viewfinder", message: self.strings.captureFailed)
                return
            }
            self.route(ScreenshotSelectionController.Capture(
                image: image,
                scale: scale,
                anchorRect: frame))
        }
    }

    private func captureScrolling(_ region: RecorderSupport.Region) {
        guard scrollingTask == nil else { return }
        let initialImage = ScreenshotSelectionController.lastInitialCapture
        ScreenshotSelectionController.lastInitialCapture = nil
        let finishSignal = ScreenshotScrollingCapture.FinishSignal()
        scrollingFinishSignal = finishSignal
        QuickToolHUD.showScrollingCapture(
            region: region,
            initialImage: initialImage,
            message: strings.scrollingCaptureProgressHUD,
            finishTitle: strings.done,
            cancelTitle: strings.cancel,
            onFinish: { finishSignal.request() },
            onCancel: { [weak self] in self?.scrollingTask?.cancel() })
        // Read after the controls are on screen so their window is protected,
        // and once for the whole run: the picture must not change halfway.

        let protectedIDs = protectedWindowIDs
        let captureID = UUID()
        scrollingCaptureID = captureID
        scrollingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await ScreenshotScrollingCapture.capture(
                region: region,
                includePointer: false,
                protectedWindowIDs: protectedIDs,
                finishSignal: finishSignal,
                onProgress: { _ in },
                onFrame: { image, height in
                    QuickToolHUD.updateScrollingCapture(image: image, height: height)
                })
            guard self.scrollingCaptureID == captureID else { return }
            self.scrollingCaptureID = nil
            self.scrollingTask = nil
            self.scrollingFinishSignal = nil
            QuickToolHUD.dismissScrollingCapture()
            switch result {
            case .success(let capture):
                self.route(capture)
            case .partial(let capture):
                self.route(capture)
                QuickToolHUD.show(icon: "rectangle.stack",
                                  message: self.strings.scrollingCapturePartialHUD)
            case .limited(let capture):
                self.route(capture)
                QuickToolHUD.show(icon: "rectangle.stack",
                                  message: self.strings.scrollingCaptureTooLongHUD)
            case .cancelled:
                QuickToolHUD.show(icon: "xmark", message: L10n.shared.s.mediaCancelled)
            case .failed:
                QuickToolHUD.show(icon: "camera.viewfinder", message: self.strings.captureFailed)
            }
        }
    }

    // MARK: - Routing

    /// Where a direct save landed, and which "%#" number it consumed — so a
    /// later Trash can remove the file and, if applicable, give exactly that
    /// number back.
    struct SaveOutcome {
        let url: URL
    }

    /// Apply independent after-capture actions. A preview is unconditional
    /// unless the editor opens first; closing that editor opens a fresh preview.
    private func route(_ capture: ScreenshotSelectionController.Capture) {
        beginLatestCapture(capture)
        latestCaptureHistoryID = capture.id
        NotchService.shared.reactMascot(.flash, patience: 1)
        preview?.close()
        RecentCaptureService.shared.recordScreenshot(capture)
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: DefaultsKey.screenshotPlayShutterSound) {
            if let sound = NSSound(contentsOfFile: "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Screen Capture.aif", byReference: true) {
                sound.play()
            } else {
                NSSound(named: "Shutter")?.play()
            }
        }
        if defaults.bool(forKey: DefaultsKey.screenshotCopyToClipboard) {
            autoCopy(capture)
        }
        let saved = defaults.bool(forKey: DefaultsKey.screenshotSaveAutomatically)
            ? saveDirect(capture) : nil
        autoShelve(capture, saved: saved?.url)
        if defaults.bool(forKey: DefaultsKey.screenshotOpenEditorAfterCapture) {
            openEditor(with: capture, reopenPreviewOnClose: true, previewSaved: saved)
        } else {
            presentPreview(capture,
                           initialSaved: saved,
                           completedActions: saved == nil ? [] : [.save],
                           latestCapture: latestCaptureToken)
        }
    }

    /// Discard only affects the currently presented capture, not a history item.
    private func discardLatestCapture(_ latestCapture: UUID?) {
        guard let latestCapture, latestCapture == latestCaptureToken else { return }
        withholdLatestCapture()
    }

    /// A discarded preview cancels only its capture, including a copy still
    /// being prepared. Other captures keep their place on the shelf.
    private func unshelve(_ capture: UUID?) {
        guard let capture else { return }
        autoShelfTasks.removeValue(forKey: capture)?.cancel()
        if let shelved = autoShelvedItem, shelved.capture == capture {
            ShelfService.shared.removeItem(shelved.item)
            autoShelvedItem = nil
        }
    }

    /// Editing does not undo the independent Add to File Cache choice.
    /// The preview returns with a fresh close interval when the editor closes.
    private func editFromPreview(_ capture: ScreenshotSelectionController.Capture, saved: SaveOutcome?) {
        openEditor(with: capture, reopenPreviewOnClose: true, previewSaved: saved)
    }

    private func cancelAutoShelf() {
        for task in autoShelfTasks.values { task.cancel() }
        autoShelfTasks.removeAll()
    }

    private func withholdLatestCapture() {
        // A discarded or edited capture must not be reopened as an unedited original.
        ScreenshotLastCaptureStore.withhold()
    }

    /// Track the latest preview for discard/Shelf ownership and retain the raw
    /// screenshot only when Edit latest screenshot is enabled.
    private func beginLatestCapture(_ capture: ScreenshotSelectionController.Capture) {
        latestCaptureToken = UUID()
        if ScreenshotSharingSupport.retainsLatestCapture() {
            ScreenshotLastCaptureStore.save(capture)
        }
    }

    /// A history item reopens without repeating automatic copy or save
    /// actions, on the selected surface and with the shared close policy.
    func restorePreview(_ capture: ScreenshotSelectionController.Capture, inNotch: Bool? = nil) {
        preview?.close()
        presentPreview(capture,
                       initialSaved: nil,
                       completedActions: [],
                       latestCapture: nil,
                       openedFromHistory: true,
                       previewInNotch: inNotch)
    }

    private func presentPreview(_ capture: ScreenshotSelectionController.Capture,
                                initialSaved: SaveOutcome?,
                                completedActions: Set<ScreenshotQuickPreviewController.Action>,
                                latestCapture: UUID?,
                                openedFromHistory: Bool = false,
                                previewInNotch: Bool? = nil) {
        var saved = initialSaved
        let presented = capture.presentationCapture
        let controller = ScreenshotQuickPreviewController(
            capture: presented,
            strings: strings,
            completedActions: completedActions,
            action: { [weak self] action in
                guard let self else { return [] }
                switch action {
                case .edit:
                    self.editFromPreview(capture, saved: saved)
                    return [.edit]
                case .pin:
                    ScreenshotPinController.shared.pin(image: presented.image, scale: capture.scale,
                        baseImage: capture.image, annotations: capture.annotations, captureID: capture.id)
                    return [.pin]
                case .copy:
                    return self.copyDirect(presented) ? [.copy] : []
                case .save:
                    guard let outcome = self.saveDirect(presented) else { return [] }
                    saved = outcome
                    return [.save]
                case .saveAndCopy:
                    guard let result = self.saveAndCopyDirect(presented) else { return [] }
                    saved = result.outcome
                    return result.copied ? [.save, .copy] : [.save]
                case .discard:
                    // If this capture was already written to disk — whether
                    // by the default action or a manual Save — Trash should
                    // undo that rather than leave an orphaned file behind.
                    // Into the actual Trash: the person may be discarding a
                    // file the HUD just announced as saved.
                    if let saved {
                        do {
                            try FileManager.default.trashItem(at: saved.url, resultingItemURL: nil)
                        } catch {
                            NSSound.beep()
                            return []
                        }
                    }
                    self.unshelve(latestCapture)
                    self.discardLatestCapture(latestCapture)
                    return [.discard]
                }
            },
            deleteCapture: { [weak self] completion in
                guard let self else { completion(false); return }
                // Resolve the same screenshot's live Shelf token before an
                // asynchronous history deletion can race with another capture.
                // This also works when shortcut retention is switched off.
                let matchingToken = ScreenshotCaptureOwnership.shelfToken(
                    for: capture.id, latestHistoryID: self.latestCaptureHistoryID,
                    latestToken: self.latestCaptureToken, previewToken: latestCapture)
                self.cancelAutoCopy(for: capture.id)
                if ScreenshotLastCaptureStore.matches(capture.id)
                    || (self.latestCaptureHistoryID == capture.id
                        && matchingToken == self.latestCaptureToken) {
                    self.withholdLatestCapture()
                }
                // A failed Trash move must leave the stored capture and preview
                // available for retry; the sequence number is still occupied.
                if let export = saved {
                    do {
                        try FileManager.default.trashItem(at: export.url, resultingItemURL: nil)
                    } catch { completion(false); return }
                    saved = nil
                }
                RecentCaptureService.shared.deleteScreenshot(id: capture.id) { [weak self] removed in
                    if removed { self?.deletePreviewSideEffects(latestCapture: matchingToken) }
                    completion(removed)
                }
            },
            share: { [weak self] duration, completion in
                guard let self else {
                    Task { @MainActor in completion(nil) }
                    return
                }
                self.shareDirect(presented, duration: duration, completion: completion)
            },
            shareFile: { [weak self] in
                guard let self, let export = self.flatten(presented) else { return nil }
                return Self.temporaryExportFile(image: export.image, scale: export.scale,
                                                strings: self.strings)
            },
            savedFile: { saved?.url },
            saveToDefault: { [weak self] in
                guard let self, let outcome = self.saveDirect(presented) else { return nil }
                saved = outcome
                return outcome.url
            },
            openedFromHistory: openedFromHistory,
            onClose: { [weak self] in self?.preview = nil })
        preview = controller
        controller.show(inNotch: previewInNotch ?? CapturePresentationRouting.opensInIsland(origin: .external))
    }

    /// An after-capture clipboard task belongs to its history UUID, not a
    /// preview token or the optional Last Screenshot cache. Detached export
    /// work checks this generation before touching the clipboard.
    private func cancelAutoCopy(for captureID: UUID) {
        guard ScreenshotCaptureOwnership.ownsPendingCopy(
            historyID: captureID, activeCopyID: autoCopyCaptureID) else { return }
        autoCopyTask?.cancel()
        autoCopyTask = nil
        autoCopyCaptureID = nil
        autoCopyGeneration += 1
    }

    /// Preserve the previous discard side effects after the stored history
    /// copy was successfully deleted, without running the old discard path
    /// twice. User exports are moved to Trash rather than permanently erased.
    private func deletePreviewSideEffects(latestCapture: UUID?) {
        unshelve(latestCapture)
        // discardLatestCapture checks the identity before clearing the latest
        // pixels, so a newer screenshot cannot be invalidated by an old one.
        discardLatestCapture(latestCapture)
    }

    func showTransformedPreview(_ capture: ScreenshotSelectionController.Capture) {
        guard AppFeature.screenshot.isAvailable else { return }
        // A menu transform is a new draft, not permission to overwrite the
        // original file or repeat an automatic clipboard/save action.
        presentPreview(capture, initialSaved: nil,
            completedActions: [], latestCapture: nil)
    }

    func openEditor(with capture: ScreenshotSelectionController.Capture, above owner: NSWindow? = nil, originatingPin: ScreenshotPinWindow? = nil, reopenPreviewOnClose: Bool = false, previewSaved: SaveOutcome? = nil) {
        WindowActivationPolicy.retain()
        // Any editor may be showing the latest capture, and what it exports
        // is no longer the stored original, so the shortcut keeps that
        // original back until a newer capture arrives.
        withholdLatestCapture()
        let editor = ScreenshotEditorController(capture: capture)
        editor.originatingPin = originatingPin
        editors.append(editor)
        if reopenPreviewOnClose {
            editorReturnPreviews[ObjectIdentifier(editor)] = EditorReturnPreview(capture: capture, saved: previewSaved)
        }
        editor.show(above: owner)
    }

    private func openLastCapture() {
        guard let capture = ScreenshotLastCaptureStore.load() else {
            QuickToolHUD.show(icon: "camera.viewfinder", message: strings.lastCaptureMissing)
            return
        }
        preview?.close()
        preview = nil
        // Editing the latest capture takes its raw copy off the Shelf, as
        // Edit in its preview does.
        unshelve(latestCaptureToken)
        openEditor(with: capture)
    }

    private func openClipboardImage() {
        GeneralPasteboardAccess.shared.async { [weak self] in
            let capture = autoreleasepool {
                Self.clipboardCapture(from: NSPasteboard.general)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, AppFeature.screenshot.isAvailable else { return }
                guard let capture else {
                    QuickToolHUD.show(icon: "photo", message: self.strings.clipboardImageMissing)
                    return
                }
                self.openEditor(with: capture)
            }
        }
    }

    /// Opens a picture from the shelf, read off the main thread. A file that
    /// does not read as an image only beeps.
    func editImage(at url: URL) {
        guard AppFeature.screenshot.isAvailable else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let capture = autoreleasepool {
                NSImage(contentsOf: url).flatMap { Self.imageCapture(from: $0) }
            }
            DispatchQueue.main.async {
                guard AppFeature.screenshot.isAvailable else { return }
                guard let capture else {
                    NSSound.beep()
                    return
                }
                NotchService.shared.perform {
                    ScreenshotService.shared.openEditor(with: capture)
                }
            }
        }
    }

    private static func clipboardCapture(
        from pasteboard: NSPasteboard
    ) -> ScreenshotSelectionController.Capture? {
        guard let image = clipboardImage(from: pasteboard) else { return nil }
        return imageCapture(from: image)
    }

    static func imageCapture(from image: NSImage) -> ScreenshotSelectionController.Capture? {
        guard image.size.width > 0, image.size.height > 0
        else { return nil }
        var rect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil),
              cgImage.width > 0, cgImage.height > 0,
              cgImage.width <= ScreenshotSupport.scrollingCaptureMaximumPixels / cgImage.height
        else { return nil }
        let pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        let scale = ScreenshotSupport.clipboardImageScale(pixelSize: pixelSize,
                                                          pointSize: image.size)
        return ScreenshotSelectionController.Capture(image: cgImage,
                                                     scale: scale,
                                                     anchorRect: .zero)
    }

    /// Copying a file in Finder leaves both its URL and a small icon preview on
    /// the pasteboard, so the file on disk wins whenever it is a readable image.
    static func clipboardImage(from pasteboard: NSPasteboard) -> NSImage? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
            .urlReadingContentsConformToTypes: [UTType.image.identifier]
        ]
        if let url = (pasteboard.readObjects(forClasses: [NSURL.self],
                                             options: options) as? [NSURL])?.first as URL?,
           let image = NSImage(contentsOf: url),
           image.size.width > 0, image.size.height > 0 {
            return image
        }
        return NSImage(pasteboard: pasteboard)
    }

    func editorDidClose(_ editor: ScreenshotEditorController) {
        guard editors.contains(where: { $0 === editor }) else { return }
        editors.removeAll { $0 === editor }
        WindowActivationPolicy.release()
        guard let awaiting = editorReturnPreviews.removeValue(forKey: ObjectIdentifier(editor)),
              AppFeature.screenshot.isAvailable else { return }
        // A final exported image is the one the user just kept. If the user
        // discarded unexported edits, return to the unmodified capture.
        let capture: ScreenshotSelectionController.Capture
        if !editor.model.isDirty,
           let export = editor.model.exportImage(withBackdrop: true, downscaleTo1x: false) {
            // Rendered pixels belong only to display/export. Keep the base
            // image and vector annotations so Edit remains fully editable.
            capture = .init(id: awaiting.capture.id,
                            image: editor.model.baseImage, scale: editor.model.scale,
                            anchorRect: awaiting.capture.anchorRect,
                            annotations: editor.model.annotations,
                            renderedImage: export.image, capturedAt: awaiting.capture.capturedAt)
        } else {
            capture = awaiting.capture
        }
        // The editor may have saved a different file after automatic saving.
        // Trash and the Save state must refer to that final export, not to
        // an older pre-editor path (or nil).
        let finalSaved = editor.finalSavedURL.map { SaveOutcome(url: $0) } ?? awaiting.saved
        DispatchQueue.main.async { [weak self] in
            guard let self, self.preview == nil else { return }
            self.presentPreview(capture,
                                initialSaved: finalSaved,
                                completedActions: finalSaved == nil ? [] : [.save],
                                latestCapture: nil)
        }
    }

    /// Automatic copy stays quiet on success: the preview or the editor is
    /// already appearing and says the capture happened, so a HUD on top of it
    /// would only repeat that. A failure still beeps, since nothing else
    /// would reveal an empty clipboard before the paste.
    private func autoCopy(_ capture: ScreenshotSelectionController.Capture) {
        let downscale = UserDefaults.standard.bool(forKey: DefaultsKey.screenshotDownscale)
        guard let folder = ScreenshotSupport.copiedFilesDirectory() else {
            NSSound.beep()
            return
        }
        let name = ScreenshotSupport.fileName(prefix: strings.fileNamePrefix, date: Date())
        autoCopyTask?.cancel()
        autoCopyCaptureID = capture.id
        autoCopyGeneration += 1
        let generation = autoCopyGeneration
        let pasteboardChangeCount = NSPasteboard.general.changeCount
        autoCopyTask = Task { @MainActor [weak self] in
            defer {
                // An older task must not clear a newer capture's copy state.
                if let self, self.autoCopyGeneration == generation {
                    self.autoCopyTask = nil
                    self.autoCopyCaptureID = nil
                }
            }
            let output = await Task.detached(priority: .userInitiated) {
                guard let export = Self.flatten(capture, downscaleTo1x: downscale) else {
                    return nil as (URL, ScreenshotEditorController.ClipboardPayload)?
                }
                let payload = ScreenshotEditorController.clipboardPayload(from: export)
                guard let png = payload.png,
                      let url = try? ScreenshotSupport.copiedFile(
                        data: png, name: name, directory: folder) else { return nil }
                return (url, payload)
            }.value
            guard let output else {
                if !Task.isCancelled { NSSound.beep() }
                return
            }
            guard let self, !Task.isCancelled,
                  generation == self.autoCopyGeneration,
                  pasteboardChangeCount == NSPasteboard.general.changeCount,
                  AppFeature.screenshot.isAvailable
            else {
                try? FileManager.default.removeItem(at: output.0)
                return
            }
            guard ScreenshotEditorController.copyFile(output.0, payload: output.1)
            else {
                try? FileManager.default.removeItem(at: output.0)
                NSSound.beep()
                return
            }
            ScreenshotSupport.pruneCopiedFiles(in: folder, preserving: output.0)
        }
    }

    /// Runs `body` once an automatic copy still being prepared has reached
    /// the clipboard, or at once when none is. A preview's Copy text waits
    /// for it: the capture lands first, as the after-capture setting asks,
    /// and the text then replaces it, while a capture with no text stays.
    func afterAutoCopy(_ body: @escaping () -> Void) {
        guard let pending = autoCopyTask else {
            body()
            return
        }
        Task { @MainActor in
            await pending.value
            body()
        }
    }

    /// The shelf gets a copy of its own, not the file a Save wrote, which can
    /// later be deleted or moved to the Trash outside Lattice. A saved
    /// capture lends its bytes and name, so nothing is encoded twice. Any
    /// other is encoded off the main thread. Each capture owns its task so
    /// taking another capture cannot lose one still being prepared. Quiet on
    /// success like the automatic copy; a shelf that refuses it beeps.
    private func autoShelve(_ capture: ScreenshotSelectionController.Capture, saved: URL?) {
        autoShelvedItem = nil
        guard ScreenshotSupport.addsCapturesToShelf() else { return }
        let token = latestCaptureToken
        let downscale = UserDefaults.standard.bool(forKey: DefaultsKey.screenshotDownscale)
        let name = saved?.lastPathComponent
            ?? ScreenshotSupport.fileName(prefix: strings.fileNamePrefix, date: Date())
        autoShelfTasks[token] = Task { @MainActor [weak self] in
            let work = Task.detached(priority: .userInitiated) { () -> Data? in
                guard !Task.isCancelled else { return nil }
                if let saved { return try? Data(contentsOf: saved) }
                guard let export = Self.flatten(capture, downscaleTo1x: downscale),
                      !Task.isCancelled else { return nil }
                return ScreenshotRenderer.pngData(from: export.image, scale: export.scale)
            }
            let png = await withTaskCancellationHandler {
                await work.value
            } onCancel: {
                work.cancel()
            }
            guard let self else { return }
            self.autoShelfTasks[token] = nil
            guard !Task.isCancelled, AppFeature.screenshot.isAvailable,
                  ScreenshotSupport.addsCapturesToShelf() else { return }
            guard let png, let item = ShelfService.shared.shelveGeneratedFile(png, named: name) else {
                NSSound.beep()
                return
            }
            if self.latestCaptureToken == token {
                self.autoShelvedItem = (token, item)
            }
        }
    }

    private func shareDirect(_ capture: ScreenshotSelectionController.Capture,
                             duration: ScreenshotShareDuration,
                             completion: @escaping @MainActor (ScreenshotShareRecord?) -> Void) {
        let downscale = UserDefaults.standard.bool(forKey: DefaultsKey.screenshotDownscale)
        Task { @MainActor [weak self] in
            guard let self else {
                completion(nil)
                return
            }
            let data = await Task.detached(priority: .userInitiated) {
                guard let export = Self.flatten(capture, downscaleTo1x: downscale) else {
                    return nil as Data?
                }
                return ScreenshotRenderer.pngData(from: export.image, scale: export.scale)
            }.value
            guard let data else {
                QuickToolHUD.show(icon: "link", message: self.strings.shareFailedHUD)
                completion(nil)
                return
            }
            do {
                let record = try await ScreenshotShareService.shared.createLink(
                    pngData: data, duration: duration)
                completion(record)
            } catch {
                QuickToolHUD.show(icon: "link", message: self.strings.shareFailedHUD)
                NSSound.beep()
                completion(nil)
            }
        }
    }

    @discardableResult
    private func copyDirect(_ capture: ScreenshotSelectionController.Capture) -> Bool {
        guard let export = flatten(capture) else { return false }
        guard ScreenshotEditorController.copyImage(
            export, fileNamePrefix: strings.fileNamePrefix) else {
            NSSound.beep()
            return false
        }
        QuickToolHUD.show(icon: "camera.viewfinder", message: strings.copiedHUD)
        return true
    }

    private func saveDirect(_ capture: ScreenshotSelectionController.Capture) -> SaveOutcome? {
        guard let export = flatten(capture),
              let data = ScreenshotRenderer.pngData(from: export.image, scale: export.scale)
        else { return nil }
        do {
            let url = try Self.saveImageData(data, at: capture.capturedAt)
            ScreenshotSupport.markAsScreenCapture(url)
            QuickToolHUD.show(icon: "camera.viewfinder",
                              message: String(format: strings.savedHUDFormat,
                                              url.deletingLastPathComponent().lastPathComponent))
            return SaveOutcome(url: url)
        } catch {
            CaptureSaveLocation.presentSaveError(error)
            return nil
        }
    }

    /// The copy half is reported honestly: when the pasteboard write fails
    /// the HUD keeps the plain saved message, so the caller leaves the Copy
    /// button available instead of claiming work that never happened.
    private func saveAndCopyDirect(_ capture: ScreenshotSelectionController.Capture)
        -> (outcome: SaveOutcome, copied: Bool)? {
        guard let export = flatten(capture),
              let data = ScreenshotRenderer.pngData(from: export.image, scale: export.scale)
        else { return nil }
        let url: URL
        do {
            url = try Self.saveImageData(data, at: capture.capturedAt)
            ScreenshotSupport.markAsScreenCapture(url)
        } catch {
            CaptureSaveLocation.presentSaveError(error)
            return nil
        }

        let copied = ScreenshotEditorController.copyFile(
            url, payload: ScreenshotEditorController.clipboardPayload(from: export, png: data))
        let format = copied ? strings.savedAndCopiedHUDFormat : strings.savedHUDFormat
        QuickToolHUD.show(icon: "camera.viewfinder",
                          message: String(format: format,
                                          url.deletingLastPathComponent().lastPathComponent))
        return (SaveOutcome(url: url), copied)
    }

    /// Direct outputs go through the same pipeline as the editor so the 1x
    /// downscale preference applies everywhere; no backdrop, no rounding and
    /// no watermark, a direct capture is the raw pixels.
    private func flatten(_ capture: ScreenshotSelectionController.Capture)
        -> ScreenshotRenderer.Export? {
        Self.flatten(
            capture,
            downscaleTo1x: UserDefaults.standard.bool(forKey: DefaultsKey.screenshotDownscale))
    }

    private static func flatten(_ capture: ScreenshotSelectionController.Capture,
                                downscaleTo1x: Bool) -> ScreenshotRenderer.Export? {
        ScreenshotRenderer.renderExport(
            baseImage: capture.image,
            annotations: [],
            blurSources: .none,
            scale: capture.scale,
            annotationShadowsEnabled: false,
            watermark: ScreenshotSupport.WatermarkStyle(),
            watermarkImage: nil,
            style: ScreenshotSupport.BackdropStyle(kind: .none, cornerRadius: 0),
            fill: .none,
            downscaleTo1x: downscaleTo1x)
    }

    /// Vends a full-resolution PNG for dragging into a folder or another app.
    /// The temporary write begins only when the person starts the drag.
    static func dragItemProvider(image: CGImage,
                                 scale: CGFloat,
                                 strings: ScreenshotFeatureStrings) -> NSItemProvider? {
        guard let url = temporaryExportFile(image: image, scale: scale, strings: strings) else {
            return nil
        }
        guard let provider = NSItemProvider(contentsOf: url) else {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
            return nil
        }
        return provider
    }

    /// The quick preview must start dragging without synchronously encoding
    /// potentially multi-megapixel screenshots on the main thread. Export is
    /// requested lazily by the drop destination; it still receives the exact
    /// original PNG pixels and image scale, never the display thumbnail.
    static func previewDragItemProvider(image: CGImage,
                                        scale: CGFloat,
                                        strings: ScreenshotFeatureStrings) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.suggestedName = ScreenshotSupport.fileName(prefix: strings.fileNamePrefix,
                                                             date: Date())
        provider.registerFileRepresentation(forTypeIdentifier: UTType.png.identifier,
                                            fileOptions: [], visibility: .all) { completion in
            let progress = Progress(totalUnitCount: 1)
            DispatchQueue.global(qos: .userInitiated).async {
                if let url = temporaryExportFile(image: image, scale: scale, strings: strings) {
                    progress.completedUnitCount = 1
                    completion(url, false, nil)
                } else {
                    completion(nil, false, CocoaError(.fileWriteUnknown))
                }
            }
            return progress
        }
        return provider
    }

    /// A dated PNG in its own temporary folder, for a drag or the system
    /// share sheet. The receiving side reads the file after the gesture ends,
    /// so the folder stays for an hour before it is removed.
    static func temporaryExportFile(image: CGImage,
                                    scale: CGFloat,
                                    strings: ScreenshotFeatureStrings) -> URL? {
        guard let data = ScreenshotRenderer.pngData(from: image, scale: scale) else {
            return nil
        }
        let name = ScreenshotSupport.fileName(prefix: strings.fileNamePrefix, date: Date())
        guard let url = try? ScreenshotSupport.temporaryDragFile(data: data, name: name) else {
            return nil
        }
        let folder = url.deletingLastPathComponent()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 60 * 60) {
            try? FileManager.default.removeItem(at: folder)
        }
        return url
    }

    // MARK: - Save location

    /// Every screenshot output uses the same template and exclusive-create
    /// algorithm, whether the user clicks Save in a preview, editor or pin.
    static func saveImageData(_ data: Data, at date: Date = Date()) throws -> URL {
        try CaptureSaveLocation.withFolder { folder in
            try CaptureSaveNaming.saveData(data, in: folder, date: date,
                                           media: .screenshot, ext: "png")
        }
    }

}

/// One atomic image-plus-ID cache record keeps the shortcut useful across
/// launches. Legacy PNG/ID pairs are invalidated rather than guessed/migrated.
enum ScreenshotLastCaptureStore {
    private static let writeQueue = DispatchQueue(
        label: "io.github.sam32j.lattice.latest-screenshot",
        qos: .utility)
    private static let stateLock = NSLock()
    private static var generation = 0
    private static var pendingCapture: ScreenshotSelectionController.Capture?

    private static var fileURL: URL? {
        guard let base = FileManager.default.urls(for: .cachesDirectory,
                                                  in: .userDomainMask).first,
              let bundleID = Bundle.main.bundleIdentifier
        else { return nil }
        return base
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("LatestScreenshot.cache")
    }

    private static var legacyPNGURL: URL? {
        fileURL?.deletingLastPathComponent().appendingPathComponent("LatestScreenshot.png")
    }

    private static var legacyIdentityURL: URL? {
        fileURL?.deletingLastPathComponent().appendingPathComponent("LatestScreenshot.id")
    }

    private static func invalidateLegacyCache() {
        if let legacyPNGURL { try? FileManager.default.removeItem(at: legacyPNGURL) }
        if let legacyIdentityURL { try? FileManager.default.removeItem(at: legacyIdentityURL) }
    }

    private static func readRecord() -> ScreenshotLatestCaptureRecord? {
        // Option A: never expose a pre-upgrade identity-less shortcut image.
        invalidateLegacyCache()
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return ScreenshotLatestCaptureRecord.decode(data)
    }

    /// Present while the stored capture was discarded or went through an
    /// editor, so the upload shortcut keeps it back after a relaunch too.
    private static var withheldURL: URL? {
        fileURL?.deletingLastPathComponent().appendingPathComponent("LatestScreenshot.withheld")
    }

    static func matches(_ id: UUID) -> Bool {
        stateLock.lock()
        let pending = pendingCapture
        stateLock.unlock()
        if let pending { return pending.id == id }
        return readRecord()?.id == id
    }

    static var isWithheld: Bool {
        guard let withheldURL else { return false }
        return FileManager.default.fileExists(atPath: withheldURL.path)
    }

    static func withhold() {
        guard let withheldURL else { return }
        try? FileManager.default.createDirectory(at: withheldURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: withheldURL.path, contents: nil)
    }

    static func save(_ capture: ScreenshotSelectionController.Capture) {
        guard let fileURL else { return }
        // Retire all old snapshots before rendering. A crash cannot make the
        // previous capture appear to be the new latest one.
        invalidateLegacyCache()
        try? FileManager.default.removeItem(at: fileURL)
        if let withheldURL { try? FileManager.default.removeItem(at: withheldURL) }
        stateLock.lock()
        generation += 1
        let operation = generation
        pendingCapture = capture
        stateLock.unlock()

        writeQueue.async {
            guard let data = ScreenshotRenderer.pngData(
                from: capture.image, scale: capture.scale)
            else {
                finish(operation, fileURL: fileURL, removeFile: true)
                return
            }
            guard isCurrent(operation) else { return }
            do {
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true)
                let record = ScreenshotLatestCaptureRecord(id: capture.id, png: data)
                try record.encoded().write(to: fileURL, options: .atomic)
                guard isCurrent(operation) else {
                    try? FileManager.default.removeItem(at: fileURL)
                    return
                }
                finish(operation, fileURL: fileURL, removeFile: false)
            } catch {
                finish(operation, fileURL: fileURL, removeFile: true)
            }
        }
    }

    static func load() -> ScreenshotSelectionController.Capture? {
        stateLock.lock()
        let pending = pendingCapture
        stateLock.unlock()
        if let pending { return pending }

        guard let record = readRecord() else { return nil }
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(record.png as CFData, sourceOptions),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as NSDictionary?,
              let dpi = properties[kCGImagePropertyDPIWidth] as? NSNumber,
              let scale = ScreenshotSupport.captureScale(fromDPI: dpi.doubleValue)
        else { return nil }
        let imageOptions = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, imageOptions) else { return nil }
        return ScreenshotSelectionController.Capture(
            id: record.id, image: image, scale: scale, anchorRect: .zero)
    }

    static func clear() {
        stateLock.lock()
        generation += 1
        pendingCapture = nil
        stateLock.unlock()
        if let withheldURL { try? FileManager.default.removeItem(at: withheldURL) }
        invalidateLegacyCache()
        guard let fileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func isCurrent(_ operation: Int) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return generation == operation
    }

    private static func finish(_ operation: Int, fileURL: URL, removeFile: Bool) {
        guard isCurrent(operation) else { return }
        if removeFile {
            try? FileManager.default.removeItem(at: fileURL)
        }
        stateLock.lock()
        if generation == operation {
            pendingCapture = nil
        }
        stateLock.unlock()
    }
}
