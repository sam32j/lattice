// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import Carbon.HIToolbox

struct FullScreenCaptureButton: View {
    let action: () -> Void
    let hoverChanged: (Bool) -> Void
    @ObservedObject private var l10n = L10n.shared
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(FeatureStrings.screenshot(l10n.language).fullScreenCaptureButton,
                  systemImage: "rectangle.inset.filled")
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 14)
                .frame(minHeight: 32)
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .foregroundStyle(.primary)
        .background(CaptureChromeBackdrop(
            material: .regularMaterial,
            shape: Capsule(style: .continuous)))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(isHovered ? 0.34 : 0.12),
                              lineWidth: isHovered ? 1.5 : 1)
        }
        .scaleEffect(isHovered ? 1.02 : 1)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover {
            isHovered = $0
            hoverChanged($0)
        }
        .shadow(color: .black.opacity(0.20), radius: 12, y: 5)
        .help(FeatureStrings.screenshot(l10n.language).fullScreenShortcutTitle)
        .accessibilityLabel(FeatureStrings.screenshot(l10n.language).fullScreenCaptureButton)
    }
}
