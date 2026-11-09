// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Drives the QR button, which appears after the capture is scanned so the
/// preview never waits on detection to show, and the buttons grayed out
/// because the after-capture action already did their work.
final class ScreenshotQuickPreviewModel: ObservableObject {
    @Published var qr: BarcodeDetector.Reading?
    @Published var disabledActions: Set<ScreenshotQuickPreviewController.Action> = []
    @Published var sharing = false
    @Published var sharedRecord: ScreenshotShareRecord?
    @Published var deletingShare = false
}

/// A transient capture preview that stays outside Command Tab and reflects
/// automatic Save or Copy work that may already have completed.
final class ScreenshotQuickPreviewController {
    enum Action {
        case edit
        case pin
        case copy
        case save
        case saveAndCopy
        case discard
    }

    private let capture: ScreenshotSelectionController.Capture
    private let strings: ScreenshotFeatureStrings
    private let defaultAction: ScreenshotDefaultAction
    /// Runs one action and reports which sub-actions actually happened —
    /// save-and-copy can succeed by halves, and only the done halves gray
    /// their buttons out. Empty means the action failed entirely.
    private let action: (Action) -> Set<Action>
    private let deleteCapture: (@escaping (Bool) -> Void) -> Void
    private let share: (ScreenshotShareDuration,
                        @escaping @MainActor (ScreenshotShareRecord?) -> Void) -> Void
    /// Writes the capture as it would be saved into a temporary file for the
    /// system share sheet.
    private let shareFile: () -> URL?
    private let savedFile: () -> URL?
    private let saveToDefault: (() -> URL?)?
    private var menuFileURL: URL?
    private let shareAnchor = ShelfSharePickerAnchor.Anchor()
    private let sharePresenter = ShelfSharePresenter()
    private var deletingCapture = false
    private var confirmingCaptureDeletion = false
    private var previewDragInProgress = false
    private var systemSharing = false
    private var contextMenuOpen = false
    private let onClose: () -> Void
    private let model = ScreenshotQuickPreviewModel()
    private var panel: ScreenshotQuickPreviewPanel?
    private var keyMonitor: Any?
    private var dismissWork: DispatchWorkItem?
    private let baseDismissDuration: TimeInterval?
    private var autoDismissDuration: TimeInterval?
    private var closed = false
    private let presentationID = UUID()
    private var shownInNotch = false
    private var didStartPreview = false
    private var pointerInside = false
    private let openedFromHistory: Bool

    var protectedWindowIDs: Set<CGWindowID> {
        guard let panel, panel.isVisible, panel.windowNumber > 0 else { return [] }
        return [CGWindowID(panel.windowNumber)]
    }

    init(capture: ScreenshotSelectionController.Capture,
         strings: ScreenshotFeatureStrings,
         defaultAction: ScreenshotDefaultAction,
         completedActions: Set<Action>,
         dismissInterval: TimeInterval?,
         action: @escaping (Action) -> Set<Action>,
         deleteCapture: @escaping (@escaping (Bool) -> Void) -> Void,
         share: @escaping (ScreenshotShareDuration,
                           @escaping @MainActor (ScreenshotShareRecord?) -> Void) -> Void,
         shareFile: @escaping () -> URL?,
         savedFile: @escaping () -> URL? = { nil },
         saveToDefault: (() -> URL?)? = nil,
         openedFromHistory: Bool = false,
         onClose: @escaping () -> Void) {
        self.capture = capture
        self.openedFromHistory = openedFromHistory
        self.strings = strings
        self.defaultAction = defaultAction
        // A manually opened history image is persistent regardless of the
        // transient confirmation timeout the caller may have supplied.
        self.baseDismissDuration = openedFromHistory ? nil : dismissInterval
        self.autoDismissDuration = openedFromHistory ? nil : dismissInterval
        self.action = action
        self.deleteCapture = deleteCapture
        self.share = share
        self.shareFile = shareFile
        self.savedFile = savedFile
        self.saveToDefault = saveToDefault
        self.onClose = onClose
        model.disabledActions = completedActions.intersection([.save, .copy])
    }

    func show(inNotch: Bool = true) {
        guard panel == nil, !shownInNotch, !closed else { return }
        if inNotch && NotchSupport.routesCapturePreviews(),
           NotchService.shared.deferCaptureUntilMissionControlRestores(id: presentationID, present: { [weak self] in
               self?.show(inNotch: true)
           }) { return }
        let wantsNotch = inNotch && NotchSupport.routesCapturePreviews()
            && NotchService.shared.acceptsSystemFeedback
        let presentationPolicy = ScreenshotSupport.confirmationPreviewPresentationPolicy(
            dismissInterval: baseDismissDuration,
            defaults: .standard)
        let content = ScreenshotQuickPreviewView(
            image: Self.thumbnail(for: capture.image),
            strings: strings,
            model: model,
            perform: { [weak self] action in self?.perform(action) },
            dragItem: { [weak self] in
                guard let self else { return NSItemProvider() }
                return ScreenshotService.previewDragItemProvider(image: self.capture.image,
                                                                 scale: self.capture.scale,
                                                                 strings: self.strings)
            },
            nativeDragFile: { [weak self] in
                guard let self else { return nil }
                // Lattice already uses this background file-promise writer for
                // pinned captures. It exports original pixels, not the thumbnail.
                return ScreenshotPinFilePromise.make(
                    image: self.capture.image, scale: self.capture.scale,
                    fileName: ScreenshotSupport.fileName(prefix: self.strings.fileNamePrefix,
                                                         date: Date()))
            },
            dragActivityChanged: { [weak self] active in
                guard let self else { return }
                self.previewDragInProgress = active
                if active {
                    self.dismissWork?.cancel()
                    self.dismissWork = nil
                } else { self.scheduleAutoDismiss() }
            },
            share: { [weak self] duration in self?.performShare(duration) },
            systemShare: { [weak self] in self?.performSystemShare() },
            shareAnchor: shareAnchor,
            copySharedLink: { [weak self] in self?.copySharedLink() },
            deleteSharedLink: { [weak self] in self?.deleteSharedLink() },
            showQR: { [weak self] in self?.showQRResult() },
            copyText: { [weak self] in self?.copyText() },
            dismiss: { [weak self] in self?.close() },
            expand: { [weak self] in
                self?.showQuickLook()
            },
            hoverChanged: { [weak self] inside in self?.hoverChanged(inside) },
            showsDismissButton: presentationPolicy.showsDismissButton,
            embedded: wantsNotch,
            menuAction: { [weak self] in self?.performMenu($0) },
            menuApplications: { [weak self] in self?.applicationsForMenu() ?? [] },
            menuOpenWith: { [weak self] app in
                guard let self, let url = self.fileForMenu() else { return }
                NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
            },
            menuOpened: { [weak self] in self?.setContextMenuOpen(true) },
            menuClosed: { [weak self] in self?.setContextMenuOpen(false) })
        if wantsNotch, NotchService.shared.presentCapture(
            id: presentationID, content: AnyView(content), actions: AnyView(content.toolbar), height: Self.size(showingLink: model.sharedRecord != nil).height,
            fromHistory: openedFromHistory,
            imageOverlay: true,
            takeFocus: presentationPolicy.takesFocus,
            closeOnCollapse: presentationPolicy.closesOnCollapse,
            fallback: { [weak self] in
                guard let self else { return }
                self.shownInNotch = false
                self.pointerInside = false
                if let keyMonitor = self.keyMonitor { NSEvent.removeMonitor(keyMonitor) }
                self.keyMonitor = nil
                self.show(inNotch: false)
            },
            close: { [weak self] in self?.close() },
            hover: { [weak self] inside in self?.hoverChanged(inside) }) {
            shownInNotch = true
            if presentationPolicy.takesFocus {
                NSApp.activate(ignoringOtherApps: true)
            }
            if let window = NotchService.shared.presentationWindow { installKeyMonitor(for: window) }
            finishShowing()
            return
        }
        let host = NSHostingController(rootView: content)
        let size = Self.size(showingLink: model.sharedRecord != nil)
        let panel = ScreenshotQuickPreviewPanel(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false)
        panel.contentViewController = host
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary,
                                    .transient, .ignoresCycle]

