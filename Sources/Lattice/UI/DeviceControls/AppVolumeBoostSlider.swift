// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// Custom volume slider featuring a 0-100% main bar and an attached 100-200% boost stub.
struct AppVolumeBoostSlider: View {
    let title: String
    @Binding var value: Double
    var onEditingChanged: (Bool) -> Void = { _ in }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isDragging = false
    @State private var isHovering = false
    @State private var previousValue: Double = 1.0
    @State private var lastTapTimestamp: TimeInterval = 0

    private var percent: Int {
        Int((value * 100).rounded())
    }

    private var isBoosted: Bool {
        value > 1.0
    }

    private var accessibilityValueString: String {
        if isBoosted {
            return "\(percent) percent, boosted"
        } else {
            return "\(percent) percent"
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let mainWidth = AppVolumeSliderMetrics.mainBarWidth(totalWidth: totalWidth)
            let thumbX = AppVolumeSliderMetrics.thumbPosition(for: value, totalWidth: totalWidth)
            let height = geometry.size.height

            ZStack(alignment: .leading) {
                // Background and fill tracks
                tracksView(mainWidth: mainWidth, height: height)

                // Thumb
                thumbView(thumbX: thumbX, centerY: height / 2)

                // Tooltip pill while dragging
                if isDragging {
                    tooltipView(thumbX: thumbX, totalWidth: totalWidth)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged(true)
                        }
                        let newVal = AppVolumeSliderMetrics.value(for: gesture.location.x, totalWidth: totalWidth)
                        checkHaptics(oldValue: previousValue, newValue: newVal)
                        previousValue = newVal
                        value = newVal
                    }
                    .onEnded { gesture in
                        isDragging = false
                        onEditingChanged(false)
                        handleTapOrDoubleTap(gesture: gesture)
                    }
            )
            .onHover { isHovering = $0 }
        }
        .frame(height: 22)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress { press in
            let isFine = press.modifiers.contains(.option)
            let step = isFine ? 0.01 : 0.05
            if press.key == .leftArrow || press.key == .downArrow {
                adjustVolume(by: -step)
                return .handled
            } else if press.key == .rightArrow || press.key == .upArrow {
                adjustVolume(by: step)
                return .handled
            }
            return .ignored
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValueString)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                adjustVolume(by: 0.05)
            case .decrement:
                adjustVolume(by: -0.05)
            @unknown default:
                break
            }
        }
    }

    // MARK: - Tracks

    @ViewBuilder
    private func tracksView(mainWidth: CGFloat, height: CGFloat) -> some View {
        let trackY = (height - AppVolumeSliderMetrics.trackHeight) / 2
        let thumbRadius = AppVolumeSliderMetrics.thumbRadius
        let stubWidth = AppVolumeSliderMetrics.stubWidth
        let gap = AppVolumeSliderMetrics.gap

        // 1. Main bar track (0-100%)
        ZStack(alignment: .leading) {
            // Neutral track background
            Capsule(style: .continuous)
                .fill(Color.secondary.opacity(colorScheme == .dark ? 0.25 : 0.15))

            // Main bar fill (accent color)
            if value > 0.001 {
                let fillFraction = min(max(CGFloat(value), 0), 1.0)
                Capsule(style: .continuous)
                    .fill(Color.accentColor)
                    .frame(width: fillFraction * mainWidth)
            }
        }
        .frame(width: mainWidth, height: AppVolumeSliderMetrics.trackHeight)
        .offset(x: thumbRadius, y: trackY)

        // 2. Boost stub (100-200%)
        let stubX = thumbRadius + mainWidth + gap
        ZStack(alignment: .leading) {
            // Stub background (faint or medium orange)
            Capsule(style: .continuous)
                .fill(stubBackgroundColor)

            // Solid orange fill when boosted
            if isBoosted {
                let boostFraction = min(max(CGFloat(value - 1.0), 0), 1.0)
                Capsule(style: .continuous)
                    .fill(Color.orange)
                    .frame(width: boostFraction * stubWidth)
            }
        }
        .frame(width: stubWidth, height: AppVolumeSliderMetrics.trackHeight)
        .offset(x: stubX, y: trackY)
    }

    private var stubBackgroundColor: Color {
        if isBoosted {
            // Medium orange beyond the thumb when boosted
            return Color.orange.opacity(colorScheme == .dark ? 0.45 : 0.38)
        } else if isDragging {
            // Medium orange while dragging below 100%
            return Color.orange.opacity(colorSchemeContrast == .increased ? 0.6 : (colorScheme == .dark ? 0.42 : 0.35))
        } else {
            // Very faint orange normally, strengthened under Increase Contrast
            return Color.orange.opacity(colorSchemeContrast == .increased ? 0.4 : (colorScheme == .dark ? 0.22 : 0.16))
        }
    }

    // MARK: - Thumb

    private func thumbView(thumbX: CGFloat, centerY: CGFloat) -> some View {
        Circle()
            .fill(Color.white)
            .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
            .frame(width: AppVolumeSliderMetrics.thumbDiameter, height: AppVolumeSliderMetrics.thumbDiameter)
            .scaleEffect(isDragging && !reduceMotion ? 1.15 : 1.0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.12), value: isDragging)
            .position(x: thumbX, y: centerY)
            .allowsHitTesting(false)
    }

    // MARK: - Tooltip

    private func tooltipView(thumbX: CGFloat, totalWidth: CGFloat) -> some View {
        Text("\(percent)%")
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
            .fixedSize()
            .position(x: min(max(thumbX, 24), totalWidth - 24), y: -12)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: - Helpers

    private func adjustVolume(by delta: Double) {
        let current = value
        let next = min(max(current + delta, 0.0), 2.0)
        checkHaptics(oldValue: current, newValue: next)
        previousValue = next
        value = next
    }

    private func checkHaptics(oldValue: Double, newValue: Double) {
        if (oldValue < 1.0 && newValue >= 1.0) || (oldValue > 1.0 && newValue <= 1.0) {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        }
    }

    private func handleTapOrDoubleTap(gesture: DragGesture.Value) {
        let now = Date().timeIntervalSinceReferenceDate
        let moveDistanceSq = gesture.translation.width * gesture.translation.width + gesture.translation.height * gesture.translation.height
        if moveDistanceSq < 16 {
            if now - lastTapTimestamp < 0.35 {
                // Double click: reset to 100%
                value = 1.0
                previousValue = 1.0
                lastTapTimestamp = 0
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                return
            }
            lastTapTimestamp = now
        }
    }
}
