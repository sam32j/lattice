// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// Native-styled slider for Device Controls with tooltip percentage readout visible
/// strictly during interaction (hover, dragging, or keyboard adjustment).
/// No permanent numeric percentage column is displayed.
struct DeviceControlsSlider: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var step: Double = 0
    let readout: String
    var tintColor: Color? = nil
    var onEditingChanged: (Bool) -> Void = { _ in }

    @State private var tracking = false
    @State private var hovering = false

    private var showTooltip: Bool { tracking || hovering }

    var body: some View {
        Slider(
            value: Binding(
                get: { value },
                set: { raw in
                    let next = step > 0
                        ? range.lowerBound + ((raw - range.lowerBound) / step).rounded() * step
                        : raw
                    value = min(max(next, range.lowerBound), range.upperBound)
                }
            ),
            in: range,
            onEditingChanged: { editing in
                tracking = editing
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
        .overlay {
            if showTooltip {
                GeometryReader { geometry in
                    let span = range.upperBound - range.lowerBound
                    let fraction = span > 0 ? min(max((value - range.lowerBound) / span, 0), 1) : 0
                    Text(readout)
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
