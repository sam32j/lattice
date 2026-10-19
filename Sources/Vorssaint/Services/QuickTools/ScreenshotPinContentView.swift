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
        if !pin.isPositionLocked {
            NotificationCenter.default.post(name: .screenshotPinWindowDragDidBegin, object: pin)
            pin.performDrag(with: event)
            NotificationCenter.default.post(name: .screenshotPinWindowDragDidEnd, object: pin)
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
