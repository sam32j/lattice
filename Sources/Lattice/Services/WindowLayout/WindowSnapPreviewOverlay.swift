// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit

/// The desktop ghost the snapping panel shows while the pointer moves over a
/// grid cell, preset pane or quick action.
///
/// The window covers the whole screen and never resizes; only a layer inside
/// it moves. Core Animation retargets that layer from wherever it is drawn,
/// in the render server, so sweeping across tiles glides from one to the next
/// without the main thread doing a window resize for every frame, which is
/// what an animated `NSWindow.setFrame` costs.
final class WindowSnapPreviewOverlay {
    private var panel: NSPanel?
    private let box = CALayer()
    private var screenFrame: CGRect = .null
    private var hideGeneration = 0
    private var isShown = false

    private static let moveDuration: CFTimeInterval = 0.16
    private static let fadeInDuration: CFTimeInterval = 0.1
    private static let fadeOutDuration: CFTimeInterval = 0.08

    /// `frame` and `screen` are in AppKit screen coordinates.
    func show(frame: CGRect, on screen: CGRect, below hubWindow: NSWindow?) {
        let panel = ensurePanel()
        hideGeneration += 1
        let local = frame.offsetBy(dx: -screen.minX, dy: -screen.minY).integral
        let movedScreens = screenFrame != screen
        if movedScreens {
            screenFrame = screen
            panel.setFrame(screen, display: false)
        }

        CATransaction.begin()
        if !isShown || movedScreens {
            // Appearing (or on another display): place it, then fade in.
            CATransaction.setDisableActions(true)
            box.frame = local
            CATransaction.commit()
            box.removeAnimation(forKey: "fade")
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = box.presentation()?.opacity ?? 0
            fade.toValue = 1
            fade.duration = Self.fadeInDuration
            fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
            box.opacity = 1
            box.add(fade, forKey: "fade")
        } else {
            CATransaction.setAnimationDuration(Self.moveDuration)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0))
            box.frame = local
            box.opacity = 1
            CATransaction.commit()
        }
        isShown = true

        if let hubWindow, hubWindow.isVisible {
            panel.order(.below, relativeTo: hubWindow.windowNumber)
        } else if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    func hide(immediately: Bool) {
        guard isShown, let panel else { return }
        isShown = false
        hideGeneration += 1
        let generation = hideGeneration
        if immediately {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            box.opacity = 0
            CATransaction.commit()
            panel.orderOut(nil)
            return
        }
        CATransaction.begin()
        CATransaction.setAnimationDuration(Self.fadeOutDuration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeIn))
        CATransaction.setCompletionBlock { [weak self, weak panel] in
            guard let self, generation == self.hideGeneration else { return }
            panel?.orderOut(nil)
        }
        box.opacity = 0
        CATransaction.commit()
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let panel = OverlayPanel(contentRect: .zero,
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered,
                                 defer: false)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.animationBehavior = .none
        let content = SnapPreviewContentView(frame: .zero)
        content.box = box
        panel.contentView = content
        content.wantsLayer = true
        content.layer?.addSublayer(box)
        box.opacity = 0
        box.cornerRadius = 14
        box.cornerCurve = .continuous
        box.borderWidth = 2
        content.applyColors()
        self.panel = panel
        return panel
    }
}

/// Keeps the ghost in the system accent, refreshed when it changes.
private final class SnapPreviewContentView: NSView {
    weak var box: CALayer?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColors()
    }

    func applyColors() {
        guard let box else { return }
        var fill: CGColor = NSColor.controlAccentColor.withAlphaComponent(0.16).cgColor
        var stroke: CGColor = NSColor.controlAccentColor.withAlphaComponent(0.88).cgColor
        effectiveAppearance.performAsCurrentDrawingAppearance {
            fill = NSColor.controlAccentColor.withAlphaComponent(0.16).cgColor
            stroke = NSColor.controlAccentColor.withAlphaComponent(0.88).cgColor
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        box.backgroundColor = fill
        box.borderColor = stroke
        CATransaction.commit()
    }
}
