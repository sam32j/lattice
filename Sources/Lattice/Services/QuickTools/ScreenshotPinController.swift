// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// Owns pins and lifetime-bound monitoring, while each pin owns its presentation.
final class ScreenshotPinController {
    static let shared = ScreenshotPinController()
    private var pins: [ScreenshotPinWindow] = []
    private var escapeMonitor: Any?
    private var gestureMonitor: Any?
    private var localGestureMonitor: Any?
    private weak var activeGesturePin: ScreenshotPinWindow?
    private var lastGestureTime: TimeInterval = 0
    private var gestureFinished = false
    private var hoverTimer: Timer?
    private var preferenceObserver: NSObjectProtocol?
    private var dragObservers: [NSObjectProtocol] = []
    private init() {
        ScreenshotPinWindow.onResetGestureState = { [weak self] in
            self?.resetGestureState()
        }
    }

    var protectedWindowIDs: Set<CGWindowID> {
        var ids = Set<CGWindowID>()
        for pin in pins {
            if pin.isVisible && pin.windowNumber > 0 {
                ids.insert(CGWindowID(pin.windowNumber))
            }
            if let children = pin.childWindows {
                for child in children {
                    if child.isVisible && child.windowNumber > 0 {
                        ids.insert(CGWindowID(child.windowNumber))
                    }
                }
            }
        }
        return ids
    }

    func setPinsHiddenForDrag(_ hidden: Bool, except: ScreenshotPinWindow? = nil) {
        for pin in pins where pin !== except {
            pin.setHiddenForDrag(hidden)
        }
    }

    func findPin(for captureID: UUID) -> ScreenshotPinWindow? {
        pins.first { $0.captureID == captureID }
    }

    @discardableResult
    func pin(image: CGImage, scale: CGFloat, baseImage: CGImage? = nil, annotations: [ScreenshotSupport.Annotation] = [], captureID: UUID = UUID()) -> ScreenshotPinWindow {
        let pin = ScreenshotPinWindow(image: image, scale: scale, captureID: captureID, baseImage: baseImage, annotations: annotations)
        pin.onClose = { [weak self, weak pin] in
            self?.pins.removeAll { $0 === pin }
            self?.refreshMonitoring()
        }
        pin.onCopy = { [weak pin] in pin.map { Self.copy($0) } }
        pin.onSave = { [weak pin] in pin.map { Self.save($0) } }
        pin.onCloseAll = { [weak self] in self?.closeAll() }
        pin.onClickThroughChanged = { [weak self] in self?.refreshEscapeMonitor() }
        pin.onEdit = { [weak pin] in
            guard let pin else { return }
            let base = pin.baseImage ?? pin.image
            ScreenshotService.shared.openEditor(
                with: .init(id: pin.captureID, image: base, scale: pin.captureScale, anchorRect: pin.frame, annotations: pin.annotations),
                above: pin,
                originatingPin: pin
            )
        }
        let offset = CGFloat(pins.count % 5) * 26
        pin.setFrameOrigin(CGPoint(x: pin.frame.minX + offset, y: pin.frame.minY - offset))
        pins.append(pin)
        pin.showPin()
        refreshMonitoring()
        return pin
    }

    func closeAll() {
        for pin in pins { pin.closePin() }
    }