        let frame = previewFrame(for: size)
        panel.setFrame(frame, display: false)
        self.panel = panel
        installKeyMonitor(for: panel)
        panel.orderFrontRegardless()
        if presentationPolicy.takesFocus {
            panel.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }
        finishShowing()
    }

    private func finishShowing() {
        if !didStartPreview {
            didStartPreview = true
            scanForQR()
        }
        scheduleAutoDismiss()
    }

    private func hoverChanged(_ inside: Bool) {
        pointerInside = inside
        dismissWork?.cancel()
        dismissWork = nil
        if !inside { scheduleAutoDismiss() }
    }

    /// Scans the full resolution capture off the main thread and reveals the
    /// QR button if a code is found. Silent when there is none, so a plain
    /// screenshot preview is untouched.
    private func scanForQR() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let image = self?.capture.image, let reading = BarcodeDetector.read(image) else { return }
            DispatchQueue.main.async {
                guard let self, !self.closed else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    self.model.qr = reading
                }
            }
        }
    }

    /// Hands the code to the shared result panel, which spells out the
    /// content before anything is copied. The preview steps aside.
    private func showQRResult() {
        guard let reading = model.qr else { return }
        close()
        QRResultController.shared.show(reading: reading)
    }

    /// The screenshot is already available at full resolution, so OCR can
    /// begin without showing another capture surface.
    private func copyText() {
        guard !closed, AppFeature.screenOCR.isAvailable else { return }
        let image = capture.image
        close()
        // An after-capture copy landing during recognition would make the
        // clipboard newer than the text, which would then be dropped, so
        // recognition starts once that copy is in.
        ScreenshotService.shared.afterAutoCopy {
            ScreenTextService.shared.copyText(from: image)
        }
    }

    private static func thumbnail(for image: CGImage) -> CGImage {
        let maximumDimension: CGFloat = 1_200
        let longest = CGFloat(max(image.width, image.height))
        guard longest > maximumDimension else { return image }
        let factor = maximumDimension / longest
        let width = max(1, Int((CGFloat(image.width) * factor).rounded()))
        let height = max(1, Int((CGFloat(image.height) * factor).rounded()))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return image }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }

    func close() {
        guard !closed else { return }
        closed = true
        NotchService.shared.cancelDeferredCapturePresentation(id: presentationID)
        dismissWork?.cancel()
        dismissWork = nil
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil
        if shownInNotch {
            shownInNotch = false
            NotchService.shared.removeCapture(id: presentationID)
        }
        onClose()
    }

    private func perform(_ requested: Action) {
        guard !closed, !deletingCapture else { return }
        if requested == .discard { confirmDelete(); return }
        // Keyboard shortcuts honor the grayed-out buttons: what the
        // after-capture action already did is not done twice.
        guard !model.disabledActions.contains(requested) else { return }
        dismissWork?.cancel()
        dismissWork = nil
        if requested == .edit || requested == .pin {
            let action = action
            close()
            DispatchQueue.main.async { _ = action(requested) }
            return
        }
        guard !action(requested).isEmpty else {
            scheduleAutoDismiss()
            return
        }
        close()
    }

    private func showQuickLook() {
        guard !closed else { return }
        dismissWork?.cancel()
        if ScreenshotQuickLookController.shared.isVisible { ScreenshotQuickLookController.shared.close(); return }
        if !ScreenshotQuickLookController.shared.show(image: capture.image, scale: capture.scale,
            owner: panel ?? NotchService.shared.presentationWindow) { NSSound.beep() }
    }

    private func fileForMenu() -> URL? {
        if let menuFileURL { return menuFileURL }
        menuFileURL = shareFile()
        return menuFileURL
    }

    private func applicationsForMenu() -> [URL] {
        guard let url = fileForMenu() else { return [] }
        return NSWorkspace.shared.urlsForApplications(toOpen: url).sorted {
            FileManager.default.displayName(atPath: $0.path).localizedStandardCompare(
                FileManager.default.displayName(atPath: $1.path)) == .orderedAscending
        }
    }

    @MainActor private func performMenu(_ requested: ScreenshotPreviewMenuAction) {
        guard !closed else { return }
        switch requested {
        case .edit: perform(.edit)
        case .pin: perform(.pin)
        case .extractText: copyText()
        case .quickLook: showQuickLook()
        case .close: close()
        case .share: performSystemShare()
        case .reveal:
            if let url = savedFile() {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } else if let url = saveToDefault?() {
                model.disabledActions.insert(.save)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        case .mail:
            if let url = fileForMenu() { NSSharingService(named: .composeEmail)?.perform(withItems: [url]) }
        case .printImage:
            ScreenshotPreviewImageActions.printImage(capture.image, scale: capture.scale)
        case .saveAs:
            if ScreenshotPreviewImageActions.saveAs(image: capture.image, scale: capture.scale,
                owner: panel ?? NotchService.shared.presentationWindow, strings: strings) { close() }
        case .rotateLeft, .flipHorizontal:
            guard let image = ScreenshotPreviewImageActions.transformed(capture.image,
                requested == .rotateLeft ? .rotateLeft : .flipHorizontal) else { NSSound.beep(); return }
            let capture = ScreenshotSelectionController.Capture(image: image, scale: capture.scale, anchorRect: capture.anchorRect)
            close()
            DispatchQueue.main.async { ScreenshotService.shared.showTransformedPreview(capture) }
        }
    }

    func shareLink() {
        guard !closed, !model.deletingShare else { return }
        if model.sharedRecord != nil {
            copySharedLink()
        } else {
            performShare(.saved())
        }
    }

    /// Anchor the native share picker to the actual window surface. The SwiftUI
    /// NSViewRepresentable behind the icon can have zero bounds in the Island's
    /// overlay toolbar, causing a picker with no usable presentation anchor.
    private func performSystemShare() {
        guard !closed, !systemSharing else { return }
        dismissWork?.cancel()
        dismissWork = nil
        guard let url = shareFile() else {
            NSSound.beep()
            scheduleAutoDismiss()
            return
        }
        let window = shownInNotch ? NotchService.shared.presentationWindow : panel
        guard let window, let content = window.contentView, window.isVisible else {
            NSSound.beep()
            scheduleAutoDismiss()
            return
        }
        // An explicit Share click may be made while another app owns focus.
        // Activating Lattice also keeps a native sharing picker above the Island.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKey()
        let location = content.convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        let bounds = content.bounds
        let point = CGPoint(x: min(max(location.x, bounds.minX + 1), bounds.maxX - 1),
                            y: min(max(location.y, bounds.minY + 1), bounds.maxY - 1))
        let anchor = CGRect(origin: point, size: CGSize(width: 1, height: 1))
        systemSharing = true
        let shown = sharePresenter.present(for: [url], from: content, relativeTo: anchor) { [weak self] chosen in
            guard let self else { return }
            self.systemSharing = false
            if chosen { self.close() } else { self.scheduleAutoDismiss() }
        }
        if !shown {
            systemSharing = false
            NSSound.beep()
            scheduleAutoDismiss()
        }
    }

    /// Deleting an image is distinct from dismissing its preview. In particular,
    /// history navigation must wait for the backing file and index to be removed.
    private func confirmDelete() {
        guard !closed, !deletingCapture, !confirmingCaptureDeletion else { return }
        confirmingCaptureDeletion = true
        dismissWork?.cancel()
        dismissWork = nil
        let notice = CapturePreviewNoticeStrings.localized(L10n.shared.language)
        let alert = NSAlert()
        alert.messageText = notice.screenshotTitle
        alert.informativeText = notice.screenshotMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: notice.screenshotAction)
        alert.addButton(withTitle: strings.cancel)
        let owner = shownInNotch ? NotchService.shared.presentationWindow : panel
        let confirmed = NotchIslandAlert.run(alert, above: owner) == .alertFirstButtonReturn
        confirmingCaptureDeletion = false
        guard confirmed else {
            scheduleAutoDismiss()
            return
        }
        deletingCapture = true
        deleteCapture { [weak self] succeeded in
            guard let self, !self.closed else { return }
            self.deletingCapture = false
            guard succeeded else {
                NSSound.beep()
                let errorAlert = NSAlert()
                errorAlert.messageText = notice.screenshotFailureTitle
                errorAlert.informativeText = notice.screenshotFailureMessage
                errorAlert.alertStyle = .warning
                errorAlert.addButton(withTitle: "OK")
                _ = NotchIslandAlert.run(errorAlert, above: self.shownInNotch
                    ? NotchService.shared.presentationWindow : self.panel)
                self.scheduleAutoDismiss()
                return
            }
            if self.openedFromHistory {
                if self.shownInNotch && NotchService.shared.isCaptureVisible(id: self.presentationID) {
                    NotchService.shared.showCaptureHistory()
                } else {
                    self.close()
                    RecentCaptureService.shared.showHistoryWindow()
                }
            } else {
                let wasInNotch = self.shownInNotch
                self.close()
                if wasInNotch { NotchService.shared.collapse() }
            }
        }
    }

    private func performShare(_ duration: ScreenshotShareDuration) {
        guard !closed, !model.sharing else { return }
        dismissWork?.cancel()
        dismissWork = nil
        model.sharing = true
        share(duration) { [weak self] record in
            guard let self, !self.closed,
                  AppFeature.screenshot.isAvailable,
                  UserDefaults.standard.bool(forKey: DefaultsKey.screenshotSharingEnabled) else {
                if let self, !self.closed {
                    self.model.sharing = false
                    self.scheduleAutoDismiss()
                }
                if let record {
                    Task { @MainActor in
                        try? await ScreenshotShareService.shared.delete(record)
                    }
                }
                return
            }
            self.model.sharing = false
            guard let record else {
                self.scheduleAutoDismiss()
                return
            }
            if self.copyLinkAndClose(record) { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                self.model.sharedRecord = record
            }
            self.autoDismissDuration = ScreenshotSupport.sharedPreviewDismissInterval(
                base: self.baseDismissDuration)
            self.resizePanel(showingLink: true)
            self.scheduleAutoDismiss()
        }
    }

    private func copySharedLink() {
        guard let record = model.sharedRecord else { return }
        dismissWork?.cancel()
        dismissWork = nil
        Task { @MainActor [weak self] in
            guard let self, !self.closed else { return }
            if !self.copyLinkAndClose(record) { self.scheduleAutoDismiss() }
        }
    }

    @MainActor
    private func copyLinkAndClose(_ record: ScreenshotShareRecord) -> Bool {
        let copied = ScreenshotSharingSupport.copyLink(
            record, using: ScreenshotShareService.shared.copy,
            dismiss: { self.close() })
        if copied {
            QuickToolHUD.show(icon: "link", message: strings.sharedHUD)
        } else {
            QuickToolHUD.show(icon: "link", message: strings.linkCopyFailedHUD)
            NSSound.beep()
        }
        return copied
    }

    private func deleteSharedLink() {
        guard let record = model.sharedRecord, !model.deletingShare else { return }
        dismissWork?.cancel()
        dismissWork = nil
        model.deletingShare = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await ScreenshotShareService.shared.delete(record)
                guard !self.closed else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    self.model.sharedRecord = nil
                    self.model.deletingShare = false
                }
                QuickToolHUD.show(icon: "link", message: self.strings.linkDeletedHUD)
                self.autoDismissDuration = self.baseDismissDuration
                self.resizePanel(showingLink: false)
            } catch {
                guard !self.closed else { return }
                self.model.deletingShare = false
                QuickToolHUD.show(icon: "link", message: self.strings.deleteFailedHUD)
                NSSound.beep()
            }
            self.scheduleAutoDismiss()
        }
    }

    fileprivate static func size(showingLink: Bool) -> CGSize {
        CGSize(width: 340, height: showingLink ? 216 : 158)
    }

    private func previewFrame(for size: CGSize) -> CGRect {
        let pointer = NSEvent.mouseLocation
        let screens = NSScreen.screens.map { (frame: $0.frame, visibleFrame: $0.visibleFrame) }
        let visibleFrame = ScreenshotSupport.quickPreviewVisibleFrame(
            anchor: capture.anchorRect,
            pointer: pointer,
            screens: screens,
            fallback: NSScreen.pointerVisibleFrame)
        let position = ScreenshotSupport.QuickPreviewPosition.current()
        // With an after-capture action the preview is just a confirmation,
        // so it sits quietly in the corner and leaves sooner, instead of
        // popping up next to the selection and waiting.
        let effectivePosition: ScreenshotSupport.QuickPreviewPosition =
            position == .automatic && defaultAction != .none
                ? .bottomRight
                : position
        return ScreenshotSupport.quickPreviewFrame(
            size: size,
            anchor: capture.anchorRect,
            pointer: pointer,
            visibleFrame: visibleFrame,
            position: effectivePosition)
    }

    private func resizePanel(showingLink: Bool) {
        if shownInNotch {
            NotchService.shared.updateCaptureHeight(id: presentationID, height: Self.size(showingLink: showingLink).height)
            return
        }
        panel?.setFrame(previewFrame(for: Self.size(showingLink: showingLink)),
                        display: true,
                        animate: true)
    }

    private func scheduleAutoDismiss() {
        guard !closed, !deletingCapture, !confirmingCaptureDeletion,
              !pointerInside, !previewDragInProgress, !contextMenuOpen, !systemSharing, !model.sharing, !model.deletingShare,
              let dismissDuration = autoDismissDuration
        else { return }
        dismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.close() }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissDuration, execute: work)
    }

    private func setContextMenuOpen(_ open: Bool) {
        contextMenuOpen = open
        dismissWork?.cancel()
        dismissWork = nil
        if !open { scheduleAutoDismiss() }
    }

    private func installKeyMonitor(for panel: NSPanel) {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak panel] event in
            guard let self, !self.closed, let panel, panel.isVisible, event.window === panel,
                  !self.shownInNotch || (!ScreenshotSelectionController.isSessionOnScreen
                      && NotchService.shared.isCaptureVisible(id: self.presentationID)),
                  panel.attachedSheet == nil, !(panel.firstResponder is NSText),
                  !ShortcutCapture.isCapturing else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let key = Int(event.keyCode)
            if flags.intersection([.command, .option, .shift, .control]) == .command {
                func matches(_ letter: String, _ fallback: Int) -> Bool {
                    ScreenshotWindowLayering.matchesLetter(letter, characters: event.charactersIgnoringModifiers,
                        keyCode: event.keyCode, fallback: fallback)
                }
                if matches("w", kVK_ANSI_W) {
                    self.close()
                    return nil
                }
                if matches("y", kVK_ANSI_Y) { self.showQuickLook(); return nil }
                if matches("e", kVK_ANSI_E) { self.perform(.edit); return nil }
            }
            if flags.contains(.command) {
                switch key {
                case kVK_ANSI_C:
                    self.perform(.copy)
                    return nil
                case kVK_ANSI_S:
                    if flags.contains(.shift) { MainActor.assumeIsolated { self.performMenu(.saveAs) } }
                    else { self.perform(.save) }
                    return nil
                case kVK_ANSI_P:
                    MainActor.assumeIsolated { self.performMenu(.printImage) }
                    return nil
                case kVK_Delete, kVK_ForwardDelete:
                    self.perform(.discard)
                    return nil
                default:
                    return event
                }
            }
            guard flags.isDisjoint(with: [.command, .control, .option]) else { return event }
            let letter = event.charactersIgnoringModifiers?.lowercased()
            if key == kVK_Space || letter == " " {
                // Space and Command-Y both toggle Quick Look. Copy remains
                // Command-C; Space must not close a history-opened preview.
                self.showQuickLook()
                return nil
            }
            if letter == "p" || key == kVK_ANSI_P {
                self.perform(.pin)
                return nil
            }
            if letter == "o" || key == kVK_ANSI_O {
                self.copyText()
                return nil
            }
            if letter == "e" || key == kVK_ANSI_E || key == kVK_Return || key == kVK_ANSI_KeypadEnter {
                self.perform(.edit)
                return nil
            }
            switch key {
            case kVK_Delete, kVK_ForwardDelete:
                self.perform(.discard)
                return nil
            case kVK_Escape:
                // Escape only dismisses. Before the after-capture actions it
                // was equivalent to discard; now a discard can delete a file
                // the HUD just announced as saved, and "make this popup go
                // away" must never do that. Deleting stays on Trash and ⌫.
                self.close()
                return nil
            default:
                return event
            }
        }
    }
}

