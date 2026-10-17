// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Production availability mutations with isolated preferences and service bindings.
enum FeatureAvailabilityTransitionTests {
    class State {
        static var bindings: [AppFeature: () -> Void] = [:]
        let defaults: UserDefaults
        var loadedThisSession = Set<AppFeature>()
        var offerableThisSession = Set<AppFeature>()
        init(_ defaults: UserDefaults) { self.defaults = defaults }
        func savedPreferences() -> [String: Any] { [:] }
        func finishAvailabilityChange() {}
    }
    static func run(_ suite: TestSuite) {
        let domain = "vorss.tests.pr3-availability.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain); State.bindings = [:] }
        let service = Runtime(defaults)
        let bundle: [AppFeature] = [.screenshot, .colorPicker, .screenOCR]
        var calls: [AppFeature] = []
        var observed: [Bool] = []
        for feature in bundle {
            State.bindings[feature] = {
                calls.append(feature)
                observed.append(AppFeature.screenshot.isAvailable(in: defaults))
            }
        }
        for feature in AppFeature.allCases { defaults.set(false, forKey: feature.availabilityKey) }
        service.setAvailable([.screenshot], true)
        suite.expect(Set(calls) == Set(bundle) && calls.count == 3 && observed.allSatisfy { $0 },
                     "screenshot install synchronizes all companions after parent availability is committed")
        suite.expect(Set(bundle).isSubset(of: service.loadedThisSession),
                     "bundled first installs update session bookkeeping for each companion")
        calls = []; observed = []
        service.setAvailable([.screenshot], false)
        suite.expect(Set(calls) == Set(bundle) && calls.count == 3 && observed.allSatisfy { !$0 },
                     "screenshot uninstall tears down every companion against the final parent state")
        calls = []; observed = []
        service.setAllAvailable(true)
        suite.expect(Set(calls) == Set(bundle) && observed.allSatisfy { $0 },
                     "bulk install synchronizes companions after screenshot even in catalog order")
        calls = []; observed = []
        service.replaceAvailable(with: [])
        suite.expect(Set(calls) == Set(bundle) && observed.allSatisfy { !$0 },
                     "preset removal tears down hidden companions after the parent changes")
        calls = []; observed = []
        service.replaceAvailable(with: [.screenshot])
        suite.expect(Set(calls) == Set(bundle) && calls.count == 3 && observed.allSatisfy { $0 },
                     "onboarding and presets install bundled companions and bind each exactly once")
        defaults.set(false, forKey: AppFeature.screenshot.availabilityKey)
        defaults.set(true, forKey: AppFeature.screenOCR.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.screenOCRShortcutEnabled)
        let users = AppFeature.activeFeatures(using: .screenRecording, defaults: defaults)
        suite.expect(!users.contains(.screenOCR) && !users.contains(.colorPicker),
                     "permission consumers honor derived companion availability")
        defaults.set(false, forKey: DefaultsKey.orphanedCaptureShortcutMigrated)
        defaults.set(true, forKey: DefaultsKey.screenshotShortcutEnabled)
        defaults.set(false, forKey: DefaultsKey.screenOCRShortcutEnabled)
        defaults.set(false, forKey: DefaultsKey.colorPickerShortcutEnabled)
        defaults.set(GlobalShortcut.screenOCRDefault.storageValue, forKey: DefaultsKey.screenOCRShortcut)
        defaults.set(GlobalShortcut.colorPickerDefault.storageValue, forKey: DefaultsKey.colorPickerShortcut)
        Defaults.migrateOrphanedCaptureShortcut(in: defaults)
        suite.expect(defaults.bool(forKey: DefaultsKey.screenshotShortcutEnabled)
                     && !defaults.bool(forKey: DefaultsKey.screenOCRShortcutEnabled)
                     && !defaults.bool(forKey: DefaultsKey.colorPickerShortcutEnabled),
                     "orphaned shortcut migration never assigns a shortcut to a hidden companion")
    }
}
