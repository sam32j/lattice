// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// A full-width slider in a popup, not a rotated control clipped by the rail.
struct ScreenshotFontSizeControl: View {
    @Binding var value: Int
    let title: String
    let onEditingChanged: (Bool) -> Void
    @StateObject private var palette = ScreenshotFontSizePalette.Presenter()

    var body: some View {
        Button {
            palette.toggle(value: $value, title: title, onEditingChanged: onEditingChanged)
        } label: {
            Text("Aa")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .focusable(false)
        .screenshotIconHover()
        .screenshotSafeHelp(title)
        .accessibilityLabel(title)
        .background(ScreenshotFontSizePalette(presenter: palette, value: $value, title: title,
                                             onEditingChanged: onEditingChanged))
    }
}
