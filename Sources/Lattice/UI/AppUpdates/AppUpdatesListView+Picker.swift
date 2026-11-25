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
    static let headerLineHeight: CGFloat = 32

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
        // The heading is two short lines of text, not the card it was.
        if itemCount == 0 { return 136 + note }
        return 73 + compactHeight(rowCount: itemCount) + note
    }
}

/// The update list's heading: its title and how many, with the refresh
/// button at the end of the row, and when it was last checked on a quieter
/// line below. The same in Settings and the Hub.
struct UpdatesHeading: View {
    let text: AppUpdateStrings
    let count: Int
    let lastCheck: String
    let isChecking: Bool
    let disabled: Bool
    var compact = false
    let onCheck: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(text.availableUpdatesTitle)
                        .font(.system(size: compact ? 12 : 13, weight: .semibold))
                        .lineLimit(1)
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: compact ? 9.5 : 10.5, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.16), in: Capsule())
                    }
                }
                Text(isChecking ? text.checking + "…" : lastCheck)
                    .font(.system(size: compact ? 10 : 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button(action: onCheck) {
                RefreshArrow(isSpinning: isChecking)
                    .font(.system(size: compact ? 11 : 12, weight: .medium))
                    .frame(width: compact ? 24 : 28, height: compact ? 24 : 28)
                    .background(Color.primary.opacity(0.07), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(disabled || isChecking ? Color.secondary.opacity(0.5) : Color.primary.opacity(0.8))
            .disabled(disabled || isChecking)
            .help(text.checkNow)
            .accessibilityLabel(isChecking ? text.checking : text.checkNow)
        }
    }
}
