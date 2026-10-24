import Foundation

enum MouseShortcutBackupTests {
    enum ReviewDefaults { static var current: UserDefaults! }
    final class RestoreHooks {
        func prepareForSettingsRestore() {}
        func relaunchApp() {}
    }
    enum ScratchpadService { static let shared = RestoreHooks() }
    enum FeatureRuntime { static let shared = RestoreHooks() }
    static func run(_ suite: TestSuite) {
        let localPath = "/Users/local-user/Tools/mouse-helper"
        let lists = ["3": ["com.apple.Safari", localPath], "4": [localPath]]
        let payload = SettingsBackupSupport.payload(appVersion: "test") { key in
            key == DefaultsKey.mouseShortcutAppExceptions ? lists : nil
        }
        let settings = payload[SettingsBackupSupport.settingsKey] as? [String: Any]
        suite.expect(settings?[DefaultsKey.mouseShortcutAppExceptions] as? [String: [String]]
                     == ["3": ["com.apple.Safari"], "4": []],
                     "per-button backups export bundle IDs without leaking local executable paths, including explicit empty lists")
        let local = ["3": [localPath, "com.apple.Terminal"], "5": [localPath]]
        let restored = SettingsBackupSupport.restoredMouseShortcutExceptions(
            restored: ["3": ["com.apple.Safari"], "4": []], local: local)
        suite.expect(restored == ["3": ["com.apple.Safari", localPath], "4": [], "5": [localPath]],
                     "restore keeps this Mac's per-button executable paths without retaining superseded portable entries")
        suite.expect(SettingsBackupSupport.restoredMouseShortcutExceptions(restored: restored, local: local) == restored,
                     "repeated restore never duplicates a local per-button path")
        let imported: [String: Any] = [SettingsBackupSupport.formatVersionKey: SettingsBackupSupport.formatVersion,
            SettingsBackupSupport.settingsKey: [DefaultsKey.mouseShortcutAppExceptions:
                ["3": ["com.apple.Safari", "/Users/another-mac/helper"]]]]
        suite.expect(SettingsBackupSupport.sanitizedSettings(from: imported)?[DefaultsKey.mouseShortcutAppExceptions]
                     as? [String: [String]] == ["3": ["com.apple.Safari"]],
                     "import sanitization refuses executable authority from another Mac")
        let domain = "com.vorssaint.tests.mouse-backup.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        ReviewDefaults.current = defaults
        defer { defaults.removePersistentDomain(forName: domain); ReviewDefaults.current = nil }
        defaults.set(["5": [localPath]], forKey: DefaultsKey.mouseShortcutAppExceptions)
        Backup.applyAndRelaunch(settings: [MouseExceptionScope.buttonShortcuts.defaultsKey: ["com.apple.Safari"]])
        suite.expect(MouseShortcutExceptions.list(for: 5, in: defaults) == ["com.apple.Safari", localPath],
                     "restoring an older shared-list backup retains inherited apps beside each button’s local executable paths")
        defaults.set(["5": [localPath]], forKey: DefaultsKey.mouseShortcutAppExceptions)
        Backup.applyAndRelaunch(settings: [MouseExceptionScope.buttonShortcuts.defaultsKey: ["com.apple.Safari"],
            DefaultsKey.mouseShortcutAppExceptions: ["5": [String]()]])
        suite.expect(MouseShortcutExceptions.list(for: 5, in: defaults) == [localPath],
                     "an explicit empty per-button override remains independent of the inherited list after restore")
    }
}
