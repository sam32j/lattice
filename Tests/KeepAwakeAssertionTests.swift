import Foundation
import IOKit.pwr_mgt

enum KeepAwakeAssertionTests {
    static func run(_ suite: TestSuite) {
        managerFailures(suite)
        var nextID: IOPMAssertionID = 0
        var live = Set<IOPMAssertionID>()
        var released: [IOPMAssertionID] = []
        var failsDisplay = true
        var failsRelease = false
        let assertions = KeepAwakeAssertions(create: { kind in
            if kind == .display && failsDisplay { return nil }
            nextID += 1; live.insert(nextID); return nextID
        }, release: { id in
            released.append(id)
            if failsRelease { return false }
            live.remove(id); return true
        }, isValid: { live.contains($0) })
        suite.expect(!assertions.acquire(allowDisplaySleep: false) && live.isEmpty,
                     "display assertion failure rolls back the system assertion")
        failsDisplay = false
        suite.expect(assertions.acquire(allowDisplaySleep: false) && live.count == 2,
                     "both assertions must succeed before activation")
        let held = live
        suite.expect(assertions.acquire(allowDisplaySleep: false) && live == held,
                     "repeated activation does not duplicate assertions")
        live.removeAll()
        let releasesBefore = released.count
        suite.expect(assertions.acquire(allowDisplaySleep: false) && live.count == 2 && live != held,
                     "lifecycle reconciliation reacquires assertions lost by the system")
        suite.expect(released.count == releasesBefore + 2,
                     "stale assertion handles are released before replacement")
        failsRelease = true
        suite.expect(!assertions.release() && assertions.hasAssertions,
                     "release failures remain visible and retryable")
        failsRelease = false
        suite.expect(assertions.release() && live.isEmpty && !assertions.hasAssertions,
                     "retrying stop releases the remaining assertions")
    }

    private static func managerFailures(_ suite: TestSuite) {
        typealias C = KeepAwakeLidSleepContract
        let failed = C.reset()
        failed.clamshellPreferred = false
        failed.assertionsSucceed = false
        failed.activate(minutes: 60)
        suite.expect(!failed.isActive && failed.assertionFailed && failed.endDate == nil,
                     "a failed native activation never publishes a running session")
        let quitting = C.reset()
        quitting.activate(minutes: 60)
        C.drain()
        quitting.releasesSucceed = false
        quitting.deactivate(reason: .quit)
        C.drain()
        suite.expect(!quitting.clamshellActive && !C.Sudoers.disabled,
                     "quit still restores persistent lid sleep when an IOKit release fails")
        let paused = C.reset()
        paused.clamshellPreferred = false
        paused.activate(minutes: 60)
        paused.releasesSucceed = false
        paused.screenLocked = true
        C.UserDefaults.standard.set(true, forKey: C.DefaultsKey.keepAwakePauseWhenLocked)
        paused.syncSessionWithScreenLock()
        suite.expect(!paused.sessionPausedForScreenLock && paused.assertionFailed,
                     "a failed native pause never reports the session as paused")
        paused.syncWithPreferences()
        suite.expect(!paused.sessionPausedForScreenLock && paused.assertionFailed,
                     "reconciliation preserves a failed requested pause instead of reacquiring assertions")
        paused.releasesSucceed = true
        paused.syncWithPreferences()
        suite.expect(paused.sessionPausedForScreenLock && !paused.assertionFailed,
                     "reconciliation retries the requested pause and clears the error only on success")
        let stopping = C.reset()
        stopping.clamshellPreferred = false
        stopping.activate(minutes: 60)
        stopping.releasesSucceed = false
        stopping.deactivate(reason: .manual)
        suite.expect(stopping.isActive && stopping.assertionFailed,
                     "a failed stop remains visibly active and reports the failure")
        stopping.releasesSucceed = true
        stopping.deactivate(reason: .manual)
        suite.expect(!stopping.isActive, "retrying stop finishes the session")
    }
}
