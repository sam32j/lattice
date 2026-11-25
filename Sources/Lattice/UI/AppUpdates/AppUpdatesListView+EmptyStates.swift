// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers


extension AppUpdatesListView {
    /// Shaped like an update row: the heading above already says there is
    /// nothing to update, so this is one quiet line.
    var caughtUpCard: some View {
        emptyRow(symbol: successfulEmptyCheck ? "checkmark.circle.fill" : "info.circle",
                 tint: successfulEmptyCheck ? .green : .secondary,
                 title: successfulEmptyCheck ? text.emptyUpToDate : statusHeadline)
    }

    var noSourcesCard: some View {
        emptyRow(symbol: "exclamationmark.triangle.fill", tint: .orange, title: text.selectSource)
    }

    func emptyRow(symbol: String, tint: Color, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
        }
    }

    var errorCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.orange)
            Text(text.checkFailed)
                .font(.system(size: 13, weight: .semibold))
            if let error = updates.lastError, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            Button(text.retry) {
                updates.check()
            }
            .buttonStyle(.appManager(.neutral))
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Row Implementation

}
