// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

extension View {
    func screenshotIconHover() -> some View {
        modifier(ScreenshotIconHover())
    }

    /// Avoid SwiftUI's tooltip bridge, which crashes while routing hover on
    /// macOS 27. A passive native view leaves button and drag events untouched.
    func screenshotSafeHelp(_ text: String) -> some View {
        background(ScreenshotControlHelp(text: text))
    }
}

private struct ScreenshotIconHover: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovered = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(hovered && isEnabled ? 0.09 : 0))
            }
            .onHover { hovered = $0 }
            .animation(.easeOut(duration: 0.12), value: hovered && isEnabled)
    }
}

struct ScreenshotControlHelp: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> HelpView {
        let view = HelpView()
        view.toolTip = text
        return view
    }

    func updateNSView(_ view: HelpView, context: Context) {
        if view.toolTip != text { view.toolTip = text }
    }

    final class HelpView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