private final class ScreenshotQuickPreviewPanel: OverlayPanel {
    override var canBecomeKey: Bool { true }

    /// The preview shows up unasked for, so presenting it leaves the keyboard
    /// where it was unless the person opted in, and a click is what hands it
    /// over. Its shortcuts read a local monitor, and that monitor is delivered
    /// nothing until this panel is key. The hand-off sits in `sendEvent`
    /// rather than `mouseDown` because the hosted SwiftUI content answers a
    /// press on a button itself, and a window's `mouseDown` never runs for the
    /// clicks a view has taken.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, !isKeyWindow {
            makeKey()
        }
        super.sendEvent(event)
    }
}

private struct ScreenshotQuickPreviewView: View {
    let image: CGImage
    let strings: ScreenshotFeatureStrings
    @ObservedObject var model: ScreenshotQuickPreviewModel
    @ObservedObject private var featureRuntime = FeatureRuntime.shared
    let perform: (ScreenshotQuickPreviewController.Action) -> Void
    let dragItem: () -> NSItemProvider
    let nativeDragFile: () -> NSFilePromiseProvider?
    var dragActivityChanged: (Bool) -> Void = { _ in }
    let share: (ScreenshotShareDuration) -> Void
    let systemShare: () -> Void
    let shareAnchor: ShelfSharePickerAnchor.Anchor
    let copySharedLink: () -> Void
    let deleteSharedLink: () -> Void
    let showQR: () -> Void
    let copyText: () -> Void
    let dismiss: () -> Void
    let expand: () -> Void
    let hoverChanged: (Bool) -> Void
    let showsDismissButton: Bool
    var embedded = false
    var actionsOnly = false
    var menuAction: @MainActor (ScreenshotPreviewMenuAction) -> Void = { _ in }
    var menuApplications: () -> [URL] = { [] }
    var menuOpenWith: (URL) -> Void = { _ in }
    var menuOpened: () -> Void = {}
    var menuClosed: () -> Void = {}
    var toolbar: Self {
        var view = self
        view.actionsOnly = true
        return view
    }
    @AppStorage(DefaultsKey.screenshotSharingEnabled) private var sharingEnabled = true
    @State private var isViewportHovered = false

