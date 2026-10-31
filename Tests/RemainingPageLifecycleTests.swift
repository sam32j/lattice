import Foundation

enum RemainingPageLifecycleTests {
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
