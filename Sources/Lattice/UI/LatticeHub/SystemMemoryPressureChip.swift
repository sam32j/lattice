// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

struct SystemMemoryPressureChip: View {
    let fraction: Double

    var body: some View {
        let (label, color) = status
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
        .accessibilityLabel("Memory pressure")
        .accessibilityValue(label)
    }

    private var status: (String, Color) {
        if fraction >= 0.90 { return ("High", .red) }
        if fraction >= 0.80 { return ("Elevated", .yellow) }
        return ("Normal", .green)
    }
}
