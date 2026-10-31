import Foundation

extension FeatureAvailabilityTransitionTests {
    static func pageActivationTransitions(_ suite: TestSuite) {
        let registration = UserDefaults.standard.volatileDomain(forName: UserDefaults.registrationDomain)
        defer {
            suite.expect(NSDictionary(dictionary: UserDefaults.standard.volatileDomain(
                forName: UserDefaults.registrationDomain)).isEqual(to: registration),
                         "page activation fixtures leave process-wide registered defaults unchanged")
        }
        let domain = "io.github.sam32j.lattice.tests.page-activation.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain); State.bindings = [:] }
        for feature in AppFeature.allCases {
            defaults.set(false, forKey: feature.availabilityKey)
            for key in feature.enabledKeys { defaults.set(false, forKey: key) }
        }
        defaults.set(false, forKey: DefaultsKey.keyboardBrightnessShortcutsEnabled)
        defaults.set(false, forKey: DefaultsKey.bluetoothSleepRestorePending)
        let runtime = Runtime(defaults)
        var events: [AppFeature] = []
        for feature in AppFeature.migratedPageFeatures {
            State.bindings[feature] = { events.append(feature) }
        }
        runtime.syncAtLaunch()
        suite.expect(events.isEmpty, "disabled page owners construct no launch services")
        for feature in AppFeature.migratedPageFeatures {
            events = []
            defaults.set(37, forKey: DefaultsKey.defaultDuration)
            runtime.setPageEnabled(feature, true)
            suite.expect(feature.isAvailable(in: defaults) && events.contains(feature),
                         "\(feature) activates from its page after a disabled launch")
            events = []
            runtime.setPageEnabled(feature, false)
            suite.expect(!feature.isAvailable(in: defaults) && events.contains(feature),
                         "\(feature) deactivation reaches runtime teardown")
            suite.expect(defaults.integer(forKey: DefaultsKey.defaultDuration) == 37,
                         "activation preserves saved utility configuration")
            events = []
            runtime.syncAtLaunch()
            suite.expect(!events.contains(feature), "disabled \(feature) stays dormant at the next launch")
        }
        runtime.setPageEnabled(.cleaner, true)
        FeatureMutationGuard.busy = [.cleaner]
        runtime.setPageEnabled(.cleaner, false)
        suite.expect(AppFeature.cleaner.isAvailable(in: defaults),
                     "a direct disable request cannot interrupt a file mutation")
        FeatureMutationGuard.busy = []
        runtime.setPageEnabled(.cleaner, false)
        suite.expect(!AppFeature.cleaner.isAvailable(in: defaults),
                     "disable succeeds after the file mutation finishes")
        defaults.set(true, forKey: AppFeature.keepAwake.availabilityKey)
        KeepAwakeManager.shared = KeepAwakeLidSleepContract.reset()
        let awake = KeepAwakeManager.shared
        awake.clamshellPreferred = false
        awake.activate(minutes: 60)
        awake.releasesSucceed = false
        runtime.setPageEnabled(.keepAwake, false)
        suite.expect(AppFeature.keepAwake.isAvailable(in: defaults) && awake.isActive,
                     "a failed native stop keeps Stay Awake's page controls available for recovery")
        awake.releasesSucceed = true
        runtime.setPageEnabled(.keepAwake, false)
        suite.expect(!AppFeature.keepAwake.isAvailable(in: defaults) && !awake.isActive,
                     "Stay Awake can be disabled once native shutdown succeeds")
        defaults.set(false, forKey: DefaultsKey.radialMenuEnabled)
        runtime.setPageEnabled(.radialMenu, true)
        suite.expect(defaults.bool(forKey: DefaultsKey.radialMenuEnabled),
                     "the Radial Menu master switch enables its saved behavior")
    }
}

extension FeatureAvailabilityTransitionTests {
    enum KeepAwakeManager { static var shared = KeepAwakeLidSleepContract.Service() }
}
