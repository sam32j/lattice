import AppKit
import SwiftUI

/// The same native-control rendering seam used by the Settings choice tests.
enum InputSettingsControlTests {
    static func run(_ suite: TestSuite) {
        for (enabled, color, expected) in [(true, Color.red, true), (true, .green, false),
                                          (true, .secondary, false), (false, .red, true),
                                          (false, .green, true), (false, .secondary, true)] {
            let options = SuperKeyOptions(superKeyEnabled: enabled,
                                          superKeyStatus: SettingsFeatureStatus(color: color, message: "Status"))
            suite.expect(options.superKeyOptionsDisabled == expected,
                         "Super Key dependent controls are disabled when off or in error, without blocking healthy configuration")
        }
        hoverLifecycle(suite)
        anchoredHint(suite)
        let secondaryScreen = NSRect(x: -1440, y: 0, width: 1440, height: 900)
        let leftEdge = HoverHintView.hintFrame(size: NSSize(width: 280, height: 60),
            anchor: NSRect(x: -1440, y: 300, width: 21, height: 21), visibleFrame: secondaryScreen)
        suite.expect(leftEdge == NSRect(x: -1440, y: 234, width: 280, height: 60),
                     "hint stays beside the icon and inside a negative-origin secondary screen")
        let bottomEdge = HoverHintView.hintFrame(size: NSSize(width: 280, height: 60),
            anchor: NSRect(x: -21, y: 5, width: 21, height: 21), visibleFrame: secondaryScreen)
        suite.expect(bottomEdge == NSRect(x: -280, y: 32, width: 280, height: 60),
                     "hint flips above the icon near the screen bottom and clamps its right edge")
        suite.expect(SettingsFeatureStatus(color: .red, message: "Conflict").symbolName == "exclamationmark.circle"
                     && SettingsFeatureStatus(color: .red, message: "Conflict").symbolColor == .red
                     && SettingsFeatureStatus(color: .green, message: "Active").symbolName == nil
                     && SettingsFeatureStatus(color: .secondary, message: "Off").symbolName == nil,
                     "only errors have an indicator: a red outlined exclamation circle")
        let light = LightState()
        let lightHost = NSHostingView(rootView: LightControl(brightness: light))
        lightHost.frame = NSRect(x: 0, y: 0, width: 500, height: 50)
        lightHost.layoutSubtreeIfNeeded()
        if let slider = sliders(in: lightHost).first {
            suite.expect(slider.isEnabled, "zero keyboard brightness does not disable its slider")
            slider.doubleValue = 0.4
            _ = slider.sendAction(slider.action, to: slider.target)
            suite.expect(light.keyboardLightEnabled == true && light.keyboardLightLevel == 0.4,
                         "raising the slider from zero restores the light without a separate toggle")
        } else { suite.expect(false, "keyboard-light control renders a native slider") }
        for (text, language, expected) in [
            ("Rules do not apply", AppLanguage.enUS, "Rules do not apply."),
            ("Rules do not apply.", .enUS, "Rules do not apply."),
            ("  ", .enUS, ""), ("\nText  ", .enUS, "Text."),
            ("設定", .ja, "設定。"), ("設定。", .ja, "設定。"),
            ("设置", .zhHans, "设置。"), ("Options…", .enUS, "Options…")
        ] {
            suite.expect(SheetCaption(caption: text, l10n: .init(language: language)).punctuatedCaption == expected,
                         "ALS descriptions add locale-appropriate punctuation without duplicating it")
        }
        let capture = Capture()
        capture.setCapturing(true)
        capture.setCapturing(true)
        suite.expect(capture.syncCount == 2 && Capture.isCaptureActive,
                     "retrying an active capture rechecks permission and rebuilds the listener without restarting")
        capture.setCapturing(false)
        suite.expect(!Capture.isCaptureActive && capture.syncCount == 3,
                     "ending a retried capture clears shared ownership and resynchronizes")
        let dot = NSHostingView(rootView: SettingsStatusDot(status: SettingsFeatureStatus(color: .red, message: "Key mapping conflict")))
        dot.frame = NSRect(x: 0, y: 0, width: 24, height: 24)
        dot.layoutSubtreeIfNeeded()
        suite.expect(hints(in: dot).contains { $0.message == "Key mapping conflict" },
                     "error indicators expose their current status through the timed hint view")
        for color in [Color.green, .secondary] {
            let hidden = NSHostingView(rootView: SettingsStatusDot(status: SettingsFeatureStatus(color: color, message: "No error")))
            hidden.frame = NSRect(x: 0, y: 0, width: 24, height: 24)
            hidden.layoutSubtreeIfNeeded()
            suite.expect(hints(in: hidden).isEmpty, "off and active states have no indicator tooltip")
        }
        suite.expect(tooltips(in: dot).isEmpty,
                     "native tooltips cannot race the one-second timed presenter")
        var value = 50.0
        let row = SettingsValueSlider(title: "Timing", value: Binding(get: { value }, set: { value = $0 }),
                                      range: 10...110, step: 10, readout: "50 ms")
        let host = NSHostingView(rootView: row)
        host.frame = NSRect(x: 0, y: 0, width: 220, height: 30)
        host.layoutSubtreeIfNeeded()
        guard let slider = sliders(in: host).first else {
            suite.expect(false, "input settings render a native NSSlider")
            return
        }
        suite.expect(slider.numberOfTickMarks == 0 && !slider.allowsTickMarkValuesOnly,
                     "native input sliders have no tick marks")
        suite.expect(slider.isContinuous && slider.minValue == 10 && slider.maxValue == 110,
                     "native input sliders retain their range and update continuously")
        for (raw, expected) in [(24.0, 20.0), (26.0, 30.0), (10.0, 10.0), (110.0, 110.0)] {
            slider.doubleValue = raw
            _ = slider.sendAction(slider.action, to: slider.target)
            suite.expect(value == expected && slider.doubleValue == expected,
                         "native slider input \(raw) preserves the configured step as \(expected)")
        }
        slider.doubleValue = 50
        _ = slider.sendAction(slider.action, to: slider.target)
        let arrow = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                     windowNumber: 0, context: nil, characters: "\u{F703}",
                                     charactersIgnoringModifiers: "\u{F703}", isARepeat: false, keyCode: 124)!
        slider.keyDown(with: arrow)
        suite.expect(value == 60, "a keyboard arrow moves a native slider by its configured step")
        let disabled = NSHostingView(rootView: row.disabled(true))
        disabled.frame = host.frame
        disabled.layoutSubtreeIfNeeded()
        suite.expect(sliders(in: disabled).first?.isEnabled == false,
                     "disabled settings cannot be changed through the native slider")
    }

    private static func sliders(in view: NSView) -> [NSSlider] {
        view.subviews.flatMap { subview in
            if let slider = subview as? NSSlider { return [slider] }
            return sliders(in: subview)
        }
    }

    private static func tooltips(in view: NSView) -> [String] {
        (view.toolTip.map { [$0] } ?? []) + view.subviews.flatMap { tooltips(in: $0) }
    }

    private static func hints(in view: NSView) -> [HoverHintView] {
        (view as? HoverHintView).map { [$0] } ?? view.subviews.flatMap { hints(in: $0) }
    }

    private static func hoverLifecycle(_ suite: TestSuite) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 80),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let hint = HoverHintView(frame: NSRect(x: 20, y: 20, width: 24, height: 24))
        hint.message = "Super Key active"
        window.contentView?.addSubview(hint)
        window.orderFrontRegardless()
        let event = NSEvent.enterExitEvent(with: .mouseEntered, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0,
            trackingNumber: 0, userData: nil)!
        hint.mouseEntered(with: event)
        RunLoop.current.run(until: Date().addingTimeInterval(0.7))
        suite.expect(!hint.hint.isVisible, "hover hint waits rather than opening immediately")
        RunLoop.current.run(until: Date().addingTimeInterval(0.45))
        suite.expect(hint.hint.isVisible, "hover hint opens after one second")
        hint.message = "Super Key paused"
        suite.expect(!hint.hint.isVisible, "a changed status dismisses the stale hover message")
        hint.mouseEntered(with: event)
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
        RunLoop.current.run(until: Date().addingTimeInterval(1.1))
        suite.expect(!hint.hint.isVisible, "switching apps cancels a pending hover hint")
        hint.mouseExited(with: event)
        hint.mouseEntered(with: event)
        hint.mouseExited(with: event)
        RunLoop.current.run(until: Date().addingTimeInterval(1.1))
        suite.expect(!hint.hint.isVisible, "leaving before the hover delay cancels presentation")
        hint.mouseEntered(with: event)
        hint.removeFromSuperview()
        RunLoop.current.run(until: Date().addingTimeInterval(1.1))
        suite.expect(!hint.hint.isVisible, "detaching a hint view cancels pending presentation")
    }

    private static func anchoredHint(_ suite: TestSuite) {
        let window = NSWindow(contentRect: NSRect(x: 150, y: 180, width: 500, height: 300),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let host = NSHostingView(rootView: HStack {
            Text("Super Key")
            SettingsStatusDot(status: SettingsFeatureStatus(color: .red, message: "Key mapping conflict"))
            Spacer()
        }.padding(30))
        host.sizingOptions = []
        host.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
        window.contentView = host
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        // Let SwiftUI finish its initial representable/layout replacement before hovering.
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        host.layoutSubtreeIfNeeded()
        guard let anchor = hints(in: host).first else {
            suite.expect(false, "Super Key status has an anchored hint view")
            return
        }
        let hoverPoint = anchor.convert(NSPoint(x: anchor.bounds.midX, y: anchor.bounds.midY), to: nil)
        let event = NSEvent.enterExitEvent(with: .mouseEntered, location: hoverPoint, modifierFlags: [],
            timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0,
            trackingNumber: 0, userData: nil)!
        anchor.mouseEntered(with: event)
        RunLoop.current.run(until: Date().addingTimeInterval(1.15))
        let anchorScreen = window.convertToScreen(anchor.convert(anchor.bounds, to: nil))
        let popoverFrame = anchor.hint.frame
        suite.expect(anchor.bounds.width > 0 && anchor.bounds.height > 0,
                     "status hint retains a nonzero local anchor")
        suite.expect(anchor.hint.isVisible && popoverFrame.insetBy(dx: -35, dy: -35).contains(
            NSPoint(x: anchorScreen.midX, y: anchorScreen.midY)),
            "conflict tooltip opens next to its status icon: anchor=\(anchorScreen), popover=\(popoverFrame), hover=\(hoverPoint), event=\(event.locationInWindow)")
        anchor.mouseExited(with: event)
    }
}
