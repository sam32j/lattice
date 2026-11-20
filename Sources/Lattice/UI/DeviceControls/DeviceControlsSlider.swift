// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// Native Liquid Glass SwiftUI slider for Device Controls and Audio settings
/// with a floating percentage tooltip during interaction and decoupled local
/// drag state so external audio/display readbacks never fight the thumb.
struct DeviceControlsSlider: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var step: Double = 0
    var readout: String? = nil
    var tintColor: Color? = nil
    var onEditingChanged: (Bool) -> Void = { _ in }

    @State private var tracking = false
    @State private var hovering = false
    @State private var dragValue: Double?
    @State private var lastEmitUptime: TimeInterval = 0

    private var showTooltip: Bool { tracking || hovering }
    private var displayedValue: Double { dragValue ?? value }

    private var effectiveReadout: String {
        if let readout { return readout }
        let span = max(range.upperBound - range.lowerBound, 0.000_01)
        let pct = Int(((displayedValue - range.lowerBound) / span * 100).rounded())
        return "\(min(max(pct, 0), 100))%"
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { dragValue ?? value },
            set: { raw in
                let clampedRaw = min(max(raw, range.lowerBound), range.upperBound)
                let snapped = step > 0
                    ? min(
                        max(
                            range.lowerBound + ((clampedRaw - range.lowerBound) / step).rounded() * step,
                            range.lowerBound
                        ),
                        range.upperBound
                    )
                    : clampedRaw
                if tracking {
                    dragValue = step > 0 ? snapped : clampedRaw
                }
                guard abs(snapped - value) > 0.000_5 || (step > 0 && abs(snapped - value) > 0.000_01) else {
                    return
                }
                if tracking, step == 0,
                   snapped > range.lowerBound + 0.000_5,
                   snapped < range.upperBound - 0.000_5 {
                    let now = ProcessInfo.processInfo.systemUptime
                    guard now - lastEmitUptime >= (1.0 / 60.0) else { return }
                    lastEmitUptime = now
                }
                value = snapped
            }
        )
    }

    private var scrollBinding: Binding<Double> {
        Binding(
            get: { dragValue ?? value },
            set: { raw in
                let effectiveStep = step > 0 ? step : 0
                let next = effectiveStep > 0
                    ? range.lowerBound + ((raw - range.lowerBound) / effectiveStep).rounded() * effectiveStep
                    : raw
                let clamped = min(max(next, range.lowerBound), range.upperBound)
                guard abs(clamped - value) > 0.000_01 else { return }
                value = clamped
            }
        )
    }

    var body: some View {
        Slider(
            value: sliderBinding,
            in: range,
            onEditingChanged: { editing in
                tracking = editing
                if editing {
                    dragValue = value
                } else {
                    if let finalValue = dragValue, abs(finalValue - value) > 0.000_01 {
                        value = finalValue
                    }
                    dragValue = nil
                }
                onEditingChanged(editing)
            }
        )
        .labelsHidden()
        .controlSize(.regular)
        .tint(tintColor)
        .onHover { isHovered in
            hovering = isHovered
        }
        .frame(height: 22)
        // The wheel and a two-finger swipe adjust the level, as on the island's sliders.
        .overlay(
            SliderScrollArea(
                value: scrollBinding,
                range: range,
                step: step > 0 ? step : (range.upperBound - range.lowerBound) * 0.01,
                onEditingChanged: onEditingChanged
            )
        )
        .overlay {
            if showTooltip {
                GeometryReader { geometry in
                    let span = range.upperBound - range.lowerBound
                    let fraction = span > 0 ? min(max((displayedValue - range.lowerBound) / span, 0), 1) : 0
                    Text(effectiveReadout)
                        .font(.caption.monospacedDigit())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.14), radius: 3, y: 1)
                        .fixedSize()
                        .position(x: 10 + fraction * max(geometry.size.width - 20, 0), y: -14)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(title)
        .accessibilityValue(effectiveReadout)
    }
}
