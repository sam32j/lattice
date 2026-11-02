// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers


extension AppUpdatesListView {
    func row(_ item: AppUpdatesSupport.Item) -> some View {
        let isInstalling = updates.installingItemIDs.contains(item.id)
        let isWebApp = item.source == .onlineCatalog
        let buttonLabel = isInstalling ? text.updating : (isWebApp ? text.openToUpdate : text.updateOne)
        let accessibleActionName = String(format: isWebApp ? text.openToUpdateAppFormat : text.updateAppFormat, item.name)

        return HStack(spacing: 12) {
            Image(nsImage: icon(for: item))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: compact ? 26 : 36, height: compact ? 26 : 36)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: compact ? 11.5 : 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.versionSummary)
                    .font(.system(size: compact ? 9.5 : 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)

            Button {
                updates.update(item)
            } label: {
                Text(buttonLabel)
                    .font(.system(size: compact ? 10.5 : 11.5, weight: .semibold))
                    .lineLimit(1)
                    .padding(.horizontal, compact ? 10 : 14)
                    .padding(.vertical, compact ? 3.5 : 5.5)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(isInstalling || isBusy)
            .opacity((isInstalling || isBusy) ? 0.55 : 1.0)
            .accessibilityLabel(accessibleActionName)

            if !compact, item.bundleID != nil {
                Menu {
                    ruleActions(for: item)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .tint(.secondary)
                .menuIndicator(.hidden)
                .fixedSize()
                .help(moreOptions)
                .accessibilityLabel("\(moreOptions): \(item.name)")
            }
        }
        .padding(.horizontal, compact ? 8 : 14)
        .padding(.vertical, compact ? 6 : 10)
        .frame(height: compact ? Self.compactRowHeight : nil)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(compact ? 0.035 : 0.04))
        )
        .contextMenu { ruleActions(for: item) }
    }

    @ViewBuilder
    func ruleActions(for item: AppUpdatesSupport.Item) -> some View {
        if item.bundleID != nil {
            Button(String(format: text.skipVersionFormat, item.latestVersion)) {
                updates.skipVersion(item)
            }
            .disabled(isBusy)
            Button("\(text.excludeApp): \(item.name)") {
                updates.excludeApp(item)
            }
            .disabled(isBusy)
        }
    }

    func icon(for item: AppUpdatesSupport.Item) -> NSImage {
        guard let path = item.bundlePath, FileManager.default.fileExists(atPath: path) else {
            return NSWorkspace.shared.icon(for: .applicationBundle)
        }
        return NSWorkspace.shared.icon(forFile: path)
    }

    // MARK: - Compact Mode (for Menu Bar Panel)
}