    var body: some View {
        Group {
            if actionsOnly { actionBar }
            else { preview }
        }
        .contextMenu {
            ScreenshotPreviewContextMenu(perform: menuAction, applications: menuApplications,
                openWith: menuOpenWith, opened: menuOpened, closed: menuClosed)
        }
    }

    private var actionBar: some View {
        HStack(spacing: embedded ? 2 : 5) {
            Button {
                perform(.discard)
            } label: {
                Image(systemName: "trash")
                    .frame(width: embedded ? 28 : 22, height: embedded ? 28 : 18)
            }
            .modifier(ScreenshotPreviewActionStyle(embedded: embedded))
            .controlSize(.small)
            .focusable(false)
            .screenshotSafeHelp("\(strings.discardConfirm)  (⌫)")
            .accessibilityLabel(strings.discardConfirm)
            if model.qr != nil {
                qrControl
                    .transition(.scale.combined(with: .opacity))
            }
            // The floating preview shows Copy text on its thumbnail.
            if embedded, featureRuntime.isAvailable(.screenOCR) {
                textControl
            }
            actionButton(symbol: "square.and.arrow.down",
                         title: strings.saveButton,
                         shortcut: "⌘S",
                         disabled: model.disabledActions.contains(.save)) {
                perform(.save)
            }
            actionButton(symbol: "doc.on.doc",
                         title: strings.copyButton,
                         shortcut: "⌘C",
                         disabled: model.disabledActions.contains(.copy)) {
                perform(.copy)
            }
            if embedded {
                Button(action: systemShare) {
                    Image(systemName: "square.and.arrow.up").frame(width: 28, height: 28)
                }
                .modifier(ScreenshotPreviewActionStyle(embedded: true))
                .controlSize(.small)
                .focusable(false)
                .background(ShelfSharePickerAnchor(anchor: shareAnchor))
                .screenshotSafeHelp(strings.shareButton)
                .accessibilityLabel(strings.shareButton)
            }
            if sharingEnabled, model.sharedRecord == nil {
                shareMenu
            }
            if !embedded { Spacer(minLength: 4) }
            if embedded {
                Button {
                    perform(.pin)
                } label: {
                    Image(systemName: "mappin").frame(width: 28, height: 28)
                }
                .modifier(ScreenshotPreviewActionStyle(embedded: true))
                .controlSize(.small)
                .focusable(false)
                .screenshotSafeHelp(strings.pinButton)
                .accessibilityLabel(strings.pinButton)
            }
            Button { perform(.edit) } label: {
                if embedded { Image(systemName: "pencil").frame(width: 28, height: 28) }
                else { Text(strings.editButton) }
            }
            .accessibilityLabel(strings.editButton)
            .modifier(ScreenshotPreviewActionStyle(embedded: embedded, prominent: true))
            .controlSize(.small)
            .focusable(false)
            .screenshotSafeHelp("\(strings.editButton)  (⏎)")
        }
    }

