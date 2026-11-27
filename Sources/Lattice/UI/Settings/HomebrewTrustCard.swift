// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// One-click resolution for Homebrew's tap trust requirement: explains the
/// confirmation, trusts the tap and resumes whatever the refusal interrupted.
struct HomebrewTrustCard: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var homebrew = HomebrewManager.shared
    let tap: String
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            Label(l10n.s.homebrewTrustTitle, systemImage: "checkmark.shield")
                .font(compact ? .system(size: 11, weight: .semibold) : .headline)
            Text(String(format: l10n.s.homebrewTrustCaption, tap))
                .font(compact ? .system(size: 9.5) : .caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                homebrew.trustTapAndContinue()
            } label: {
                HStack(spacing: 5) {
                    if homebrew.isTrustingTap {
                        ProgressView()
                            .controlSize(.mini)
                    }
                    Text(l10n.s.homebrewTrustButton)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(compact ? .small : .regular)
            .disabled(homebrew.isTrustingTap)
        }
        .padding(compact ? 8 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.09)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.22), lineWidth: 1))
    }
}
