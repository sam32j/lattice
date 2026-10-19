// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreImage

final class RecorderOverlayPanel: OverlayPanel {
    init() {
        super.init(contentRect: CGRect(x: 0, y: 0, width: 1, height: 1),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class RecorderCameraOverlayView: NSView {
    private weak var controller: RecorderOverlayController?
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var dragStart: CGPoint?
    private var origin = CGPoint.zero
    private var dragged = false

    init(controller: RecorderOverlayController) {
        self.controller = controller
        super.init(frame: .zero)
        setAccessibilityLabel("Recording camera overlay")
    }
    @available(*, unavailable) required init?(coder: NSCoder) { nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let controller, let graphics = NSGraphicsContext.current?.cgContext else { return }
        graphics.saveGState()
        defer { graphics.restoreGState() }
        if controller.layout.shape == .circle && !controller.layout.isFullArea { graphics.addEllipse(in: bounds) }
        else { graphics.addRect(bounds) }
        graphics.clip()
        graphics.setFillColor(NSColor.black.cgColor)
        graphics.fill(bounds)
        guard var camera = controller.frames.snapshot.camera else {
            let text = "Starting camera…" as NSString
            text.draw(at: CGPoint(x: 10, y: max(4, bounds.midY - 8)),
                withAttributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.white])
            return
        }
        let source = camera.extent
        camera = camera.transformed(by: CGAffineTransform(translationX: -source.minX, y: -source.minY))
        if controller.layout.isFlipped {
            camera = camera.transformed(by: CGAffineTransform(translationX: source.width, y: 0).scaledBy(x: -1, y: 1))
        }
        let backing = window?.backingScaleFactor ?? 1
        let target = CGRect(x: 0, y: 0, width: bounds.width * backing, height: bounds.height * backing)
        let scale = max(target.width / source.width, target.height / source.height)
        camera = camera.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        camera = camera.transformed(by: CGAffineTransform(translationX: target.midX - camera.extent.midX,
                                                         y: target.midY - camera.extent.midY))
        if let image = context.createCGImage(camera, from: target) {
            graphics.interpolationQuality = .high
            graphics.draw(image, in: bounds)
        }
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        origin = window?.frame.origin ?? .zero
        dragged = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let point = NSEvent.mouseLocation
        if hypot(point.x - start.x, point.y - start.y) > 4 { dragged = true }
        if dragged { controller?.moveCamera(origin: CGPoint(x: origin.x + point.x - start.x,
                                                            y: origin.y + point.y - start.y)) }
    }
    override func mouseUp(with event: NSEvent) {
        if !dragged, dragStart != nil { controller?.layout.isFullArea.toggle() }
        dragStart = nil
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let controller else { return nil }
        let menu = NSMenu()
        func section(_ title: String) -> NSMenu {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let submenu = NSMenu(); item.submenu = submenu; menu.addItem(item); return submenu
        }
        let cameras = section("Camera")
        let system = cameras.addItem(withTitle: "System default", action: #selector(cameraSelected(_:)), keyEquivalent: "")
        system.target = self; system.state = controller.selectedCameraID == nil ? .on : .off
        for device in RecorderCaptureInputs.cameras {
            let item = cameras.addItem(withTitle: device.localizedName, action: #selector(cameraSelected(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = device.uniqueID
            item.state = device.uniqueID == controller.selectedCameraID ? .on : .off
        }
        let sizes = section("Size")
        sizes.autoenablesItems = false
        for size in RecorderCameraLayout.Size.allCases {
            let item = sizes.addItem(withTitle: size.rawValue.capitalized, action: #selector(sizeSelected(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = size.rawValue
            let effective = controller.layout.isAvailable(controller.layout.size, in: controller.pixelSize)
                ? controller.layout.size : .small
            item.state = effective == size ? .on : .off
            item.isEnabled = controller.layout.isAvailable(size, in: controller.pixelSize)
        }
        let shapes = section("Shape")
        for shape in RecorderCameraLayout.Shape.allCases {
            let title = shape == .rectangle ? "Rectangle (1.47:1)" : shape == .vertical ? "Vertical (1:1.47)" : shape.rawValue.capitalized
            let item = shapes.addItem(withTitle: title, action: #selector(shapeSelected(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = shape.rawValue
            item.state = controller.layout.shape == shape ? .on : .off
        }
        let flip = menu.addItem(withTitle: "Flip camera", action: #selector(flipCamera), keyEquivalent: "")
        flip.target = self; flip.state = controller.layout.isFlipped ? .on : .off
        return menu
    }
    @objc private func cameraSelected(_ item: NSMenuItem) { controller?.selectedCameraID = item.representedObject as? String }
    @objc private func sizeSelected(_ item: NSMenuItem) {
        if let raw = item.representedObject as? String, let size = RecorderCameraLayout.Size(rawValue: raw) { controller?.layout.size = size }
    }
    @objc private func shapeSelected(_ item: NSMenuItem) {
        if let raw = item.representedObject as? String, let shape = RecorderCameraLayout.Shape(rawValue: raw) { controller?.layout.shape = shape }
    }
    @objc private func flipCamera() { controller?.layout.isFlipped.toggle() }
}
