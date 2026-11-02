// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers


extension AppUpdatesListView {
    var caughtUpCard: some View {
        VStack(spacing: 8) {
            Image(systemName: successfulEmptyCheck ? "checkmark.circle.fill" : "info.circle")
                .font(.system(size: 26))
                .foregroundStyle(successfulEmptyCheck ? Color.green : Color.secondary)
            Text(statusHeadline)
                .font(.system(size: 13.5, weight: .semibold))
            Text(updates.hasCheckedThisSession && totalAppsCount > 0 && !coveragePartial
                 ? String(format: text.checkedAppsFormat, totalAppsCount) : statusDetail)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 142)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.025))
        )
    }

    var noSourcesCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 26))
                .foregroundStyle(.orange)
            Text(text.selectSource)
                .font(.system(size: 13.5, weight: .semibold))
            Text(text.selectSourceDetail)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 142)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.025))
        )
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
