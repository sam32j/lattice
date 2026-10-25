import Foundation

enum PermissionResetStateTests {
    static func run(_ suite: TestSuite) {
        let state = PermissionResetState()
        var finish: ((Bool) -> Void)?
        var requests = 0
        suite.expect(state.phase == .ready, "permission reset starts with a clear action, not a restart claim")
        state.begin { completion in requests += 1; finish = completion }
        state.begin { _ in requests += 1 }
        suite.expect(state.phase == .working && requests == 1, "reset confirmation starts exactly one operation while pending")
        finish?(false)
        suite.expect(state.phase == .failed, "a failed reset never claims all permissions were cleared")
        state.begin { completion in requests += 1; finish = completion }
        finish?(true)
        state.begin { _ in requests += 1 }
        suite.expect(state.phase == .restartRequired && requests == 2,
                     "successful reset becomes a restart action and cannot reset again before restart")
        let domain = "io.github.sam32j.lattice.tests.reset-configuration.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(true, forKey: DefaultsKey.keyboardDebounceEnabled)
        defaults.set("saved-keyboard-shortcut", forKey: DefaultsKey.cleaningModeShortcut)
        defaults.set(BrightnessSupport.KeyStep.quarter.rawValue, forKey: DefaultsKey.brightnessKeyStep)
        let reset = PermissionResetState()
        reset.begin { complete in
            let verified = PermissionRevocationPolicy.revalidated([.accessibility: false], verify: { _ in false })
            _ = PermissionRevocationPolicy.apply(verified, in: defaults)
            complete(true)
        }
        suite.expect(reset.phase == .restartRequired && !defaults.bool(forKey: DefaultsKey.keyboardDebounceEnabled)
                     && defaults.string(forKey: DefaultsKey.cleaningModeShortcut) == "saved-keyboard-shortcut"
                     && defaults.string(forKey: DefaultsKey.brightnessKeyStep) == BrightnessSupport.KeyStep.quarter.rawValue,
                     "reset and verified revocation disable restricted activation but retain saved shortcuts and tuning")
        _ = PermissionRevocationPolicy.apply([.accessibility: true], in: defaults)
        suite.expect(BrightnessKeyStepReader(defaults: defaults).keyStep == .standard
                     && defaults.string(forKey: DefaultsKey.brightnessKeyStep) == BrightnessSupport.KeyStep.quarter.rawValue,
                     "restoring permission retains Quarter tuning without rearming finer-step interception")
        let backup = SettingsBackupSupport.payload(appVersion: "test", valueFor: defaults.object(forKey:))
        let restored = SettingsBackupSupport.sanitizedSettings(from: backup) ?? [:]
        let restoredDomain = "io.github.sam32j.lattice.tests.reset-configuration-restored.\(UUID())"
        let restoredDefaults = UserDefaults(suiteName: restoredDomain)!
        defer { restoredDefaults.removePersistentDomain(forName: restoredDomain) }
        restored.forEach { restoredDefaults.set($0.value, forKey: $0.key) }
        suite.expect(restoredDefaults.string(forKey: DefaultsKey.brightnessKeyStep) == "quarter"
                     && BrightnessKeyStepReader(defaults: restoredDefaults).keyStep == .standard,
                     "exporting and restoring paused Quarter tuning never rearms interception")
    }
}
