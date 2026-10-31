import Foundation

enum FeatureOwnedWorkTests {
    static func run(_ suite: TestSuite) { ownedWork(suite); HomebrewReadLifecycleTests.run(suite) }
}

extension FeatureOwnedWorkTests {
    static func ownedWork(_ suite: TestSuite) {
        let work = FeatureWorkRegistry()
        var available: Set<AppFeature> = [.homebrew, .uninstaller, .appUpdates]
        let browser = work.begin(owner: .homebrew, isAvailable: { available.contains($0) })!
        let removal = work.begin(owner: .uninstaller, isAvailable: { available.contains($0) })!
        let updates = work.begin(owner: .appUpdates, isAvailable: { available.contains($0) })!
        available.remove(.homebrew)
        work.cancelUnavailable(isAvailable: { available.contains($0) })
        suite.expect(browser.isCancelled && !removal.isCancelled && !updates.isCancelled,
                     "disabling Homebrew cancels browsing and preserves the Uninstaller's shared backend work")
        suite.expect(work.begin(owner: .homebrew, isAvailable: { available.contains($0) }) == nil,
                     "a stale read cannot obtain work for a disabled owner")
        available.remove(.appUpdates)
        work.cancelUnavailable(isAvailable: { available.contains($0) })
        suite.expect(updates.isCancelled && !removal.isCancelled,
                     "disabling App Updates cancels its backend reads without stopping Uninstaller")
        available.insert(.homebrew)
        var executions = 0
        let executor: FeatureReadProcess.Executor = { _, child in
            executions += 1
            return .init(status: child.isCancelled ? -1 : 0, output: Data("owner survives".utf8), timedOut: false)
        }
        let stopped = FeatureReadProcess.run("fixture", [], cancellation: browser, executor: executor)
        suite.expect(stopped.status != 0 && stopped.output.isEmpty && executions == 0,
                     "a canceled queued read never reaches the process boundary")
        let kept = FeatureReadProcess.run("fixture", [], cancellation: removal, executor: executor)
        suite.expect(kept.status == 0 && kept.output == "owner survives" && executions == 1,
                     "the enabled owner's executor still runs after another owner is disabled")
        let next = work.begin(owner: .homebrew, isAvailable: { available.contains($0) })!
        suite.expect(next !== browser && !next.isCancelled && browser.isCancelled,
                     "re-enable creates fresh work without accepting an old callback")
    }
}

extension FeatureAvailabilityTransitionTests {
    enum FeatureMutationGuard {
        static var busy: Set<AppFeature> = []
        static func isBusy(_ feature: AppFeature) -> Bool { busy.contains(feature) }
    }
}
