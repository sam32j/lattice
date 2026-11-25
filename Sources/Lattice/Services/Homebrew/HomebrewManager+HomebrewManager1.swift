// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Darwin
import Foundation

extension HomebrewManager {

    var isBusy: Bool {
        isLoadingInstalled || isSearching || isLoadingDetails || operation != nil
    }

    var outdatedCount: Int {
        outdatedPackagesByID.count
    }

    /// - Parameter clearingError: pass `false` when refreshing straight after a
    ///   failed operation, so the reason that operation gave is still on screen
    ///   while the fresh state loads.
    func refreshInstalled(clearingError: Bool = true, owner: AppFeature = .homebrew) {
        guard let cancellation = readWork.begin(owner: owner, isAvailable: { $0.isAvailable }) else { return }
        guard let brewPath = detectBrewPath() else {
            installedRead = nil
            isLoadingInstalled = false
            self.brewPath = nil
            installed = []
            searchResults = []
            selectedPackage = nil
            clearOutdatedRead(owner: owner)
            if clearingError { errorMessage = nil }
            isShellConfigured = true
            shellConfigProfilePath = nil
            didOpenShellConfig = false
            return
        }
        self.brewPath = brewPath
        updateShellConfigStatus(brewPath: brewPath)
        let request = UUID()
        installedRead = (request, owner)
        isLoadingInstalled = true
        if clearingError { errorMessage = nil }
        clearUntrustedTap()
        let command = HomebrewCommandBuilder.installed(brewPath: brewPath)
        run(command, cancellation: cancellation) { [weak self] status, output in
            DispatchQueue.main.async {
                guard let self, self.installedRead?.id == request else { return }
                self.installedRead = nil
                self.isLoadingInstalled = false
                guard !cancellation.isCancelled else { return }
                guard status == 0 else {
                    if let tap = HomebrewCommandBuilder.untrustedTapName(fromOutput: output) {
                        self.presentUntrustedTap(tap) { [weak self] in self?.refreshInstalled(owner: owner) }
                    } else {
                        self.errorMessage = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    self.clearOutdatedRead(owner: owner)
                    return
                }
                do {
                    self.installed = try HomebrewParser.parseInfoCommandOutput(output).map(self.packageEnriched)
                    self.searchResults = HomebrewSearchResults.reconciled(self.searchResults,
                                                                         installed: self.installed)
                    self.didOpenInstaller = false
                    if let selected = self.selectedPackage {
                        self.selectedPackage = self.packageEnriched(self.installed.first { $0.id == selected.id } ?? selected)
                    }
                    self.refreshOutdated(brewPath: brewPath, owner: owner)
                } catch {
                    self.errorMessage = error.localizedDescription
                    self.clearOutdatedRead(owner: owner)
                }
            }
        }
    }

    func search(query: String, kind: HomebrewPackageKind) {
        guard let cancellation = readWork.begin(owner: .homebrew, isAvailable: { $0.isAvailable }) else { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }
        guard let brewPath = brewPath ?? detectBrewPath() else {
            self.brewPath = nil
            searchResults = []
            return
        }
        self.brewPath = brewPath
        searchGeneration += 1
        let generation = searchGeneration
        currentSearchKind = kind
        isSearching = true
        errorMessage = nil
        let command = HomebrewCommandBuilder.search(brewPath: brewPath, kind: kind, query: trimmed)
        run(command, cancellation: cancellation) { [weak self] status, output in
            DispatchQueue.main.async {
                guard let self, !cancellation.isCancelled, generation == self.searchGeneration else { return }
                self.isSearching = false
                if status == 0 {
                    let packages = HomebrewParser.parseSearchOutput(output,
                                                                    kind: kind,
                                                                    installed: self.installed)
                    self.searchResults = self.packagesEnriched(packages, kind: kind)
                    if !packages.isEmpty {
                        self.loadPopularityIfNeeded(kind: kind)
                    }
                } else if output.localizedCaseInsensitiveContains("No formulae or casks found") {
                    self.searchResults = []
                } else {
                    self.searchResults = []
                    self.errorMessage = output.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
    }

    func select(_ package: HomebrewPackage, owner: AppFeature = .homebrew) {
        guard let cancellation = readWork.begin(owner: owner, isAvailable: { $0.isAvailable }) else { return }
        selectedPackage = package
        guard let brewPath = brewPath ?? detectBrewPath() else { return }
        detailsGeneration += 1
        let generation = detailsGeneration
        isLoadingDetails = true
        errorMessage = nil
        let command = HomebrewCommandBuilder.details(brewPath: brewPath, package: package)
        run(command, cancellation: cancellation) { [weak self] status, output in
            DispatchQueue.main.async {
                guard let self, !cancellation.isCancelled, generation == self.detailsGeneration else { return }
                self.isLoadingDetails = false
                guard status == 0 else {
                    if let tap = HomebrewCommandBuilder.untrustedTapName(fromOutput: output) {
                        self.presentUntrustedTap(tap) { [weak self] in self?.select(package, owner: owner) }
                    } else {
                        self.errorMessage = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    return
                }
                do {
                    if let detail = try HomebrewParser.parseInfoCommandOutput(output).first {
                        self.selectedPackage = self.packageEnriched(detail)
                    }
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func clearSelection() {
        detailsGeneration += 1
        selectedPackage = nil
        isLoadingDetails = false
    }

    func install(_ package: HomebrewPackage) {
        perform(.install, package: package)
    }

    func uninstall(_ package: HomebrewPackage, owner: AppFeature = .homebrew) {
        perform(.uninstall, package: package, owner: owner)
    }

    /// Removal needs a fresh inventory: an app may have just been installed
    /// outside Lattice. Concurrent requests for the same path share one read.
    /// A failed read must never be mistaken for an unmanaged app.
    func packageManagingApplication(at url: URL,
                                    completion: @escaping (Result<HomebrewPackage?, HomebrewOwnershipError>) -> Void) {
        guard let cancellation = readWork.begin(owner: .uninstaller, isAvailable: { $0.isAvailable }) else {
            completion(.failure(.unavailable))
            return
        }
        let path = url.standardizedFileURL.path
        if ownershipLoads[path] != nil {
            ownershipLoads[path]?.append(completion)
            return
        }
        ownershipLoads[path] = [completion]
        guard let brewPath = brewPath ?? detectBrewPath() else {
            finishOwnershipLoad(path: path, result: .success(nil))
            return
        }
        self.brewPath = brewPath
        run(HomebrewCommandBuilder.installed(brewPath: brewPath), cancellation: cancellation) { [weak self] status, output in
            DispatchQueue.main.async {
                guard let self, !cancellation.isCancelled else { return }
                guard status == 0,
                      let records = try? HomebrewParser.parseInstalledCaskRecords(output) else {
                    self.finishOwnershipLoad(path: path, result: .failure(.unavailable))
                    return
                }
                let result = HomebrewOwnershipSupport.packageManagingApplication(
                    atPath: path,
                    installed: records
                )
                self.finishOwnershipLoad(path: path, result: result)
            }
        }
    }

    func upgrade(_ package: HomebrewPackage) {
        perform(.upgrade, package: package)
    }

    func upgradeAll() {
        perform(.upgradeAll, package: nil)
    }

    /// Upgrades exactly the casks asked for, through the same single
    /// operation lane as every other Homebrew action, so the app never runs
    /// two package commands at once. Used by the app update list, where the
    /// person picks which apps to update.
    func upgradeCasks(_ tokens: [String], owner: AppFeature = .appUpdates) {
        guard operation == nil,
              let brewPath = brewPath ?? detectBrewPath(),
              let command = HomebrewCommandBuilder.upgradeCasks(brewPath: brewPath, tokens: tokens) else {
            return
        }
        perform(.upgradeAll, package: nil, command: command, owner: owner)
    }

    func updateHomebrew() {
        perform(.updateHomebrew, package: nil)
    }

    func cleanup(owner: AppFeature = .homebrew) {
        perform(.cleanup, package: nil, owner: owner)
    }

    func refreshCleanupEstimate(force: Bool = false) {
        guard AppFeature.homebrew.isAvailable, operation == nil, !HomebrewSimulator.shared.isSimulating else { return }
        if !force {
            if isCheckingCleanup { return }
            if let checkedAt = cleanupEstimateCheckedAt,
               Date().timeIntervalSince(checkedAt) < 5 * 60 { return }
        }
        guard let brewPath = brewPath ?? detectBrewPath(),
              let cancellation = readWork.begin(owner: .homebrew, isAvailable: { $0.isAvailable }) else {
            cleanupEstimateRead = nil
            isCheckingCleanup = false
            return
        }
        let request = UUID()
        cleanupEstimateRead = request
        isCheckingCleanup = true
        let command = HomebrewCommandBuilder.cleanupDryRun(brewPath: brewPath)
        cleanupEstimateQueue.async { [weak self] in
            let result = FeatureReadProcess.run(command.executable, command.arguments,
                                                timeout: Self.brewReadTimeout,
                                                environment: HomebrewEnvironment.forBrew,
                                                cancellation: cancellation)
            DispatchQueue.main.async {
                guard let self, self.cleanupEstimateRead == request else { return }
                self.cleanupEstimateRead = nil
                self.isCheckingCleanup = false
                guard !HomebrewSimulator.shared.isSimulating else { return }
                guard !cancellation.isCancelled, self.operation == nil, result.status == 0 else { return }
                self.cleanupEstimate = HomebrewCleanupParser.parse(result.output)
                self.cleanupEstimateCheckedAt = Date()
            }
        }
    }

    func cancelOperation() {
        if HomebrewSimulator.shared.handleCancel() { return }
        guard operation != nil else { return }
        cancelRequested = true
        if let activeProcess {
            Self.stop(activeProcess)
        }
        appendLog("\nCancelled.\n")
    }

    func clearLog() {
        if HomebrewSimulator.shared.handleClearLog() { return }
        completedOperationCleanup?.cancel()
        completedOperationCleanup = nil
        isOperationDetailsExpanded = false
        log = ""
        terminalFallbackCommand = nil
        if operation == nil {
            errorMessage = nil
            operationStatus = nil
            lastCleanupSummary = nil
        }
    }

    func openTerminalFallback() {
        let owner = operationOwner ?? .homebrew
        guard owner.isAvailable else { return }
        guard let command = terminalFallbackCommand else { return }
        openTerminal(command: command, owner: owner)
    }

    func openHomebrewInstaller() {
        guard AppFeature.homebrew.isAvailable else { return }
        errorMessage = nil
        openTerminal(command: HomebrewCommandBuilder.installerCommand) { [weak self] in
            self?.didOpenInstaller = true
        }
    }

    func openShellConfiguration() {
        guard AppFeature.homebrew.isAvailable else { return }
        guard let brewPath = brewPath ?? detectBrewPath() else { return }
        self.brewPath = brewPath
        errorMessage = nil
        let command = HomebrewCommandBuilder.shellConfigCommand(brewPath: brewPath)
        openTerminal(command: command) { [weak self] in
            self?.didOpenShellConfig = true
        }
    }

    func refreshShellConfigurationStatus() {
        guard AppFeature.homebrew.isAvailable else { return }
        guard let brewPath = brewPath ?? detectBrewPath() else {
            isShellConfigured = true
            shellConfigProfilePath = nil
            didOpenShellConfig = false
            return
        }
        updateShellConfigStatus(brewPath: brewPath)
    }
}
