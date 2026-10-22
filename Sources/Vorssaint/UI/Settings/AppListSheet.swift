// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
import SwiftUI

/// A stable sheet shell shared by settings app lists. Only the list scrolls.
struct AppListSheet<Content: View, Footer: View>: View {
    let caption: String
    var centersContent = false
    let onDone: () -> Void
    @ViewBuilder let content: () -> Content
    @ViewBuilder let footer: () -> Footer
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(SettingsAppListStrings.text(l10n.language).disabledApps).font(.title2.weight(.semibold))
            Text(caption).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            GeometryReader { proxy in
                ScrollView {
                    content()
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: centersContent ? proxy.size.height : 0)
                }
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                footer()
                Spacer()
                Button(SettingsAppListStrings.text(l10n.language).done, action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520, height: 460)
    }
}
