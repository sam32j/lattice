// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import Darwin
import Foundation

extension HomebrewManager {

    /// Opens the command in the person's own terminal (see
    /// `HomebrewTerminalScript`), with no Automation consent involved;
    /// `opened` runs on the main thread once macOS has handed it over.
    func openTerminal(command: String, owner: AppFeature = .homebrew, opened: (() -> Void)? = nil) {
        guard owner.isAvailable else { return }
        let script: URL
        do {
            script = try HomebrewTerminalScript.write(command: command)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        NSWorkspace.shared.open(script, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let error else {
                    opened?()
                    return
                }
                // Nothing ran the script, so nothing deleted it; a file that is
                // already gone needs no report.
                try? FileManager.default.removeItem(at: script)
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    func perform(_ action: HomebrewOperation.Action,
                         package: HomebrewPackage?,
                         command commandOverride: HomebrewCommand? = nil, owner: AppFeature = .homebrew) {
        if HomebrewSimulator.shared.handlePerform(action, package: package, owner: owner) { return }
        guard owner.isAvailable, operation == nil else { return }
        guard let brewPath = brewPath ?? detectBrewPath() else { return }
        guard let command = commandOverride
                ?? standardCommand(for: action, package: package, brewPath: brewPath) else { return }
        operationOwner = owner
        operation = HomebrewOperation(action: action, package: package)
        operationStatus = HomebrewOperationStatus(action: action,
                                                  package: package,
                                                  phase: initialPhase(for: action),
                                                  result: .running,
                                                  progressFraction: nil,
                                                  startedAt: Date(),
                                                  finishedAt: nil,
                                                  lastActivity: nil)
        terminalFallbackCommand = nil
        errorMessage = nil
        cleanupEstimateRead = nil
        isCheckingCleanup = false
        if action == .cleanup { lastCleanupSummary = nil }
        clearUntrustedTap()
        cancelRequested = false
        completedOperationCleanup?.cancel()
        completedOperationCleanup = nil
        isOperationDetailsExpanded = false
        log = ""
        runStreaming(command,
                     onOutput: { [weak self] chunk in
                         self?.appendLog(chunk)
                         self?.updateOperationStatus(from: chunk, action: action)
                     }) { [weak self] status, output in
            DispatchQueue.main.async {
                guard let self else { return }
                self.activeProcess = nil
                self.operation = nil
                if status == 0 {
                    if action == .cleanup {
                        self.lastCleanupSummary = HomebrewCleanupParser.parse(output)
                        self.cleanupEstimate = HomebrewCleanupSummary(freedSizeText: nil, removedCount: 0)
                        self.cleanupEstimateCheckedAt = Date()
                    } else if action != .updateHomebrew {
                        self.lastCleanupSummary = nil
                        self.cleanupEstimateCheckedAt = nil
                    }
                    self.markOperationComplete(result: .succeeded,
                                               phase: .refreshing,
                                               activity: nil)
                    if action.clearsSelectionOnSuccess {
                        if self.selectedPackage?.id == package?.id {
                            self.clearSelection()
                        }
                    }
                    self.refreshInstalled(owner: owner)
                    if action != .cleanup && action != .updateHomebrew {
                        self.refreshCleanupEstimate(force: true)
                    }
                    if !action.clearsSelectionOnSuccess, let package {
                        self.select(package, owner: owner)
                    }
                } else if self.cancelRequested {
                    self.markOperationComplete(result: .cancelled,
                                               phase: self.operationStatus?.phase ?? .finalizing,
                                               activity: nil)
                    self.refreshInstalled(clearingError: false, owner: owner)
                } else if HomebrewCommandBuilder.needsTerminalFallback(output: output) {
                    self.terminalFallbackCommand = HomebrewCommandBuilder.shellCommand(command)
                    self.markOperationComplete(result: .needsTerminal,
                                               phase: self.operationStatus?.phase ?? .finalizing,
                                               activity: HomebrewProgressParser.visibleError(from: output))
                    // Same partly-done case: `upgrade` moves the formulae, then a
                    // cask asks for a password and brew stops there.
                    self.refreshInstalled(clearingError: false, owner: owner)
                } else if let tap = HomebrewCommandBuilder.untrustedTapName(fromOutput: output) {
                    self.presentUntrustedTap(tap) { [weak self] in self?.perform(action, package: package, owner: owner) }
                    self.markOperationComplete(result: .failed,
                                               phase: self.operationStatus?.phase ?? .finalizing,
                                               activity: nil)
                    // No refresh here: `refreshInstalled` calls `clearUntrustedTap()`,
                    // which would drop the prompt and retry closure just installed.
                } else {
                    let message = HomebrewProgressParser.visibleError(from: output)
                    self.errorMessage = message.isEmpty ? output.trimmingCharacters(in: .whitespacesAndNewlines) : message
                    self.markOperationComplete(result: .failed,
                                               phase: self.operationStatus?.phase ?? .finalizing,
                                               activity: self.errorMessage)
                    // brew reports a run as failed when it could not do all of it,
                    // not only when it did none of it: one disabled package makes
                    // `upgrade` skip that one, upgrade the rest and still exit
                    // non-zero. Re-read regardless, or the panel keeps showing the
                    // versions from before a run that moved most of them.
                    self.refreshInstalled(clearingError: false, owner: owner)
                }
                self.cancelRequested = false
            }
        }
    }

    func finishOwnershipLoad(path: String, result: Result<HomebrewPackage?, HomebrewOwnershipError>) {
        let completions = ownershipLoads.removeValue(forKey: path) ?? []
        completions.forEach { $0(result) }
    }

    func standardCommand(for action: HomebrewOperation.Action,
                                 package: HomebrewPackage?,
                                 brewPath: String) -> HomebrewCommand? {
        switch action {
        case .install, .uninstall, .upgrade:
            guard let package,
                  HomebrewCommandBuilder.isValidToken(package.name) else { return nil }
            switch action {
            case .install: return HomebrewCommandBuilder.install(brewPath: brewPath, package: package)
            case .uninstall: return HomebrewCommandBuilder.uninstall(brewPath: brewPath, package: package)
            default: return HomebrewCommandBuilder.upgrade(brewPath: brewPath, package: package)
            }
        case .upgradeAll:
            return HomebrewCommandBuilder.upgradeAll(brewPath: brewPath)
        case .updateHomebrew:
            return HomebrewCommandBuilder.update(brewPath: brewPath)
        case .cleanup:
            return HomebrewCommandBuilder.cleanup(brewPath: brewPath)
        }
    }

    func updateOperationStatus(from chunk: String, action: HomebrewOperation.Action) {
        guard var status = operationStatus, status.isActive else { return }
        if let phase = HomebrewProgressParser.phase(in: chunk, action: action) {
            status.phase = phase
        }
        if let progress = HomebrewProgressParser.progressFraction(in: chunk) {
            status.progressFraction = progress
        }
        if let activity = HomebrewProgressParser.activity(in: chunk) {
            status.lastActivity = activity
        }
        operationStatus = status
    }

    func initialPhase(for action: HomebrewOperation.Action) -> HomebrewOperationPhase {
        switch action {
        case .install, .upgrade, .upgradeAll, .updateHomebrew:
            return .preparing
        case .uninstall:
            return .uninstalling
        case .cleanup:
            return .cleaning
        }
    }

    func updateShellConfigStatus(brewPath: String) {
        let expectedLine = HomebrewCommandBuilder.shellEnvLine(brewPath: brewPath)
        let primaryPath = HomebrewCommandBuilder.shellProfilePath()
        let paths = HomebrewCommandBuilder.shellProfilePathsToCheck()
        shellConfigProfilePath = primaryPath
        isShellConfigured = paths.contains { path in
            guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else { return false }
            return HomebrewCommandBuilder.setsUpHomebrew(contents, expectedLine: expectedLine)
        }
        if isShellConfigured {
            didOpenShellConfig = false
            return
        }
        // No startup file says so, but a setup can live anywhere a shell
        // sources. The login shell itself answers whether brew is found.
        let shell = HomebrewCommandBuilder.currentShellPath
        workQueue.async { [weak self] in
            let found = Self.loginShellFindsBrew(shell: shell, brewPath: brewPath)
            DispatchQueue.main.async {
                guard let self, found, self.brewPath == brewPath || self.brewPath == nil else { return }
                self.isShellConfigured = true
                self.didOpenShellConfig = false
            }
        }
    }

    /// Runs the person's login shell once, interactively so its rc files are
    /// read too, and asks where `brew` is. Gives up after a few seconds.
    nonisolated static func loginShellFindsBrew(shell: String, brewPath: String) -> Bool {
        guard !shell.isEmpty, FileManager.default.isExecutableFile(atPath: shell) else { return false }
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-l", "-i", "-c", "command -v brew"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        let deadline = DispatchTime.now() + 5
        let done = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in done.signal() }
        if done.wait(timeout: deadline) == .timedOut {
            process.terminate()
            return false
        }
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let resolved = text.split(separator: "\n").last.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        return resolved == brewPath
            || URL(fileURLWithPath: resolved).resolvingSymlinksInPath().path
                == URL(fileURLWithPath: brewPath).resolvingSymlinksInPath().path
    }

    func markOperationComplete(result: HomebrewOperationResult,
                                       phase: HomebrewOperationPhase,
                                       activity: String?) {
        guard var status = operationStatus else { return }
        status.result = result
        status.phase = phase
        status.finishedAt = Date()
        if result == .succeeded {
            status.progressFraction = 1
        }
        if let activity, !activity.isEmpty {
            status.lastActivity = activity
        }
        operationStatus = status
        scheduleCompletedOperationCleanup(result: result,
                                          targetID: status.targetID,
                                          finishedAt: status.finishedAt)
    }

    func loadPopularityIfNeeded(kind: HomebrewPackageKind) {
        guard let cancellation = readWork.begin(owner: .homebrew, isAvailable: { $0.isAvailable }) else { return }
        if popularityCache[kind]?.isFresh == true {
            applyPopularityToCurrentSearch(kind: kind)
            return
        }
        guard !popularityLoads.contains(kind) else { return }
        popularityLoads.insert(kind)
        isLoadingPopularity = true
        let url = HomebrewAnalytics.url(kind: kind)
        let task = analyticsSession.dataTask(with: url) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                guard let self, !cancellation.isCancelled else { return }
                self.popularityLoads.remove(kind)
                self.isLoadingPopularity = !self.popularityLoads.isEmpty
                guard let data,
                      let values = try? HomebrewAnalytics.parse(data, kind: kind) else { return }
                self.popularityCache[kind] = PopularityCacheEntry(values: values, fetchedAt: Date())
                self.applyPopularityToCurrentSearch(kind: kind)
            }
        }
        cancellation.register { [weak task] in task?.cancel() }
        task.resume()
    }

