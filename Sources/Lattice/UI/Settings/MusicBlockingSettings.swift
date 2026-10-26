// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Music App Blocker settings: intercepts media key launches of Apple Music.
struct MusicBlockingSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var musicBlocker = MusicLaunchBlocker.shared
    @State private var replacementRejected = false
    @AppStorage(DefaultsKey.musicBlockEnabled) private var enabled = false
    @AppStorage(DefaultsKey.musicBlockReplacementPath) private var replacementPath = ""
    @AppStorage(DefaultsKey.musicBlockPlayReplacement) private var playReplacement = true

    var body: some View {
        SettingsCard(title: l10n.s.musicBlockSection, headerAccessory: {
            PermissionGatedToggle(l10n.s.musicBlockTitle, isOn: $enabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.regular)
                .help(l10n.s.musicBlockTitle)
                .accessibilityLabel(l10n.s.musicBlockTitle)
                .onChange(of: enabled) { _, enabled in
                    FeatureRuntime.shared.setAvailable([.musicBlock], enabled)
                    musicBlocker.syncWithPreferences()
                }
        }) {
            VStack(alignment: .leading, spacing: 10) {
                Text(l10n.s.musicBlockCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if enabled {
                    if !permissions.accessibility {
                        PermissionRow(kind: .accessibility)
                    } else if !musicBlocker.isMonitoring {
                        Text(l10n.s.musicBlockUnavailable)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 8) {
                        Text(l10n.s.musicBlockReplacementLabel)
                        Spacer()
                        Text(replacementName)
                            .foregroundStyle(.secondary)
                        Button(l10n.s.musicBlockChooseApp) { chooseReplacement() }
                        if !replacementPath.isEmpty {
                            Button {
                                replacementPath = ""
                                replacementRejected = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }
                    if !replacementPath.isEmpty {
                        Toggle(l10n.s.musicBlockPlayReplacement, isOn: $playReplacement)
                    }
                    if replacementRejected {
                        Text(l10n.s.musicBlockReplacementBlocked)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.55)
        }
        .settingsExpansionAnimation(value: [enabled, permissions.accessibility, musicBlocker.isMonitoring,
            replacementPath.isEmpty, replacementRejected])
    }

    private var replacementName: String {
        guard !replacementPath.isEmpty else { return l10n.s.musicBlockReplacementNone }
        let name = FileManager.default.displayName(atPath: replacementPath)
        return (name as NSString).deletingPathExtension
    }

    private func chooseReplacement() {
        replacementRejected = false
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        // Picking the blocked app itself would start a launch-and-kill loop.
        if let bundleID = Bundle(url: url)?.bundleIdentifier,
           MusicLaunchBlocker.blockedBundleIDs.contains(bundleID) {
            replacementRejected = true
            return
        }
        replacementPath = url.path
    }
}