    private var thumbnailDismissButton: some View {
        Button(action: dismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.black.opacity(0.65), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8))
                .shadow(color: Color.black.opacity(0.25), radius: 2, y: 1)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .padding(6)
        .screenshotSafeHelp("\(strings.done)  (⎋)")
        .accessibilityLabel(strings.done)
    }

    private var viewportTopLeadingButtons: some View {
        HStack(spacing: 5) {
            if showsDismissButton {
                thumbnailDismissButton
            }
            if featureRuntime.isAvailable(.screenOCR) {
                thumbnailButton(symbol: "text.viewfinder", title: strings.copyTextButton,
                                action: copyText)
            }
            thumbnailButton(symbol: "mappin", title: strings.pinButton) { perform(.pin) }
        }
        .padding(6)
    }

    private var viewportTopTrailingButtons: some View {
        HStack(spacing: 5) {
            if sharingEnabled, model.sharedRecord == nil {
                viewportLinkMenu
            }
            thumbnailButton(symbol: "square.and.arrow.up", title: strings.shareButton,
                            action: systemShare)
                .background(ShelfSharePickerAnchor(anchor: shareAnchor))
        }
        .padding(6)
    }

    private var viewportLinkMenu: some View {
        Button(action: showShareMenu) {
            Group {
                if model.sharing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "link")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 24, height: 24)
            .background(Color.black.opacity(0.65), in: Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8))
            .shadow(color: Color.black.opacity(0.25), radius: 2, y: 1)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(model.sharing)
        .focusable(false)
        .screenshotSafeHelp(strings.shareSectionTitle)
        .accessibilityLabel(strings.shareSectionTitle)
    }

    private func showShareMenu() {
        let menu = NSMenu()
        for duration in ScreenshotShareDuration.allCases {
            let item = NSMenuItem(
                title: duration.title(strings),
                action: #selector(ScreenshotQuickPreviewMenuHelper.handleDurationAction(_:)),
                keyEquivalent: ""
            )
            item.target = ScreenshotQuickPreviewMenuHelper.shared
            item.representedObject = {
                self.share(duration)
            }
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private var viewportBottomLeadingButtons: some View {
        HStack(spacing: 5) {
            if model.qr != nil {
                thumbnailButton(symbol: "qrcode", title: L10n.shared.s.qrResultTitle, action: showQR)
            }
            thumbnailButton(symbol: "pencil", title: "\(strings.editButton)  (E)") {
                perform(.edit)
            }
        }
        .padding(6)
    }

    private var viewportBottomTrailingButtons: some View {
        Button(action: { perform(.discard) }) {
            Image(systemName: "trash")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.45))
                .frame(width: 24, height: 24)
                .background(Color.black.opacity(0.65), in: Circle())
                .overlay(Circle().strokeBorder(Color.red.opacity(0.4), lineWidth: 0.8))
                .shadow(color: Color.black.opacity(0.25), radius: 2, y: 1)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .screenshotSafeHelp("\(strings.discardConfirm)  (⌫)")
        .accessibilityLabel(strings.discardConfirm)
        .padding(6)
    }

    private var viewportCenterOverlay: some View {
        QuickPreviewCenterActions(
            strings: strings,
            disabledActions: model.disabledActions,
            onCopy: { perform(.copy) },
            onSave: { perform(.save) }
        )
    }

    private func thumbnailButton(symbol: String,
                                 title: String,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.black.opacity(0.65), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8))
                .shadow(color: Color.black.opacity(0.25), radius: 2, y: 1)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .screenshotSafeHelp(title)
        .accessibilityLabel(title)
    }

    private var preview: some View {
        Group {
            if embedded { islandPreview } else { floatingPreview }
        }
    }

    /// The Island size is owned by NotchService. The image fills only its
    /// existing canvas (cropping at the edges when aspect ratios differ), and
    /// the controls float above it without reserving an extra layout row.
    private var islandPreview: some View {
        GeometryReader { size in
            VStack(spacing: 5) {
                GeometryReader { canvas in
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: canvas.size.width, height: canvas.size.height)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        // Native AppKit dragging avoids SwiftUI recompositing
                        // the image/Glass view as a drag moves over this Island.
                        // The source owns just the image; toolbar overlays sit
                        // above it and remain fully interactive.
                        .overlay {
                            ScreenshotIslandDragSurface(image: image,
                                                        filePromise: nativeDragFile,
                                                        expand: expand,
                                                        dragActivityChanged: dragActivityChanged)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                                .allowsHitTesting(false)
                        }
                        .overlay(alignment: .topLeading) {
                            // Quick Look is separate from the screenshot drag
                            // surface, so this control doesn't enter the drag
                            // preview or steal gestures outside its bounds.
                            thumbnailButton(symbol: "eye", title: "Quick Look", action: expand)
                                .padding(6)
                        }
                        .overlay(alignment: .topTrailing) {
                            islandImageToolbar.padding(6)
                        }
                        .overlay(alignment: .bottomLeading) {
                            if model.qr != nil { qrControl.padding(6) }
                        }
                }
                if let record = model.sharedRecord {
                    sharedLinkRow(record)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 3)
            .padding(.bottom, 4)
            .frame(width: size.size.width, height: size.size.height)
        }
    }

    /// Every action uses the same 28-point hit target and symbol typography.
    /// The native Menu style previously gave Quick Link a different baseline;
    /// use its existing duration picker through the same button treatment.
    private func islandTool(symbol: String, title: String,
                            disabled: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) { islandToolImage(symbol) }
            .modifier(ScreenshotPreviewActionStyle(embedded: true))
            .controlSize(.small)
            .focusable(false)
            .disabled(disabled)
            .opacity(disabled ? 0.4 : 1)
            .screenshotSafeHelp(title)
            .accessibilityLabel(title)
    }

    private func islandToolImage(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle()) // Tap the entire hover tile, not just the SF Symbol.
    }

    private var islandToolSeparator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.18))
            .frame(width: 1, height: 15)
            .padding(.horizontal, 5)
            .accessibilityHidden(true)
    }

    /// Copy, Save, Pin to Screen, OCR | Share, Quick Link | Edit, Delete.
    /// The pin here is for the IMAGE, not the Island's camera-side pin.
    private var islandImageToolbar: some View {
        HStack(spacing: 3) {
            islandTool(symbol: "doc.on.doc", title: strings.copyButton,
                       disabled: model.disabledActions.contains(.copy)) { perform(.copy) }
            islandTool(symbol: "square.and.arrow.down", title: strings.saveButton,
                       disabled: model.disabledActions.contains(.save)) { perform(.save) }
            islandTool(symbol: "mappin", title: strings.pinButton) { perform(.pin) }
            if featureRuntime.isAvailable(.screenOCR) {
                islandTool(symbol: "text.viewfinder", title: strings.copyTextButton,
                           action: copyText)
            }
            islandToolSeparator
            islandTool(symbol: "square.and.arrow.up", title: strings.shareButton,
                       action: systemShare)
            if sharingEnabled, model.sharedRecord == nil {
                Button(action: showShareMenu) {
                    if model.sharing {
                        ProgressView().controlSize(.small).frame(width: 28, height: 28).contentShape(Rectangle())
                    } else {
                        islandToolImage("link")
                    }
                }
                .modifier(ScreenshotPreviewActionStyle(embedded: true))
                .controlSize(.small)
                .focusable(false)
                .disabled(model.sharing)
                .screenshotSafeHelp(strings.shareSectionTitle)
                .accessibilityLabel(strings.shareSectionTitle)
            }
            islandToolSeparator
            islandTool(symbol: "pencil", title: strings.editButton) { perform(.edit) }
            islandTool(symbol: "trash", title: strings.discardConfirm) { perform(.discard) }
        }
        .fixedSize(horizontal: true, vertical: true)
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(HUDBackdrop(cornerRadius: 12, contrast: .standard))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.7)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }

    private var floatingPreview: some View {
        VStack(spacing: 10) {
            ZStack {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(maxWidth: 320, maxHeight: 138)
                    .frame(width: embedded ? nil : 320, height: 138)
                    .clipped()
                    .background(Color.black.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                    .onDrag(dragItem)
                    .onTapGesture(count: 2, perform: expand)

                if !embedded {
                    VStack {
                        HStack {
                            viewportTopLeadingButtons
                            Spacer()
                            viewportTopTrailingButtons
                        }
                        Spacer()
                        HStack {
                            viewportBottomLeadingButtons
                            Spacer()
                            viewportBottomTrailingButtons
                        }
                    }
                }
                // In Dynamic Island, Close lives in the camera-side header.
                // Do not duplicate a dismiss X over a persistent screenshot.

                if !embedded && isViewportHovered {
                    viewportCenterOverlay
                        .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                }
            }
            .frame(width: embedded ? nil : 320, height: 138)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .onHover { inside in
                isViewportHovered = inside
            }

            if let record = model.sharedRecord {
                sharedLinkRow(record)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(10)
        .frame(width: embedded ? nil : ScreenshotQuickPreviewController.size(showingLink: false).width,
               height: embedded ? nil : ScreenshotQuickPreviewController.size(
                   showingLink: model.sharedRecord != nil).height)
        .background {
            if !embedded {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.regularMaterial)
            }
        }
        .overlay {
            if !embedded {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
            }
        }
        .onHover(perform: previewHoverChanged)
    }

    private func previewHoverChanged(_ inside: Bool) {
        // The island tracks the image and header together. Leaving just the
        // image must not restart dismissal while its actions are still hovered.
        guard !embedded else { return }
        hoverChanged(inside)
    }

    private func sharedLinkRow(_ record: ScreenshotShareRecord) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.url.absoluteString)
                    .font(.system(size: 11, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                HStack(spacing: 3) {
                    Text(strings.expiresLabel)
                    Text(record.expiresAt, style: .relative)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 2)
            Button(action: copySharedLink) {
                Image(systemName: "doc.on.doc")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.borderless)
            .disabled(model.deletingShare)
            .screenshotSafeHelp(strings.copyLink)
            .accessibilityLabel(strings.copyLink)
            Button(role: .destructive, action: deleteSharedLink) {
                Group {
                    if model.deletingShare {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: "trash")
                    }
                }
                .frame(width: 18, height: 18)
            }
            .buttonStyle(.borderless)
            .disabled(model.deletingShare)
            .screenshotSafeHelp(strings.deleteLink)
            .accessibilityLabel(strings.deleteLink)
        }
        .padding(.horizontal, 9)
        .frame(width: embedded ? nil : 320, height: 48)
        .background(Color.primary.opacity(0.055),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
        )
    }

    /// A code was found: open the result panel that spells out its content.
    private var qrControl: some View {
        Button(action: showQR) {
            Image(systemName: "qrcode")
                .frame(width: embedded ? 28 : 22, height: embedded ? 28 : 18)
        }
        .modifier(ScreenshotPreviewActionStyle(embedded: embedded))
        .controlSize(.small)
        .focusable(false)
        .tint(.accentColor)
        .screenshotSafeHelp(L10n.shared.s.qrResultTitle)
        .accessibilityLabel(L10n.shared.s.qrResultTitle)
    }

    /// Runs OCR against the full-resolution capture and copies its text.
    private var textControl: some View {
        Button(action: copyText) {
            Image(systemName: "text.viewfinder").frame(width: 28, height: 28)
        }
        .modifier(ScreenshotPreviewActionStyle(embedded: true))
        .controlSize(.small)
        .focusable(false)
        .screenshotSafeHelp(strings.copyTextButton)
        .accessibilityLabel(strings.copyTextButton)
    }

    @ViewBuilder private var shareMenu: some View {
        if embedded {
            // The island hides the menu arrow, so a primary action would leave
            // the durations behind a press and hold that nothing hints at. A
            // click there opens the durations, as it always has.
            shareMenuChrome(Menu { shareDurations } label: { shareMenuLabel },
                            help: strings.shareSectionTitle)
                .menuStyle(.borderlessButton).menuIndicator(.hidden)
                .frame(width: 28, height: 28)
        } else {
            shareMenuChrome(Menu { shareDurations } label: { shareMenuLabel } primaryAction: {
                share(.saved())
            }, help: "\(strings.shareSectionTitle) · \(ScreenshotShareDuration.saved().title(strings))")
                .menuStyle(.button).buttonStyle(.bordered).controlSize(.small)
        }
    }

    private var shareDurations: some View {
        ForEach(ScreenshotShareDuration.allCases) { duration in
            Button(duration.title(strings)) { share(duration) }
        }
    }

    private var shareMenuLabel: some View {
        Group {
            if model.sharing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "link")
            }
        }
        .frame(width: embedded ? 28 : 22, height: embedded ? 28 : 18)
    }

    private func shareMenuChrome(_ menu: some View, help: String) -> some View {
        menu
            .disabled(model.sharing)
            .screenshotSafeHelp(model.sharing ? strings.sharingHUD : help)
            .accessibilityLabel(strings.shareSectionTitle)
    }

    private func actionButton(symbol: String,
                              title: String,
                              shortcut: String,
                              disabled: Bool = false,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if embedded { Image(systemName: symbol).frame(width: 28, height: 28) }
                else { Label(title, systemImage: symbol) }
            }
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .modifier(ScreenshotPreviewActionStyle(embedded: embedded))
        .controlSize(.small)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .screenshotSafeHelp("\(title)  (\(shortcut))")
        .accessibilityLabel(title)
    }
}

