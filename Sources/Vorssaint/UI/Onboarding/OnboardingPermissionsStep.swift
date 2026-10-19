// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Permission requirements for the features enabled during setup.
struct SelectedPermissionsStep: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var showingOtherPermissions = false
    let features: Set<AppFeature>
    let permissions: [AppPermission]

    private var hub: FeatureHubStrings { FeatureStrings.hub(l10n.language) }
    private var otherPermissions: [AppPermission] {
        AppPermission.allCases.filter { !permissions.contains($0) }
    }

    var body: some View {
        VStack(spacing: 18) {
            StepHeader(icon: "key.horizontal.fill",
                       title: hub.tabPermissions,
                       subtitle: hub.permissionsIntro)

            VStack(alignment: .leading, spacing: 12) {
                Text(hub.onboardingSelectedPermissionsTitle)
                    .font(.headline)

                if permissions.isEmpty {
                    Label(hub.onboardingNoSelectedPermissions,
                          systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(permissions.enumerated()), id: \.offset) { index, permission in
                            if index > 0 { Divider().padding(.vertical, 12) }
                            VStack(alignment: .leading, spacing: 8) {
                                PermissionRow(kind: permission == .accessibility
                                              ? .accessibility : .screenRecording)
                                Text(permission.explainer(hub))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(String(format: hub.usedByFormat,
                                            featureNames(for: permission)))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
            .padding(.horizontal, 28)

            DisclosureGroup(isExpanded: $showingOtherPermissions) {
                VStack(alignment: .leading, spacing: 14) {
                    PermissionsPortalSections(hub: hub,
                                              visiblePermissions: otherPermissions)
                }
                .padding(.top, 12)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(hub.onboardingOtherPermissionsTitle)
                        .font(.headline)
                    Text(hub.onboardingOtherPermissionsCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
            .padding(.horizontal, 28)

            Text(l10n.s.permissionRestartNote)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            Spacer()
        }
    }

    private func featureNames(for permission: AppPermission) -> String {
        features
            .filter { $0.onboardingPermissions.contains(permission) }
            .map { $0.hubTitle(l10n.s, hub: hub) }
            // Localized: a plain sort orders by Unicode scalar, which throws
            // every accented name past Z. On the first screen someone sees,
            // in a language with accents, that reads as a list in no order.
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .joined(separator: ", ")
    }
}

// MARK: - Shared header

private struct StepHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.spaceGradient)
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(title)
                .font(.system(size: 19, weight: .bold))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 48)
        }
        .padding(.top, 30)
    }
}
