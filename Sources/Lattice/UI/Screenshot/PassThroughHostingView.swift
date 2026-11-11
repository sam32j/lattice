// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import Carbon.HIToolbox

final class PassThroughHostingView<Content: View>: NSHostingView<Content> {
    var passesThrough = true
    var acceptsFirstClick = false
    var isHovered = false
    /// Only the actual visible capture controls receive clicks. The large
    /// hosting frame contains empty space that must remain draggable.
    /// Nil means the entire host is interactive (the standalone full-screen pill).
    var interactiveRegions: [CGRect]? {
        didSet { refreshCaptureCursor() }
    }
    /// Capture selection drags keep the crosshair, even when they pass over a
    /// button. Both the screenshot and recording chooser use the same host.
    var selectionIsInProgress: (() -> Bool)?
    private var captureCursorTrackingArea: NSTrackingArea?
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
    /// SwiftUI lays out its anchor bounds from the top left. NSHostingView
    /// may be either flipped or non-flipped; normalize AppKit input before
    /// comparing it to the resolved SwiftUI regions.
    private func swiftUIPoint(from local: NSPoint) -> NSPoint {
        isFlipped ? local : NSPoint(x: local.x, y: bounds.maxY - local.y)
    }

    private func appKitRect(from swiftUIRect: CGRect) -> CGRect {
        guard !isFlipped else { return swiftUIRect }
        return CGRect(x: swiftUIRect.minX,
                      y: bounds.maxY - swiftUIRect.maxY,
                      width: swiftUIRect.width, height: swiftUIRect.height)
    }

    func containsCaptureControl(at local: NSPoint) -> Bool {
        guard !passesThrough, bounds.contains(local), selectionIsInProgress?() != true else {
            return false
        }
        guard let interactiveRegions else { return true }
        let target = swiftUIPoint(from: local)
        return interactiveRegions.contains { !$0.isEmpty && $0.contains(target) }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // AppKit provides superview coordinates, not coordinates local to the
        // host. Hit-testing and cursor feedback use the same normalized bounds.
        guard containsCaptureControl(at: convert(point, from: superview)) else { return nil }
        return super.hitTest(point)
    }
    /// Use the same hit regions for pointer feedback and for clicks. This
    /// matters because the hosting view is substantially wider than the strip.
    func captureCursor(at point: NSPoint) -> NSCursor {
        containsCaptureControl(at: point) ? .arrow : .crosshair
    }

    func refreshCaptureCursor() {
        window?.invalidateCursorRects(for: self)
        guard let window, !isHidden else { return }
        let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        if bounds.contains(point) { captureCursor(at: point).set() }
    }

    override func resetCursorRects() {
        discardCursorRects()
        guard !passesThrough, selectionIsInProgress?() != true else {
            addCursorRect(bounds, cursor: .crosshair)
            return
        }
        if let interactiveRegions {
            for region in interactiveRegions where !region.isEmpty {
                let visible = bounds.intersection(appKitRect(from: region))
                if !visible.isEmpty { addCursorRect(visible, cursor: .arrow) }
            }
        } else {
            // The standalone Full Screen button fills its hosting frame.
            addCursorRect(bounds, cursor: .arrow)
        }
    }

    override func updateTrackingAreas() {
        if let captureCursorTrackingArea { removeTrackingArea(captureCursorTrackingArea) }
        super.updateTrackingAreas()
        let area = NSTrackingArea(rect: .zero,
                                  options: [.activeAlways, .inVisibleRect, .mouseMoved,
                                            .mouseEnteredAndExited, .cursorUpdate],
                                  owner: self)
        captureCursorTrackingArea = area
        addTrackingArea(area)
    }

    override func cursorUpdate(with event: NSEvent) {
        captureCursor(at: convert(event.locationInWindow, from: nil)).set()
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        cursorUpdate(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        cursorUpdate(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NSCursor.crosshair.set()
    }
}
