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
    private var hoverTimer: Timer?
    private var preferenceObserver: NSObjectProtocol?
    private var dragObservers: [NSObjectProtocol] = []
    private init() {}

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

    func pin(image: CGImage, scale: CGFloat) {
        let pin = ScreenshotPinWindow(image: image, scale: scale)
        pin.onClose = { [weak self, weak pin] in
            self?.pins.removeAll { $0 === pin }
            self?.refreshMonitoring()
        }
        pin.onCopy = { [weak pin] in pin.map { Self.copy($0) } }
        pin.onSave = { [weak pin] in pin.map { Self.save($0) } }
        pin.onCloseAll = { [weak self] in self?.closeAll() }
        pin.onClickThroughChanged = { [weak self] in self?.refreshEscapeMonitor() }
        pin.onReopenPreview = { [weak pin] in
            guard let pin else { return }
            ScreenshotService.shared.reopenPreview(image: pin.image, scale: pin.captureScale, anchorRect: pin.frame)
        }
        let offset = CGFloat(pins.count % 5) * 26
        pin.setFrameOrigin(CGPoint(x: pin.frame.minX + offset, y: pin.frame.minY - offset))
        pins.append(pin)
        pin.showPin()
        refreshMonitoring()
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
                guard let pin = self?.gestureTarget() else { return }
                if !NSApp.isActive || !pin.isKeyWindow {
                    NSApp.activate(ignoringOtherApps: true)
                    pin.makeKeyAndOrderFront(nil)
                    pin.makeFirstResponder(pin.contentView)
                }
                pin.handleGestureEvent(event)
            }
        }
        if localGestureMonitor == nil {
            localGestureMonitor = NSEvent.addLocalMonitorForEvents(matching: [.gesture, .magnify]) { [weak self] event in
                guard let pin = self?.gestureTarget() else { return event }
                if event.type == .magnify {
                    pin.magnify(with: event)
                    return nil
                }
                pin.handleGestureEvent(event)
                return nil
            }
        }
    }

    private func gestureTarget() -> ScreenshotPinWindow? {
        let location = NSEvent.mouseLocation
        return pins.first {
            $0.isVisible && !$0.isHiddenForDrag && $0.frame.contains(location) && !$0.isClosed && !$0.isPositionLocked && !$0.ignoresMouseEvents
        }
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
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = ScreenshotSupport.fileName(prefix: strings.fileNamePrefix, date: Date())
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, let url = panel.url,
                  let data = ScreenshotRenderer.pngData(from: pin.image, scale: pin.captureScale) else { return }
            do { try data.write(to: url, options: .atomic) }
            catch { NSSound.beep() }
        }
    }
}
