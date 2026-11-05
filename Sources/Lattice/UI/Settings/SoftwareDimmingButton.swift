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

    /// The opt-out from DDC for a readable monitor. Some monitors answer
    /// reads but black out on brightness writes, and the only way to stop
    /// sending them is to leave DDC (issue #3621). Settings only, and only
    /// while no other choice is on: once chosen, the main button carries it.
    private var pictureDimmingOffered: Bool {
        guard !compact, !chosen, display.isActive, !display.isBuiltIn,
              display.canChooseDimming else { return false }
        return display.method == .ddc && display.readable
    }

    var body: some View {
        if offered {
            choice(usesExtendedDimming ? strings.extendedDimming : strings.softwareDimming,
                   chosen: chosen) {
                if usesExtendedDimming {
                    service.setExtendedDimmingPreferred(!extendedChosen, for: display.id)
                } else {
                    service.setSoftwareDimmingPreferred(!softwareChosen, for: display.id)
                }
            }
        }
        if pictureDimmingOffered {
            choice(strings.softwareDimming, chosen: false) {
                service.setSoftwareDimmingPreferred(true, for: display.id)
            }
        }
    }

    private func choice(_ title: String, chosen: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: compact ? 4 : 5) {
                Image(systemName: chosen ? "checkmark.circle.fill" : "circle.lefthalf.filled")
                    .font(.system(size: compact ? 9.5 : 11, weight: .semibold))
                Text(title)
                    .font(.system(size: compact ? 10 : 12, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(chosen ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .disabled(service.isDisplayPending(display.id))
        .accessibilityLabel("\(display.name): \(title)")
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
