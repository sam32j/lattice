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
            self.brewPath = nil
            installed = []
            installedCaskRecords = []
            installedCaskRecordsFetchedAt = nil
            searchResults = []
            selectedPackage = nil
            outdatedGeneration += 1
            outdatedPackagesByID = [:]
            isLoadingOutdated = false
            if clearingError { errorMessage = nil }
            isShellConfigured = true
            shellConfigProfilePath = nil
            didOpenShellConfig = false
            return
        }
        self.brewPath = brewPath
        updateShellConfigStatus(brewPath: brewPath)
        isLoadingInstalled = true
        if clearingError { errorMessage = nil }
        clearUntrustedTap()
        let command = HomebrewCommandBuilder.installed(brewPath: brewPath)
        run(command, cancellation: cancellation) { [weak self] status, output in
            DispatchQueue.main.async {
                guard let self, !cancellation.isCancelled else { return }
                self.isLoadingInstalled = false
                guard status == 0 else {
                    if let tap = HomebrewCommandBuilder.untrustedTapName(fromOutput: output) {
                        self.presentUntrustedTap(tap) { [weak self] in self?.refreshInstalled(owner: owner) }
                    } else {
                        self.errorMessage = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    self.outdatedGeneration += 1
                    self.outdatedPackagesByID = [:]
                    self.isLoadingOutdated = false
                    return
                }
                do {
                    self.installed = try HomebrewParser.parseInfoCommandOutput(output).map(self.packageEnriched)
                    self.searchResults = HomebrewSearchResults.reconciled(self.searchResults,
                                                                         installed: self.installed)
                    self.installedCaskRecords = HomebrewParser.parseInstalledCaskRecords(output)
                    self.installedCaskRecordsFetchedAt = Date()
                    self.didOpenInstaller = false
                    if let selected = self.selectedPackage {
                        self.selectedPackage = self.packageEnriched(self.installed.first { $0.id == selected.id } ?? selected)
                    }
                    self.refreshOutdated(brewPath: brewPath, owner: owner)
                } catch {
                    self.errorMessage = error.localizedDescription
                    self.outdatedGeneration += 1
                    self.outdatedPackagesByID = [:]
                    self.isLoadingOutdated = false
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

    /// Looks up whether Homebrew owns this exact app bundle. The cached
    /// installed catalog is reused when fresh; otherwise one read-only command
    /// answers every concurrent request for the same path.
    func packageManagingApplication(at url: URL,
                                    completion: @escaping (HomebrewPackage?) -> Void) {
        guard let cancellation = readWork.begin(owner: .uninstaller, isAvailable: { $0.isAvailable }) else {
            completion(nil)
            return
        }
        let path = url.standardizedFileURL.path
        if let fetchedAt = installedCaskRecordsFetchedAt,
           Date().timeIntervalSince(fetchedAt) < 60 {
            completion(HomebrewOwnershipSupport.packageManagingApplication(
                atPath: path,
                installed: installedCaskRecords
            ))
            return
        }
        if ownershipLoads[path] != nil {
            ownershipLoads[path]?.append(completion)
            return
        }
        ownershipLoads[path] = [completion]
        guard let brewPath = brewPath ?? detectBrewPath() else {
            finishOwnershipLoad(path: path, package: nil)
            return
        }
        self.brewPath = brewPath
        run(HomebrewCommandBuilder.installed(brewPath: brewPath), cancellation: cancellation) { [weak self] status, output in
            DispatchQueue.main.async {
                guard let self, !cancellation.isCancelled else { return }
                let records = status == 0 ? HomebrewParser.parseInstalledCaskRecords(output) : []
                if status == 0 {
                    self.installedCaskRecords = records
                    self.installedCaskRecordsFetchedAt = Date()
                }
                let package = HomebrewOwnershipSupport.packageManagingApplication(
                    atPath: path,
                    installed: records
                )
                self.finishOwnershipLoad(path: path, package: package)
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

    func cancelOperation() {
        guard operation != nil else { return }
        cancelRequested = true
        if let activeProcess {
            Self.stop(activeProcess)
        }
        appendLog("\nCancelled.\n")
    }

    func clearLog() {
        completedOperationCleanup?.cancel()
        completedOperationCleanup = nil
        log = ""
        terminalFallbackCommand = nil
        if operation == nil {
            operationStatus = nil
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
        if openTerminal(command: HomebrewCommandBuilder.installerCommand) {
            didOpenInstaller = true
        }
    }

    func openShellConfiguration() {
        guard AppFeature.homebrew.isAvailable else { return }
        guard let brewPath = brewPath ?? detectBrewPath() else { return }
        self.brewPath = brewPath
        errorMessage = nil
        let command = HomebrewCommandBuilder.shellConfigCommand(brewPath: brewPath)
        if openTerminal(command: command) {
            didOpenShellConfig = true
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