/// The island header has its own surface; native button bezels waste the space
/// needed by its title at the minimum width. Keep 28-point targets in that host.
private struct ScreenshotPreviewActionStyle: ViewModifier {
    let embedded: Bool
    var prominent = false

    @ViewBuilder func body(content: Content) -> some View {
        if embedded {
            content.buttonStyle(NotchButtonStyle(cornerRadius: 8))
                .background(prominent ? Color.white.opacity(0.14) : .clear,
                            in: RoundedRectangle(cornerRadius: 8))
        } else if prominent {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

private struct QuickPreviewCenterActions: View {
    let strings: ScreenshotFeatureStrings
    let disabledActions: Set<ScreenshotQuickPreviewController.Action>
    let onCopy: () -> Void
    let onSave: () -> Void
    @State private var isCopyHovered = false
    @State private var isSaveHovered = false

    var body: some View {
        VStack(spacing: 6) {
            Button(action: onCopy) {
                HStack(spacing: 5) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                    Text(strings.copyButton)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(minWidth: 84)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    isCopyHovered ? Color.accentColor.opacity(0.85) : Color.accentColor,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(isCopyHovered ? 0.35 : 0.15), lineWidth: 1)
                )
                .scaleEffect(isCopyHovered ? 1.04 : 1.0)
                .animation(.easeInOut(duration: 0.12), value: isCopyHovered)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .disabled(disabledActions.contains(.copy))
            .onHover { isCopyHovered = $0 }
            .screenshotSafeHelp("\(strings.copyButton)  (⌘C)")

            Button(action: onSave) {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 11, weight: .semibold))
                    Text(strings.saveButton)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(minWidth: 84)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    isSaveHovered ? Color.white.opacity(0.25) : Color.black.opacity(0.45),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(isSaveHovered ? 0.35 : 0.15), lineWidth: 1)
                )
                .scaleEffect(isSaveHovered ? 1.04 : 1.0)
                .animation(.easeInOut(duration: 0.12), value: isSaveHovered)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .disabled(disabledActions.contains(.save))
            .onHover { isSaveHovered = $0 }
            .screenshotSafeHelp("\(strings.saveButton)  (⌘S)")
        }
        .padding(5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 8, y: 3)
    }
}

