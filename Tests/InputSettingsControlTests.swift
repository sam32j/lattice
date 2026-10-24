import AppKit
import SwiftUI

/// The same native-control rendering seam used by the Settings choice tests.
enum InputSettingsControlTests {
    static func run(_ suite: TestSuite) {
        let capture = Capture()
        capture.setCapturing(true)
        capture.setCapturing(true)
        suite.expect(capture.syncCount == 2 && Capture.isCaptureActive,
                     "retrying an active capture rechecks permission and rebuilds the listener without restarting")
        capture.setCapturing(false)
        suite.expect(!Capture.isCaptureActive && capture.syncCount == 3,
                     "ending a retried capture clears shared ownership and resynchronizes")
        let dot = NSHostingView(rootView: SettingsStatusDot(status: SettingsFeatureStatus(color: .green, message: "Super Key active")))
        dot.frame = NSRect(x: 0, y: 0, width: 24, height: 24)
        dot.layoutSubtreeIfNeeded()
        suite.expect(tooltips(in: dot).contains("Super Key active"),
                     "status dots expose their message through a native hover tooltip")
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
}
