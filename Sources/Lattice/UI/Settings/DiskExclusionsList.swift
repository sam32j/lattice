// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The list of drives excluded from "Eject all disks".
/// Presents an Application Listing Panel (ALP) style row with an "Edit…" button,
/// opening a dedicated sheet with saved exclusions and auto-discovered mounted disks.
struct DiskExclusionsList: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var protection = DiskProtectionService.shared
    @State private var showingSheet = false

    private var strings: DiskExclusionStrings {
        FeatureStrings.diskExclusions(l10n.language)
    }

    var body: some View {
        SettingsControlRow(title: strings.listTitle) {
            Button(SettingsAppListStrings.text(l10n.language).edit) {
                showingSheet = true
            }
        }
        .sheet(isPresented: $showingSheet) {
            exclusionsSheet
        }
    }

    private var exclusionsSheet: some View {
        let candidates = mountedCandidateDrives
        return AppListSheet(
            caption: strings.caption,
            title: strings.sheetTitle,
            centersContent: protection.excludedVolumes.isEmpty && candidates.isEmpty,
            onDone: { showingSheet = false }
        ) {
            if protection.excludedVolumes.isEmpty && candidates.isEmpty {
                ContentUnavailableView(strings.emptyTitle, systemImage: "externaldrive.badge.xmark")
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    // Saved excluded section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(strings.savedSection)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        if protection.excludedVolumes.isEmpty {
                            Text(strings.noSavedDisks)
                                .font(.callout)
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 4)
                        } else {
                            VStack(spacing: 6) {
                                ForEach(protection.excludedVolumes, id: \.self) { name in
                                    HStack(spacing: 10) {
                                        Image(systemName: "externaldrive.fill")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 20)
                                        Text(name)
                                            .font(.system(size: 13))
                                            .lineLimit(1)
                                        Spacer()
                                        Button {
                                            protection.removeExcludedVolume(name)
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.system(size: 15))
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("\(strings.removeButton): \(name)")
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }

                    Divider()

                    // Discovered connected disks section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(strings.discoverySection)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        if candidates.isEmpty {
                            Text(strings.noDiscoveredDisks)
                                .font(.callout)
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 4)
                        } else {
                            VStack(spacing: 6) {
                                ForEach(candidates, id: \.self) { drive in
                                    HStack(spacing: 10) {
                                        Image(systemName: "externaldrive")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 20)
                                        Text(drive)
                                            .font(.system(size: 13))
                                            .lineLimit(1)
                                        Spacer()
                                        Button {
                                            protection.addExcludedVolume(drive)
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 15))
                                                .foregroundStyle(Color.accentColor)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("\(strings.addButton): \(drive)")
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
        } footer: {
            EmptyView()
        }
    }

    private var mountedCandidateDrives: [String] {
        let keys: Set<URLResourceKey> = [
            .volumeIsInternalKey, .volumeIsRemovableKey,
            .volumeIsEjectableKey, .volumeIsLocalKey,
            .volumeIsRootFileSystemKey,
            .volumeNameKey,
            .volumeLocalizedNameKey,
            .volumeUUIDStringKey,
        ]
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys),
            options: [.skipHiddenVolumes]) else { return [] }
        let currentExcluded = Set(protection.excludedVolumes.map { $0.lowercased() })
        var results: [String] = []
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: keys) else { continue }
            let isOfferable = QuickTogglesSupport.shouldOfferEject(
                isInternal: values.volumeIsInternal ?? false,
                isRemovable: values.volumeIsRemovable ?? false,
                isEjectable: values.volumeIsEjectable ?? false,
                isLocal: values.volumeIsLocal ?? false,
                isRootFileSystem: values.volumeIsRootFileSystem ?? (url.path == "/")
            )
            guard isOfferable else { continue }
            let name = values.volumeLocalizedName ?? values.volumeName ?? url.lastPathComponent
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let alreadyExcluded = QuickTogglesSupport.isExcluded(
                volumeName: trimmed,
                volumeUUID: values.volumeUUIDString,
                mountPath: url.path,
                excludedVolumes: currentExcluded)
            if !trimmed.isEmpty, !alreadyExcluded, !results.contains(trimmed) {
                results.append(trimmed)
            }
        }
        return results.sorted()
    }
}
