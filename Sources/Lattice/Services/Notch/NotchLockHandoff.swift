// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import SwiftUI
import QuartzCore
import os

/// A single opaque silhouette spans both sides of the session change. Its
/// Core Animation path keeps moving while SwiftUI and services rebuild.
final class NotchLockHandoff {
    private let panel: NotchLockScreenPanel
    private let space: NotchOverlaySpace
    private let shape = CAShapeLayer()
    private let contentMask = CAShapeLayer()
    private let content = NSHostingView(rootView: AnyView(EmptyView()))
    private let screen: CGRect
    private let cameraWidth: CGFloat
    private var generation = 0
    private let logger = Logger(subsystem: "io.github.sam32j.lattice", category: "LockHandoff")
    private(set) var unlocking = false
    private var unlockStarted: CFTimeInterval?
    private var retractionFrame: CGRect?

    var visibleFrame: CGRect {
        let bounds = (shape.presentation()?.path ?? shape.path)?.boundingBoxOfPath ?? .zero
        return CGRect(x: screen.minX + bounds.minX, y: screen.maxY - bounds.maxY,
                      width: bounds.width, height: bounds.height)
    }

    init?(from frame: CGRect, geometry: NotchGeometry) {
        guard geometry.isNotched, !geometry.floats,
              let space = NotchOverlaySpace(absoluteLevel: NotchLockScreenSupport.spaceLevel) else { return nil }
        self.space = space
        screen = geometry.screen
        cameraWidth = geometry.bareCutout.width
        panel = NotchLockScreenPanel(contentRect: screen, styleMask: [.borderless, .nonactivatingPanel],
                                     backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.level = NotchPanel.normalLevel
        panel.collectionBehavior = NotchPanel.overlayCollectionBehavior
        let view = NotchLockHandoffCanvas(frame: CGRect(origin: .zero, size: screen.size))
        view.wantsLayer = true
        shape.fillColor = NSColor.black.cgColor
        shape.frame = view.bounds
        view.layer?.addSublayer(shape)
        content.frame = view.bounds
        content.sizingOptions = []
        content.wantsLayer = true
        contentMask.frame = view.bounds
        content.layer?.mask = contentMask
        view.addSubview(content)
        panel.contentView = view
        shape.path = path(for: frame)
        contentMask.path = shape.path
        space.add(panel)
        panel.orderFrontRegardless()
#if LATTICE_DEVELOPMENT
        NotchLockTransitionDiagnostics.event("shared-window-ready", window: panel.windowNumber)
#endif
        CATransaction.flush()
    }

    func setLockContent(_ view: AnyView, in frame: CGRect) {
        let origin = CGPoint(x: frame.minX - screen.minX, y: screen.maxY - frame.maxY)
        content.rootView = AnyView(view
            .frame(width: frame.width, height: frame.height)
            .offset(x: origin.x, y: origin.y)
            .frame(width: screen.width, height: screen.height, alignment: .topLeading))
        content.layoutSubtreeIfNeeded()
        panel.displayIfNeeded()
#if LATTICE_DEVELOPMENT
        NotchLockTransitionDiagnostics.event("lock-content-mounted", window: panel.windowNumber)
#endif
        logger.debug("Lock content mounted in shared window \(self.panel.windowNumber, privacy: .public)")
    }

    private func path(for frame: CGRect) -> CGPath {
        let rect = CGRect(x: frame.minX - screen.minX, y: screen.maxY - frame.maxY,
                          width: frame.width, height: frame.height)
        return NotchShape(attached: true, radius: NotchLayout.surfaceRadius(height: rect.height),
                          cutoutWidth: cameraWidth)
            .path(in: CGRect(origin: .zero, size: rect.size)).offsetBy(dx: rect.minX, dy: rect.minY).cgPath
    }

    func morph(to frame: CGRect) {
        generation += 1
        let previous = shape.presentation()?.path ?? shape.path
        let destination = path(for: frame)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.path = destination
        contentMask.path = destination
        shape.removeAnimation(forKey: "handoff")
        contentMask.removeAnimation(forKey: "handoff")
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            let animation = CABasicAnimation(keyPath: "path")
            animation.fromValue = previous
            animation.toValue = destination
            animation.duration = 0.32
            animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
            shape.add(animation, forKey: "handoff")
            contentMask.add(animation, forKey: "handoff")
        }
        CATransaction.commit()
        CATransaction.flush()
    }

    func beginUnlock(to frame: CGRect, retracting: Bool) {
        logger.debug("Unlock target retracting=\(retracting, privacy: .public) frame=\(String(describing: frame), privacy: .public)")
        unlocking = true
        retractionFrame = retracting ? frame : nil
        unlockStarted = CACurrentMediaTime()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        content.layer?.opacity = 0
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = content.layer?.presentation()?.opacity ?? 1
            fade.toValue = 0
            fade.duration = 0.2
            content.layer?.add(fade, forKey: "unlock-content")
        }
        CATransaction.commit()
        morph(to: frame)
    }

    /// The destination is rendered before the shared silhouette is retired.
    func finishUnlock(to frame: CGRect, panel desktop: NSPanel?, completion: @escaping () -> Void) {
        guard unlocking else { return }
        let started = CACurrentMediaTime()
        let preparation = started - (unlockStarted ?? started)
        logger.debug("Desktop prepared behind lock backdrop in \(preparation, privacy: .public)s")
        morph(to: retractionFrame ?? frame)
        let token = generation
        let duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.32
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self, weak desktop] in
            guard let self, self.generation == token, self.unlocking else { return }
            desktop?.contentView?.layoutSubtreeIfNeeded()
            desktop?.displayIfNeeded()
            desktop?.alphaValue = 1
            CATransaction.flush()
            self.close()
            self.logger.debug("Unlock handoff completed in \(CACurrentMediaTime() - started, privacy: .public)s")
            completion()
        }
    }

    func close() {
        generation += 1
        panel.orderOut(nil)
        space.close()
    }

    deinit { close() }
}

private final class NotchLockHandoffCanvas: NSView {
    override var isFlipped: Bool { true }
}
