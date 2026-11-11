// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// A transient video capture preview that matches the image quick preview experience:
/// displays thumbnail, supports double-click Quick Look, drag-and-drop, Download/Save,
/// Copy, Share, temporary recording links, and Edit (with scissors icon).
final class RecorderQuickPreviewController {
    static let shared = RecorderQuickPreviewController()

    private var url: URL?
    private var panel: RecorderQuickPreviewPanel?
    private var keyMonitor: Any?
    private var dismissWork: DispatchWorkItem?
    private var closePolicy = CapturePreviewClosePolicy.fiveSeconds
    private var focusLossObserver: NSObjectProtocol?
    /// A history-opened preview is navigation, not a transient capture confirmation.
    private var openedFromHistory = false
    private var quickLinkTask: Task<Void, Never>?
    private var quickLinkGeneration = UUID()
    private var closed = false
    private var pointerInside = false
    private var systemSharing = false
    private var menuOpen = false
    private var quickLookOpen = false
    private var shownInNotch = false
    private let presentationID = UUID()
    private let shareAnchor = ShelfSharePickerAnchor.Anchor()
    private let sharePresenter = ShelfSharePresenter()
    private let model = RecorderQuickPreviewModel(loadThumbnail: RecentCaptureService.recordingThumbnail)

    private init() {}

