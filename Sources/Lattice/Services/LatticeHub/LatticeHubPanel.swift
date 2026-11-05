// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

final class KeyableHubPanel: OverlayPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

extension LatticeHubService {
    func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let panel = KeyableHubPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 380),
                                    styleMask: [.borderless, .nonactivatingPanel],
                                    backing: .buffered,
                                    defer: false)
        panel.title = "Lattice Hub"
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        let host = NSHostingController(rootView: LatticeHubView())
        // Keep natural content measurement without letting the controller
        // independently resize the window through preferredContentSize.
        host.sizingOptions = [.intrinsicContentSize]
        panel.contentViewController = host
        self.panel = panel
        return panel
    }

    func position(_ panel: NSPanel, anchoredBelow anchor: NSRect? = nil) {
        panel.contentViewController?.view.layoutSubtreeIfNeeded()
        let raw = panel.contentViewController?.view.fittingSize ?? .zero
        let size = (raw.width >= 200 && raw.height >= 100) ? raw : NSSize(width: 420, height: 380)
        let screen = NSScreen.pointerVisibleFrame
        let x: CGFloat
        let y: CGFloat
        if let anchor {
            x = anchor.midX - size.width / 2
            y = anchor.minY - size.height - 6
        } else {
            x = screen.midX - size.width / 2
            y = screen.minY + (screen.height - size.height) * 0.62
        }
        panel.setFrame(NSRect(x: max(screen.minX + 16, min(x, screen.maxX - size.width - 16)),
                              y: max(screen.minY + 16, y),
                              width: size.width,
                              height: size.height),
                       display: true,
                       animate: false)
    }

    func updatePanelSize(_ size: CGSize) {
        guard let panel, panel.isVisible else { return }
        guard size.width >= 200 && size.height >= 100 else { return }
        let screen = panel.screen?.visibleFrame ?? NSScreen.pointerVisibleFrame
        var frame = panel.frame
        guard abs(frame.width - size.width) > 0.5 || abs(frame.height - size.height) > 0.5 else { return }
        frame.origin.x = frame.midX - size.width / 2
        frame.origin.y = frame.maxY - size.height
        frame.size = size
        frame.origin.x = max(screen.minX + 16, min(frame.origin.x, screen.maxX - size.width - 16))
        frame.origin.y = max(screen.minY + 16, frame.origin.y)
        // SwiftUI's accordion supplies each animation frame. A second AppKit
        // animation would move the window on a different timeline.
        panel.setFrame(frame, display: true)
    }
}
