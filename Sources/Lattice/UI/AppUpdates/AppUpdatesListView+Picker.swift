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

    static let headerLineHeight: CGFloat = 32
    static let compactLoaderHeight: CGFloat = 120

    static let compactRowHeight: CGFloat = 40
    static let compactRowSpacing: CGFloat = 5

    static func compactHeight(rowCount: Int, maxRows: Int) -> CGFloat {
        let visible = min(max(rowCount, 1), maxRows)
        return CGFloat(visible) * compactRowHeight
            + CGFloat(visible - 1) * compactRowSpacing
    }

    /// The list's viewport: its rows, up to `maxRows`, and the room its soft
    /// edges take at rest.
    static func compactListViewport(rowCount: Int, maxRows: Int) -> CGFloat {
        compactHeight(rowCount: rowCount, maxRows: maxRows) + HubScrollEdge.inset * 2
    }

    /// A first guess at the panel's height, before the panel has measured
    /// what it shows.
    @MainActor
    static func compactUtilityHeight(itemCount: Int, maxRows: Int) -> CGFloat {
        if AppUpdatesService.shared.isChecking { return compactLoaderHeight }
        if itemCount == 0 { return headerLineHeight + 8 + 80 }
        return headerLineHeight + 8 + compactListViewport(rowCount: itemCount, maxRows: maxRows)
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
    /// What a check could not read, shown as a small mark that opens the
    /// list of them; nil when it read everything.
    var uncheckedNote: String? = nil
    var onShowUnchecked: () -> Void = {}
    let onCheck: () -> Void

    private var title: String {
        count == 0 ? text.noUpdatesAvailable
            : count == 1 ? text.oneUpdateAvailable : String(format: text.updatesAvailableFormat, count)
    }

    /// "N Updates Available" with the refresh arrow beside it, as the
    /// Homebrew card's title has it, and when it was last checked below.
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: compact ? 12 : 13, weight: .semibold))
                        .lineLimit(1)
                    Button(action: onCheck) {
                        RefreshArrow(isSpinning: isChecking)
                            .font(.system(size: compact ? 11 : 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 18, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(disabled || isChecking)
                    .help(text.checkNow)
                    .accessibilityLabel(isChecking ? text.checking : text.checkNow)
                }
                Text(isChecking ? text.checking + "…" : lastCheck)
                    .font(.system(size: compact ? 10 : 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let uncheckedNote {
                Button(action: onShowUnchecked) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: compact ? 11 : 12))
                        .foregroundStyle(.orange)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(uncheckedNote)
                .accessibilityLabel(uncheckedNote)
            }
        }
    }
}
