// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// The apps whose being open starts a Stay Awake session: one summary row
/// whose Edit… button opens the shared app list sheet.
struct StayAwakeAppsList: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var awake = KeepAwakeManager.shared

    var body: some View {
        let strings = FeatureStrings.stayAwakeSettings(l10n.language)
        let automation = FeatureStrings.keepAwakeAutomation(l10n.language)
        AppBundleList(title: strings.appsTitle,
                      caption: automation.runningAppsListCaption,
                      action: .add,
                      removeLabel: automation.runningAppsRemoveButton,
                      bundleIDs: awake.runningAppBundleIDs,
                      reachesEveryApp: true,
                      usesSheet: true,
                      sheetTitle: strings.appsTitle,
                      summary: AnyView(StayAwakeAppsSummary(bundleIDs: awake.runningAppBundleIDs)),
                      onAdd: { save(awake.runningAppBundleIDs + [$0]) },
                      onRemove: { id in save(awake.runningAppBundleIDs.filter { $0 != id }) })
    }

    private func save(_ bundleIDs: [String]) {
        let sanitized = Defaults.sanitizedBundleIdentifierList(bundleIDs)
        UserDefaults.standard.set(sanitized, forKey: DefaultsKey.keepAwakeRunningAppBundleIDs)
        awake.automationPreferencesDidChange()
    }
}

/// The chosen apps in one line: up to four icons and their names, or a
/// short note when there are none.
struct StayAwakeAppsSummary: View {
    @ObservedObject private var l10n = L10n.shared
    let bundleIDs: [String]

    var body: some View {
        let strings = FeatureStrings.stayAwakeSettings(l10n.language)
        let names = bundleIDs.map { InstalledApps.name(for: $0) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        HStack(spacing: 10) {
            if !bundleIDs.isEmpty {
                HStack(spacing: -6) {
                    ForEach(Array(bundleIDs.prefix(4)), id: \.self) { id in
                        Image(nsImage: InstalledApps.icon(for: id))
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 22, height: 22)
                    }
                }
                .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(bundleIDs.isEmpty ? strings.appsEmpty
                     : strings.appsSummary(count: bundleIDs.count, names: names.joined(separator: ", "), l10n.language))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(strings.appsCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
