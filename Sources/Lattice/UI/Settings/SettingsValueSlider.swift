import AppKit
import SwiftUI

/// Native, tick-free input control. Values remain available to VoiceOver and
/// appear above the thumb while dragging instead of taking a separate column.
struct SettingsValueSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0
    let readout: String
    var usesSystemAppearance = false
    var onEditingChanged: (Bool) -> Void = { _ in }
    @State private var tracking = false

    var body: some View {
        Group {
            if usesSystemAppearance {
                Slider(value: Binding(get: { value }, set: { raw in
                    let next = step > 0 ? range.lowerBound + ((raw - range.lowerBound) / step).rounded() * step : raw
                    value = min(max(next, range.lowerBound), range.upperBound)
                }), in: range, onEditingChanged: { editing in
                    tracking = editing
                    onEditingChanged(editing)
                })
                .labelsHidden()
                .controlSize(.regular)
            } else {
                NativeSettingsSlider(value: $value, tracking: $tracking, range: range, step: step,
                                     onEditingChanged: onEditingChanged)
            }
        }
            .frame(height: 22)
            .overlay {
                if tracking {
                    GeometryReader { geometry in
                        let fraction = min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
                        Text(readout)
                            .font(.caption.monospacedDigit())
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                            .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                            .fixedSize()
                            .position(x: 8 + fraction * max(geometry.size.width - 16, 0), y: -14)
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .help(readout)
            .accessibilityLabel(title)
            .accessibilityValue(readout)
    }
}

struct SettingsSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0
    let readout: String
    var sliderWidth: CGFloat = 140
    var usesSystemAppearance = true
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        SettingsControlRow(title: title) {
            SettingsValueSlider(title: title, value: $value, range: range, step: step,
                                readout: readout, usesSystemAppearance: usesSystemAppearance,
                                onEditingChanged: onEditingChanged)
                .frame(width: sliderWidth)
        }
    }
}

private struct NativeSettingsSlider: NSViewRepresentable {
    @Binding var value: Double
    @Binding var tracking: Bool
    let range: ClosedRange<Double>
    let step: Double
    let onEditingChanged: (Bool) -> Void
    @Environment(\.isEnabled) private var isEnabled

    func makeNSView(context: Context) -> TrackingSettingsSlider {
        let slider = TrackingSettingsSlider(frame: .zero)
        slider.numberOfTickMarks = 0
        slider.allowsTickMarkValuesOnly = false
        slider.isContinuous = true
        slider.target = context.coordinator
        slider.action = #selector(Coordinator.changed(_:))
        slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        slider.onTrackingChanged = { [weak coordinator = context.coordinator] editing in
            coordinator?.owner.tracking = editing
            coordinator?.owner.onEditingChanged(editing)
        }
        return slider
    }

    func updateNSView(_ slider: TrackingSettingsSlider, context: Context) {
        context.coordinator.owner = self
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.doubleValue = value
        slider.discreteStep = step
        slider.isEnabled = isEnabled
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var owner: NativeSettingsSlider
        init(_ owner: NativeSettingsSlider) { self.owner = owner }
        @objc func changed(_ slider: NSSlider) {
            let raw = slider.doubleValue
            let snapped = owner.step > 0
                ? owner.range.lowerBound + ((raw - owner.range.lowerBound) / owner.step).rounded() * owner.step
                : raw
            let value = min(max(snapped, owner.range.lowerBound), owner.range.upperBound)
            slider.doubleValue = value
            owner.value = value
        }
    }
}

private final class TrackingSettingsSlider: NSSlider {
    var onTrackingChanged: ((Bool) -> Void)?
    var discreteStep = 0.0

    override func mouseDown(with event: NSEvent) {
        guard isEnabled, let trackingWindow = window, let cell = cell as? NSSliderCell else {
            super.mouseDown(with: event)
            return
        }
        onTrackingChanged?(true)
        defer { onTrackingChanged?(false) }

        // NSSliderCell's default tracking can cancel/reset or oscillate outside
        // its tracking area or window boundary. Own the gesture until mouse-up,
        // in screen coordinates, so crossing another window or leaving the window
        // cannot reinterpret coordinates or cause value jiggling.
        let bar = cell.barRect(flipped: isFlipped)
        var knob = cell.knobRect(flipped: isFlipped)
        let lower = bar.minX + knob.width / 2
        let travel = bar.width - knob.width
        guard travel > 0, maxValue > minValue else {
            super.mouseDown(with: event)
            return
        }
        func point(_ event: NSEvent) -> CGPoint {
            let screen = event.window?.convertPoint(toScreen: event.locationInWindow) ?? event.locationInWindow
            return convert(trackingWindow.convertPoint(fromScreen: screen), from: nil)
        }
        let start = point(event)
        let center = lower + (doubleValue - minValue) / (maxValue - minValue) * travel
        knob.origin.x = center - knob.width / 2
        let offset = knob.contains(start) ? start.x - center : 0
        func update(_ event: NSEvent) {
            let fraction = min(1, max(0, (point(event).x - offset - lower) / travel))
            doubleValue = minValue + fraction * (maxValue - minValue)
            _ = sendAction(action, to: target)
        }
        if !knob.contains(start) { update(event) }
        while window === trackingWindow && trackingWindow.isVisible && isEnabled {
            guard let next = NSApp.nextEvent(matching: [.leftMouseDragged, .leftMouseUp, .keyDown, .appKitDefined],
                until: Date().addingTimeInterval(0.1), inMode: .eventTracking, dequeue: true) else { continue }
            guard window === trackingWindow && trackingWindow.isVisible && isEnabled else { break }
            if next.type == .appKitDefined || next.type == .keyDown { NSApp.sendEvent(next); continue }
            update(next)
            if next.type == .leftMouseUp { break }
        }
    }

    override func accessibilityPerformIncrement() -> Bool {
        guard isEnabled else { return false }
        let step = discreteStep > 0 ? discreteStep : (maxValue - minValue) / 10
        doubleValue = min(maxValue, doubleValue + step)
        _ = sendAction(action, to: target)
        return true
    }

    override func accessibilityPerformDecrement() -> Bool {
        guard isEnabled else { return false }
        let step = discreteStep > 0 ? discreteStep : (maxValue - minValue) / 10
        doubleValue = max(minValue, doubleValue - step)
        _ = sendAction(action, to: target)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard [123, 124, 125, 126, 115, 119, 116, 121].contains(Int(event.keyCode)) else {
            super.keyDown(with: event)
            return
        }
        onTrackingChanged?(true)
        defer { onTrackingChanged?(false) }
        guard discreteStep > 0 else {
            super.keyDown(with: event)
            return
        }
        switch event.keyCode {
        case 123, 125: doubleValue = max(minValue, doubleValue - discreteStep)
        case 124, 126: doubleValue = min(maxValue, doubleValue + discreteStep)
        case 115: doubleValue = minValue
        case 119: doubleValue = maxValue
        case 116: doubleValue = min(maxValue, doubleValue + discreteStep * 10)
        case 121: doubleValue = max(minValue, doubleValue - discreteStep * 10)
        default: return
        }
        _ = sendAction(action, to: target)
    }
}
