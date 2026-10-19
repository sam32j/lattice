// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Permission status, permission reset, portable settings, and self-uninstall.
struct DataPermissionsSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var showClearConfirm = false
    @State private var showUninstallConfirm = false
    @State private var uninstallFailed = false
    @State private var uninstallFailedBody = ""
    @State private var working = false
    @State private var cleared: Bool?
    @State private var exported: Bool?
    @State private var importFailed = false
    @State private var pendingImport: [String: Any]?
    @State private var showImportConfirm = false

    private var backup: BackupFeatureStrings {
        FeatureStrings.backup(l10n.language)
    }

    var body: some View {
        Form {
            Section(FeatureStrings.hub(l10n.language).tabPermissions) {
                PermissionsPortalSections(hub: FeatureStrings.hub(l10n.language))
                VStack(alignment: .leading, spacing: 10) {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label(l10n.s.advancedClearButton, systemImage: "lock.slash")
                    }
                    .foregroundStyle(.red)
                    .disabled(working)
                    Text(l10n.s.advancedResetDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if cleared == true {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text(l10n.s.advancedCleared).font(.caption).foregroundStyle(.green)
                        }
                    } else if cleared == false {
                        Text(l10n.s.advancedClearFailed)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.vertical, 8)
            }

            Section(DataPermissionsStrings.localized(l10n.language).data) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Button {
                            importFailed = false
                            exported = SettingsBackup.runExportPanel()
                        } label: {
                            Label(backup.exportButton, systemImage: "square.and.arrow.up")
                        }
                        Button {
                            exported = nil
                            importFailed = false
                            guard let url = SettingsBackup.runImportPanel() else { return }
                            if let settings = SettingsBackup.readSettings(at: url) {
                                pendingImport = settings
                                showImportConfirm = true
                            } else {
                                importFailed = true
                            }
                        } label: {
                            Label(backup.importButton, systemImage: "square.and.arrow.down")
                        }
                    }
                    Text(backup.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if exported == true {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text(backup.exported).font(.caption).foregroundStyle(.green)
                        }
                    } else if exported == false {
                        Text(backup.exportFailed)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if importFailed {
                        Text(backup.invalidFile)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.vertical, 8)
            }

            Section(l10n.s.advancedUninstallSection) {
                VStack(alignment: .leading, spacing: 10) {
                    Button(role: .destructive) {
                        showUninstallConfirm = true
                    } label: {
                        Label(l10n.s.advancedUninstallButton, systemImage: "trash")
                    }
                    .buttonStyle(DestructiveOutlineButtonStyle())
                    .disabled(working)
                    Text(l10n.s.advancedUninstallDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
            }
        }
        .formStyle(.grouped)
        .alert(l10n.s.advancedClearConfirmTitle, isPresented: $showClearConfirm) {
            Button(l10n.s.uninstallerCancel, role: .cancel) {}
            Button(l10n.s.advancedClearButton, role: .destructive) {
                working = true
                cleared = nil
                SelfUninstall.clearPermissions { succeeded in
                    working = false
                    cleared = succeeded
                }
            }
        } message: {
            Text(l10n.s.advancedClearConfirmBody)
        }
        .alert(l10n.s.advancedUninstallConfirmTitle, isPresented: $showUninstallConfirm) {
            Button(l10n.s.uninstallerCancel, role: .cancel) {}
            Button(l10n.s.advancedUninstallButton, role: .destructive) {
                working = true
                SelfUninstall.uninstallCompletely { body in
                    working = false
                    uninstallFailedBody = body
                    // Stopping leaves the Mac exactly as it was, so the only
                    // thing left to do is say so: the button going quiet on
                    // its own reads as the app ignoring the request.
                    uninstallFailed = true
                }
            }
        } message: {
            Text(l10n.s.advancedUninstallConfirmBody)
        }
        .alert(l10n.s.advancedUninstallFailedTitle, isPresented: $uninstallFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(uninstallFailedBody)
        }
        .alert(backup.importConfirmTitle, isPresented: $showImportConfirm) {
            Button(l10n.s.uninstallerCancel, role: .cancel) { pendingImport = nil }
            Button(backup.importAction) {
                if let pendingImport {
                    SettingsBackup.applyAndRelaunch(settings: pendingImport)
                }
            }
        } message: {
            Text(SettingsBackupSupport.omitsDynamicIslandSettings(pendingImport ?? [:])
                 ? backup.importMissingIslandBody : backup.importConfirmBody)
        }
    }
}

private struct DestructiveOutlineButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(.red)
            .background(.red.opacity(configuration.isPressed ? 0.12 : 0.03),
                        in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6).strokeBorder(.red.opacity(0.7))
            }
            .opacity(isEnabled ? 1 : 0.45)
    }
}
