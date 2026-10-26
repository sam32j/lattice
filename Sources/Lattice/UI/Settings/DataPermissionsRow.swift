// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

/// Shared geometry for backup, permission, reset and uninstall controls.
struct DataPermissionsRow: View {
    let symbol: String
    let title: String
    var description: String? = nil
    var status: String? = nil
    var tone: DataSettingsTone = .neutral
    var descriptionIsError = false
    var information: AnyView? = nil
    let actionTitle: String
    var actionTone: DataSettingsActionTone = .quiet
    var actionAccessibleName: String? = nil
    var actionRole: ButtonRole? = nil
    var actionEnabled = true
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = DataPermissionsPalette(scheme)
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.foreground(tone))
                .frame(width: 30, height: 30)
                .background(palette.tile(tone), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 2) {
                    Text(title).font(.body.weight(.medium))
                        .foregroundStyle(palette.title)
                        .lineLimit(1).truncationMode(.tail)
                    if let information { information.padding(.leading, -2).layoutPriority(1) }
                }
                .frame(height: 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                if let status {
                    HStack(spacing: 4) {
                        Circle().fill(palette.foreground(tone)).frame(width: 6, height: 6)
                            .accessibilityHidden(true)
                        Text(status).font(.caption).foregroundStyle(palette.foreground(tone))
                    }
                    .lineLimit(1)
                } else if let description {
                    Text(description).font(.caption)
                        .foregroundStyle(descriptionIsError ? palette.foreground(.destructive) : palette.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .help(description)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            DataSettingsActionButton(title: actionTitle, tone: actionTone,
                accessibleName: actionAccessibleName, role: actionRole, action: action)
                .disabled(!actionEnabled)
        }
        .frame(minHeight: 30)
        .padding(.vertical, 10)
        .accessibilityElement(children: .contain)
    }
}

struct DataSettingsDivider: View {
    var body: some View { Divider().accessibilityHidden(true) }
}

struct DataSettingsCard<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(spacing: 0, content: content)
            .padding(.horizontal, 16)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct DataSettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.medium))
                .foregroundStyle(.secondary).accessibilityAddTraits(.isHeader)
            DataSettingsCard(content: content)
        }
    }
}
