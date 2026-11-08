// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import QuickLookUI

/// Use the system's original Quick Look window for screenshots and recordings.
/// The shared QLPreviewPanel follows the key-window responder chain, so its
/// window level needs to be maintained while it is previewing Island content.
final class ScreenshotQuickLookController: NSResponder, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = ScreenshotQuickLookController()
    private(set) var previewURL: URL?
    private weak var owner: NSWindow?
    private var previousResponder: NSResponder?
    private var keyMonitor: Any?
    private var ownerClickMonitor: Any?
    private var previewPanel: QLPreviewPanel?
    private var originalLevel: NSWindow.Level?
    private var isTemporaryURL = false
    var presentationWindow: NSWindow? { previewPanel }
    var isVisible: Bool { previewPanel?.isVisible == true }
    var protectedWindowIDs: Set<CGWindowID> {
        guard let previewPanel, previewPanel.isVisible, previewPanel.windowNumber > 0 else { return [] }
        return [CGWindowID(previewPanel.windowNumber)]
    }

    @discardableResult func show(image: CGImage, scale: CGFloat, owner: NSWindow?) -> Bool {
        close()
        let bitmap = NSBitmapImageRep(cgImage: image)
        bitmap.size = NSSize(width: CGFloat(image.width) / max(1, scale),
                             height: CGFloat(image.height) / max(1, scale))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Lattice-QuickLook-\(UUID().uuidString).png")
        do {
            guard let data = bitmap.representation(using: .png, properties: [:]) else { return false }
            try data.write(to: url, options: .withoutOverwriting)
        } catch { return false }
        return present(url: url, temporary: true, owner: owner)
    }

    @discardableResult func show(url: URL, owner: NSWindow? = nil) -> Bool {
        close()
        return present(url: url, temporary: false, owner: owner)
    }

    private func present(url: URL, temporary: Bool, owner: NSWindow?) -> Bool {
        previewURL = url
        isTemporaryURL = temporary
        self.owner = owner
        // A native Quick Look panel needs the application to be active to
        // receive its keyboard events. Opening from a global shortcut can
        // arrive while another app remains frontmost; make Lattice active
        // before selecting the shared panel's responder-chain controller.
        NSApp.activate(ignoringOtherApps: true)
        // The native QLPreviewPanel discovers its controller through the
        // responder chain. Leave this controller in the chain even when the
        // Island, rather than Quick Look, becomes the key window.
        previousResponder = NSApp.nextResponder
        nextResponder = previousResponder
        NSApp.nextResponder = self
        guard let panel = QLPreviewPanel.shared() else { close(); return false }
        previewPanel = panel
        originalLevel = panel.level
        panel.alphaValue = 1
        panel.updateController()
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
        maintainPreviewLevel()

        // Quick Look may reset its native window level when the key/main
        // window changes (including a click on the Quick Look title bar).
        // Reassert the level after AppKit completes that transition; do not
        // change the panel's native style, sizing, or responder ownership.
        for notification in [NSWindow.didBecomeKeyNotification, NSWindow.didBecomeMainNotification] {
            NotificationCenter.default.addObserver(self,
                selector: #selector(windowDidGainFocus(_:)), name: notification, object: nil)
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak panel] event in
            guard let self, self.isVisible,
                  event.window === panel || (self.owner != nil && event.window === self.owner) else { return event }
            let imageSpace = url.pathExtension.lowercased() == "png" && event.keyCode == 49
                && event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty
            if event.keyCode == 53 || imageSpace || ScreenshotWindowLayering.isQuickLookShortcut(event) {
                self.close()
                return nil
            }
            return event
        }
        ownerClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self, weak owner] event in
            guard let self, self.isVisible, event.window === owner else { return event }
            // An explicit click on a pinned Island is a request to return
            // focus to Lattice, not only to hide Quick Look. Do this before
            // closing so the keyboard no longer belongs to the background app.
            NSApp.activate(ignoringOtherApps: true)
            self.close()
            // Clicking the Island dismisses Quick Look, not the control below.
            return nil
        }
        return panel.isVisible
    }

    @objc private func windowDidGainFocus(_ notification: Notification) {
        guard let focused = notification.object as? NSWindow,
              focused === previewPanel || focused === owner else { return }
        maintainPreviewLevel()
        // QLPreviewPanel can adjust its level again at the end of the native
        // focus handoff. Restore it once more after that AppKit pass.
        DispatchQueue.main.async { [weak self] in self?.maintainPreviewLevel() }
    }

    private func maintainPreviewLevel() {
        guard let panel = previewPanel, panel.isVisible else { return }
        let level = ScreenshotWindowLayering.previewLevel(above: owner)
        if panel.level != level { panel.level = level }
    }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { previewURL != nil }
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = self
        panel.delegate = self
    }
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
    }
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { previewURL == nil ? 0 : 1 }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        previewURL.map { $0 as NSURL }
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { close(); return false }
    override func cancelOperation(_ sender: Any?) { close() }

    func close() {
        let returnFocus = previewPanel?.isKeyWindow == true
        for notification in [NSWindow.didBecomeKeyNotification, NSWindow.didBecomeMainNotification] {
            NotificationCenter.default.removeObserver(self, name: notification, object: nil)
        }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        if let ownerClickMonitor { NSEvent.removeMonitor(ownerClickMonitor) }
        ownerClickMonitor = nil

        if let panel = previewPanel {
            // Keep the native panel above the Island until it is fully out of
            // the compositor. Restoring its old level synchronously caused the
            // brief under-Island flash on Cmd+Y dismissal.
            panel.alphaValue = 0
            panel.orderOut(nil)
            let level = originalLevel
            DispatchQueue.main.async { [weak self, weak panel] in
                guard let panel, !panel.isVisible,
                      self?.previewPanel !== panel else { return }
                if let level { panel.level = level }
                panel.alphaValue = 1
            }
        }
        previewPanel = nil
        originalLevel = nil
        if NSApp.nextResponder === self { NSApp.nextResponder = previousResponder }
        previousResponder = nil
        nextResponder = nil
        if let url = previewURL, isTemporaryURL { try? FileManager.default.removeItem(at: url) }
        previewURL = nil
        isTemporaryURL = false
        if returnFocus, owner?.isVisible == true { owner?.makeKey() }
        owner = nil
    }
}
