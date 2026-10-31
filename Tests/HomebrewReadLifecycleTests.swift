import Foundation

/// Exercises production service methods with only the command boundary held.
enum HomebrewReadLifecycleTests {
    static var available: Set<AppFeature> = [.homebrew, .appUpdates, .uninstaller]
    static func isAvailable(_ feature: AppFeature) -> Bool { available.contains(feature) }

    class State {
        let readWork = FeatureWorkRegistry()
        var installedRead: (id: UUID, owner: AppFeature)?
        var outdatedRead: (id: UUID, owner: AppFeature)?
        var trustRead: UUID?
        var brewPath: String? = "/fixture/brew"
        var installed: [HomebrewPackage] = [], searchResults: [HomebrewPackage] = []
        var selectedPackage: HomebrewPackage?
        var installedCaskRecords: [HomebrewCaskRecord] = []
        var installedCaskRecordsFetchedAt: Date?
        var outdatedGeneration = 0
        var outdatedPackagesByID: [String: HomebrewPackageUpdate] = [:]
        var isLoadingInstalled = false, isLoadingOutdated = false
        var isSearching = false, isLoadingDetails = false, isLoadingPopularity = false
        var isShellConfigured = true, didOpenShellConfig = false, didOpenInstaller = false
        var shellConfigProfilePath: String?, errorMessage: String?
        var untrustedTap: String?, untrustedTapRetry: (() -> Void)?
        var isTrustingTap = false
        var operation: HomebrewOperation?, operationOwner: AppFeature?
        var completedOperationCleanup: DispatchWorkItem?
        var operationStatus: HomebrewOperationStatus?
        var terminalFallbackCommand: String?, log = ""
        var popularityCache: [HomebrewPackageKind: Int] = [:]
        var popularityLoads: Set<HomebrewPackageKind> = []
        var ownershipLoads: [String: [(HomebrewPackage?) -> Void]] = [:]
        var commands: [(FeatureWorkCancellation, (Int32, String) -> Void)] = []
        func detectBrewPath() -> String? { brewPath }
        func updateShellConfigStatus(brewPath: String) {}
        func packageEnriched(_ package: HomebrewPackage) -> HomebrewPackage { package }
        func applyOutdatedToCurrentPackages() {}
        func run(_ command: HomebrewCommand, cancellation: FeatureWorkCancellation,
                 completion: @escaping (Int32, String) -> Void) {
            commands.append((cancellation, completion))
        }
        func finish(_ index: Int, status: Int32 = 1, output: String = "read failed") {
            commands[index].1(status, output)
            let until = Date().addingTimeInterval(0.02)
            while Date() < until { RunLoop.current.run(until: until) }
        }
    }

    static func run(_ suite: TestSuite) {
        defer { available = [.homebrew, .appUpdates, .uninstaller] }
        available = [.homebrew, .appUpdates, .uninstaller]
        let cancelled = Service()
        cancelled.refreshInstalled(owner: .appUpdates)
        cancelled.refreshOutdated(brewPath: "/fixture/brew", owner: .appUpdates)
        available.remove(.appUpdates)
        cancelled.syncWithFeatures()
        suite.expect(!cancelled.isLoadingInstalled && !cancelled.isLoadingOutdated,
                     "disabling App Updates immediately clears its shared loading indicators")

        available.insert(.appUpdates)
        let newer = Service()
        newer.refreshInstalled(owner: .appUpdates)
        newer.refreshOutdated(brewPath: "/fixture/brew", owner: .appUpdates)
        newer.refreshInstalled(owner: .homebrew)
        newer.refreshOutdated(brewPath: "/fixture/brew", owner: .homebrew)
        available.remove(.appUpdates)
        newer.syncWithFeatures()
        newer.finish(0)
        newer.finish(1)
        suite.expect(newer.isLoadingInstalled && newer.isLoadingOutdated,
                     "cancelled App Updates callbacks preserve newer Homebrew reads")
        newer.finish(2)
        newer.finish(3)
        suite.expect(!newer.isLoadingInstalled && !newer.isLoadingOutdated,
                     "the current reads clear their own indicators when they finish")

        available.insert(.appUpdates)
        let sibling = Service()
        sibling.refreshInstalled(owner: .appUpdates)
        sibling.refreshOutdated(brewPath: "/fixture/brew", owner: .appUpdates)
        available.remove(.homebrew)
        sibling.syncWithFeatures()
        suite.expect(sibling.isLoadingInstalled && sibling.isLoadingOutdated,
                     "disabling Homebrew preserves App Updates loading indicators")

        available.insert(.homebrew)
        let superseded = Service()
        superseded.refreshInstalled()
        superseded.refreshInstalled()
        superseded.finish(0, status: 0, output: "{\"formulae\":[],\"casks\":[]}")
        suite.expect(superseded.isLoadingInstalled && superseded.commands.count == 2,
                     "an older same-owner success cannot end or chain work over a newer installed read")
        superseded.refreshOutdated(brewPath: "/fixture/brew", owner: .appUpdates)
        superseded.finish(1)
        suite.expect(superseded.isLoadingOutdated,
                     "an installed-read failure cannot clear another owner's outdated read")
        let successful = Service()
        successful.refreshInstalled(owner: .appUpdates)
        successful.finish(0, status: 0, output: "{\"formulae\":[],\"casks\":[]}")
        suite.expect(!successful.isLoadingInstalled && successful.isLoadingOutdated
                     && successful.commands.count == 2 && successful.errorMessage == nil,
                     "a successful installed read starts the normal outdated follow-up")
        available.remove(.appUpdates)
        successful.syncWithFeatures()
        suite.expect(!successful.isLoadingOutdated,
                     "the successful follow-up retains the original App Updates owner")
        trustCancellation(suite)
    }

    static func trustCancellation(_ suite: TestSuite) {
        available = [.homebrew, .appUpdates, .uninstaller]
        let service = Service()
        var retries = 0
        service.presentUntrustedTap("vendor/tools") { retries += 100 }
        service.trustTapAndContinue()
        service.trustTapAndContinue()
        suite.expect(service.isTrustingTap && service.commands.count == 1,
                     "repeated trust clicks keep a single command in flight")
        available.remove(.homebrew)
        service.syncWithFeatures()
        suite.expect(!service.isTrustingTap,
                     "disabling Homebrew clears a pending trust indicator immediately")
        available.insert(.homebrew)
        service.presentUntrustedTap("vendor/tools") { retries += 1 }
        service.trustTapAndContinue()
        suite.expect(service.commands.count == 2 && service.isTrustingTap,
                     "re-enabling Homebrew permits another trust attempt before the old reply")
        service.finish(0, status: 0)
        suite.expect(retries == 0 && service.isTrustingTap && service.untrustedTap == "vendor/tools",
                     "a cancelled trust reply cannot retry work or clear a newer trust attempt")
        if service.commands.count == 2 { service.finish(1, status: 0) }
        suite.expect(retries == 1 && !service.isTrustingTap && service.untrustedTap == nil,
                     "the fresh trust reply clears its indicator and retries only its own work")

        let failed = Service()
        failed.presentUntrustedTap("vendor/tools") { retries += 100 }
        failed.trustTapAndContinue()
        failed.finish(0, output: "permission denied")
        suite.expect(!failed.isTrustingTap && failed.errorMessage == "permission denied"
                     && failed.untrustedTap == "vendor/tools" && retries == 1,
                     "a failed trust attempt shows the error and remains retryable")
    }
}