    func applyPopularityToCurrentSearch(kind: HomebrewPackageKind) {
        guard currentSearchKind == kind else { return }
        searchResults = packagesEnriched(searchResults, kind: kind)
        if let selectedPackage, selectedPackage.kind == kind {
            self.selectedPackage = packageEnriched(selectedPackage)
        }
    }

    func packagesApplyingPopularity(_ packages: [HomebrewPackage],
                                            kind: HomebrewPackageKind) -> [HomebrewPackage] {
        guard let cache = popularityCache[kind], cache.isFresh else {
            return packages
        }
        return HomebrewAnalytics.enrichAndSort(packages, popularity: cache.values)
    }

    func packageApplyingPopularity(_ package: HomebrewPackage) -> HomebrewPackage {
        guard let popularity = popularityCache[package.kind]?.values[package.name] else {
            return package
        }
        var copy = package
        copy.popularity = popularity
        return copy
    }

    func refreshOutdated(brewPath: String, owner: AppFeature = .homebrew) {
        guard let cancellation = readWork.begin(owner: owner, isAvailable: { $0.isAvailable }) else { return }
        outdatedGeneration += 1
        let generation = outdatedGeneration
        let request = UUID()
        outdatedRead = (request, owner)
        isLoadingOutdated = true
        let command = HomebrewCommandBuilder.outdated(brewPath: brewPath)
        run(command, cancellation: cancellation) { [weak self] status, output in
            DispatchQueue.main.async {
                guard let self, self.outdatedRead?.id == request, generation == self.outdatedGeneration else { return }
                self.outdatedRead = nil
                self.isLoadingOutdated = false
                guard !cancellation.isCancelled else { return }
                guard status == 0,
                      let updates = try? HomebrewParser.parseOutdatedCommandOutput(output) else {
                    self.outdatedPackagesByID = [:]
                    self.applyOutdatedToCurrentPackages()
                    return
                }
                self.outdatedPackagesByID = updates
                self.applyOutdatedToCurrentPackages()
            }
        }
    }

    func applyOutdatedToCurrentPackages() {
        installed = installed.map(packageApplyingOutdated)
        searchResults = searchResults.map(packageApplyingOutdated)
        if let selectedPackage {
            self.selectedPackage = packageApplyingOutdated(selectedPackage)
        }
    }

    func packagesEnriched(_ packages: [HomebrewPackage],
                                  kind: HomebrewPackageKind) -> [HomebrewPackage] {
        packagesApplyingPopularity(packages, kind: kind).map(packageApplyingOutdated)
    }

    func packageEnriched(_ package: HomebrewPackage) -> HomebrewPackage {
        packageApplyingOutdated(packageApplyingPopularity(package))
    }

    func packageApplyingOutdated(_ package: HomebrewPackage) -> HomebrewPackage {
        var copy = package
        copy.update = outdatedPackagesByID[package.id]
        return copy
    }
}
