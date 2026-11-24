// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The same failed-check state in Settings, the panel and Command Bar.
struct UninstallerHomebrewFailureNote: View {
    @ObservedObject private var l10n = L10n.shared
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(l10n.s.uninstallerHomebrewCheckFailed, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            Button(l10n.s.homebrewRefresh, action: onRetry)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
