// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import QuickLookUI

/// Quick Look stays in this process; it never opens Preview.app or an editor.
final class ScreenshotQuickLookController: NSResponder, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = ScreenshotQuickLookController()
    private(set) var previewURL: URL?
    private weak var owner: NSWindow?
    private var previousResponder: NSResponder?
    private var keyMonitor: Any?
    private var previewPanel: QLPreviewPanel?
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
        previewURL = url
        self.owner = owner
        previousResponder = NSApp.nextResponder
        nextResponder = previousResponder
        NSApp.nextResponder = self
        guard let panel = QLPreviewPanel.shared() else { close(); return false }
        previewPanel = panel
        panel.updateController()
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak panel] event in
            guard event.window === panel, event.keyCode == 53 else { return event }
            self?.close()
            return nil
        }
        return panel.isVisible
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
        previewPanel?.orderOut(nil)
        previewPanel?.dataSource = nil
        previewPanel?.delegate = nil
        previewPanel = nil
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        if NSApp.nextResponder === self { NSApp.nextResponder = previousResponder }
        previousResponder = nil
        nextResponder = nil
        if let url = previewURL { try? FileManager.default.removeItem(at: url) }
        previewURL = nil
        if returnFocus, owner?.isVisible == true { owner?.makeKey() }
        owner = nil
    }
}
