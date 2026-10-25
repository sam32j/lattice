import Foundation

enum UtilityShortcutAssignmentTests {
    static func run(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.utility-shortcut.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let roles: [(GlobalShortcutRole, String)] = [
            (.clipboard, DefaultsKey.clipboardHistoryEnabled), (.shelf, DefaultsKey.shelfEnabled),
            (.cameraPreview, AppFeature.cameraPreview.availabilityKey),
            (.quickLauncher, AppFeature.quickLauncher.availabilityKey),
            (.scratchpad, AppFeature.scratchpad.availabilityKey)
        ]
        for (role, masterKey) in roles {
            let recorder = CompactShortcutValidationTests.Recorder()
            recorder.role = role
            recorder.preferenceDefaults = defaults
            defaults.set(false, forKey: masterKey)
            recorder.resetToDefault()
            suite.expect(recorder.isEnabled && !recorder.rawValue.isEmpty,
                         "\(role) can save its shortcut independently")
            suite.expect(!defaults.bool(forKey: masterKey),
                         "assigning \(role) never enables or installs its owner")
            defaults.set(true, forKey: masterKey)
            recorder.clearShortcut()
            suite.expect(!recorder.isEnabled && recorder.rawValue.isEmpty,
                         "\(role) can remove its shortcut independently")
            suite.expect(defaults.bool(forKey: masterKey),
                         "removing \(role) never disables or uninstalls its owner")
        }
    }
}
