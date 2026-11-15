// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit

/// The floating screenshot and recording previews arrive and leave with a
/// short fade and rise instead of popping in and out. Only the position and
/// opacity animate, so the preview's content never relayouts mid-transition.
enum FloatingPreviewTransition {
    private static let rise: CGFloat = 10
    private static var animates: Bool {
        !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion && !NotchSupport.isTestHarness
    }

    static func present(_ panel: NSPanel) {
        guard animates else { panel.orderFrontRegardless(); return }
        let target = panel.frame.origin
        panel.alphaValue = 0
        panel.setFrameOrigin(CGPoint(x: target.x, y: target.y - rise))
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrameOrigin(target)
        }
    }

    static func dismiss(_ panel: NSPanel) {
        guard animates, panel.isVisible else { panel.orderOut(nil); return }
        let origin = panel.frame.origin
        // Clicks during the fade go to whatever is behind it.
        panel.ignoresMouseEvents = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrameOrigin(CGPoint(x: origin.x, y: origin.y - rise * 0.6))
        }, completionHandler: {
            panel.orderOut(nil)
            panel.alphaValue = 1
        })
    }
}
