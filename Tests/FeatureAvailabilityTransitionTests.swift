// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

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

        defaults.set(false, forKey: DefaultsKey.focusFollowsMouseEnabled)
        defaults.set(false, forKey: DefaultsKey.superKeyEnabled)
        service.setAllAvailable(true)
        suite.expect(!defaults.bool(forKey: DefaultsKey.focusFollowsMouseEnabled)
                     && !defaults.bool(forKey: DefaultsKey.superKeyEnabled),
                     "hub install-all leaves permanent mouse and keyboard controls off")
        defaults.set(true, forKey: DefaultsKey.focusFollowsMouseEnabled)
        defaults.set(true, forKey: DefaultsKey.superKeyEnabled)
        service.setAllAvailable(false)
        suite.expect(defaults.bool(forKey: DefaultsKey.focusFollowsMouseEnabled)
                     && defaults.bool(forKey: DefaultsKey.superKeyEnabled),
                     "hub uninstall-all preserves enabled mouse and keyboard preferences")
        service.replaceAvailable(with: [])
        suite.expect(defaults.bool(forKey: DefaultsKey.focusFollowsMouseEnabled)
                     && defaults.bool(forKey: DefaultsKey.superKeyEnabled),
                     "replacing hub installations does not reset permanent input preferences")
        defaults.set(true, forKey: DefaultsKey.scrollInverterHorizontalEnabled)
        service.setAvailable([.focusFollowsMouse, .scrollInverter], false)
        suite.expect(defaults.bool(forKey: DefaultsKey.focusFollowsMouseEnabled)
                     && defaults.bool(forKey: DefaultsKey.scrollInverterHorizontalEnabled),
                     "direct installation requests cannot reset permanent input controls or secondary preferences")

        var running = false
        State.bindings = [.focusFollowsMouse: {
            running = defaults.bool(forKey: DefaultsKey.focusFollowsMouseEnabled)
        }]
        service.loadedThisSession = []
        defaults.set(true, forKey: DefaultsKey.focusFollowsMouseEnabled)
        service.sync([.focusFollowsMouse])
        suite.expect(running, "an input control enabled after launch starts through runtime sync")
        defaults.set(false, forKey: DefaultsKey.focusFollowsMouseEnabled)
        service.sync([.focusFollowsMouse])
        suite.expect(!running, "turning that input control off always reaches its service teardown")
        service.loadedThisSession = [.focusFollowsMouse]
        suite.expect(!service.needsRestartToUnload,
                     "ordinary input toggle-off does not produce an uninstall restart prompt")
    }
}
