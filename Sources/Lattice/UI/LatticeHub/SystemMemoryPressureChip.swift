// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

/// The memory detail's pressure chip, in the same level and colors as the
/// System widget's ring and the menu bar dot.
struct SystemMemoryPressureChip: View {
    @ObservedObject private var l10n = L10n.shared
    let level: MonitorLevel

    var body: some View {
        let color = Color(nsColor: level.statusColor)
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.18), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l10n.s.memoryPressure)
        .accessibilityValue(label)
    }

    private var label: String {
        switch level {
        case .normal: return l10n.s.pressureNormal
        case .elevated: return l10n.s.pressureWarning
        case .critical: return l10n.s.pressureCritical
        }
    }
}