@objc final class ScreenshotQuickPreviewMenuHelper: NSObject {
    static let shared = ScreenshotQuickPreviewMenuHelper()
    @objc func handleDurationAction(_ sender: NSMenuItem) {
        if let block = sender.representedObject as? () -> Void {
            block()
        }
    }
}


// MARK: - Native Dynamic Island screenshot dragging

/// The Island's glass/backdrop and its SwiftUI image should never be live drag
/// artwork. AppKit carries a small, fixed image while a lazy file promise
/// exports the original pixels only if a destination asks for the file.
private struct ScreenshotIslandDragSurface: NSViewRepresentable {
    let image: CGImage
    let filePromise: () -> NSFilePromiseProvider?
    let expand: () -> Void
    let dragActivityChanged: (Bool) -> Void

    func makeNSView(context: Context) -> DragView { DragView(frame: .zero) }

    func updateNSView(_ view: DragView, context: Context) {
        view.updateArtwork(for: image)
        view.filePromise = filePromise
        view.expand = expand
        view.dragActivityChanged = dragActivityChanged
    }

    static func dismantleNSView(_ view: DragView, coordinator: ()) {
        view.finishDrag()
        view.filePromise = nil
        view.expand = nil
        view.dragActivityChanged = nil
        view.sourceImage = nil
        view.dragArtwork = nil
    }

