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
        let pinchRecognizer = NSMagnificationGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        pinchRecognizer.delaysMagnificationEvents = false
        addGestureRecognizer(pinchRecognizer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let pin, !pin.isClosed else { return }
        if event.clickCount == 2 { pin.closePin(); return }
        NSApp.activate(ignoringOtherApps: true)
        pin.makeKey()
        pin.makeFirstResponder(self)
        if !pin.isPositionLocked {
            NotificationCenter.default.post(name: .screenshotPinWindowDragDidBegin, object: pin)
            pin.performDrag(with: event)
            NotificationCenter.default.post(name: .screenshotPinWindowDragDidEnd, object: pin)
        }
    }

    @objc private func handlePinchGesture(_ gesture: NSMagnificationGestureRecognizer) {
        guard let pin, !pin.isClosed, !pin.isPositionLocked, !pin.ignoresMouseEvents else { return }
        lastGestureMagnificationTime = ProcessInfo.processInfo.systemUptime
        let delta = gesture.magnification
        guard delta.isFinite, delta != 0, delta > -1 else { return }
        zoom(by: 1 + delta, at: gesture.location(in: self))
        gesture.magnification = 0
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let pin, !pin.isClosed else { return nil }
        let strings = FeatureStrings.screenshot(L10n.shared.language)
        let controls = ScreenshotPinStrings.localized(L10n.shared.language)
        let menu = NSMenu()
        func add(_ title: String, _ action: Selector, checked: Bool = false, value: Int? = nil) {
            let item = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
            item.target = self
            item.state = checked ? .on : .off
            item.representedObject = value
        }
        add(strings.copyButton, #selector(copyPin))
        add(strings.saveAsButton, #selector(savePin))
        menu.addItem(.separator())
        let opacity = NSMenuItem(title: strings.pinOpacity, action: nil, keyEquivalent: "")
        let levels = NSMenu()
        for percent in [100, 90, 70, 50, 25, 10] {
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
        add(L10n.shared.s.menuClose, #selector(closePin))
        add(strings.pinCloseAll, #selector(closeAll))
        return menu
    }

    @objc private func copyPin() { pin?.onCopy?() }
    @objc private func savePin() { pin?.onSave?() }
    @objc private func closePin() { pin?.closePin() }
    @objc private func closeAll() { pin?.onCloseAll?() }
    @objc private func lockPin() { if let pin { pin.setPositionLocked(!pin.isPositionLocked) } }
    @objc private func clickThrough() { if let pin { pin.setClickThrough(!pin.ignoresMouseEvents) } }
    @objc private func setOpacity(_ item: NSMenuItem) {
        if let percent = item.representedObject as? Int { pin?.setOpacity(CGFloat(percent) / 100) }
    }
}
