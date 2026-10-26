import Foundation

enum SettingsPageOrderTests {
    static func run(_ suite: TestSuite) {
        suite.expect(FeatureVisibilitySupport.isPageVisible(.dataPermissions, isAvailable: { _ in false }),
                     "Data and Permissions remains available with every optional feature removed")
        suite.expect(DataPermissionsStrings.localized(.enUS).title == "Data & Permissions"
                     && DataPermissionsStrings.localized(.enUS).data == "Lattice Data",
                     "the consolidated page and backup section use their requested names")
    }
}
