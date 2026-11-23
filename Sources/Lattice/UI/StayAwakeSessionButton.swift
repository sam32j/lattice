// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

/// One way to start a Stay Awake session, drawn the same in the Hub popover
/// and on the Settings page: a 34 pt tile, accent-tinted while it is the
/// session that runs.
struct StayAwakeSessionButton: View {
    let title: String
    var symbol: String? = nil
    var selected = false
    /// The full spoken name when the title is an abbreviation like "+15m".
    var accessibilityName: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol).frame(width: 16) }
                Text(title).lineLimit(1).minimumScaleFactor(0.75)
                if symbol != nil { Spacer(minLength: 0) }
            }
            .font(.system(size: symbol == nil ? 11 : 12, weight: .medium))
            .padding(.horizontal, symbol == nil ? 6 : 10)
            .frame(maxWidth: .infinity, minHeight: 34)
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .background(selected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(selected ? Color.accentColor.opacity(0.7) : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityName ?? title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
