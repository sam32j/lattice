// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct ScreenshotWatermarkStyleControls: View {
    @Binding var style: ScreenshotSupport.WatermarkStyle
    let strings: ScreenshotFeatureStrings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(strings.watermarkPositionLabel)
                Spacer()
                anchorGrid
            }
            slider(strings.watermarkSizeLabel, value: $style.size, range: 0...1)
            slider(strings.watermarkOpacityLabel, value: $style.opacity,
                   range: ScreenshotSupport.WatermarkStyle.opacityRange)
            HStack {
                Text(strings.watermarkRotationLabel).frame(width: 74, alignment: .leading)
                Slider(value: $style.rotation, in: ScreenshotSupport.WatermarkStyle.rotationRange)
                    .accessibilityLabel(strings.watermarkRotationLabel)
                Text("\(Int(style.rotation.rounded()))°")
                    .monospacedDigit().frame(width: 34, alignment: .trailing)
            }
        }
        .font(.system(size: 12))
        .controlSize(.small)
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack {
            Text(title).frame(width: 74, alignment: .leading)
            Slider(value: value, in: range).accessibilityLabel(title)
            Text("\(Int((value.wrappedValue * 100).rounded()))%")
                .monospacedDigit().frame(width: 34, alignment: .trailing)
        }
    }

    private var anchorGrid: some View {
        CaptureAnchorPicker(selected: style.anchor, strings: strings, cellWidth: 24, cellHeight: 17) {
            style.anchor = $0
        }
        .fixedSize()
    }
}
