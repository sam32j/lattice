import Foundation

enum PermissionRevocationTests {
    static func run(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.revocation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(true, forKey: DefaultsKey.keyboardDebounceEnabled)
        defaults.set(true, forKey: DefaultsKey.textSnippetsEnabled)
        defaults.set(true, forKey: DefaultsKey.snippetLibraryEnabled)
        defaults.set(true, forKey: DefaultsKey.brightnessControlEnabled)
        defaults.set(true, forKey: DefaultsKey.keepAwakeMouseJiggleEnabled)
        defaults.set(true, forKey: DefaultsKey.keyboardBrightnessShortcutsEnabled)
        defaults.set(true, forKey: DefaultsKey.cleaningModeShortcutEnabled)
        defaults.set("saved-shortcut", forKey: DefaultsKey.cleaningModeShortcut)
        let unknown = PermissionRevocationPolicy.apply([:], in: defaults)
        suite.expect(unknown.affected.isEmpty && defaults.bool(forKey: DefaultsKey.keyboardDebounceEnabled),
                     "an unknown initial permission state cannot revoke saved feature activation")
        let denied = PermissionRevocationPolicy.apply([.accessibility: false], in: defaults)
        suite.expect(!defaults.bool(forKey: DefaultsKey.keyboardDebounceEnabled)
                     && !defaults.bool(forKey: DefaultsKey.textSnippetsEnabled)
                     && denied.affected.contains(.keyboardDebounce),
                     "verified denial disables activation immediately without any settings page")
        suite.expect(!defaults.bool(forKey: DefaultsKey.cleaningModeShortcutEnabled)
                     && defaults.string(forKey: DefaultsKey.cleaningModeShortcut) == "saved-shortcut"
                     && denied.endsCleaningLock,
                     "lost Accessibility removes Cleaning Mode activation and releases a temporary lock without deleting its shortcut")
        suite.expect(defaults.bool(forKey: DefaultsKey.brightnessControlEnabled)
                     && defaults.bool(forKey: DefaultsKey.keyboardBrightnessShortcutsEnabled)
                     && defaults.bool(forKey: DefaultsKey.snippetLibraryEnabled)
                     && !defaults.bool(forKey: DefaultsKey.keepAwakeMouseJiggleEnabled),
                     "revocation preserves direct brightness, keyboard-light shortcuts and child configuration")
        _ = PermissionRevocationPolicy.apply([.accessibility: true], in: defaults)
        suite.expect(!defaults.bool(forKey: DefaultsKey.keyboardDebounceEnabled),
                     "later permission restoration never silently reactivates a revoked feature")
        defaults.set(true, forKey: DefaultsKey.keyboardDebounceEnabled)
        let current = PermissionRevocationPolicy.revalidated([.accessibility: false], verify: { _ in true })
        _ = PermissionRevocationPolicy.apply(current, in: defaults)
        suite.expect(defaults.bool(forKey: DefaultsKey.keyboardDebounceEnabled),
                     "an old queued denial cannot erase an explicit enable after a verified live grant")
        defaults.set(true, forKey: DefaultsKey.screenRecorderEnabled)
        defaults.set(true, forKey: DefaultsKey.recorderMicrophone)
        _ = PermissionRevocationPolicy.apply([.microphone: false], in: defaults)
        suite.expect(defaults.bool(forKey: DefaultsKey.screenRecorderEnabled)
                     && !defaults.bool(forKey: DefaultsKey.recorderMicrophone),
                     "microphone loss disables only microphone recording, not screen recording")
        let screen = PermissionRevocationPolicy.apply([.screenRecording: false], in: defaults)
        suite.expect(screen.uninstall.contains(.screenshot) && screen.uninstall.contains(.screenRecorder)
                     && !defaults.bool(forKey: DefaultsKey.screenRecorderEnabled),
                     "screen-access denial also disables page-owned capture installation")
    }
}
