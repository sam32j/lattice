// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

/// Refresh for the Settings page's top bar: rescans processes now.
struct KillProcessRefreshButton: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = KillProcessService.shared
    /// Only a refresh asked for here turns the arrow, never the live timer's.
    @State private var isRefreshing = false

    var body: some View {
        let title = FeatureStrings.killProcessList(l10n.language).refresh
        Button {
            isRefreshing = true
            service.refresh(force: true) { isRefreshing = false }
        } label: { RefreshArrow(isSpinning: isRefreshing) }
            .buttonStyle(FlatSettingsOptionsButtonStyle())
            .disabled(isRefreshing)
            .help(title)
            .accessibilityLabel(title)
    }
}
