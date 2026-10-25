// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// Native destination over the existing status button; clicks still belong
/// to that button, including its right-click menu and normal highlighting.
final class StatusMediaDropView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        autoresizingMask = [.width, .height]
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { nil }

    override func mouseDown(with event: NSEvent) { (superview as? NSButton)?.mouseDown(with: event) }
    override func rightMouseDown(with event: NSEvent) { (superview as? NSButton)?.rightMouseDown(with: event) }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let accepted = MediaEditorFileOpener.shared.canOpen(MediaEditorFileSupport.urls(from: sender.draggingPasteboard))
        (superview as? NSButton)?.highlight(accepted)
        return accepted ? .copy : []
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { draggingEntered(sender) }
    override func draggingExited(_ sender: NSDraggingInfo?) { (superview as? NSButton)?.highlight(false) }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { draggingEntered(sender) != [] }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        (superview as? NSButton)?.highlight(false)
        let urls = MediaEditorFileSupport.urls(from: sender.draggingPasteboard)
        guard MediaEditorFileOpener.shared.canOpen(urls) else { return false }
        return MediaEditorFileOpener.shared.open(urls)
    }
}
