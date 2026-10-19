// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Presentation only: viewing usage never requests or changes a permission.
struct PermissionDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var l10n = L10n.shared
    let title: String
    let explanation: String
    let featureNames: [String]
    let isUnused: Bool
    let hub: FeatureHubStrings

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Text(title).font(.title2.bold())
                Text(explanation)
                    .foregroundStyle(.secondary)
                Divider()
                Text(featureNames.isEmpty ? hub.usedByNone
                     : String(format: hub.usedByFormat, featureNames.joined(separator: ", ")))
                if isUnused {
                    Label(hub.unusedBanner, systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            Divider()
            HStack {
                Spacer()
                Button(l10n.s.doneButton) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 460)
    }
}
