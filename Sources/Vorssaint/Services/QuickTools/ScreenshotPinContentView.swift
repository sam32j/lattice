// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

final class ScreenshotPinContentView: ScreenshotPinGestureView {
    private weak var pin: ScreenshotPinWindow?
    override var acceptsFirstResponder: Bool { true }
    override var needsPanelToBecomeKey: Bool { true }
    override var isPositionLocked: Bool { pin?.isPositionLocked ?? true }
    override var pinOpacity: CGFloat {
        get { pin?.chosenOpacity ?? 1 }
        set { pin?.setOpacity(newValue) }
    }
    override func didZoom() { pin?.reportZoom() }

    init(image: CGImage, pin: ScreenshotPinWindow) {
        self.pin = pin
        super.init(frame: .zero)
        wantsLayer = true
        layer?.contents = image
        layer?.contentsGravity = .resizeAspect
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = CGColor(gray: 0.5, alpha: 0.4)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private static let nwseCursor: NSCursor = {
        let sel = Selector(("_windowResizeNorthWestSouthEastCursor"))
        if NSCursor.responds(to: sel),
           let obj = NSCursor.perform(sel)?.takeUnretainedValue() as? NSCursor {
            return obj
        }
        return .resizeLeftRight
    }()

    private static let neswCursor: NSCursor = {
        let sel = Selector(("_windowResizeNorthEastSouthWestCursor"))
        if NSCursor.responds(to: sel),
           let obj = NSCursor.perform(sel)?.takeUnretainedValue() as? NSCursor {
            return obj
        }
        return .resizeLeftRight
    }()

    private enum ResizeEdge {
        case left, right, top, bottom, topLeft, topRight, bottomLeft, bottomRight
    }

    private let borderThickness: CGFloat = 6
    private let cornerSize: CGFloat = 14

    private func resizeEdge(at point: NSPoint) -> ResizeEdge? {
        guard bounds.width > cornerSize * 2, bounds.height > cornerSize * 2 else { return nil }
        let isLeft = point.x <= borderThickness
        let isRight = point.x >= bounds.width - borderThickness
        let isBottom = point.y <= borderThickness
        let isTop = point.y >= bounds.height - borderThickness

        let isCornerLeft = point.x <= cornerSize
        let isCornerRight = point.x >= bounds.width - cornerSize
        let isCornerBottom = point.y <= cornerSize
        let isCornerTop = point.y >= bounds.height - cornerSize

        if isCornerLeft && isCornerTop { return .topLeft }
        if isCornerRight && isCornerTop { return .topRight }
        if isCornerLeft && isCornerBottom { return .bottomLeft }
        if isCornerRight && isCornerBottom { return .bottomRight }

        if isLeft { return .left }
        if isRight { return .right }
        if isTop { return .top }
        if isBottom { return .bottom }

        return nil
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard let pin, !pin.isClosed, !pin.isPositionLocked else { return }
        guard bounds.width > cornerSize * 2, bounds.height > cornerSize * 2 else { return }

        let bottomLeft = NSRect(x: 0, y: 0, width: cornerSize, height: cornerSize)
        let bottomRight = NSRect(x: bounds.maxX - cornerSize, y: 0, width: cornerSize, height: cornerSize)
        let topLeft = NSRect(x: 0, y: bounds.maxY - cornerSize, width: cornerSize, height: cornerSize)
        let topRight = NSRect(x: bounds.maxX - cornerSize, y: bounds.maxY - cornerSize, width: cornerSize, height: cornerSize)

        let left = NSRect(x: 0, y: cornerSize, width: borderThickness, height: bounds.height - cornerSize * 2)
        let right = NSRect(x: bounds.maxX - borderThickness, y: cornerSize, width: borderThickness, height: bounds.height - cornerSize * 2)
        let bottom = NSRect(x: cornerSize, y: 0, width: bounds.width - cornerSize * 2, height: borderThickness)
        let top = NSRect(x: cornerSize, y: bounds.maxY - borderThickness, width: bounds.width - cornerSize * 2, height: borderThickness)

        addCursorRect(left, cursor: .resizeLeftRight)
        addCursorRect(right, cursor: .resizeLeftRight)
        addCursorRect(top, cursor: .resizeUpDown)
        addCursorRect(bottom, cursor: .resizeUpDown)

        addCursorRect(topLeft, cursor: Self.nwseCursor)
        addCursorRect(bottomRight, cursor: Self.nwseCursor)
        addCursorRect(topRight, cursor: Self.neswCursor)
        addCursorRect(bottomLeft, cursor: Self.neswCursor)
    }

    override var mouseDownCanMoveWindow: Bool { !isPositionLocked }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let pin, !pin.isClosed else { return }
        guard event.clickCount < 2 else { return }
        if !pin.isKeyWindow || !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
            pin.makeKeyAndOrderFront(nil)
            pin.makeFirstResponder(self)
        }
        guard !pin.isPositionLocked else { return }
        let point = convert(event.locationInWindow, from: nil)
        if let edge = resizeEdge(at: point) {
            handleResize(with: event, edge: edge)
            return
        }
        NotificationCenter.default.post(name: .screenshotPinWindowDragDidBegin, object: pin)
        pin.performDrag(with: event)
        NotificationCenter.default.post(name: .screenshotPinWindowDragDidEnd, object: pin)
    }

    private func handleResize(with event: NSEvent, edge: ResizeEdge) {
        guard let window = self.window, let pin else { return }
        let initialFrame = window.frame
        let initialMouse = NSEvent.mouseLocation
        let minW = pin.minSize.width
        let minH = pin.minSize.height
        let aspect = pin.contentAspectRatio.width / max(1, pin.contentAspectRatio.height)

        while true {
            guard let nextEvent = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else { break }
            if nextEvent.type == .leftMouseUp { break }

            let currentMouse = NSEvent.mouseLocation
            let deltaX = currentMouse.x - initialMouse.x
            let deltaY = currentMouse.y - initialMouse.y

            var newFrame = initialFrame

            switch edge {
            case .right:
                let targetW = max(minW, initialFrame.width + deltaX)
                newFrame.size.width = targetW
                newFrame.size.height = max(minH, targetW / aspect)
            case .left:
                let clampedDeltaX = min(deltaX, initialFrame.width - minW)
                let targetW = initialFrame.width - clampedDeltaX
                newFrame.origin.x = initialFrame.origin.x + clampedDeltaX
                newFrame.size.width = targetW
                newFrame.size.height = max(minH, targetW / aspect)
            case .top:
                let targetH = max(minH, initialFrame.height + deltaY)
                newFrame.size.height = targetH
                newFrame.size.width = max(minW, targetH * aspect)
            case .bottom:
                let clampedDeltaY = min(deltaY, initialFrame.height - minH)
                let targetH = initialFrame.height - clampedDeltaY
                newFrame.origin.y = initialFrame.origin.y + clampedDeltaY
                newFrame.size.height = targetH
                newFrame.size.width = max(minW, targetH * aspect)
            case .topRight:
                let targetW = max(minW, initialFrame.width + deltaX)
                newFrame.size.width = targetW
                newFrame.size.height = max(minH, targetW / aspect)
            case .topLeft:
                let clampedDeltaX = min(deltaX, initialFrame.width - minW)
                let targetW = initialFrame.width - clampedDeltaX
                newFrame.origin.x = initialFrame.origin.x + clampedDeltaX
                newFrame.size.width = targetW
                newFrame.size.height = max(minH, targetW / aspect)
            case .bottomRight:
                let targetW = max(minW, initialFrame.width + deltaX)
                let targetH = max(minH, targetW / aspect)
                newFrame.origin.y = initialFrame.maxY - targetH
                newFrame.size.width = targetW
                newFrame.size.height = targetH
            case .bottomLeft:
                let clampedDeltaX = min(deltaX, initialFrame.width - minW)
                let targetW = initialFrame.width - clampedDeltaX
                let targetH = max(minH, targetW / aspect)
                newFrame.origin.x = initialFrame.origin.x + clampedDeltaX
                newFrame.origin.y = initialFrame.maxY - targetH
                newFrame.size.width = targetW
                newFrame.size.height = targetH
            }

            window.setFrame(newFrame, display: true)
            pin.reportZoom()
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let pin, !pin.isClosed else { return nil }
        let strings = FeatureStrings.screenshot(L10n.shared.language)
        let controls = ScreenshotPinStrings.localized(L10n.shared.language)
        let menu = NSMenu()
        func add(_ title: String, _ action: Selector, key: String = "", checked: Bool = false, value: Int? = nil) {
            let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
            item.target = self
            item.state = checked ? .on : .off
            item.representedObject = value
        }
        add(strings.editButton, #selector(editPin), key: "e")
        add(strings.copyButton, #selector(copy(_:)), key: "c")
        add(strings.saveButton, #selector(savePin), key: "s")
        menu.addItem(.separator())
        let zoom = NSMenuItem(title: "Zoom", action: nil, keyEquivalent: "")
        let scales = NSMenu()
        scales.autoenablesItems = false
        for multiplier in [0.5, 0.8, 1.0, 2.0] {
            let item = scales.addItem(withTitle: "\(multiplier.formatted())x", action: #selector(setZoom(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = multiplier
            item.isEnabled = !pin.isPositionLocked && !NSEvent.modifierFlags.contains(.option)
            item.state = abs(pin.zoomMultiplier - multiplier) < 0.01 ? .on : .off
        }
        zoom.submenu = scales
        menu.addItem(zoom)
        let opacity = NSMenuItem(title: strings.pinOpacity, action: nil, keyEquivalent: "")
        let levels = NSMenu()
        for percent in [10, 50, 100] {
            let item = levels.addItem(withTitle: "\(percent)%", action: #selector(setOpacity(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = percent
            item.state = Int((pin.chosenOpacity * 100).rounded()) == percent ? .on : .off
        }
        opacity.submenu = levels
        menu.addItem(opacity)
        add(pin.isPositionLocked ? controls.unlock : controls.lock, #selector(lockPin), checked: pin.isPositionLocked)
        add(strings.pinClickThrough, #selector(clickThrough), checked: pin.ignoresMouseEvents)
        menu.addItem(.separator())
        add(L10n.shared.s.menuClose, #selector(closePin), key: "w")
        add(strings.pinCloseAll, #selector(closeAll))
        return menu
    }

    @objc func copy(_ sender: Any?) { pin?.onCopy?() }
    @objc private func editPin() { pin?.onEdit?() }
    @objc private func savePin() { pin?.onSave?() }
    @objc private func closePin() { pin?.closePin() }
    @objc private func closeAll() { pin?.onCloseAll?() }
    @objc private func lockPin() { if let pin { pin.setPositionLocked(!pin.isPositionLocked) } }
    @objc private func clickThrough() { if let pin { pin.setClickThrough(!pin.ignoresMouseEvents) } }
    @objc private func setOpacity(_ item: NSMenuItem) {
        if let percent = item.representedObject as? Int { pin?.setOpacity(CGFloat(percent) / 100) }
    }
    @objc private func setZoom(_ item: NSMenuItem) {
        if let multiplier = item.representedObject as? Double { pin?.setZoom(multiplier) }
    }
}
