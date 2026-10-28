// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

struct LatticeHubOptionsCard: View {
    let item: LatticeHubItem
    let notchSize: CGSize?
    let title: String
    let icon: String
    let onClose: () -> Void

    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.clipboardHistoryEnabled) private var clipboardEnabled = false
    @AppStorage(DefaultsKey.clipboardHistoryLimit) private var clipboardLimit = 50

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(l10n.s.menuClose)
            }
            if item == .clipboard {
                Toggle(FeatureStrings.clipboard(l10n.language).enable, isOn: $clipboardEnabled)
                    .onChange(of: clipboardEnabled) { _, _ in
                        ClipboardHistoryService.shared.syncWithPreferences()
                    }
                if clipboardEnabled {
                    Picker(FeatureStrings.clipboard(l10n.language).limit, selection: $clipboardLimit) {
                        ForEach(Defaults.allowedClipboardHistoryLimits, id: \.self) { value in
                            Text(value == 0 ? FeatureStrings.clipboard(l10n.language).limitUnlimited : "\(value)").tag(value)
                        }
                    }
                    .onChange(of: clipboardLimit) { _, value in
                        let sanitized = Defaults.sanitizedClipboardHistoryLimit(value)
                        if sanitized != value { clipboardLimit = sanitized }
                        ClipboardHistoryService.shared.trimToLimit()
                    }
                }
            }
        }
        .font(.system(size: 11))
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(notchSize != nil ? .black : Color.primary.opacity(0.05))
        )
    }
}
