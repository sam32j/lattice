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
                .font(.system(size: 20))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
            Text(title).font(.system(size: 13, weight: .medium))
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.04)))
    }

    var errorCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
            Text(text.checkFailed)
                .font(.system(size: 13.5, weight: .semibold))
            if let error = updates.lastError, !error.isEmpty {
                Text(error)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            Button(text.retry) {
                updates.check()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.025))
        )
    }

    // MARK: - Row Implementation

}
