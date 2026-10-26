// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Permission status, permission reset, portable settings, and self-uninstall.
struct DataPermissionsSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.colorScheme) private var scheme
    private let permissionsContent: AnyView?

    init(permissionsContent: AnyView? = nil) { self.permissionsContent = permissionsContent }
    @State private var showUninstallConfirm = false
    @State private var uninstallFailed = false
    @State private var uninstallFailedBody = ""
    @State private var working = false
    @State private var exported: Bool?
    @State private var importFailed = false
    @State private var pendingImport: [String: Any]?
    @State private var showImportConfirm = false

    private var backup: BackupFeatureStrings {
        FeatureStrings.backup(l10n.language)
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

    private func copy(_ key: DataPermissionsPageCopy.Key) -> String {
        DataPermissionsPageCopy.text(key, l10n.language)
    }

    private var exportDescription: String {
        if let exported { return exported ? backup.exported : backup.exportFailed }
        return copy(.exportDescription)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                DataSettingsSection(title: DataPermissionsStrings.localized(l10n.language).data) {
                    DataPermissionsRow(symbol: "square.and.arrow.down", title: backup.importButton,
                        description: importFailed ? backup.invalidFile : copy(.importDescription),
                        descriptionIsError: importFailed, actionTitle: backup.compactImport(l10n.language)) {
                            exported = nil
                            importFailed = false
                            guard let url = SettingsBackup.runImportPanel() else { return }
                            if let settings = SettingsBackup.readSettings(at: url) {
                                pendingImport = settings
                                showImportConfirm = true
                            } else { importFailed = true }
                        }
                    DataSettingsDivider()
                    DataPermissionsRow(symbol: "square.and.arrow.up", title: backup.exportButton,
                        description: exportDescription, descriptionIsError: exported == false,
                        actionTitle: backup.compactExport(l10n.language)) {
                            importFailed = false
                            exported = SettingsBackup.runExportPanel()
                        }
                }
                DataSettingsSection(title: FeatureStrings.hub(l10n.language).tabPermissions) {
                    if let permissionsContent { permissionsContent }
                    else { PermissionsPortalSections(hub: FeatureStrings.hub(l10n.language)) }
                }
                DataSettingsSection(title: DataPermissionsStrings.localized(l10n.language).dangerZone) {
                    PermissionResetSettingsRow(onWorkingChange: { working = $0 }).disabled(working)
                    DataSettingsDivider()
                    DataPermissionsRow(symbol: "trash", title: l10n.s.advancedUninstallButton,
                        description: l10n.s.advancedUninstallDescription, tone: .destructive,
                        actionTitle: uninstallActionTitle, actionTone: .destructive,
                        actionRole: .destructive, actionEnabled: !working) { showUninstallConfirm = true }
                }
            }
            .padding(22)
        }
        .background(DataPermissionsPalette(scheme).page)
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
