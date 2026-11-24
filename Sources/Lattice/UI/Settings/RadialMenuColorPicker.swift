// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// The profile colors as a 6 × 2 grid of gradient swatches. The chosen one
/// carries a checkmark and a ring, so the choice never rests on color alone.
struct RadialMenuColorPicker: View {
    @Binding var selection: RadialMenuColor
    let strings: RadialMenuFeatureStrings
    @Environment(\.colorScheme) private var colorScheme

    /// Flexible columns spread the swatches across the whole width, so the
    /// grid sits balanced in whatever holds it.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 12) {
            ForEach(RadialMenuColor.allCases) { color in
                let chosen = selection == color
                Button {
                    selection = color
                } label: {
                    ZStack {
                        Circle()
                            .fill(color.gradient(for: colorScheme))
                        if chosen {
                            Circle()
                                .strokeBorder(color.color(for: colorScheme), lineWidth: 2)
                                .padding(-4)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(color.foreground(for: colorScheme))
                        }
                    }
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(color.title(strings))
                .accessibilityLabel(color.title(strings))
                .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
    }
}
