// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// Nonactivating until the focus session has secured main/key ownership.
class ScreenshotCapturePanel: OverlayPanel {
    var ownsCaptureFocus = false
    private var testIsKey = false
    private var testIsMain = false

    init(screenRect: CGRect) {
        super.init(contentRect: screenRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        worksWhenModal = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { ownsCaptureFocus }

    override var isKeyWindow: Bool { super.isKeyWindow || (testIsKey && isVisible) }
    override var isMainWindow: Bool { super.isMainWindow || (testIsMain && ownsCaptureFocus && isVisible) }

    override func makeKey() {
        testIsKey = true
        super.makeKey()
    }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        testIsKey = true
        super.makeKeyAndOrderFront(sender)
    }

    override func resignKey() {
        testIsKey = false
        super.resignKey()
    }

    override func makeMain() {
        if canBecomeMain { testIsMain = true }
        super.makeMain()
    }

    override func resignMain() {
        testIsMain = false
        super.resignMain()
    }

    override func orderOut(_ sender: Any?) {
        testIsKey = false
        testIsMain = false
        super.orderOut(sender)
    }

    /// Flipped capture coordinates: a larger bottom clearance moves the bar up.
    static func guideFrame(in bounds: CGRect, preferredHeight: CGFloat) -> CGRect {
        let width = min(620, max(0, bounds.width - 32))
        let height = min(preferredHeight, max(0, bounds.height - 32))
        return CGRect(x: bounds.midX - width / 2,
                      y: max(bounds.minY + 16, bounds.maxY - height - 102),
                      width: width, height: height)
    }
}
