// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// A transient video capture preview that matches the image quick preview experience:
/// displays thumbnail, supports double-click Quick Look, drag-and-drop, Download/Save,
/// Copy, Share (via native share sheet, not quick link), and Edit (with scissors icon).
final class RecorderQuickPreviewController {
    static let shared = RecorderQuickPreviewController()

    private var url: URL?
    private var panel: RecorderQuickPreviewPanel?
    private var keyMonitor: Any?
    private var dismissWork: DispatchWorkItem?
    private let autoDismissDuration = ScreenshotSupport.recoveryPreviewDismissInterval
    private var closed = false
    private var pointerInside = false
    private var systemSharing = false
    private var menuOpen = false
    private var shownInNotch = false
    private let presentationID = UUID()
    private let shareAnchor = ShelfSharePickerAnchor.Anchor()
    private let model = RecorderQuickPreviewModel(loadThumbnail: RecentCaptureService.recordingThumbnail)

    private init() {}

    func show(url: URL, initialThumbnail: CGImage? = nil, inNotch: Bool = true) {
        close()
        self.url = url
        self.closed = false
        self.pointerInside = false
        self.systemSharing = false
        self.menuOpen = false
        model.show(url: url, initialThumbnail: initialThumbnail)

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
            takeFocus: false,
            closeOnCollapse: false,
            fallback: { [weak self] in
                guard let self else { return }
                self.shownInNotch = false
                self.pointerInside = false
                if let keyMonitor = self.keyMonitor { NSEvent.removeMonitor(keyMonitor) }
                self.keyMonitor = nil
                self.show(url: url, initialThumbnail: self.model.thumbnail, inNotch: false)
            },
            close: { [weak self] in self?.close() },
            hover: { [weak self] inside in self?.hoverChanged(inside) }
        ) {
            shownInNotch = true
            if let window = NotchService.shared.presentationWindow { installKeyMonitor(for: window) }
            scheduleAutoDismiss()
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
        previewPanel.hidesOnDeactivate = false
        previewPanel.level = .statusBar
        previewPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        let frame = previewFrame(for: size)
        previewPanel.setFrame(frame, display: false)
        self.panel = previewPanel
        installKeyMonitor(for: previewPanel)
        previewPanel.orderFrontRegardless()
        scheduleAutoDismiss()
    }

    func close() {
        guard !closed else { return }
        closed = true
        dismissWork?.cancel()
        dismissWork = nil
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
        guard !closed, !pointerInside, !systemSharing, !menuOpen else { return }
        dismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.close() }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissDuration, execute: work)
    }

    private func menuChanged(_ open: Bool) {
        menuOpen = open
        dismissWork?.cancel()
        dismissWork = nil
        if !open { scheduleAutoDismiss() }
    }

    private func previewFrame(for size: CGSize) -> CGRect {
        let pointer = NSEvent.mouseLocation
        let screens = NSScreen.screens.map { (frame: $0.frame, visibleFrame: $0.visibleFrame) }
        let visibleFrame = ScreenshotSupport.quickPreviewVisibleFrame(
            anchor: .zero,
            pointer: pointer,
            screens: screens,
            fallback: NSScreen.pointerVisibleFrame)
        return ScreenshotSupport.quickPreviewFrame(
            size: size,
            anchor: .zero,
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
    }

    private func performDownload() {
        guard let url else { return }
        let strings = FeatureStrings.recorder(L10n.shared.language)
        let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
        let destination = ScreenRecorderService.saveDestination(strings: strings, fileExtension: ext)
        do {
            try RecorderFileCopy.save(from: url, to: destination, replacing: false)
            let folder = destination.deletingLastPathComponent().lastPathComponent
            QuickToolHUD.show(icon: "square.and.arrow.down",
                              message: String(format: strings.savedHUDFormat, folder))
        } catch {
            performSaveAs()
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
            close()
        } catch {
            NSSound.beep()
            scheduleAutoDismiss()
        }
    }

    private func performSystemShare() {
        guard !closed, !systemSharing, let url else { return }
        dismissWork?.cancel()
        dismissWork = nil
        systemSharing = true
        let shown = shareAnchor.present([url]) { [weak self] chosen in
            guard let self else { return }
            self.systemSharing = false
            if chosen { self.close() } else { self.scheduleAutoDismiss() }
        }
        if !shown {
            systemSharing = false
            scheduleAutoDismiss()
        }
    }

    private func performQuickLook() {
        guard let url else { return }
        dismissWork?.cancel()
        if ScreenshotQuickLookController.shared.isVisible {
            ScreenshotQuickLookController.shared.close()
            return
        }
        if !ScreenshotQuickLookController.shared.show(url: url, owner: panel) {
            NSSound.beep()
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