    final class DragView: NSView, NSDraggingSource {
        // The visible screenshot can be 1,200 pixels wide. NSImage(cgImage:size:)
        // changes POINT size but retains the original pixels, so a native drag
        // would still carry a large texture through the Island's compositor.
        // Rasterize once at the actual cursor-artwork size, as HubTileDragPreview
        // does for grid items. Never re-rasterize for mouse movement.
        var sourceImage: CGImage?
        var dragArtwork: NSImage?
        var filePromise: (() -> NSFilePromiseProvider?)?
        var expand: (() -> Void)?
        var dragActivityChanged: ((Bool) -> Void)?
        private var press: NSEvent?
        private var isDragging = false

        func finishDrag() {
            press = nil
            guard isDragging else { return }
            isDragging = false
            NotchService.shared.capturePreviewDragChanged(false)
            dragActivityChanged?(false)
        }

        func updateArtwork(for image: CGImage) {
            guard sourceImage !== image else { return }
            sourceImage = image
            let scale = min(240 / CGFloat(image.width), 150 / CGFloat(image.height), 1)
            let width = max(1, Int((CGFloat(image.width) * scale).rounded()))
            let height = max(1, Int((CGFloat(image.height) * scale).rounded()))
            guard let context = CGContext(data: nil, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                dragArtwork = nil
                return
            }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            dragArtwork = context.makeImage().map {
                NSImage(cgImage: $0, size: CGSize(width: width, height: height))
            }
        }

        override var isFlipped: Bool { true }
        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 {
                press = nil
                expand?()
            } else {
                press = event
            }
        }

        override func mouseUp(with event: NSEvent) { press = nil }

        override func mouseDragged(with event: NSEvent) {
            guard let press,
                  hypot(event.locationInWindow.x - press.locationInWindow.x,
                        event.locationInWindow.y - press.locationInWindow.y) >= 4,
                  let artwork = dragArtwork, let provider = filePromise?() else { return }
            self.press = nil

            // Pair the preview's frame with the ORIGINAL mouse-down, as the
            // working Hub grid drag does. Starting from the later dragged event
            // can cause the first drag frame to jump relative to the cursor.
            let size = artwork.size
            let point = convert(press.locationInWindow, from: nil)
            let item = NSDraggingItem(pasteboardWriter: provider)
            item.setDraggingFrame(CGRect(x: point.x - size.width / 2,
                                         y: point.y - size.height / 2,
                                         width: size.width, height: size.height),
                                  contents: artwork)
            isDragging = true
            dragActivityChanged?(true)
            NotchService.shared.capturePreviewDragChanged(true)
            beginDraggingSession(with: [item], event: press, source: self)
        }

        func draggingSession(_ session: NSDraggingSession,
                             sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
        func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }
        func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint,
                             operation: NSDragOperation) { finishDrag() }
    }
}