    private func refreshMonitoring() {
        refreshEscapeMonitor()
        refreshGestureMonitor()
        if !pins.isEmpty, hoverTimer == nil {
            let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
                let location = NSEvent.mouseLocation
                self?.pins.forEach { $0.updateHover(at: location) }
            }
            timer.tolerance = 0.02
            RunLoop.main.add(timer, forMode: .common)
            hoverTimer = timer
            preferenceObserver = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
                    self?.pins.forEach { $0.refreshAppearance() }
                }
        } else if pins.isEmpty {
            hoverTimer?.invalidate()
            hoverTimer = nil
            if let preferenceObserver { NotificationCenter.default.removeObserver(preferenceObserver) }
            preferenceObserver = nil
        }
        if !pins.isEmpty && dragObservers.isEmpty {
            let center = NotificationCenter.default
            dragObservers = [
                center.addObserver(forName: .screenshotPinDragDidBegin, object: nil, queue: .main) { [weak self] _ in
                    self?.setPinsHiddenForDrag(true)
                },
                center.addObserver(forName: .screenshotPinDragDidEnd, object: nil, queue: .main) { [weak self] _ in
                    self?.setPinsHiddenForDrag(false)
                },
                center.addObserver(forName: .screenshotPinWindowDragDidBegin, object: nil, queue: .main) { [weak self] note in
                    self?.setPinsHiddenForDrag(true, except: note.object as? ScreenshotPinWindow)
                },
                center.addObserver(forName: .screenshotPinWindowDragDidEnd, object: nil, queue: .main) { [weak self] _ in
                    self?.setPinsHiddenForDrag(false)
                }
            ]
        } else if pins.isEmpty && !dragObservers.isEmpty {
            let center = NotificationCenter.default
            dragObservers.forEach { center.removeObserver($0) }
            dragObservers.removeAll()
        }
    }

    private func refreshGestureMonitor() {
        guard !pins.isEmpty else {
            activeGesturePin = nil
            if let monitor = gestureMonitor {
                NSEvent.removeMonitor(monitor)
                gestureMonitor = nil
            }
            if let monitor = localGestureMonitor {
                NSEvent.removeMonitor(monitor)
                localGestureMonitor = nil
            }
            return
        }
        if gestureMonitor == nil {
            gestureMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.gesture, .magnify]) { [weak self] event in
                self?.routeGesture(event)
            }
        }
        if localGestureMonitor == nil {
            localGestureMonitor = NSEvent.addLocalMonitorForEvents(matching: [.gesture, .magnify]) { [weak self] event in
                self?.routeGesture(event) == true ? nil : event
            }
        }
    }

    @discardableResult private func routeGesture(_ event: NSEvent) -> Bool {
        let location = NSEvent.mouseLocation
        let time = ProcessInfo.processInfo.systemUptime
        let sequenceBegan = event.phase.contains(.began)
            || (event.type == .gesture && event.allTouches().contains { $0.phase == .began })
        // Retain the target while fingers move beyond the pin. A quiet gap
        // recovers ownership if AppKit omitted the preceding end packet.
        if activeGesturePin == nil || time - lastGestureTime > 0.25
            || (gestureFinished && sequenceBegan) {
            activeGesturePin?.resetGestureTracking()
            var windows = NSApp.orderedWindows.filter { window in
                window.isVisible && pins.contains { $0 === window }
            }
            if windows.isEmpty {
                windows = pins.filter(\.isVisible).reversed()
            }
            activeGesturePin = ScreenshotPinWindow.gestureTarget(at: location, windows: windows)
            activeGesturePin?.resetGestureTracking()
            gestureFinished = false
        }
        guard let pin = activeGesturePin, pin.isVisible, !pin.isClosed,
              !pin.isPositionLocked, !pin.ignoresMouseEvents, !pin.isHiddenForDrag else {
            activeGesturePin?.resetGestureTracking()
            activeGesturePin = nil
            return false
        }
        lastGestureTime = time
        pin.handleGestureEvent(event, screenLocation: location)
        if event.phase.contains(.ended) || event.phase.contains(.cancelled)
            || (event.type == .gesture && event.allTouches().allSatisfy {
                $0.phase == .ended || $0.phase == .cancelled
            }) { gestureFinished = true }
        return true
    }

    func resetGestureState() {
        activeGesturePin?.resetGestureTracking()
        activeGesturePin = nil
        gestureFinished = false
        lastGestureTime = 0
    }

    private func refreshEscapeMonitor() {
        let needed = pins.contains { $0.ignoresMouseEvents }
        if needed, escapeMonitor == nil {
            escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                guard let self, event.modifierFlags.contains(.option) else { return }
                let location = NSEvent.mouseLocation
                for pin in self.pins where pin.ignoresMouseEvents && pin.frame.contains(location) {
                    pin.setClickThrough(false)
                }
                self.refreshEscapeMonitor()
            }
        } else if !needed, let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
    }

    private static func copy(_ pin: ScreenshotPinWindow) {
        let strings = FeatureStrings.screenshot(L10n.shared.language)
        guard ScreenshotEditorController.copyImage(
            ScreenshotRenderer.Export(image: pin.image, scale: pin.captureScale),
            fileNamePrefix: strings.fileNamePrefix) else { NSSound.beep(); return }
        QuickToolHUD.show(icon: "camera.viewfinder", message: strings.copiedHUD)
    }

    private static func save(_ pin: ScreenshotPinWindow) {
        let strings = FeatureStrings.screenshot(L10n.shared.language)
        guard let data = ScreenshotRenderer.pngData(from: pin.image, scale: pin.captureScale) else {
            NSSound.beep()
            return
        }
        let (url, number) = ScreenshotService.saveDestination(strings: strings)
        do {
            try data.write(to: url, options: .withoutOverwriting)
            ScreenshotSupport.markAsScreenCapture(url)
            QuickToolHUD.show(icon: "camera.viewfinder", message: String(format: strings.savedHUDFormat,
                url.deletingLastPathComponent().lastPathComponent))
        } catch {
            if let number { ScreenshotService.rewindNumberSequence(toReuse: number) }
            QuickToolHUD.show(icon: "exclamationmark.triangle", message: error.localizedDescription)
        }
    }
}
