// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// Nonactivating until the focus session has secured main/key ownership.
class ScreenshotCapturePanel: OverlayPanel {
    var ownsCaptureFocus = false
    init(screenRect: CGRect) {
        super.init(contentRect: screenRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { ownsCaptureFocus }

    /// Flipped capture coordinates: a larger bottom clearance moves the bar up.
    static func guideFrame(in bounds: CGRect, preferredHeight: CGFloat) -> CGRect {
        let width = min(620, max(0, bounds.width - 32))
        let height = min(preferredHeight, max(0, bounds.height - 32))
        return CGRect(x: bounds.midX - width / 2,
                      y: max(bounds.minY + 16, bounds.maxY - height - 102),
                      width: width, height: height)
    }
}
