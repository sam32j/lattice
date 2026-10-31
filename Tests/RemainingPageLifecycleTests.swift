import Foundation

enum RemainingPageLifecycleTests {
    class AwakeState {
        var stoppingSession = false, screenLocked = false
        func syncSessionWithScreenLock() {}
        var isTerminating = false
        var defaultsObserver: Int? = 1
        var preferenceSyncScheduled = true
        var isActive = true
        var clamshellNeedsRestore = true
        var sessionPausedForScreenLock = false
        var starts = 0, stops = 0, pointerStops = 0, assertions = 0
        func stopPreferenceObservation() { defaultsObserver = nil; preferenceSyncScheduled = false }
        func startPreferenceObservation() { starts += 1; defaultsObserver = 1 }
        func stopAutomationMonitoring() { stops += 1 }
        func stopMouseJiggleTimer() { pointerStops += 1 }
        func deactivate(reason: Reason) { isActive = false; clamshellNeedsRestore = false }
        enum Reason { case manual }
        func syncAutomationMonitoring() {}
        func applyAssertions() -> Bool { assertions += 1; return true }
        func syncMouseJiggleTimer() {}
    }
    class UpdatesState {
        var scanGeneration = 3
        var checkCancellation: AppUpdateCheckCancellation? = AppUpdateCheckCancellation()
        var isChecking = true
        var sourceRefreshPending = true
        var automaticCheckPending = true
        var upgradeObserver: Int? = 1
        var pendingUpdateHandoffs: Set<UUID> = [UUID()]
    }
    static func run(_ suite: TestSuite) {
        let domain = "io.github.sam32j.lattice.tests.remaining-lifecycle.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(false, forKey: AppFeature.keepAwake.availabilityKey)
        let awake = Awake()
        awake.syncWithPreferences(defaults)
        suite.expect(awake.starts == 0 && awake.defaultsObserver == nil
                     && !awake.preferenceSyncScheduled && !awake.isActive && !awake.clamshellNeedsRestore
                     && awake.stops == 1 && awake.pointerStops == 1,
                     "disabled Stay Awake releases observers, pointer activity, session and pending override")
        defaults.set(true, forKey: AppFeature.keepAwake.availabilityKey)
        awake.syncWithPreferences(defaults)
        suite.expect(awake.starts == 1 && awake.defaultsObserver != nil,
                     "re-enabling Stay Awake resumes preference observation")
        let updates = Updates()
        let old = updates.checkCancellation!
        var canceled = 0
        let removed = old.register { canceled += 100 }
        old.remove(removed)
        old.register { canceled += 1 }
        updates.cancelChecks()
        updates.cancelChecks()
        old.register { canceled += 1 }
        suite.expect(old.isCancelled && canceled == 2,
                     "cancel cancels owned work once and immediately cancels late registrations")
        suite.expect(!updates.isChecking && updates.checkCancellation == nil
                     && !updates.sourceRefreshPending && !updates.automaticCheckPending
                     && updates.upgradeObserver == nil && updates.pendingUpdateHandoffs.isEmpty
                     && updates.scanGeneration > 3,
                     "disabled App Updates invalidates completion and clears pending schedules and handoffs")
    }
}
