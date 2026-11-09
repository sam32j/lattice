// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

final class KeyableHubPanel: OverlayPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Owns the *only* native HUD resize animation. Every intermediate frame is
/// reconstructed using the same top coordinate, so content changes can never
/// make the shared header move vertically. SwiftUI owns opacity/accordion
/// changes; it does not animate the NSPanel frame.
final class HubPanelResizer {
    private weak var panel: NSPanel?
    private var timer: Timer?
    private var startTime: TimeInterval = 0
    private var startHeight: CGFloat = 0
    private var targetHeight: CGFloat = 0
    private var targetWidth: CGFloat = 0
    private var top: CGFloat = 0
    private var centerX: CGFloat = 0
    private let duration: TimeInterval = 0.22

    func cancel() {
        timer?.invalidate()
        timer = nil
        panel = nil
    }

    func resize(_ window: NSPanel, to size: CGSize, maximumHeight: CGFloat, animated: Bool) {
        let height = min(size.height, maximumHeight)
        guard height >= 100, size.width >= 200 else { return }

        if animated, let timer, timer.isValid,
           panel === window,
           abs(targetHeight - height) <= 0.5,
           abs(targetWidth - size.width) <= 0.5 { return }

        // This is sampled from the window, not from SwiftUI content. Once an
        // animation begins, all subsequent frames reuse this fixed top edge.
        let frame = window.frame
        if timer == nil,
           abs(frame.height - height) <= 0.5,
           abs(frame.width - size.width) <= 0.5 { return }
        let fixedTop = timer == nil ? frame.maxY : top
        let fixedCenter = timer == nil ? frame.midX : centerX
        let destination = Self.topAnchoredFrame(centerX: fixedCenter, top: fixedTop,
                                                width: size.width, height: height)

        // The accordion's animatable layout supplies intermediate heights.
        // Follow it directly instead of applying a second 0.22 s animation.
        if !animated {
            cancel()
            window.setFrame(destination, display: true, animate: false)
            return
        }

        cancel()
        panel = window
        top = fixedTop
        centerX = fixedCenter
        startHeight = frame.height
        targetHeight = height
        targetWidth = size.width
        startTime = ProcessInfo.processInfo.systemUptime
        let nextTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
    }

    // The window's upper edge is the invariant across both direct and
    // timer-driven resizing. Use one calculation for every frame.
    private static func topAnchoredFrame(centerX: CGFloat, top: CGFloat,
                                         width: CGFloat, height: CGFloat) -> NSRect {
        NSRect(x: centerX - width / 2, y: top - height,
               width: width, height: height)
    }

    private func tick() {
        guard let panel, panel.isVisible else { cancel(); return }
        let elapsed = ProcessInfo.processInfo.systemUptime - startTime
        let t = min(1, max(0, elapsed / duration))
        // Ease-in/ease-out, interpolating ONLY height. The window top cannot
        // drift because y is recomputed as top - height on every single tick.
        let eased = t * t * (3 - 2 * t)
        let height = startHeight + (targetHeight - startHeight) * eased
        let frame = Self.topAnchoredFrame(centerX: centerX, top: top,
                                          width: targetWidth, height: height)
        panel.setFrame(frame, display: true, animate: false)
        if t >= 1 { cancel() }
    }
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
        host.sizingOptions = [.intrinsicContentSize]
        panel.contentViewController = host
        if let content = panel.contentView {
            content.wantsLayer = true
            content.layer?.cornerRadius = 22
            content.layer?.cornerCurve = .continuous
            content.layer?.masksToBounds = true
        }
        self.panel = panel
        return panel
    }

    func position(_ panel: NSPanel, anchoredBelow anchor: NSRect? = nil) {
        panelResizer.cancel()
        // Never inherit the previous presentation's height limit when opening
        // on a new display or after the user has changed visible tools.
        setFloatingPanelHeightBudget(.greatestFiniteMagnitude)
        panel.contentViewController?.view.layoutSubtreeIfNeeded()
        let raw = panel.contentViewController?.view.fittingSize ?? .zero
        let screen = NSScreen.pointerVisibleFrame
        let maximumOpeningHeight = max(100, screen.height - 32)
        let size = (raw.width >= 200 && raw.height >= 100)
            ? NSSize(width: raw.width, height: min(raw.height, maximumOpeningHeight))
            : NSSize(width: 420, height: min(380, maximumOpeningHeight))
        let x: CGFloat
        let y: CGFloat
        if let anchor {
            x = anchor.midX - size.width / 2
            y = anchor.minY - size.height - 6
        } else {
            x = screen.midX - size.width / 2
            y = screen.minY + (screen.height - size.height) * 0.62
        }
        let frame = NSRect(x: max(screen.minX + 16, min(x, screen.maxX - size.width - 16)),
                           y: max(screen.minY + 16, y),
                           width: size.width, height: size.height)
        panel.setFrame(frame, display: true, animate: false)
        // A stable budget is established once on presentation, not recomputed
        // from panel.frame during each animation tick. Content can scroll once
        // this height is reached; the native panel never clips its own corners.
        setFloatingPanelHeightBudget(max(100, frame.maxY - screen.minY - 16))
    }

    func updatePanelSize(_ size: CGSize) {
        guard let panel, panel.isVisible,
              size.width >= 200, size.height >= 100 else { return }
        let screen = panel.screen?.visibleFrame ?? NSScreen.pointerVisibleFrame
        let maximumHeight = min(floatingPanelHeightBudget,
                                max(100, panel.frame.maxY - screen.minY - 16))
        // During opening/closing of Manage Tools, the accordion produces
        // intermediate heights already. Later discrete grid/tray edits still
        // deserve a smooth native resize rather than an abrupt jump.
        let editingTransitionInFlight = ProcessInfo.processInfo.systemUptime - editingChangedAt < 0.28
        let animate = !editingTransitionInFlight &&
            !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panelResizer.resize(panel, to: size, maximumHeight: maximumHeight,
                            animated: animate)
    }
}
