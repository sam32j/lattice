// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// App volume slider featuring a 0-100% main bar and an attached 100-200% boost stub,
/// built with native AppKit components (NSSlider / NSSliderCell) to preserve the genuine
/// macOS native slider knob, bevel, and OS appearance.
struct AppVolumeBoostSlider: View {
    let title: String
    @Binding var value: Double
    var onEditingChanged: (Bool) -> Void = { _ in }

    @State private var isTracking = false

    private var percent: Int {
        Int((value * 100).rounded())
    }

    var body: some View {
        NativeAppVolumeSliderRepresentable(
            title: title,
            value: $value,
            isTracking: $isTracking,
            onEditingChanged: onEditingChanged
        )
        .frame(height: 22)
        .overlay {
            if isTracking {
                GeometryReader { geometry in
                    let totalWidth = geometry.size.width
                    let thumbX = AppVolumeSliderMetrics.thumbPosition(for: value, totalWidth: totalWidth)
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
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }
}

private struct NativeAppVolumeSliderRepresentable: NSViewRepresentable {
    let title: String
    @Binding var value: Double
    @Binding var isTracking: Bool
    let onEditingChanged: (Bool) -> Void
    @Environment(\.isEnabled) private var isEnabled

    func makeNSView(context: Context) -> AppVolumeBoostSliderControl {
        let slider = AppVolumeBoostSliderControl()
        slider.cell = AppVolumeBoostSliderCell()
        slider.minValue = 0.0
        slider.maxValue = 2.0
        slider.doubleValue = value
        slider.isContinuous = true
        slider.numberOfTickMarks = 0
        slider.target = context.coordinator
        slider.action = #selector(Coordinator.sliderChanged(_:))
        slider.setAccessibilityLabel(title)

        slider.onTrackingChanged = { [weak coordinator = context.coordinator] tracking in
            coordinator?.owner.isTracking = tracking
            coordinator?.owner.onEditingChanged(tracking)
        }

        return slider
    }

    func updateNSView(_ slider: AppVolumeBoostSliderControl, context: Context) {
        context.coordinator.owner = self
        slider.isEnabled = isEnabled
        let clamped = min(max(value, 0.0), 2.0)
        if !slider.isCurrentlyTracking && slider.doubleValue != clamped {
            slider.doubleValue = clamped
        }
        slider.setAccessibilityLabel(title)
        let percent = Int((clamped * 100).rounded())
        let valueDesc = clamped > 1.0 ? "\(percent) percent, boosted" : "\(percent) percent"
        slider.setAccessibilityValueDescription(valueDesc)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var owner: NativeAppVolumeSliderRepresentable
        init(_ owner: NativeAppVolumeSliderRepresentable) { self.owner = owner }

        @objc func sliderChanged(_ sender: NSSlider) {
            let next = min(max(sender.doubleValue, 0.0), 2.0)
            owner.value = next
        }
    }
}

private final class AppVolumeBoostSliderCell: NSSliderCell {
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        guard let view = controlView else { return }
        let totalWidth = view.bounds.width
        let stubWidth = AppVolumeSliderMetrics.stubWidth
        let gap = AppVolumeSliderMetrics.gap
        let trackHeight = AppVolumeSliderMetrics.trackHeight
        let thumbRadius = AppVolumeSliderMetrics.thumbRadius
        let mainWidth = AppVolumeSliderMetrics.mainBarWidth(totalWidth: totalWidth)
        let y = (view.bounds.height - trackHeight) / 2

        let isDark = view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        // 1. Main bar track (0-100%)
        let mainRect = NSRect(x: thumbRadius, y: y, width: mainWidth, height: trackHeight)
        let mainPath = NSBezierPath(roundedRect: mainRect, xRadius: trackHeight / 2, yRadius: trackHeight / 2)
        NSColor.secondaryLabelColor.withAlphaComponent(isDark ? 0.25 : 0.15).setFill()
        mainPath.fill()

        // Main bar fill (accent)
        if doubleValue > 0.001 {
            let fillFraction = min(max(CGFloat(doubleValue), 0), 1.0)
            NSGraphicsContext.saveGraphicsState()
            mainPath.addClip()
            let fillRect = NSRect(x: thumbRadius, y: y, width: mainWidth * fillFraction, height: trackHeight)
            NSColor.controlAccentColor.setFill()
            fillRect.fill()
            NSGraphicsContext.restoreGraphicsState()
        }

        // 2. Boost stub (100-200%)
        let stubX = thumbRadius + mainWidth + gap
        let stubRect = NSRect(x: stubX, y: y, width: stubWidth, height: trackHeight)
        let stubPath = NSBezierPath(roundedRect: stubRect, xRadius: trackHeight / 2, yRadius: trackHeight / 2)

        let isBoosted = doubleValue > 1.0
        let stubBg = isBoosted
            ? NSColor.systemOrange.withAlphaComponent(isDark ? 0.45 : 0.38)
            : NSColor.systemOrange.withAlphaComponent(isDark ? 0.22 : 0.16)
        stubBg.setFill()
        stubPath.fill()

        // Boost fill
        if isBoosted {
            let boostFraction = min(max(CGFloat(doubleValue - 1.0), 0), 1.0)
            NSGraphicsContext.saveGraphicsState()
            stubPath.addClip()
            let boostFillRect = NSRect(x: stubX, y: y, width: stubWidth * boostFraction, height: trackHeight)
            NSColor.systemOrange.setFill()
            boostFillRect.fill()
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    override func knobRect(flipped: Bool) -> NSRect {
        var base = super.knobRect(flipped: flipped)
        guard let view = controlView else { return base }
        let totalWidth = view.bounds.width
        let centerX = AppVolumeSliderMetrics.thumbPosition(for: doubleValue, totalWidth: totalWidth)
        base.origin.x = centerX - base.width / 2
        return base
    }

    override func drawKnob(_ knobRect: NSRect) {
        // Renders the genuine native macOS slider knob with OS materials and shadows!
        super.drawKnob(knobRect)
    }
}

private final class AppVolumeBoostSliderControl: NSSlider {
    var onTrackingChanged: ((Bool) -> Void)?
    private(set) var isCurrentlyTracking = false
    private var previousValue: Double = 1.0

    override var acceptsFirstResponder: Bool { true }
    override var focusRingType: NSFocusRingType {
        get { .none }
        set { }
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled, let trackingWindow = window else {
            super.mouseDown(with: event)
            return
        }

        if event.clickCount == 2 {
            // Double click: reset to 100%
            updateValue(1.0)
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            return
        }

        isCurrentlyTracking = true
        onTrackingChanged?(true)
        defer {
            isCurrentlyTracking = false
            onTrackingChanged?(false)
        }

        func pointX(_ event: NSEvent) -> CGFloat {
            let screen = event.window?.convertPoint(toScreen: event.locationInWindow) ?? event.locationInWindow
            let local = convert(trackingWindow.convertPoint(fromScreen: screen), from: nil)
            return local.x
        }

        func handleEvent(_ event: NSEvent) {
            let x = pointX(event)
            let totalWidth = bounds.width
            let newVal = AppVolumeSliderMetrics.value(for: x, totalWidth: totalWidth)
            checkHaptics(oldValue: previousValue, newValue: newVal)
            updateValue(newVal)
        }

        handleEvent(event)

        while window === trackingWindow && trackingWindow.isVisible && isEnabled {
            guard let next = NSApp.nextEvent(
                matching: [.leftMouseDragged, .leftMouseUp, .keyDown, .appKitDefined],
                until: Date().addingTimeInterval(0.1),
                inMode: .eventTracking,
                dequeue: true
            ) else { continue }

            guard window === trackingWindow && trackingWindow.isVisible && isEnabled else { break }
            if next.type == .appKitDefined || next.type == .keyDown {
                NSApp.sendEvent(next)
                continue
            }
            handleEvent(next)
            if next.type == .leftMouseUp { break }
        }
    }

    private func updateValue(_ newVal: Double) {
        let clamped = min(max(newVal, 0.0), 2.0)
        previousValue = clamped
        doubleValue = clamped
        _ = sendAction(action, to: target)
        needsDisplay = true
    }

    private func checkHaptics(oldValue: Double, newValue: Double) {
        if (oldValue < 1.0 && newValue >= 1.0) || (oldValue > 1.0 && newValue <= 1.0) {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        }
    }

    override func keyDown(with event: NSEvent) {
        let isFine = event.modifierFlags.contains(.option)
        let step = isFine ? 0.01 : 0.05
        switch event.keyCode {
        case 123, 125: // Left, Down
            let next = max(0.0, doubleValue - step)
            checkHaptics(oldValue: doubleValue, newValue: next)
            updateValue(next)
        case 124, 126: // Right, Up
            let next = min(2.0, doubleValue + step)
            checkHaptics(oldValue: doubleValue, newValue: next)
            updateValue(next)
        default:
            super.keyDown(with: event)
        }
    }

    override func accessibilityPerformIncrement() -> Bool {
        guard isEnabled else { return false }
        let next = min(2.0, doubleValue + 0.05)
        checkHaptics(oldValue: doubleValue, newValue: next)
        updateValue(next)
        return true
    }

    override func accessibilityPerformDecrement() -> Bool {
        guard isEnabled else { return false }
        let next = max(0.0, doubleValue - 0.05)
        checkHaptics(oldValue: doubleValue, newValue: next)
        updateValue(next)
        return true
    }
}
