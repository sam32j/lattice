// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Presentation only: viewing usage never requests or changes a permission.
struct PermissionDetailsSheet: View {
    struct Item: Identifiable {
        var id: String { name }
        let name: String
        let symbolName: String?
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var l10n = L10n.shared
    let title: String
    let explanation: String
    let items: [Item]
    let isUnused: Bool
    let hub: FeatureHubStrings

    init(title: String,
         explanation: String,
         features: [(name: String, symbolName: String?)],
         isUnused: Bool,
         hub: FeatureHubStrings) {
        self.title = title
        self.explanation = explanation
        self.items = features.map { Item(name: $0.name, symbolName: $0.symbolName) }
        self.isUnused = isUnused
        self.hub = hub
    }

    init(title: String,
         explanation: String,
         featureNames: [String],
         isUnused: Bool,
         hub: FeatureHubStrings) {
        self.title = title
        self.explanation = explanation
        self.items = featureNames.map { Item(name: $0, symbolName: nil) }
        self.isUnused = isUnused
        self.hub = hub
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Text(title).font(.title2.bold())
                Text(explanation)
                    .foregroundStyle(.secondary)
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text(usedByHeader)
                        .font(.headline)
                    if items.isEmpty {
                        if isUnused {
                            Label(hub.unusedBanner, systemImage: "info.circle")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding(12)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                        } else {
                            Text(hub.usedByNone)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        VStack(spacing: 6) {
                            ForEach(items) { item in
                                HStack(spacing: 10) {
                                    Image(systemName: item.symbolName ?? "app.fill")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.tint)
                                        .frame(width: 24, height: 24)
                                        .background(Color.accentColor.opacity(0.12),
                                                    in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    Text(item.name)
                                        .font(.body)
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.08),
                                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
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

    private var usedByHeader: String {
        let raw = hub.usedByFormat
            .replacingOccurrences(of: "%@", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.hasSuffix(":") || raw.hasSuffix("：") ? raw : "\(raw):"
    }
}
