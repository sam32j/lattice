// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers


extension AppUpdatesListView {
    @ViewBuilder
    var compactList: some View {
        let rows = LazyVStack(alignment: .leading, spacing: Self.compactRowSpacing) {
            ForEach(updates.items) { item in
                row(item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        // No scroll view of its own: the panel around it scrolls, and a
        // second one inside it read as two layers.
        rows
    }

    static let incompleteLineHeight: CGFloat = 20

    /// Whether the last check left apps out, as the panel's note reports it.
    @MainActor
    static var coverageWasIncomplete: Bool {
        let service = AppUpdatesService.shared
        let defaults = UserDefaults.standard
        guard service.hasCheckedThisSession, !service.isChecking else { return false }
        return (defaults.bool(forKey: DefaultsKey.appUpdatesIncludeAppStore) && !service.appStoreAvailable)
            || (defaults.bool(forKey: DefaultsKey.appUpdatesIncludeOnlineCatalog) && !service.onlineCatalogAvailable)
            || !service.uncheckedAppNames.isEmpty
    }

    static let compactRowHeight: CGFloat = 40
    static let compactRowSpacing: CGFloat = 5
    static let compactVisibleRows = 4

    static func compactHeight(rowCount: Int) -> CGFloat {
        let visible = min(max(rowCount, 1), compactVisibleRows)
        return CGFloat(visible) * compactRowHeight
            + CGFloat(visible - 1) * compactRowSpacing
    }

    @MainActor
    static func compactUtilityHeight(itemCount: Int) -> CGFloat {
        let note = coverageWasIncomplete ? incompleteLineHeight + 8 : 0
        if itemCount == 0 { return 148 + note }
        return min(290, 85 + compactHeight(rowCount: itemCount)) + note
    }
}
