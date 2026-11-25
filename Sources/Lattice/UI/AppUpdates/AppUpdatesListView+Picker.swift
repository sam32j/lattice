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

    static let compactRowHeight: CGFloat = 40
    static let compactRowSpacing: CGFloat = 5

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
    /// The "Last checked …" line under the title.
    var showsDetail = true
    /// An arrow at the row's end that opens App Updates in Settings.
    var onOpen: (() -> Void)? = nil
    let onCheck: () -> Void

    private var title: String {
        if isChecking && count == 0 { return text.checking + "…" }
        return count == 0 ? text.noUpdatesAvailable
            : count == 1 ? text.oneUpdateAvailable : String(format: text.updatesAvailableFormat, count)
    }

    /// "N Updates Available" with the refresh arrow beside it, as the
    /// Homebrew card's title has it, and when it was last checked below.
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: showsDetail ? 2 : 0) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: compact ? 11.5 : 12, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
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
                if showsDetail {
                    Text((isChecking && count > 0) ? text.checking + "…" : lastCheck)
                        .font(.system(size: compact ? 10 : 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let onOpen {
                Button(action: onOpen) {
                    Text(text.openAppUpdates)
                        .font(.system(size: compact ? 10.5 : 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
