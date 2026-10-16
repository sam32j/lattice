// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// Only these small panels receive input when the image is click-through.
final class ScreenshotPinChrome {
    private weak var pin: ScreenshotPinWindow?
    private let closePanel = PinControlPanel(size: CGSize(width: 46, height: 46))
    private let modePanel = PinControlPanel(size: CGSize(width: 80, height: 46))
    private let dragPanel = PinControlPanel(size: CGSize(width: 100, height: 26))
    private let feedbackPanel = PinControlPanel(size: CGSize(width: 76, height: 28))
    private let feedback = ScreenshotPinFeedbackView(frame: CGRect(x: 0, y: 0, width: 76, height: 28))
    private let lockButton = PinControlButton()
    private let cursorButton = PinControlButton()
    private var attached = false

    init(pin: ScreenshotPinWindow) {
        self.pin = pin
        let close = PinControlButton()
        configure(close, symbol: "xmark", label: L10n.shared.s.menuClose, action: #selector(closePin))
        closePanel.contentView?.addSubview(circle(close, x: 8))
        configure(lockButton, symbol: "lock.open", label: "", action: #selector(toggleLock))
        configure(cursorButton, symbol: "cursorarrow", label: "", action: #selector(toggleClickThrough))
        modePanel.contentView?.addSubview(circle(lockButton, x: 8))
        modePanel.contentView?.addSubview(circle(cursorButton, x: 42))
        feedbackPanel.contentView = feedback
        dragPanel.contentView = ScreenshotPinDragView(pin: pin)
        feedbackPanel.ignoresMouseEvents = true
        refreshButtons()
    }

    private var panels: [NSPanel] { [closePanel, modePanel, dragPanel, feedbackPanel] }

    func attach() {
        guard !attached, let pin else { return }
        attached = true
        layout()
        for panel in panels {
            pin.addChildWindow(panel, ordered: .above)
            panel.contentView?.layoutSubtreeIfNeeded()
        }
        setControlsVisible(pin.isHovered)
    }

    func layout() {
        guard let pin else { return }
        closePanel.setFrameOrigin(CGPoint(x: pin.frame.minX, y: pin.frame.maxY - 46))
        modePanel.setFrameOrigin(CGPoint(x: pin.frame.maxX - 80, y: pin.frame.maxY - 46))
        dragPanel.setFrameOrigin(CGPoint(x: pin.frame.midX - 50, y: pin.frame.minY + 8))
        feedbackPanel.setFrameOrigin(CGPoint(x: pin.frame.midX - 38, y: pin.frame.midY - 14))
        for panel in panels { panel.contentView?.layoutSubtreeIfNeeded() }
    }

    func setControlsVisible(_ visible: Bool) {
        for panel in [closePanel, modePanel, dragPanel] {
            panel.alphaValue = visible ? 1 : 0
            panel.ignoresMouseEvents = !visible
        }
    }

    func showFeedback(_ text: String) { feedback.show(text) }

    func refreshButtons() {
        guard let pin else { return }
        let strings = ScreenshotPinStrings.localized(L10n.shared.language)
        let lockLabel = pin.isPositionLocked ? strings.unlock : strings.lock
        lockButton.image = NSImage(systemSymbolName: pin.isPositionLocked ? "lock.fill" : "lock.open", accessibilityDescription: lockLabel)
        lockButton.setAccessibilityLabel(lockLabel)
        lockButton.toolTip = lockLabel
        lockButton.contentTintColor = pin.isPositionLocked ? .systemYellow : .white
        cursorButton.setAccessibilityLabel(strings.clickThrough)
        cursorButton.toolTip = strings.clickThrough
        cursorButton.contentTintColor = pin.ignoresMouseEvents ? .systemYellow : .white
        lockButton.state = pin.isPositionLocked ? .on : .off
        cursorButton.state = pin.ignoresMouseEvents ? .on : .off
    }

    func detach() {
        feedback.dismiss()
        for panel in panels {
            pin?.removeChildWindow(panel)
            panel.orderOut(nil)
        }
        attached = false
    }

    private func configure(_ button: NSButton, symbol: String, label: String, action: Selector) {
        let cell = PinControlButtonCell()
        cell.horizontalOffsetInPixels = button === cursorButton ? 2 : 0
        cell.highlightsBy = []
        cell.showsStateBy = []
        button.cell = cell
        button.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        button.title = ""
        button.isBordered = false
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        button.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        button.imagePosition = .imageOnly
        button.contentTintColor = .white
        button.setAccessibilityLabel(label)
        button.toolTip = label
        button.target = self
        button.action = action
    }

    static func safeSetKVC(_ object: AnyObject?, value: Any?, key: String) {
        guard let target = object as? NSObject else { return }
        let sel1 = NSSelectorFromString("set\(key.prefix(1).uppercased() + key.dropFirst()):")
        let sel2 = NSSelectorFromString("set\(key):")
        if target.responds(to: sel1) || target.responds(to: sel2) {
            target.setValue(value, forKey: key)
            return
        }
        var currentCls: AnyClass? = object_getClass(target)
        while let cls = currentCls {
            if class_getProperty(cls, key) != nil ||
               class_getInstanceVariable(cls, key) != nil ||
               class_getInstanceVariable(cls, "_" + key) != nil {
                target.setValue(value, forKey: key)
                return
            }
            currentCls = class_getSuperclass(cls)
        }
    }

    private func circle(_ button: NSButton, x: CGFloat) -> NSView {
        // Liquid Glass draws beyond its nominal frame. The transparent panel
        // gutter keeps its rounded edge and shadow away from the window clip.
        let frame = CGRect(x: x, y: 8, width: 30, height: 30)
        let container = NSView(frame: frame)
        container.wantsLayer = true
        let material: NSView
        // Look up this public AppKit class at runtime so builds made with the
        // supported macOS 15 SDK also use Liquid Glass on newer systems.
        if #available(macOS 26.0, *), let glassClass = NSClassFromString("NSGlassEffectView") as? NSView.Type {
            let glass = glassClass.init(frame: container.bounds)
            Self.safeSetKVC(glass, value: 0, key: "style")
            Self.safeSetKVC(glass, value: 15, key: "cornerRadius")
            glass.appearance = NSAppearance(named: .darkAqua)
            Self.safeSetKVC(glass, value: 1, key: "_contentLensing")
            Self.safeSetKVC(glass, value: NSColor.black.withAlphaComponent(0.25), key: "tintColor")
            if #available(macOS 27.0, *) { Self.safeSetKVC(glass, value: false, key: "effectIsInteractive") }
            Self.safeSetKVC(glass, value: true, key: "_placesContentAboveGlass")
            material = glass
        } else {
            let frost = NSVisualEffectView(frame: container.bounds)
            frost.material = .hudWindow
            frost.blendingMode = .behindWindow
            frost.state = .active
            frost.appearance = NSAppearance(named: .darkAqua)
            frost.wantsLayer = true
            frost.layer?.cornerRadius = 15
            frost.layer?.masksToBounds = true
            material = frost
        }
        material.autoresizingMask = [.width, .height]
        container.addSubview(material)

        let sheen = CALayer()
        sheen.frame = container.bounds
        sheen.cornerRadius = 15
        sheen.masksToBounds = true
        sheen.backgroundColor = NSColor.clear.cgColor
        container.layer?.addSublayer(sheen)

        button.frame = container.bounds
        button.autoresizingMask = [.width, .height]
        container.addSubview(button)

        if let controlBtn = button as? PinControlButton {
            controlBtn.circleContainer = container
            controlBtn.glassView = material
            controlBtn.highlightLayer = sheen
        }

        container.layoutSubtreeIfNeeded()
        return container
    }

    @objc private func closePin() { pin?.closePin() }
    @objc private func toggleLock() { if let pin { pin.setPositionLocked(!pin.isPositionLocked) } }
    @objc private func toggleClickThrough() { if let pin { pin.setClickThrough(!pin.ignoresMouseEvents) } }
}

private final class PinControlButton: NSButton {
    weak var circleContainer: NSView?
    weak var glassView: NSView?
    weak var highlightLayer: CALayer?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    private var trackingArea: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        self.trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateSheen(hover: true, pressed: false)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateSheen(hover: false, pressed: false)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        updateSheen(hover: true, pressed: true)
        var inside = true
        window?.trackEvents(matching: [.leftMouseUp, .leftMouseDragged], timeout: .infinity, mode: .eventTracking) { [weak self] e, stop in
            guard let self, let e else { return }
            let pt = self.convert(e.locationInWindow, from: nil)
            let inBounds = self.bounds.contains(pt)
            if inBounds != inside {
                inside = inBounds
                self.updateSheen(hover: inside, pressed: inside)
            }
            if e.type == .leftMouseUp {
                stop.pointee = true
            }
        }
        let pt = convert(window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)
        updateSheen(hover: bounds.contains(pt), pressed: false)
        if inside {
            sendAction(action, to: target)
        }
    }

    private func updateSheen(hover: Bool, pressed: Bool) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = pressed ? 0.08 : 0.16
            ctx.timingFunction = CAMediaTimingFunction(name: pressed ? .easeOut : .easeInEaseOut)
            ctx.allowsImplicitAnimation = true
            let alpha: CGFloat = pressed ? 0.28 : (hover ? 0.12 : 0.0)
            highlightLayer?.backgroundColor = NSColor(white: 1.0, alpha: alpha).cgColor
            if let layer = circleContainer?.layer {
                if pressed {
                    let cx = layer.bounds.midX
                    let cy = layer.bounds.midY
                    var t = CATransform3DMakeTranslation(cx, cy, 0)
                    t = CATransform3DScale(t, 1.10, 1.10, 1)
                    layer.transform = CATransform3DTranslate(t, -cx, -cy, 0)
                } else {
                    layer.transform = CATransform3DIdentity
                }
            }
            if #available(macOS 26.0, *), let glassView {
                ScreenshotPinChrome.safeSetKVC(glassView, value: pressed ? 2 : 1, key: "_contentLensing")
            }
        }
    }
}

private final class PinControlButtonCell: NSButtonCell {
    var horizontalOffsetInPixels: CGFloat = 0
    override func imageRect(forBounds rect: NSRect) -> NSRect {
        let size = super.imageRect(forBounds: rect).size
        let scale = controlView?.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
        return NSRect(x: rect.midX - size.width / 2 + horizontalOffsetInPixels / scale, y: rect.midY - size.height / 2,
                      width: size.width, height: size.height)
    }
}

private final class PinControlPanel: OverlayPanel {
    init(size: CGSize) {
        super.init(contentRect: CGRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
    }
    override var canBecomeKey: Bool { false }
}
