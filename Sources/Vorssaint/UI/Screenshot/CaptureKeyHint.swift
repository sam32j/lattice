// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import Carbon.HIToolbox

struct CaptureKeyHint: View {
    let key: String
    let icon: String
    var isActive: Bool = false
    var isEnabled: Bool = true
    var action: (() -> Void)? = nil
    @State private var isHovered = false

    var body: some View {
        let content = HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(
            !isEnabled
                ? Color.secondary.opacity(0.4)
                : (isActive ? Color.white : (isHovered && action != nil ? Color.primary : Color.secondary))
        )
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(
            !isEnabled
                ? Color.primary.opacity(0.02)
                : (isActive
                    ? Color.accentColor
                    : Color.primary.opacity(isHovered && action != nil ? 0.12 : 0.06)),
            in: Capsule(style: .continuous)
        )
        .overlay {
            if isEnabled && isActive {
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
            }
        }

        if isEnabled, let action {
            Button(action: action) {
                content
            }
            .buttonStyle(.plain)
            .focusable(false)
            .onHover { isHovered = $0 }
        } else {
            content
        }
    }
}
