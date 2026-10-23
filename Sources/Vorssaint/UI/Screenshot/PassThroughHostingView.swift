// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import Carbon.HIToolbox

final class PassThroughHostingView<Content: View>: NSHostingView<Content> {
    var passesThrough = true
    var acceptsFirstClick = false
    var isHovered = false
    /// The guide gets its frame from the overlay's layout. Its changing
    /// ideal size must not resize the shielding window. Other hosts keep
    /// intrinsic sizing, including the full-screen button measured by layout.
    convenience init(fixedFrameRootView rootView: Content) {
        self.init(rootView: rootView)
        sizingOptions = []
        safeAreaRegions = []
        translatesAutoresizingMaskIntoConstraints = true
    }
    /// Capture actions remain clickable while the Dynamic Island panel owns
    /// key focus. Keep both parts of that policy on the interactive host.
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
