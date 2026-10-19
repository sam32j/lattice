// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Production availability mutations with isolated preferences and service bindings.
enum FeatureAvailabilityTransitionTests {
    enum InputEventTap { static var isBlocked = false }
    class State {
        static var bindings: [AppFeature: () -> Void] = [:]
        let defaults: UserDefaults
        var loadedThisSession = Set<AppFeature>()
        var offerableThisSession = Set<AppFeature>()
        var revision = 0
        init(_ defaults: UserDefaults) { self.defaults = defaults }
        func savedPreferences() -> [String: Any] { [:] }
        func finishAvailabilityChange() {}
    }
    struct CommandBarService {
        static let shared = CommandBarService()
        func noteHubChange() {}
    }
    final class Consumer {
        let runtime: Runtime
        init(_ runtime: Runtime) { self.runtime = runtime }
        var dockClickHideEnabled = false
        var dockClickEnabled = false
        func requestAccessibilityIfNeeded(_ enabled: Bool) {}
        func startDirect(_ feature: AppFeature) { State.bindings[feature]?() }
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
        service.setAllAvailable(false)
        suite.expect(Set(calls) == Set(bundle) && observed.allSatisfy { !$0 },
                     "bulk removal tears down hidden companions after the parent changes")
        calls = []; observed = []
        service.setAvailable([.screenshot], true)
        suite.expect(Set(calls) == Set(bundle) && calls.count == 3 && observed.allSatisfy { $0 },
                     "direct installs synchronize bundled companions and bind each exactly once")
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
        service.setAllAvailable(false)
        suite.expect(defaults.bool(forKey: DefaultsKey.focusFollowsMouseEnabled)
                     && defaults.bool(forKey: DefaultsKey.superKeyEnabled),
                     "bulk-changing hub installations does not reset permanent input preferences")
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
        let priorRevision = service.revision
        service.sync([.focusFollowsMouse])
        suite.expect(running, "an input control enabled after launch starts through runtime sync")
        suite.expect(service.revision > priorRevision,
                     "runtime control changes invalidate Settings and Command Bar availability views")
        defaults.set(false, forKey: DefaultsKey.focusFollowsMouseEnabled)
        service.sync([.focusFollowsMouse])
        suite.expect(!running, "turning that input control off always reaches its service teardown")
        service.loadedThisSession = [.focusFollowsMouse]
        suite.expect(!service.needsRestartToUnload,
                     "ordinary input toggle-off does not produce an uninstall restart prompt")

        defaults.set(false, forKey: AppFeature.dockClick.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.dockClickMinimize)
        suite.expect(AppFeature.dockClick.isAvailable(in: defaults),
                     "Dock click behavior follows its own toggle rather than a retired installation gate")
        service.setAllAvailable(false)
        suite.expect(AppFeature.dockClick.isAvailable(in: defaults),
                     "bulk uninstall does not disable Dock-owned behavior")
        defaults.set(true, forKey: AppFeature.pastePlain.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.pastePlainEnabled)
        suite.expect(!AppFeature.pastePlain.isAvailable(in: defaults),
                     "plain paste cannot run when its Clipboard History owner is uninstalled")
        defaults.set(true, forKey: AppFeature.clipboardHistory.availabilityKey)
        suite.expect(AppFeature.pastePlain.isAvailable(in: defaults),
                     "plain paste retains its own toggle under Clipboard History")
        var plainPasteRunning = true
        State.bindings = [.pastePlain: { plainPasteRunning = AppFeature.pastePlain.isAvailable(in: defaults) }]
        service.loadedThisSession.insert(.pastePlain)
        service.setAvailable([.clipboardHistory], false)
        suite.expect(!plainPasteRunning,
                     "uninstalling Clipboard History also tears down its active plain-paste shortcut")
        defaults.set(true, forKey: DefaultsKey.extraBrightnessEnabled)
        suite.expect(!AppFeature.extraBrightness.isAvailable(in: defaults, hardwareSupported: false),
                     "an enabled XDR preference cannot run on an unsupported display")
        suite.expect(!AppFeature.fanControl.isPresentInControls(in: defaults, hardwareSupported: false),
                     "fanless machines do not expose a fan control")
        defaults.set(false, forKey: DefaultsKey.extraBrightnessEnabled)
        suite.expect(AppFeature.extraBrightness.isPresentInControls(in: defaults, hardwareSupported: true),
                     "supported XDR controls remain discoverable while off")
        defer { FeatureHardwareBoundary.unsupported = [] }
        var overlayTransitions: [Bool] = []
        State.bindings = [.extraBrightness: {
            overlayTransitions.append(AppFeature.extraBrightness.isAvailable(in: defaults))
        }]
        service.loadedThisSession = []
        defaults.set(true, forKey: DefaultsKey.extraBrightnessEnabled)
        FeatureHardwareBoundary.unsupported = [.extraBrightness]
        service.syncAtLaunch()
        suite.expect(overlayTransitions.isEmpty,
                     "unsupported XDR never constructs its service at launch even with a saved on preference")
        FeatureHardwareBoundary.unsupported = []
        service.hardwareDidChange()
        FeatureHardwareBoundary.unsupported = [.extraBrightness]
        service.hardwareDidChange()
        suite.expect(overlayTransitions == [true, false]
                     && defaults.bool(forKey: DefaultsKey.extraBrightnessEnabled),
                     "capability arrival starts saved XDR and its loss tears down without erasing the preference")

        let panel = Consumer(service)
        defaults.set(false, forKey: DefaultsKey.extraBrightnessEnabled)
        FeatureHardwareBoundary.unsupported = []
        suite.expect(panel.offersXDR, "the panel keeps supported XDR editable while switched off")
        FeatureHardwareBoundary.unsupported = [.extraBrightness]
        suite.expect(!panel.offersXDR, "the panel hides unsupported XDR without constructing the overlay")
        FeatureHardwareBoundary.unsupported = []
        for (feature, key, enable) in [
            (AppFeature.autoQuit, DefaultsKey.autoQuitEnabled, panel.autoQuitEnabled),
            (.windowMaximizer, DefaultsKey.windowMaximizeEnabled, panel.windowMaximizeEnabled),
            (.dockClick, DefaultsKey.dockClickMinimize, panel.dockClickEnabled),
            (.dockClick, DefaultsKey.dockClickHide, panel.dockClickHideEnabled),
            (.dockClick, DefaultsKey.dockClickCycleWindows, panel.dockClickCycleEnabled),
            (.spacesOrder, DefaultsKey.spacesOrderEnabled, panel.spacesOrderEnabled),
        ] {
            feature.enabledKeys.forEach { defaults.set(false, forKey: $0) }
            service.loadedThisSession = []
            var active = false
            State.bindings = [feature: { active = feature.isAvailable(in: defaults) }]
            defaults.set(true, forKey: key)
            enable(true)
            suite.expect(active, "Quick Controls starts \(feature.rawValue) from its off-at-launch state")
            defaults.set(false, forKey: key)
            service.sync([feature])
            suite.expect(!active, "Settings stops \(feature.rawValue) after Quick Controls enabled it")
        }
    }
}
