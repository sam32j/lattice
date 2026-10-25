import Foundation

enum SettingsPageOrderTests {
    static func run(_ suite: TestSuite) {
        suite.expect(FeatureVisibilitySupport.isPageVisible(.dataPermissions, isAvailable: { _ in false }),
                     "Data and Permissions remains available with every optional feature removed")
        suite.expect(DataPermissionsStrings.localized(.enUS).title == "Data & Permissions"
                     && DataPermissionsStrings.localized(.enUS).data == "Lattice Data",
                     "the consolidated page and backup section use their requested names")
        let dataPage = (try? String(contentsOfFile: "Sources/Lattice/UI/Settings/DataPermissionsSettings.swift",
                                   encoding: .utf8)) ?? ""
        let sections = ["Section(DataPermissionsStrings.localized", "PermissionsPortalSections(hub:",
                        "PermissionResetSettingsRow(", "l10n.s.advancedUninstallButton"]
        let positions = sections.compactMap { dataPage.range(of: $0)?.lowerBound }
        suite.expect(positions.count == sections.count && positions == positions.sorted(),
                     "the page orders Lattice Data, permissions, permission reset, and uninstall")
    }
}
