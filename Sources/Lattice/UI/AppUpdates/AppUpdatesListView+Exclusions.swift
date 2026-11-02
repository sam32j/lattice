// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers


extension AppUpdatesListView {
    var alsSheet: some View {
        AppListSheet(
            caption: text.excludedAppsCaption,
            title: text.excludedAppsTitle,
            centersContent: excludedRules.isEmpty,
            onDone: { showingALS = false }
        ) {
            if excludedRules.isEmpty {
                ContentUnavailableView(text.noExcludedApps, systemImage: "app.dashed",
                                       description: Text(text.noExcludedAppsDetail))
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(excludedRules) { rule in
                        HStack(spacing: 9) {
                            Image(nsImage: InstalledApps.icon(for: rule.bundleID))
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text(rule.name)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            Spacer()
                            Button {
                                updates.removeRule(rule)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(text.removeRule): \(rule.name)")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }
                .padding(12)
            }
        } footer: {
            Button {
                showingAppPicker = true
            } label: {
                Label(text.addException, systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingAppPicker) {
            let listed = Set(excludedRules.map(\.bundleID))
            AppPickerView(canBrowseApplications: true, acceptsExecutables: false) {
                showingAppPicker = false
            } onSelect: { url in
                showingAppPicker = false
                updates.addExclusion(appAt: url)
            } onSelectApp: { app in
                showingAppPicker = false
                if let id = app.explicitIdentity ?? app.bundleID {
                    updates.storeRule(bundleID: id, name: app.name, version: nil)
                }
            } loadApps: {
                InstalledApps.installedBundleApplications(excluding: listed, includeRunningApplications: true)
            }
        }
    }

}
