// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// The apps whose being open starts a Stay Awake session, edited in a sheet
/// so the page never grows a list in place.
struct StayAwakeAppsSheet: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var awake = KeepAwakeManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let strings = FeatureStrings.stayAwakeSettings(l10n.language)
        let automation = FeatureStrings.keepAwakeAutomation(l10n.language)
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(strings.appsTitle)
                    .font(.headline)
                Text(automation.runningAppsListCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if awake.runningAppBundleIDs.isEmpty {
                Text(strings.appsEmpty)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            AppBundleList(title: automation.runningAppsListTitle,
                          caption: automation.runningAppsListCaption,
                          addTitle: automation.runningAppsAddButton,
                          removeLabel: automation.runningAppsRemoveButton,
                          bundleIDs: awake.runningAppBundleIDs,
                          reachesEveryApp: true,
                          onAdd: { save(awake.runningAppBundleIDs + [$0]) },
                          onRemove: { id in save(awake.runningAppBundleIDs.filter { $0 != id }) })
            HStack {
                Spacer()
                Button(strings.done) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func save(_ bundleIDs: [String]) {
        let sanitized = Defaults.sanitizedBundleIdentifierList(bundleIDs)
        UserDefaults.standard.set(sanitized, forKey: DefaultsKey.keepAwakeRunningAppBundleIDs)
        awake.automationPreferencesDidChange()
    }
}

/// The chosen apps in one line: up to four icons and their names.
struct StayAwakeAppsSummary: View {
    @ObservedObject private var l10n = L10n.shared
    let bundleIDs: [String]
    let edit: () -> Void

    var body: some View {
        let strings = FeatureStrings.stayAwakeSettings(l10n.language)
        let names = bundleIDs.map(Self.name(for:)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        HStack(spacing: 10) {
            HStack(spacing: -6) {
                ForEach(Array(bundleIDs.prefix(4)), id: \.self) { id in
                    Image(nsImage: Self.icon(for: id))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 22, height: 22)
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(bundleIDs.isEmpty ? strings.appsEmpty
                     : strings.appsSummary(count: bundleIDs.count, names: names.joined(separator: ", "), l10n.language))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(strings.appsOpenCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Button(strings.appsEdit, action: edit)
                .controlSize(.small)
                .fixedSize()
        }
    }

    private static func appURL(for id: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
    }

    static func name(for id: String) -> String {
        guard let url = appURL(for: id) else { return id }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    static func icon(for id: String) -> NSImage {
        guard let url = appURL(for: id) else { return NSWorkspace.shared.icon(for: .application) }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
