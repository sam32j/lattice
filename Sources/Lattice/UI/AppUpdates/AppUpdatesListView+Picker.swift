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
    static let headerLineHeight: CGFloat = 18

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
    /// The panel grows with the list up to this many apps; past it the
    /// panel's own scroll view takes over.
    static let compactVisibleRows = 10

    static func compactHeight(rowCount: Int) -> CGFloat {
        let visible = min(max(rowCount, 1), compactVisibleRows)
        return CGFloat(visible) * compactRowHeight
            + CGFloat(visible - 1) * compactRowSpacing
    }

    @MainActor
    static func compactUtilityHeight(itemCount: Int) -> CGFloat {
        let note = coverageWasIncomplete ? incompleteLineHeight + 8 : 0
        // The heading is one line of text now, not the card it was (about
        // 26pt shorter).
        if itemCount == 0 { return 122 + note }
        return 59 + compactHeight(rowCount: itemCount) + note
    }
}

/// "Last checked 5 min ago · Check Now" in text: the check's state and the
/// way to run it again, beside the list's heading in Settings and the Hub.
struct UpdatesCheckLine: View {
    let text: AppUpdateStrings
    let lastCheck: String
    let isChecking: Bool
    let disabled: Bool
    let size: CGFloat
    let onCheck: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(isChecking ? text.checking + "…" : lastCheck)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Button(action: onCheck) {
                HStack(spacing: 3) {
                    RefreshArrow(isSpinning: isChecking)
                    Text(text.checkNow)
                }
                .foregroundStyle(disabled || isChecking ? Color.secondary.opacity(0.5) : Color.accentColor)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(disabled || isChecking)
            .accessibilityLabel(isChecking ? text.checking : text.checkNow)
        }
        .font(.system(size: size))
    }
}
