// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Shared software-dimming affordance used by Settings.
struct SoftwareDimmingButton: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = BrightnessService.shared
    let display: BrightnessDisplay
    var compact = false

    private var strings: BrightnessFeatureStrings { FeatureStrings.brightness(l10n.language) }
    private var extendedChosen: Bool { service.extendedDimmingPreferred.contains(display.id) }
    private var softwareChosen: Bool { service.softwareDimmingPreferred.contains(display.id) }
    private var chosen: Bool { extendedChosen || softwareChosen }
    private var usesExtendedDimming: Bool {
        !softwareChosen && (extendedChosen || (display.method == .ddc && display.readable))
    }

    private var offered: Bool {
        guard display.isActive, !display.isBuiltIn, display.canChooseDimming else { return false }
        if chosen { return true }
        guard display.method == .ddc else { return false }
        return !(compact && display.readable)
    }

    var body: some View {
        if offered {
            Button {
                if usesExtendedDimming {
                    service.setExtendedDimmingPreferred(!extendedChosen, for: display.id)
                } else {
                    service.setSoftwareDimmingPreferred(!softwareChosen, for: display.id)
                }
            } label: {
                HStack(spacing: compact ? 4 : 5) {
                    Image(systemName: chosen ? "checkmark.circle.fill" : "circle.lefthalf.filled")
                        .font(.system(size: compact ? 9.5 : 11, weight: .semibold))
                    Text(usesExtendedDimming ? strings.extendedDimming : strings.softwareDimming)
                        .font(.system(size: compact ? 10 : 12, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(chosen ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(service.isDisplayPending(display.id))
            .accessibilityLabel("\(display.name): \(usesExtendedDimming ? strings.extendedDimming : strings.softwareDimming)")
        }
    }
}

/// Shared power affordance used by Settings.
struct DisplayPowerButton: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = BrightnessService.shared
    let display: BrightnessDisplay
    var compact = false

    private var strings: BrightnessFeatureStrings { FeatureStrings.brightness(l10n.language) }
    private var pending: Bool { service.isDisplayPending(display.id) }
    private var enabled: Bool { service.canToggleDisplay(display) }

    private var label: String {
        if !service.displaySwitchingAvailable { return strings.switchUnavailable }
        if display.isActive, !enabled { return strings.lastDisplayCaption }
        return display.isActive ? strings.turnOffDisplay : strings.turnOnDisplay
    }

    var body: some View {
        Group {
            if pending {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: compact ? 16 : 20, height: 18)
                    .accessibilityLabel(label)
            } else {
                Button {
                    service.toggleDisplay(display)
                } label: {
                    Image(systemName: display.isActive ? "power" : "power.circle.fill")
                        .font(.system(size: compact ? 10.5 : 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .foregroundStyle(display.isActive ? Color.secondary : Color.accentColor)
                .help(label)
                .accessibilityLabel(label)
            }
        }
    }
}

func displayControlFailureText(_ failure: BrightnessService.DisplayControlFailure,
                               strings: BrightnessFeatureStrings) -> String {
    switch failure {
    case .unavailable: return strings.switchUnavailable
    case .lastActive: return strings.lastDisplayCaption
    case .failed: return strings.switchFailed
    case .closedLid: return strings.openLidToEnable
    }
}
