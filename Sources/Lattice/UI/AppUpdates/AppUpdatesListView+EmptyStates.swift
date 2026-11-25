// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers


extension AppUpdatesListView {
    /// Shaped like an update row: the heading above already says there is
    /// nothing to update, so this is a quiet line of what was checked.
    var caughtUpCard: some View {
        emptyRow(symbol: successfulEmptyCheck ? "checkmark.seal.fill" : "info.circle.fill",
                 tint: successfulEmptyCheck ? .green : .secondary,
                 title: statusHeadline,
                 detail: updates.hasCheckedThisSession && totalAppsCount > 0 && !coveragePartial
                     ? String(format: text.checkedAppsFormat, totalAppsCount) : statusDetail)
    }

    var noSourcesCard: some View {
        emptyRow(symbol: "exclamationmark.triangle.fill", tint: .orange,
                 title: text.selectSource, detail: text.selectSourceDetail)
    }

    func emptyRow(symbol: String, tint: Color, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
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
