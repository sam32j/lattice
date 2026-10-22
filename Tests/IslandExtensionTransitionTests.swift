import Foundation

extension FeatureAvailabilityTransitionTests {
    static func islandExtensionTransitions(_ service: Runtime, defaults: UserDefaults, suite: TestSuite) {
        IslandSettingsFocusTests.run(suite)
        NotchWaveformNormalizationTests.run(suite)
        let owned: [AppFeature] = [.notchTimer, .notchCalendar, .notchNotifications, .notchDownloads, .notchAgents,
            .notchWatch, .notchMascot, .notchGestures, .notchLyrics, .notchQueue,
            .notchLiveEqualizer, .notchAccessories]
        suite.expect(AppFeature.hubFeatures(in: .dynamicIsland).isEmpty,
                     "Dynamic Island and all its extensions are absent from Features")
        defaults.set(true, forKey: AppFeature.notch.availabilityKey)
        for feature in owned {
            defaults.set(false, forKey: feature.availabilityKey)
            var observed: [Bool] = []
            State.bindings = [feature: {
                observed.append(feature.isAvailable(in: defaults)
                    && feature.enabledKeys.allSatisfy { defaults.bool(forKey: $0) })
            }]
            service.setIslandFeature(feature, enabled: true)
            suite.expect(feature.isAvailable(in: defaults) && observed.last == true,
                         "dedicated toggle installs and starts \(feature.rawValue)")
            service.setIslandFeature(feature, enabled: false)
            suite.expect(!feature.isAvailable(in: defaults) && observed.last == false
                         && feature.enabledKeys.allSatisfy { !defaults.bool(forKey: $0) },
                         "dedicated toggle removes and tears down \(feature.rawValue)")
            service.setIslandFeature(feature, enabled: true)
            suite.expect(observed.last == true, "re-enabling reinstalls \(feature.rawValue)")
            // Existing installations can have their enable preference off.
            for key in feature.enabledKeys { defaults.set(false, forKey: key) }
            service.setIslandFeature(feature, enabled: true)
            suite.expect(observed.last == true, "installed extension reconciles its saved toggle")
        }
        parentTransitions(service, defaults: defaults, suite: suite)
        State.bindings = [:]
    }
    private static func parentTransitions(_ service: Runtime, defaults: UserDefaults, suite: TestSuite) {
        defaults.set(false, forKey: AppFeature.notch.availabilityKey)
        defaults.set(false, forKey: DefaultsKey.notchEnabled)
        defaults.set(true, forKey: DefaultsKey.notchInitialExtensionsInstalled)
        // A previous user choice survives switching the parent off and back on.
        defaults.set(true, forKey: AppFeature.notchTimer.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.notchTimerEnabled)
        defaults.set(false, forKey: AppFeature.notchMascot.availabilityKey)
        var running = false
        State.bindings = [.notch: {
            running = AppFeature.notch.isAvailable(in: defaults) && defaults.bool(forKey: DefaultsKey.notchEnabled)
        }]
        service.setIslandFeature(.notch, enabled: true)
        suite.expect(running, "main Island toggle installs and starts from an uninstalled state")
        service.setIslandFeature(.notch, enabled: false)
        suite.expect(!running && !AppFeature.notch.isAvailable(in: defaults)
                     && !defaults.bool(forKey: DefaultsKey.notchEnabled),
                     "main Island toggle uninstalls and reaches runtime teardown")
        suite.expect(AppFeature.notchTimer.isAvailable(in: defaults) && defaults.bool(forKey: DefaultsKey.notchTimerEnabled)
                     && !AppFeature.notchMascot.isAvailable(in: defaults),
                     "removing Island retains selected and unselected child choices")
        service.setIslandFeature(.notch, enabled: true)
        suite.expect(running && AppFeature.notchTimer.isAvailable(in: defaults)
                     && !AppFeature.notchMascot.isAvailable(in: defaults),
                     "re-enabling Island restores selected extensions without installing unselected ones")
        // Bulk Features actions no longer control this page-owned installation.
        service.setAllAvailable(false)
        suite.expect(running && AppFeature.notch.isAvailable(in: defaults),
                     "Features uninstall-all leaves the page-owned Island alone")
    }
}
