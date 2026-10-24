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

    private var clearActionTitle: String {
        switch l10n.language {
        case .enUS: return "Clear"
        case .ptBR: return "Limpar"
        case .es: return "Borrar"
        case .de: return "Zurücksetzen"
        case .fr: return "Effacer"
        case .it: return "Cancella"
        case .ja: return "消去"
        case .ko: return "지우기"
        case .zhHans: return "清除"
        case .zhTW, .zhHK: return "清除"
        case .ru: return "Сбросить"
        case .uk: return "Скинути"
        case .tr: return "Temizle"
        case .sk: return "Vymazať"
        }
    }

    private var uninstallActionTitle: String {
        switch l10n.language {
        case .enUS: return "Uninstall"
        case .ptBR: return "Desinstalar"
        case .es: return "Desinstalar"
        case .de: return "Deinstallieren"
        case .fr: return "Désinstaller"
        case .it: return "Disinstalla"
        case .ja: return "アンインストール"
        case .ko: return "제거"
        case .zhHans: return "卸载"
        case .zhTW, .zhHK: return "解除安裝"
        case .ru: return "Удалить"
        case .uk: return "Видалити"
        case .tr: return "Kaldır"
        case .sk: return "Odinštalovať"
        }
    }

    var body: some View {
        Form {
            Section(DataPermissionsStrings.localized(l10n.language).data) {
                VStack(alignment: .leading, spacing: 12) {
                    // Row 1: Import settings
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(backup.importButton)
                                .font(.body)
                            if importFailed {
                                Text(backup.invalidFile)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        Spacer(minLength: 12)
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
                            Label(l10n.language == .enUS ? "Import…" : backup.importButton,
                                  systemImage: "square.and.arrow.down")
                        }
                    }

                    Divider()

                    // Row 2: Export settings
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(backup.exportButton)
                                .font(.body)
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
                        }
                        Spacer(minLength: 12)
                        Button {
                            importFailed = false
                            exported = SettingsBackup.runExportPanel()
                        } label: {
                            Label(l10n.language == .enUS ? "Export…" : backup.exportButton,
                                  systemImage: "square.and.arrow.up")
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section(FeatureStrings.hub(l10n.language).tabPermissions) {
                PermissionsPortalSections(hub: FeatureStrings.hub(l10n.language))
            }

            Section(DataPermissionsStrings.localized(l10n.language).dangerZone) {
                VStack(alignment: .leading, spacing: 12) {
                    // Row 1: Clear all permissions
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.s.advancedClearButton)
                                .font(.body)
                            Text(l10n.s.advancedResetDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            if let cleared {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label(cleared ? l10n.s.advancedCleared : l10n.s.advancedClearFailed,
                                          systemImage: cleared ? "arrow.clockwise.circle" : "exclamationmark.triangle")
                                        .font(.caption)
                                        .foregroundStyle(cleared ? Color.secondary : Color.orange)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Button(FeatureStrings.hub(l10n.language).restartButton) {
                                        FeatureRuntime.shared.relaunchApp()
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        Spacer(minLength: 12)
                        Button(role: .destructive) {
                            showClearConfirm = true
                        } label: {
                            Text(clearActionTitle).frame(minWidth: 100)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .foregroundStyle(.red)
                        .disabled(working)
                    }

                    Divider()

                    // Row 2: Uninstall Lattice
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.s.advancedUninstallButton)
                                .font(.body)
                            Text(l10n.s.advancedUninstallDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 12)
                        Button(role: .destructive) {
                            showUninstallConfirm = true
                        } label: {
                            Text(uninstallActionTitle).frame(minWidth: 100)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .foregroundStyle(.red)
                        .disabled(working)
                    }
                }
                .padding(.vertical, 4)
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
