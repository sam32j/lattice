// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The same nine positions and adaptive contrast in both capture editors.
struct CaptureAnchorPicker: View {
    let selected: RecorderTextOverlay.Anchor
    let strings: ScreenshotFeatureStrings
    var cellWidth: CGFloat? = nil
    var cellHeight: CGFloat = 20
    let onSelect: (RecorderTextOverlay.Anchor) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(
            cellWidth.map { .fixed($0) } ?? .flexible(), spacing: 4), count: 3), spacing: 4) {
            ForEach(RecorderTextOverlay.Anchor.allCases, id: \.rawValue) { anchor in
                Button { onSelect(anchor) } label: {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(selected == anchor ? Color.accentColor : Color.primary.opacity(0.14))
                        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.24), lineWidth: 0.75))
                        .frame(height: cellHeight)
                }
                .buttonStyle(.plain)
                .screenshotIconHover()
                .screenshotSafeHelp(strings.watermarkPositionName(anchor))
                .accessibilityLabel(strings.watermarkPositionName(anchor))
                .accessibilityAddTraits(selected == anchor ? .isSelected : [])
            }
        }
    }
}
