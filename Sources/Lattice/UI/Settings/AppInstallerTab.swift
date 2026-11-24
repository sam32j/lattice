// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The App Manager's App Installer tab: the disk image waiting to install, or
/// a drop strip while none is; the install preferences; recent installs.
struct AppInstallerTab: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var installer = DiskImageInstallerService.shared
    @AppStorage(DefaultsKey.diskImageInstallerUseUserApplications) private var useUserApplications = false
    @AppStorage(DefaultsKey.diskImageInstallerTrashesDownload) private var trashesDownload = true
    @AppStorage(DefaultsKey.diskImageInstallerRevealsApp) private var revealsApp = false
    @AppStorage(DefaultsKey.diskImageInstallerOffersUnverifiedOpen) private var offersUnverifiedOpen = false
    /// The switch is the source of truth; Launch Services follows it.
    @AppStorage(DefaultsKey.diskImageInstallerOpensDiskImages) private var opensInLattice = false

    private var strings: AppInstallerTabStrings { FeatureStrings.appInstallerTab(l10n.language) }
    private var destination: String { useUserApplications ? "~/Applications" : "/Applications" }

    var body: some View {
        AppManagerPage {
            Group {
                if let image = installer.detected {
                    detectedCard(image)
                        .transition(.settingsReveal)
                } else {
                    dropStrip
                        .transition(.settingsReveal)
                }
            }
            preferences
            recentInstalls
        }
        .settingsExpansionAnimation(value: installer.detected?.id)
        .onChange(of: installer.detected != nil, initial: true) { _, waiting in
            AppManagerAttention.shared.diskImageWaiting = waiting
        }
    }

    private var dropStrip: some View {
        AppManagerDropStrip(symbol: "externaldrive.badge.plus", headline: strings.watchingTitle,
                            detail: strings.watchingDetail, types: [.fileURL],
                            onDrop: { urls in urls.forEach { installer.open(diskImage: $0) } }) {
            Button(strings.chooseButton, action: chooseDiskImage)
        }
    }

    private func chooseDiskImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = DiskImageOpenHandler.contentTypes
        panel.allowsOtherFileTypes = false
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        installer.open(diskImage: url)
    }

    private func detectedCard(_ image: DetectedDiskImage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AppManagerAppIcon(path: image.appPath, name: image.displayName, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    switch image.phase {
                    case .waiting:
                        HStack(spacing: 6) {
                            Text(image.displayName).font(.system(size: 13, weight: .semibold))
                            if image.replacesExisting { AppManagerChip(text: strings.updateChip, tone: .accent) }
                            if let accepted = image.gatekeeperAccepted {
                                AppManagerChip(text: accepted ? strings.gatekeeperVerified : strings.gatekeeperUnverified,
                                               tone: accepted ? .green : .orange)
                            }
                        }
                        Text(details(image)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    case let .installing(step):
                        Text(String(format: FeatureStrings.diskImageInstaller(l10n.language).installingFormat,
                                    image.displayName))
                            .font(.system(size: 13, weight: .semibold))
                        Text(stepText(step)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            switch image.phase {
            case .waiting:
                Divider()
                HStack(spacing: 10) {
                    Text(String(format: image.replacesExisting
                                    ? (trashesDownload ? strings.planReplaceTrashFormat : strings.planReplaceFormat)
                                    : (trashesDownload ? strings.planTrashFormat : strings.planFormat), destination))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Button(strings.skip) { installer.skipDetected() }
                    Button(FeatureStrings.diskImageInstaller(l10n.language).installButton) { installer.installDetected() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            case let .installing(step):
                ProgressView(value: step.progress)
                    .progressViewStyle(.linear)
                    .animation(.easeOut(duration: 0.3), value: step)
            }
        }
        .padding(16)
        .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.accentColor.opacity(0.3)))
    }

    private func details(_ image: DetectedDiskImage) -> String {
        var parts = [image.imageFileName]
        if let version = image.version { parts.append(version) }
        if let size = image.imageSize { parts.append(AppManagerFormat.bytes(size)) }
        if let developer = image.developer { parts.append(developer) }
        return parts.joined(separator: " · ")
    }

    private func stepText(_ step: DiskImageInstallStep) -> String {
        switch step {
        case .copying: return strings.stepCopying
        case .verifying: return strings.stepVerifying
        case .moving: return strings.stepMoving
        case .ejecting: return strings.stepEjecting
        case .trashing: return strings.stepTrashing
        }
    }

    private var preferences: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppManagerSectionHeader(title: strings.preferencesTitle)
            SettingsCard {
                SettingsControlRow(title: strings.locationTitle) {
                    Picker(strings.locationTitle, selection: $useUserApplications) {
                        Text(strings.locationSystem).tag(false)
                        Text(strings.locationUser).tag(true)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                }
                Divider()
                SettingsControlRow(title: strings.openWithLattice) {
                    Toggle(strings.openWithLattice, isOn: Binding(get: { opensInLattice }, set: { on in
                        opensInLattice = on
                        DiskImageOpenHandler.setOpensInLattice(on) {}
                    }))
                    .labelsHidden()
                }
                Divider()
                SettingsControlRow(title: strings.trashTitle, caption: strings.trashCaption) {
                    Toggle(strings.trashTitle, isOn: $trashesDownload).labelsHidden()
                }
                Divider()
                SettingsControlRow(title: strings.revealTitle, caption: strings.revealCaption) {
                    Toggle(strings.revealTitle, isOn: $revealsApp).labelsHidden()
                }
                Divider()
                SettingsControlRow(title: strings.unverifiedToggle, caption: strings.unverifiedCaption) {
                    Toggle(strings.unverifiedToggle, isOn: $offersUnverifiedOpen).labelsHidden()
                }
                Divider()
                SettingsControlRow(title: strings.ignoreHomebrewTitle, caption: strings.ignoreHomebrewCaption) {
                    AppManagerChip(text: FeatureStrings.appManager(l10n.language).alwaysOn)
                }
            }
            .toggleStyle(.switch)
        }
    }

    private var recentInstalls: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppManagerSectionHeader(title: strings.recentTitle,
                                    meta: installer.recentInstalls.isEmpty ? nil
                                        : String(format: strings.recentCountFormat, installer.recentInstalls.count))
            SettingsCard {
                if installer.recentInstalls.isEmpty {
                    Text(strings.recentEmpty)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(installer.recentInstalls.enumerated()), id: \.element.id) { index, install in
                        if index > 0 { Divider() }
                        recentRow(install)
                    }
                }
            }
        }
    }

    private func recentRow(_ install: DiskImageRecentInstall) -> some View {
        let missing = !FileManager.default.fileExists(atPath: install.destinationPath)
        return HStack(spacing: 12) {
            AppManagerAppIcon(path: install.destinationPath, name: install.name)
                .saturation(missing ? 0 : 1)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(install.name).font(.system(size: 13, weight: .medium))
                    if missing {
                        AppManagerChip(text: strings.notFound)
                    } else {
                        AppManagerChip(text: install.downloadTrashed ? strings.downloadTrashed : strings.downloadKept,
                                       tone: install.downloadTrashed ? .green : .muted)
                    }
                }
                Text([install.version, (install.destinationPath as NSString).abbreviatingWithTildeInPath,
                      AppManagerFormat.relative(install.date, language: l10n.language)]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            if missing {
                Button(strings.clear) { installer.forget(install) }
            } else {
                Button(strings.reveal) { installer.reveal(install) }
            }
        }
        // An app deleted since reads as gone.
        .opacity(missing ? 0.55 : 1)
    }
}
