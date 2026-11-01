import Foundation

enum NotchVisualizerActivationTests {
    static func run(_ suite: TestSuite) {
        SystemAudioAuthorizationTests.run(suite)
        NotchVisualizerEntryContract.run(suite)
        var replies: [(SystemAudioAccessResult) -> Void] = []
        var work: [FeatureWorkCancellation] = []
        var on = false
        var allowed = true
        let activation = NotchVisualizerActivation(request: { replies.append($0); let token = FeatureWorkCancellation(); work.append(token); return token },
            verify: { _ in FeatureWorkCancellation() }, openSettings: {},
            canEnable: { allowed }, apply: { on = $0 })
        suite.expect(replies.isEmpty && !on, "launch and parent availability do not request system audio")
        activation.setEnabled(true)
        suite.expect(replies.count == 1 && activation.requesting && !on,
                     "explicit visualizer enable requests access immediately while silent and stays off pending access")
        if let reply = replies.last { reply(.denied) }
        suite.expect(!on && !activation.requesting, "denial leaves the visualizer off")
        activation.setEnabled(true)
        if let reply = replies.last { reply(.granted) }
        suite.expect(on && !activation.requesting, "successful explicit audio request enables the visualizer")
        activation.setEnabled(false)
        suite.expect(!on, "explicit disable stops visualizer activation without a new request")
        activation.setEnabled(true)
        let old = replies.last
        let cancelledWork = work.last
        activation.setEnabled(false)
        suite.expect(cancelledWork?.isCancelled == true, "disable cancels queued native work before it can request audio later")
        activation.setEnabled(true)
        old?(.granted)
        suite.expect(!on && activation.requesting, "an old permission reply cannot complete a newer request")
        allowed = false
        if let reply = replies.last { reply(.granted) }
        suite.expect(!on && !activation.requesting, "permission reset or parent disable rejects a late successful reply")
        let requests = replies.count
        allowed = true
        suite.expect(!on && replies.count == requests, "restoring a parent never requests or enables the visualizer")

        var settingsOpened = 0
        var verificationReplies: [(SystemAudioAuthorizationStatus) -> Void] = []
        let recovery = NotchVisualizerActivation(request: { replies.append($0); return FeatureWorkCancellation() },
            verify: { verificationReplies.append($0); return FeatureWorkCancellation() },
            openSettings: { settingsOpened += 1 }, canEnable: { allowed }, apply: { on = $0 })
        recovery.setEnabled(true)
        replies.last?(.denied)
        suite.expect(!on && settingsOpened == 0, "initial denial respects the user's choice without opening Settings")
        recovery.setEnabled(true)
        replies.last?(.needsSettings)
        suite.expect(!on && settingsOpened == 0, "denied retry stays off without automatically opening Settings")
        recovery.returnedToApplication()
        suite.expect(verificationReplies.isEmpty, "returning without clicking Settings cannot activate recovery")
        recovery.openSettingsForRecovery()
        suite.expect(settingsOpened == 1 && !on, "only clicking Open Settings navigates away and arms recovery")
        recovery.returnedToApplication()
        verificationReplies.last?(.granted)
        suite.expect(on, "Settings return enables only after a fresh verified grant")
        recovery.returnedToApplication()
        suite.expect(verificationReplies.count == 1, "Settings recovery consumes its one-shot intent")
        recovery.setEnabled(true)
        replies.last?(.needsSettings)
        recovery.openSettingsForRecovery()
        recovery.returnedToApplication()
        verificationReplies.last?(.denied)
        recovery.returnedToApplication()
        suite.expect(!on && verificationReplies.count == 2, "denied Settings return cannot enable or retry itself")
        recovery.setEnabled(true)
        replies.last?(.needsSettings)
        recovery.openSettingsForRecovery()
        recovery.returnedToApplication()
        recovery.setEnabled(false)
        verificationReplies.last?(.granted)
        suite.expect(!on, "disabling cancels an in-flight Settings return grant")
        recovery.setEnabled(true)
        replies.last?(.unavailable)
        suite.expect(!on && recovery.failed, "unavailable authorization fails closed")

        let domain = "io.github.sam32j.lattice.tests.visualizer-permission.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(true, forKey: DefaultsKey.notchLiveEqualizer)
        defaults.set(true, forKey: AppFeature.notchLiveEqualizer.availabilityKey)
        NotchVisualizerActivation.reconcileAuthorization(.denied, in: defaults)
        suite.expect(!defaults.bool(forKey: DefaultsKey.notchLiveEqualizer), "startup rejects previously stored-on denied authorization")
        NotchVisualizerActivation.reconcileAuthorization(.granted, in: defaults)
        suite.expect(!defaults.bool(forKey: DefaultsKey.notchLiveEqualizer), "passive permission recovery never re-enables the visualizer")
        defaults.set(true, forKey: DefaultsKey.notchLiveEqualizer)
        defaults.set(true, forKey: AppFeature.notchLiveEqualizer.availabilityKey)
        _ = PermissionRevocationPolicy.apply([.screenRecording: false], in: defaults)
        suite.expect(defaults.bool(forKey: DefaultsKey.notchLiveEqualizer),
                     "screen access loss alone does not revoke the distinct system-audio visualizer")
        DeferredPermissionActivation.record(feature: .notchLiveEqualizer, in: defaults)
        NotchVisualizerActivation.disableForPermissionReset(in: defaults)
        suite.expect(!defaults.bool(forKey: DefaultsKey.notchLiveEqualizer)
                     && !defaults.bool(forKey: AppFeature.notchLiveEqualizer.availabilityKey)
                     && DeferredPermissionActivation.pendingFeature(in: defaults) == nil,
                     "permission reset disables both visualizer switches and removes its pending recovery")
        DeferredPermissionActivation.record(feature: .notchLiveEqualizer, in: defaults)
        suite.expect(DeferredPermissionActivation.evaluateRecovery(in: defaults, verify: { _ in true }) == nil,
                     "a Screen Recording grant cannot recover an old system-audio visualizer intent")
        for parents in [(false, true), (true, false)] {
            defaults.set(true, forKey: DefaultsKey.notchLiveEqualizer)
            defaults.set(true, forKey: AppFeature.notchLiveEqualizer.availabilityKey)
            let stopped = NotchVisualizerActivation.reconcileParents(islandEnabled: parents.0,
                musicEnabled: parents.1, in: defaults)
            suite.expect(stopped && !defaults.bool(forKey: DefaultsKey.notchLiveEqualizer),
                         "disabling either parent clears visualizer activation outside Settings")
            _ = NotchVisualizerActivation.reconcileParents(islandEnabled: true, musicEnabled: true, in: defaults)
            suite.expect(!defaults.bool(forKey: DefaultsKey.notchLiveEqualizer),
                         "re-enabling either parent leaves the visualizer off")
        }
    }
}
