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

        let content = HStack(spacing: 12) {
            Image(nsImage: icon(for: item))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: compact ? 26 : 30, height: compact ? 26 : 30)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: compact ? 11.5 : 13, weight: compact ? .semibold : .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.versionSummary)
                    .font(compact ? .system(size: 9.5) : .caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)

            Button(buttonLabel) {
                updates.update(item)
            }
            .buttonStyle(.appManager(compact: compact))
            .disabled(isInstalling || isBusy)
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

        if compact {
            return AnyView(
                content
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(height: Self.compactRowHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.035))
                    )
                    .contextMenu { ruleActions(for: item) }
            )
        } else {
            return AnyView(
                content
                    .contextMenu { ruleActions(for: item) }
            )
        }
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
