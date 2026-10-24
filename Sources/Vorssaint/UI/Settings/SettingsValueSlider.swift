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
    var onEditingChanged: (Bool) -> Void = { _ in }
    @State private var tracking = false

    var body: some View {
        NativeSettingsSlider(value: $value, tracking: $tracking, range: range, step: step,
                             onEditingChanged: onEditingChanged)
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
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        SettingsControlRow(title: title) {
            SettingsValueSlider(title: title, value: $value, range: range, step: step,
                                readout: readout, onEditingChanged: onEditingChanged)
                .frame(width: 220)
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
        onTrackingChanged?(true)
        defer { onTrackingChanged?(false) }
        super.mouseDown(with: event)
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