    func show(url: URL, initialThumbnail: CGImage? = nil,
              inNotch: Bool = CapturePresentationRouting.opensInIsland(origin: .external),
              openedFromHistory: Bool = false) {
        close()
        self.url = url
        self.closed = false
        self.pointerInside = false
        self.systemSharing = false
        self.menuOpen = false
        self.quickLookOpen = false
        self.quickLinkGeneration = UUID()
        self.openedFromHistory = openedFromHistory
        closePolicy = CapturePreviewClosePolicy.current()
        model.show(url: url, initialThumbnail: initialThumbnail)
        Task { @MainActor [weak self] in
            guard let self, !self.closed, self.url == url else { return }
            self.model.sharedRecord = QuickLinkMediaIndex.shared.latestRecording(for: url)
        }

        let wantsNotch = inNotch && NotchSupport.routesCapturePreviews()
            && NotchService.shared.acceptsSystemFeedback

        let content = RecorderQuickPreviewView(
            url: url,
            model: model,
            shareAnchor: shareAnchor,
            embedded: wantsNotch,
            onClose: { [weak self] in self?.close() },
            onEdit: { [weak self] in self?.performEdit() },
            onCopy: { [weak self] in self?.performCopy() },
            onDownload: { [weak self] in self?.performDownload() },
            onSaveAs: { [weak self] in self?.performSaveAs() },
            onShare: { [weak self] in self?.performSystemShare() },
            onQuickLink: { [weak self] duration in self?.performQuickLink(duration) },
            onCopyLink: { [weak self] in self?.copyQuickLink() },
            onDelete: { [weak self] in self?.performDelete() },
            onContextDelete: { [weak self] in self?.confirmContextDelete() },
            onQuickLook: { [weak self] in self?.performQuickLook() },
            onHoverChanged: { [weak self] inside in self?.hoverChanged(inside) },
            applicationsForMenu: { [weak self] in self?.applicationsForMenu() ?? [] },
            openWith: { [weak self] app in self?.openWith(app) },
            revealInFinder: { [weak self] in self?.revealInFinder() },
            onMenuChanged: { [weak self] open in self?.menuChanged(open) }
        )

        if wantsNotch, NotchService.shared.presentCapture(
            id: presentationID,
            content: AnyView(content),
            actions: AnyView(content.toolbar),
            height: 138,
            fromHistory: openedFromHistory,
            imageOverlay: true,
            takeFocus: UserDefaults.standard.bool(forKey: DefaultsKey.screenshotPreviewTakesFocus),
            // An unpinned video preview must close on outside clicks, just
            // like the screenshot preview. Pinning still blocks collapse.
            closeOnCollapse: closePolicy.closesOnIslandCollapse,
            fallback: { [weak self] in
                guard let self else { return }
                self.shownInNotch = false
                self.pointerInside = false
                if let keyMonitor = self.keyMonitor { NSEvent.removeMonitor(keyMonitor) }
                self.keyMonitor = nil
                self.show(url: url, initialThumbnail: self.model.thumbnail, inNotch: false,
                          openedFromHistory: openedFromHistory)
            },
            close: { [weak self] in self?.close() },
            hover: { [weak self] inside in self?.hoverChanged(inside) }
        ) {
            shownInNotch = true
            if let window = NotchService.shared.presentationWindow { installKeyMonitor(for: window) }
            scheduleAutoDismiss()
            if closePolicy == .focusLost, let window = NotchService.shared.presentationWindow {
                observeFocusLoss(of: window)
            }
            return
        }

        let size = CGSize(width: 340, height: 158)
        let host = NSHostingController(rootView: content)
        let previewPanel = RecorderQuickPreviewPanel(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        previewPanel.contentViewController = host
        previewPanel.isReleasedWhenClosed = false
        previewPanel.isOpaque = false
        previewPanel.backgroundColor = .clear
        previewPanel.hasShadow = true
        previewPanel.isMovableByWindowBackground = false
        previewPanel.hidesOnDeactivate = false
        previewPanel.level = .statusBar
        previewPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        let frame = previewFrame(for: size)
        previewPanel.setFrame(frame, display: false)
        self.panel = previewPanel
        installKeyMonitor(for: previewPanel)
        previewPanel.orderFrontRegardless()
        if UserDefaults.standard.bool(forKey: DefaultsKey.screenshotPreviewTakesFocus) {
            previewPanel.makeKey()
        }
        scheduleAutoDismiss()
        if closePolicy == .focusLost { observeFocusLoss(of: previewPanel) }
    }

    func close() {
        guard !closed else { return }
        closed = true
        if let focusLossObserver {
            NotificationCenter.default.removeObserver(focusLossObserver)
            self.focusLossObserver = nil
        }
        dismissWork?.cancel()
        dismissWork = nil
        quickLinkTask?.cancel()
        quickLinkTask = nil
        quickLinkGeneration = UUID()
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if shownInNotch {
            NotchService.shared.removeCapture(id: presentationID)
            shownInNotch = false
        }
        panel?.orderOut(nil)
        panel = nil
        url = nil
        model.close()
    }

    private func hoverChanged(_ inside: Bool) {
        pointerInside = inside
        dismissWork?.cancel()
        dismissWork = nil
        if !inside { scheduleAutoDismiss() }
    }

    private func scheduleAutoDismiss() {
        guard !closed, !quickLookOpen, !pointerInside, !systemSharing, !menuOpen,
              !model.sharing, let timeout = closePolicy.timeout else { return }
        dismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.close() }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: work)
    }

    private func observeFocusLoss(of window: NSWindow) {
        guard focusLossObserver == nil else { return }
        focusLossObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: window, queue: .main
        ) { [weak self] _ in
            guard let self, !self.closed, !self.quickLookOpen, !self.systemSharing,
                  !self.menuOpen, !self.model.sharing else { return }
            self.close()
        }
    }

    private func menuChanged(_ open: Bool) {
        menuOpen = open
        if shownInNotch { NotchService.shared.setCaptureMenuInteractionActive(open) }
        dismissWork?.cancel()
        dismissWork = nil
        if !open { scheduleAutoDismiss() }
    }

    private func previewFrame(for size: CGSize) -> CGRect {
        let pointer = NSEvent.mouseLocation
        let screens = NSScreen.screens.map { (frame: $0.frame, visibleFrame: $0.visibleFrame) }
        // An automatic floating preview is anchored to the pointer,
        // not the origin of the display (which previously looked like a corner).
        let cursorAnchor = CGRect(origin: pointer, size: CGSize(width: 1, height: 1))
        let visibleFrame = ScreenshotSupport.quickPreviewVisibleFrame(
            anchor: cursorAnchor,
            pointer: pointer,
            screens: screens,
            fallback: NSScreen.pointerVisibleFrame)
        return ScreenshotSupport.quickPreviewFrame(
            size: size,
            anchor: cursorAnchor,
            pointer: pointer,
            visibleFrame: visibleFrame,
            position: ScreenshotSupport.QuickPreviewPosition.current())
    }

    private func installKeyMonitor(for panel: NSPanel) {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak panel] event in
            guard let self, !self.closed, let panel, panel.isVisible, event.window === panel,
                  !self.shownInNotch || (!ScreenshotSelectionController.isSessionOnScreen
                      && NotchService.shared.isCaptureVisible(id: self.presentationID)),
                  panel.attachedSheet == nil, !(panel.firstResponder is NSText),
                  !ShortcutCapture.isCapturing else { return event }
            guard let action = RecorderPreviewShortcut.match(keyCode: event.keyCode,
                characters: event.charactersIgnoringModifiers, modifiers: event.modifierFlags) else { return event }
            switch action {
            case .copy: self.performCopy()
            case .save: self.performDownload()
            case .saveAs: self.performSaveAs()
            case .close: self.close()
            case .quickLook: self.performQuickLook()
            case .edit: self.performEdit()
            }
            return nil
        }
    }

    private func performEdit() {
        guard AppFeature.screenRecorder.isAvailable, let url else { return }
        close()
        Task { @MainActor in
            let take = await Task.detached(priority: .userInitiated) {
                RecorderTakeStore.shared.importVideo(at: url)
            }.value
            guard let take else { NSSound.beep(); return }
            MediaEditorFileSupport.presentIfEnabled(AppFeature.screenRecorder.isAvailable, present: {
                ScreenRecorderService.shared.openEditor(with: take, preservedRecordingURL: url)
            }, discard: { RecorderTakeStore.shared.delete(take) })
        }
    }

    /// Match screenshot quick-preview actions: success feedback survives a
    /// dismissed preview, and a pinned Island must collapse as well.
    private func completeQuickAction() {
        let wasInNotch = shownInNotch
        close()
        if wasInNotch { NotchService.shared.collapse() }
    }

    private func performCopy() {
        guard let url else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.writeObjects([url as NSURL]) else {
            NSSound.beep()
            return
        }
        pasteboard.declareLatticeSource()
        QuickToolHUD.show(icon: "doc.on.doc", message: FeatureStrings.recorder(L10n.shared.language).copiedHUD)
        completeQuickAction()
    }

    private func performDownload() {
        guard let url else { return }
        let strings = FeatureStrings.recorder(L10n.shared.language)
        let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
        do {
            let destination = try CaptureSaveLocation.withFolder { folder in
                try CaptureSaveNaming.copyFile(from: url, in: folder,
                                               date: (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date(),
                                               media: .recording, ext: ext)
            }
            let folder = destination.deletingLastPathComponent().lastPathComponent
            QuickToolHUD.show(icon: "square.and.arrow.down",
                              message: String(format: strings.savedHUDFormat, folder))
            completeQuickAction()
        } catch {
            // Cancel means cancel, not a second Save panel. Report actual
            // write/bookmark failures instead of silently changing workflows.
            CaptureSaveLocation.presentSaveError(error)
            scheduleAutoDismiss()
        }
    }

    private func performSaveAs() {
        guard let url else { return }
        dismissWork?.cancel()
        dismissWork = nil
        let panel = NSSavePanel()
        panel.nameFieldStringValue = url.lastPathComponent
        panel.canCreateDirectories = true
        let response = ScreenshotWindowLayering.runModalPanel(panel, above: self.panel)
        guard response == .OK, let target = panel.url else {
            scheduleAutoDismiss()
            return
        }
        do {
            try RecorderFileCopy.save(from: url, to: target, replacing: true)
            let strings = FeatureStrings.recorder(L10n.shared.language)
            let folder = target.deletingLastPathComponent().lastPathComponent
            QuickToolHUD.show(icon: "square.and.arrow.down",
                              message: String(format: strings.savedHUDFormat, folder))
            completeQuickAction()
        } catch {
            NSSound.beep()
            scheduleAutoDismiss()
        }
    }

    /// Present the system picker from the *visible* window. The zero-sized
    /// representable behind the embedded toolbar is not a reliable popover anchor.
    private func performSystemShare() {
        guard !closed, !systemSharing, let url else { return }
        dismissWork?.cancel()
        dismissWork = nil
        let window = shownInNotch ? NotchService.shared.presentationWindow : panel
        guard let window, let content = window.contentView, window.isVisible else {
            NSSound.beep()
            scheduleAutoDismiss()
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKey()
        let pointInContent = content.convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        let bounds = content.bounds
        let anchorPoint = CGPoint(x: min(max(pointInContent.x, bounds.minX + 1), bounds.maxX - 1),
                                  y: min(max(pointInContent.y, bounds.minY + 1), bounds.maxY - 1))
        systemSharing = true
        let shown = sharePresenter.present(for: [url], from: content,
                                          relativeTo: CGRect(origin: anchorPoint,
                                                             size: CGSize(width: 1, height: 1))) { [weak self] chosen in
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

    /// The recording sharing endpoint only accepts a validated MP4 artifact.
    /// Reuse the same import/export pipeline as the recorder editor; never send
    /// the original MOV directly or block the main thread while encoding.
    private func performQuickLink(_ duration: RecordingShareDuration) {
        guard !closed, !model.sharing, let source = url else { return }
        // Encoding and upload can outlive the usual preview timeout.
        dismissWork?.cancel()
        dismissWork = nil
        model.sharing = true
        let generation = quickLinkGeneration
        quickLinkTask = Task { @MainActor [weak self] in
            let take = await Task.detached(priority: .userInitiated) {
                RecorderTakeStore.shared.importVideo(at: source)
            }.value
            guard let take else {
                if let self, !Task.isCancelled, self.quickLinkGeneration == generation {
                    self.finishQuickLink(failed: true)
                }
                return
            }
            defer { RecorderTakeStore.shared.delete(take) }
            guard let self, !Task.isCancelled, !self.closed,
                  self.quickLinkGeneration == generation else { return }
            let exporter = RecorderExporter()
            let result = await exporter.exportForSharing(take: take,
                                                         document: RecorderEditDocument()) { _ in }
            guard !Task.isCancelled, !self.closed, self.quickLinkGeneration == generation else {
                result.artifact?.discard()
                return
            }
            if let artifact = result.artifact {
                do {
                    let record = try await RecordingShareService.shared.createLink(
                        artifact: artifact, duration: duration)
                    guard !Task.isCancelled, !self.closed,
                          self.quickLinkGeneration == generation,
                          UserDefaults.standard.bool(forKey: DefaultsKey.recorderSharingEnabled) else {
                        // A closed preview or a preference change may race
                        // upload completion. Never abandon an active URL.
                        Task { @MainActor in
                            try? await RecordingShareService.shared.delete(record)
                        }
                        if !self.closed && self.quickLinkGeneration == generation {
                            self.finishQuickLink(failed: true)
                        }
                        return
                    }
                    QuickLinkMediaIndex.shared.rememberRecording(source, record: record)
                    self.model.sharedRecord = record
                    guard RecordingShareService.shared.copy(record.url) else {
                        self.finishQuickLink(failed: true)
                        return
                    }
                    QuickToolHUD.show(icon: "link",
                                      message: FeatureStrings.screenshot(L10n.shared.language).sharedHUD)
                    self.finishQuickLink(failed: false)
                    self.completeQuickAction()
                } catch {
                    if self.quickLinkGeneration == generation && !Task.isCancelled {
                        self.finishQuickLink(failed: true)
                    }
                }
            } else if self.quickLinkGeneration == generation {
                self.finishQuickLink(failed: true)
            }
        }
    }

    private func finishQuickLink(failed: Bool) {
        guard !closed else { return }
        model.sharing = false
        quickLinkTask = nil
        if failed {
            NSSound.beep()
            QuickToolHUD.show(icon: "link",
                message: FeatureStrings.recorderShare(L10n.shared.language).failed)
        }
        scheduleAutoDismiss()
    }

    private func copyQuickLink() {
        Task { @MainActor [weak self] in
            guard let self, !self.closed, let source = self.url,
                  let record = QuickLinkMediaIndex.shared.latestRecording(for: source) else { return }
            self.model.sharedRecord = record
            self.dismissWork?.cancel()
            self.dismissWork = nil
            guard RecordingShareService.shared.copy(record.url) else {
                self.finishQuickLink(failed: true)
                return
            }
            QuickToolHUD.show(icon: "link",
                message: FeatureStrings.screenshot(L10n.shared.language).sharedHUD)
            self.completeQuickAction()
        }
    }

    /// Context menus cannot use the inline two-click toolbar state, so
    /// explicitly confirm before entering the shared deletion operation.
    private func confirmContextDelete() {
        // Let AppKit close the context menu before presenting a native alert.
        // Opening it synchronously from a menu action can leave its buttons
        // with the wrong appearance or keyboard focus.
        DispatchQueue.main.async { [weak self] in
            self?.presentContextDeleteConfirmation()
        }
    }

    private func presentContextDeleteConfirmation() {
        guard !closed else { return }
        let notice = CapturePreviewNoticeStrings.localized(L10n.shared.language)
        let label = notice.trashAction
        guard NotchIslandAlert.confirmDestructive(
            title: label, message: "", action: label,
            cancel: FeatureStrings.screenshot(L10n.shared.language).cancel,
            above: shownInNotch ? NotchService.shared.presentationWindow : panel) else { return }
        performDelete()
    }

    /// Called only after the inline red checkmark is confirmed.
    private func performDelete() {
        guard !closed, !model.sharing, let source = url else { return }
        dismissWork?.cancel()
        dismissWork = nil
        let owner = shownInNotch ? NotchService.shared.presentationWindow : panel
        do {
            try FileManager.default.trashItem(at: source, resultingItemURL: nil)
            RecentCaptureService.shared.removeRecording(at: source)
            if openedFromHistory {
                if shownInNotch && NotchService.shared.isCaptureVisible(id: presentationID) {
                    NotchService.shared.showCaptureHistory()
                } else {
                    close()
                    RecentCaptureService.shared.showHistoryWindow(origin: .floatingWindow)
                }
            } else {
                let wasInNotch = shownInNotch
                close()
                if wasInNotch { NotchService.shared.collapse() }
            }
        } catch {
            NSSound.beep()
            let failure = NSAlert()
            let failureText = CapturePreviewNoticeStrings.recordingFailure(L10n.shared.language)
            failure.messageText = failureText.title
            failure.informativeText = failureText.message
            failure.alertStyle = .warning
            failure.addButton(withTitle: "OK")
            _ = NotchIslandAlert.run(failure, above: owner)
            scheduleAutoDismiss()
        }
    }

    private func performQuickLook() {
        guard !closed, let url else { return }
        dismissWork?.cancel()
        dismissWork = nil
        if ScreenshotQuickLookController.shared.isVisible {
            ScreenshotQuickLookController.shared.close()
            return
        }
        quickLookOpen = true
        let shown = ScreenshotQuickLookController.shared.show(
            url: url, owner: panel ?? NotchService.shared.presentationWindow,
            onDismiss: { [weak self] in
                guard let self, self.url == url else { return }
                self.quickLookOpen = false
                if !self.closed { self.scheduleAutoDismiss() }
            })
        if !shown {
            quickLookOpen = false
            NSSound.beep()
            scheduleAutoDismiss()
        }
    }

    private func applicationsForMenu() -> [URL] {
        guard let url else { return [] }
        return NSWorkspace.shared.urlsForApplications(toOpen: url).sorted {
            FileManager.default.displayName(atPath: $0.path).localizedStandardCompare(
                FileManager.default.displayName(atPath: $1.path)) == .orderedAscending
        }
    }

    private func openWith(_ app: URL) {
        guard let url else { return }
        close()
        NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }

    private func revealInFinder() {
        guard let url else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
