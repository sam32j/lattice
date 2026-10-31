import AppKit
import Combine
import CoreServices

extension AppUpdatesService {
    // MARK: - Package manager source

    struct PackageResult {
        let items: [AppUpdatesSupport.Item]
        let coveredPaths: Set<String>
        let available: Bool
        let onlineCoverageAvailable: Bool
    }

    func packageManagerFindings(apps: [AppUpdatesSupport.InstalledApp],
                                        includeUpdates: Bool, cancellation: AppUpdateCheckCancellation? = nil) -> PackageResult {
        guard let brewPath = HomebrewCommandBuilder.candidatePaths.first(where: {
            FileManager.default.isExecutableFile(atPath: $0)
        }) else {
            return PackageResult(items: [], coveredPaths: [], available: !includeUpdates,
                                 onlineCoverageAvailable: true)
        }
        let installedOutput = Self.runCommand(HomebrewCommandBuilder.installed(brewPath: brewPath),
                                              environment: HomebrewEnvironment.forBrew, cancellation: cancellation)
        let records = installedOutput.status == 0
            ? HomebrewParser.parseInstalledCaskRecords(installedOutput.output)
            : []
        let coveredPaths = Set(records.compactMap {
            AppUpdatesSupport.packageBundle(for: $0, apps: apps)?.path
        })
        guard includeUpdates else {
            return PackageResult(items: [], coveredPaths: coveredPaths, available: true,
                                 onlineCoverageAvailable: installedOutput.status == 0)
        }
        guard cancellation?.isCancelled != true else {
            return PackageResult(items: [], coveredPaths: [], available: false, onlineCoverageAvailable: false)
        }
        let outdatedOutput = Self.runCommand(
            HomebrewCommandBuilder.outdatedCasksIncludingSelfUpdating(brewPath: brewPath),
            environment: HomebrewEnvironment.forBrew, cancellation: cancellation)
        guard installedOutput.status == 0, outdatedOutput.status == 0 else {
            let failure = [outdatedOutput, installedOutput].first { $0.status != 0 }
            let message = failure.map { HomebrewProgressParser.visibleError(from: $0.output) } ?? ""
            DispatchQueue.main.async { [weak self] in
                guard cancellation?.isCancelled != true else { return }
                self?.lastError = message.isEmpty ? nil : message
            }
            return PackageResult(items: [], coveredPaths: coveredPaths, available: true,
                                 onlineCoverageAvailable: installedOutput.status == 0)
        }
        let updates = (try? HomebrewParser.parseOutdatedCommandOutput(outdatedOutput.output)) ?? [:]
        let items = AppUpdatesSupport.packageUpdates(
            outdated: Array(updates.values),
            installed: records,
            ignoredTokens: Self.ownPackageTokens,
            apps: apps.filter { !$0.version.isEmpty })
        return PackageResult(items: items, coveredPaths: coveredPaths, available: true,
                             onlineCoverageAvailable: true)
    }

}
