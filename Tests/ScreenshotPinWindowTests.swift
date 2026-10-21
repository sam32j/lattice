// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum ScreenshotPinWindowTests {
    @MainActor static func run(_ suite: TestSuite) {
        guard let context = CGContext(data: nil, width: 400, height: 200, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let image = context.makeImage() else { suite.expect(false, "pin fixture image"); return }
        let namespace = "com.vorssaint.tests.pin-window-\(UUID().uuidString)"
        guard let preferences = UserDefaults(suiteName: namespace) else { return }
        defer { preferences.removePersistentDomain(forName: namespace) }
        let pin = ScreenshotPinWindow(image: image, scale: 2, preferences: preferences)
        defer { pin.closePin() }
        var saved = 0
        pin.onSave = { saved += 1 }
        if let save = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
                                      timestamp: 0, windowNumber: pin.windowNumber, context: nil,
                                      characters: "s", charactersIgnoringModifiers: "s", isARepeat: false,
                                      keyCode: 1) {
            pin.keyDown(with: save)
        }
        suite.expect(saved == 1, "Command-S dispatches the focused pin's save action")
        var copied = 0
        pin.onCopy = { copied += 1 }
        suite.expect(pin.contentView?.tryToPerform(#selector(NSText.copy(_:)), with: nil) == true && copied == 1,
                     "the standard Edit menu copy action reaches the focused pin responder")
        suite.expect(!pin.isVisible, "pin window is not visible upon initialization")
        pin.setOpacity(0.1)
        suite.expectClose(pin.alphaValue, 1, "pin controls retain an opaque window at ten percent image opacity")
        suite.expectClose(pin.displayedImageOpacity, 0.1, "only the image becomes ten percent opaque")
        suite.expectClose(pin.cornerRadius, 10, "pin corners use the fixed ten point default")
        preferences.set(false, forKey: DefaultsKey.screenshotPinRoundedCorners)
        pin.refreshAppearance()
        suite.expectClose(pin.cornerRadius, 0, "disabling rounded corners updates an existing pin")
        preferences.set(true, forKey: DefaultsKey.screenshotPinRoundedCorners)
        pin.refreshAppearance()
        suite.expect(SettingsBackupSupport.exportKeys().contains(DefaultsKey.screenshotPinRoundedCorners),
                     "the rounded pin preference travels with settings backups")

        pin.setOpacity(0.9)
        pin.setClickThrough(true)
        pin.updateHover(at: CGPoint(x: pin.frame.midX, y: pin.frame.midY))
        suite.expect(!pin.isVisible, "pin window remains invisible during hover testing")
        suite.expect(pin.ignoresMouseEvents, "click-through releases the image's mouse events")
        suite.expectClose(pin.displayedImageOpacity, 0.25, "hovering a click-through pin dims the image")
        pin.updateHover(at: CGPoint(x: pin.frame.maxX + 10, y: pin.frame.maxY + 10))
        suite.expectClose(pin.displayedImageOpacity, 0.9, "leaving restores the chosen opacity")
        pin.updateHover(at: CGPoint(x: pin.frame.midX, y: pin.frame.midY))
        pin.setOpacity(0.1)
        suite.expectClose(pin.displayedImageOpacity, 0.1, "hover dimming never makes a faint pin more opaque")
        pin.setClickThrough(false)
        suite.expect(!pin.ignoresMouseEvents, "the cursor action restores image interaction")

        let frame = pin.frame
        pin.setPositionLocked(true)
        let wheel = ScreenshotPinGestureTests.Gesture()
        wheel.scroll = 1
        let pinch = ScreenshotPinGestureTests.Gesture()
        pinch.pinch = 0.5
        let surface = pin.contentView as? ScreenshotPinGestureView
        suite.expect(surface != nil && pin.makeFirstResponder(surface) && pin.firstResponder === surface
                     && surface?.needsPanelToBecomeKey == true,
                     "the pin image requests nonactivating panel focus and can become first responder")
        surface?.scrollWheel(with: wheel)
        surface?.magnify(with: pinch)
        if let arrow = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                       windowNumber: pin.windowNumber, context: nil,
                                       characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 124) {
            pin.keyDown(with: arrow)
        }
        suite.expect(pin.frame == frame && !pin.styleMask.contains(.resizable),
                     "locking a production pin freezes arrows, wheel, pinch and native resize")
        wheel.flags = .option
        surface?.scrollWheel(with: wheel)
        suite.expect(pin.chosenOpacity > 0.1, "production locked pins still accept opacity changes")
        pin.setPositionLocked(false)
        surface?.magnify(with: pinch)
        suite.expect(pin.frame.width > frame.width && pin.styleMask.contains(.resizable),
                     "unlocking restores zoom and native edge resizing")
        suite.expectClose(pin.cornerRadius, 10, "zoom does not scale the corner radius")
        suite.expectClose(pin.zoomMultiplier, 1.5, "zoom feedback uses original display points")

        let beforeForeign = pin.frame
        let center = CGPoint(x: beforeForeign.midX, y: beforeForeign.midY)
        let foreign = ScreenshotPinGestureTests.Gesture()
        foreign.pinch = 0.1
        foreign.point = CGPoint(x: 9000, y: 9000)
        pin.handleGestureEvent(foreign, screenLocation: center)
        suite.expectClose(pin.frame.midX, center.x, "foreign-window pinch coordinates do not move the horizontal anchor", tol: 1)
        suite.expectClose(pin.frame.midY, center.y, "foreign-window pinch coordinates do not move the vertical anchor", tol: 1)

        let other = ScreenshotPinWindow(image: image, scale: 2, preferences: preferences)
        defer { other.closePin() }
        let oldFrame = other.frame
        let oldZoom = other.zoomMultiplier
        let croppedImage = image.cropping(to: CGRect(x: 0, y: 0, width: 100, height: 200))!
        other.updateImage(croppedImage)
        suite.expectClose(other.frame.width / other.frame.height, 0.5,
                          "editing a pin to a new aspect ratio immediately resizes its frame")
        suite.expectClose(other.zoomMultiplier, oldZoom, "a cropped pin preserves its display zoom")
        suite.expectClose(other.frame.midX, oldFrame.midX, "cropping keeps the pin horizontally centered")
        suite.expectClose(other.frame.midY, oldFrame.midY, "cropping keeps the pin vertically centered")
        other.setFrame(pin.frame, display: false)
        suite.expect(ScreenshotPinWindow.gestureTarget(at: center, windows: [other, pin]) === other,
                     "overlapping pins route gestures in front-to-back window order")
        other.setPositionLocked(true)
        suite.expect(ScreenshotPinWindow.gestureTarget(at: center, windows: [other, pin]) === pin,
                     "a locked front pin leaves the eligible pin underneath reachable")
        pin.setZoom(0.5)
        suite.expectClose(pin.zoomMultiplier, 0.5, "the half-size menu preset is reachable even for a small source image")
        other.performClose(nil)
        suite.expect(other.isClosed, "the native Close Window menu action runs pin cleanup")

        var closed = 0
        pin.onClose = { closed += 1 }
        let drag = ScreenshotPinDragView(pin: pin)
        drag.completeDrag(operation: [], modifiers: [])
        suite.expect(!pin.isClosed, "cancelling or rejecting a file drop keeps the pin")
        drag.completeDrag(operation: .copy, modifiers: .option)
        suite.expect(!pin.isClosed, "Option-dropping a file keeps its pin")
        drag.completeDrag(operation: .copy, modifiers: [])
        pin.closePin()
        suite.expect(pin.isClosed && closed == 1, "a successful ordinary file drop closes its pin once")
        ScreenshotPinFilePromiseTests.run(suite, image: image)
        ScreenshotPinChromeTests.run(suite, image: image)
        ScreenshotQuickLookTests.run(suite, image: image)
    }
}
