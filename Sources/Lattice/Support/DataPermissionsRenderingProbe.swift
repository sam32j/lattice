// SPDX-License-Identifier: GPL-3.0-or-later
#if LATTICE_DEVELOPMENT
import AppKit
import SwiftUI

/// Disposable-identity rendering only. Permission states are supplied, not read
/// from the OS; none of the request, backup, reset or uninstall actions is run.
enum DataPermissionsRenderingProbe {
    static func run(output: URL, failures: inout [String]) {
        guard Bundle.main.bundleIdentifier?.hasPrefix("io.github.sam32j.lattice.tests.") == true else {
            failures.append("Data page rendering requires a disposable identity."); return
        }
        for (name, scheme, language, width) in [
            ("data-permissions-light", ColorScheme.light, AppLanguage.enUS, 600.0),
            ("data-permissions-dark", .dark, .enUS, 600.0),
            ("data-permissions-narrow", .light, .enUS, 542.0),
            ("data-permissions-german", .light, .de, 600.0) ] {
            UserDefaults.standard.set(language.rawValue, forKey: DefaultsKey.language)
            L10n.shared.language = language
            let view = DataPermissionsSettings(permissionsContent: AnyView(permissionRows(language)))
                .environment(\.colorScheme, scheme)
            SettingsRefactorProbe.render(name, view: AnyView(view),
                size: CGSize(width: width, height: 1280), output: output, failures: &failures, colorScheme: scheme)
        }
        L10n.shared.language = .enUS
        for phase in [PermissionResetState.Phase.ready, .restartRequired, .failed] {
            let row = DataSettingsCard {
                PermissionResetSettingsRow(state: PermissionResetState(phase: phase), reset: { _ in }, restart: {})
            }.padding(28)
            SettingsRefactorProbe.render("data-reset-\(phase)", view: AnyView(row),
                size: CGSize(width: 600, height: 180), output: output, failures: &failures)
        }
        let details = PermissionDetailsSheet(title: "Device Control and Data Access",
            explanation: "Lets the features you enable respond to keys, pointer input and other apps’ windows.",
            featureNames: ["Super Key", "Window Management"], isUnused: false,
            hub: FeatureStrings.hub(.enUS), onOpenSystemSettings: {})
        SettingsRefactorProbe.render("permission-details-with-settings", view: AnyView(details),
            size: CGSize(width: 460, height: 380), output: output, failures: &failures)
    }

    private static func permissionRows(_ language: AppLanguage) -> some View {
        let granted: Set<AppPermission> = [.accessibility, .screenRecording, .notifications, .camera, .bluetooth]
        let missing: Set<AppPermission> = [.fullDiskAccess, .automationFinder, .microphone, .calendar]
        return VStack(spacing: 0) {
            ForEach(AppPermission.allCases, id: \.self) { permission in
                PermissionPortalRow(permission: permission, hub: FeatureStrings.hub(language),
                    status: granted.contains(permission) ? .granted : missing.contains(permission) ? .missing : .unknown,
                    requestAvailable: true)
                if permission != AppPermission.allCases.last { DataSettingsDivider() }
            }
        }
    }
}
#endif
