// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox

/// Image presentation is independent from the small interactive chrome panels.
final class ScreenshotPinWindow: OverlayPanel, NSWindowDelegate {
    private(set) var image: CGImage
    let captureScale: CGFloat
    var captureID: UUID
    var baseImage: CGImage?
    var annotations: [ScreenshotSupport.Annotation] = []
    private let preferences: UserDefaults
    private(set) var chosenOpacity: CGFloat = 1
    private(set) var isPositionLocked = false
    private(set) var isHovered = false
    private(set) var isClosed = false
    var onClose: (() -> Void)?
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onCloseAll: (() -> Void)?
    var onClickThroughChanged: (() -> Void)?
    var onEdit: (() -> Void)?
    static let pinLevel = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue - 1)
    private lazy var chrome = ScreenshotPinChrome(pin: self)
    private lazy var surface = ScreenshotPinContentView(image: image, pin: self)

    var displayedImageOpacity: CGFloat { CGFloat(surface.layer?.opacity ?? 1) }
    var zoomMultiplier: CGFloat { frame.width / (CGFloat(image.width) / captureScale) }
    var cornerRadius: CGFloat { surface.layer?.cornerRadius ?? 0 }

    func updateImage(_ newImage: CGImage, baseImage: CGImage? = nil, annotations: [ScreenshotSupport.Annotation] = []) {
        guard !isClosed else { return }
        self.image = newImage
        if let baseImage { self.baseImage = baseImage }
        self.annotations = annotations
        surface.layer?.contents = newImage
        contentAspectRatio = CGSize(width: newImage.width, height: newImage.height)
    }

    init(image: CGImage, scale: CGFloat, preferences: UserDefaults = .standard, captureID: UUID = UUID(), baseImage: CGImage? = nil, annotations: [ScreenshotSupport.Annotation] = []) {
        self.image = image
        self.captureID = captureID
        self.baseImage = baseImage
        self.annotations = annotations
        captureScale = scale.isFinite && scale > 0 ? scale : 1
        self.preferences = preferences
        let pointer = NSEvent.mouseLocation
        let screen = (NSScreen.screens.first { NSMouseInRect(pointer, $0.frame, false) }
                      ?? NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let native = CGSize(width: CGFloat(image.width) / captureScale,
                            height: CGFloat(image.height) / captureScale)
        let cap = min(screen.width, screen.height) * 0.55
        let fit = min(1, cap / max(native.width, native.height))
        let floor = max(140 / native.width, 90 / native.height)
        let factor = min(max(fit, floor), min(screen.width / native.width, screen.height / native.height))
        let size = CGSize(width: native.width * factor, height: native.height * factor)
        super.init(contentRect: CGRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2,
                                      width: size.width, height: size.height),
                   styleMask: [.borderless, .resizable, .nonactivatingPanel], backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        level = Self.pinLevel
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        contentAspectRatio = CGSize(width: image.width, height: image.height)
        minSize = CGSize(width: min(140, native.width * 0.5), height: min(90, native.height * 0.5))
        contentView = surface
        delegate = self
        refreshAppearance()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func magnify(with event: NSEvent) {
        surface.magnify(with: event)
    }

    static func gestureTarget(at point: CGPoint, windows: [NSWindow]) -> ScreenshotPinWindow? {
        windows.lazy.compactMap { $0 as? ScreenshotPinWindow }.first {
            !$0.isHiddenForDrag && !$0.isClosed && !$0.isPositionLocked
                && !$0.ignoresMouseEvents && $0.frame.contains(point)
        }
    }

    func resetGestureTracking() { surface.resetGestureTracking() }

    func handleGestureEvent(_ event: NSEvent, screenLocation: CGPoint = NSEvent.mouseLocation) {
        guard !isClosed, !isPositionLocked, !ignoresMouseEvents else { return }
        surface.handleGestureEvent(event, at: convertPoint(fromScreen: screenLocation))
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .gesture {
            surface.handleGestureEvent(event)
        }
        super.sendEvent(event)
    }

    func attachChrome() {
        guard !isClosed else { return }
        chrome.attach()
        updateHover(at: NSEvent.mouseLocation)
    }

    func showPin(orderFront: Bool = true) {
        guard !isClosed else { return }
        if orderFront {
            NSApp.activate(ignoringOtherApps: true)
            makeKeyAndOrderFront(nil)
            orderFrontRegardless()
            makeFirstResponder(surface)
        }
        attachChrome()
        updateHover(at: NSEvent.mouseLocation)
    }

    func refreshAppearance() {
        let rounded = preferences.object(forKey: DefaultsKey.screenshotPinRoundedCorners) as? Bool ?? true
        surface.layer?.cornerRadius = rounded ? 10 : 0
        invalidateShadow()
    }

    func updateHover(at point: CGPoint) {
        guard !isClosed else { return }
        let hovered = frame.contains(point)
        if hovered != isHovered {
            isHovered = hovered
            updateImageOpacity()
            chrome.setControlsVisible(hovered)
        }
    }

    func setOpacity(_ value: CGFloat) {
        guard !isClosed, value.isFinite else { return }
        let next = min(1, max(0.1, value))
        guard next != chosenOpacity else { return }
        chosenOpacity = next
        updateImageOpacity()
        chrome.showFeedback("\(Int((next * 100).rounded()))%")
    }

    func reportZoom() {
        guard !isClosed else { return }
        chrome.showFeedback(String(format: "%.1fx", locale: Locale.current, Double(zoomMultiplier)))
    }

    func setZoom(_ multiplier: CGFloat) {
        guard multiplier.isFinite, multiplier > 0, !NSEvent.modifierFlags.contains(.option) else { return }
        surface.zoom(by: multiplier / zoomMultiplier,
                     at: CGPoint(x: frame.width / 2, y: frame.height / 2))
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isKeyWindow, event.modifierFlags.intersection([.command, .option, .control, .shift]) == .command,
              ["w", "e", "c", "s"].contains(event.charactersIgnoringModifiers?.lowercased() ?? "")
        else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }

    func setPositionLocked(_ enabled: Bool) {
        guard !isClosed else { return }
        isPositionLocked = enabled
        isMovableByWindowBackground = !enabled
        if enabled { styleMask.remove(.resizable) } else { styleMask.insert(.resizable) }
        chrome.refreshButtons()
    }

    func setClickThrough(_ enabled: Bool) {
        guard !isClosed else { return }
        ignoresMouseEvents = enabled
        updateImageOpacity()
        chrome.refreshButtons()
        onClickThroughChanged?()
    }

    private func updateImageOpacity() {
        surface.layer?.opacity = Float(ignoresMouseEvents && isHovered ? min(chosenOpacity, 0.25) : chosenOpacity)
    }

    func closePin() {
        guard !isClosed else { return }
        isClosed = true
        chrome.detach()
        orderOut(nil)
        onClose?()
    }

    override func performClose(_ sender: Any?) { closePin() }

    func windowDidMove(_ notification: Notification) { chrome.layout() }
    func windowDidResize(_ notification: Notification) { chrome.layout() }
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        isPositionLocked || NSEvent.modifierFlags.contains(.option) ? frame.size : frameSize
    }

    private(set) var isHiddenForDrag = false
    private var wasVisibleBeforeDrag = false

    func setHiddenForDrag(_ hidden: Bool) {
        guard !isClosed, hidden != isHiddenForDrag else { return }
        isHiddenForDrag = hidden
        if hidden {
            wasVisibleBeforeDrag = isVisible
            orderOut(nil)
            chrome.setControlsVisible(false)
        } else {
            if wasVisibleBeforeDrag {
                orderFrontRegardless()
            }
            chrome.layout()
            chrome.setControlsVisible(isHovered)
        }
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let step: CGFloat = flags.contains(.shift) ? 12 : 1
        switch Int(event.keyCode) {
        case kVK_Escape: closePin()
        case kVK_ANSI_W where flags.contains(.command): closePin()
        case kVK_ANSI_C where flags.contains(.command): onCopy?()
        case kVK_ANSI_E where flags.contains(.command): onEdit?()
        case kVK_ANSI_S where flags.contains(.command): onSave?()
        case kVK_LeftArrow where !isPositionLocked: setFrameOrigin(CGPoint(x: frame.minX - step, y: frame.minY))
        case kVK_RightArrow where !isPositionLocked: setFrameOrigin(CGPoint(x: frame.minX + step, y: frame.minY))
        case kVK_UpArrow where !isPositionLocked: setFrameOrigin(CGPoint(x: frame.minX, y: frame.minY + step))
        case kVK_DownArrow where !isPositionLocked: setFrameOrigin(CGPoint(x: frame.minX, y: frame.minY - step))
        default: break
        }
    }
}

extension Notification.Name {
    static let screenshotPinDragDidBegin = Notification.Name("screenshotPinDragDidBegin")
    static let screenshotPinDragDidEnd = Notification.Name("screenshotPinDragDidEnd")
    static let screenshotPinWindowDragDidBegin = Notification.Name("screenshotPinWindowDragDidBegin")
    static let screenshotPinWindowDragDidEnd = Notification.Name("screenshotPinWindowDragDidEnd")
}
