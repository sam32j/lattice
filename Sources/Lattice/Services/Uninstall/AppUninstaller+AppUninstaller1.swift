// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import CoreServices
import Darwin
import Security

/// Finds the files an app leaves around — caches, preferences, logs, support
/// folders, containers, preference panes, plugins — and removes only what you
/// pick. Ordinary files go to the Trash; after an extra confirmation, a
/// package-managed app is delegated to its package manager before the remaining
/// choices go to the Trash.
extension AppUninstaller {
    var selectedHomebrewPackage: HomebrewPackage? {
        guard items.contains(where: { $0.category == .app && $0.include }) else { return nil }
        return homebrewPackage
    }
    var isRemovingWithHomebrew: Bool {
        guard let package = selectedHomebrewPackage,
              let status = HomebrewManager.shared.operationStatus else { return false }
        return status.action == .uninstall
            && status.package?.id == package.id
            && status.isActive
    }

    var isRemoving: Bool {
        phase == .removing || isRemovingWithHomebrew
    }

    var homebrewRemovalConfirmation: HomebrewRemovalConfirmation? {
        guard phase == .results, !isRemoving,
              let package = selectedHomebrewPackage, let target else { return nil }
        return HomebrewRemovalConfirmation(package: package, targetURL: target.url,
                                           selectedIDs: Set(items.filter(\.include).map(\.id)))
    }

    // MARK: - Selection & scan

    /// Reads an app bundle and starts scanning for its leftovers.
    @discardableResult
    func select(appURL: URL) -> Bool {
        guard AppFeature.uninstaller.isAvailable else { return false }
        guard !isRemoving else { return false }
        let selection: UninstallerSupport.Selection
        switch UninstallerSupport.evaluate(appURL) {
        case let .success(accepted):
            selection = accepted
        case let .failure(reason):
            refusal = UninstallerSupport.RefusedApp(name: UninstallerSupport.appName(at: appURL),
                                                    refusal: reason)
            return false
        }
        refusal = nil
        let bundleID = selection.bundleID
        let selectedURL = selection.url
        let selectedIdentity = selection.identity
        let selectedInfoIdentity = selection.infoIdentity
        let name = UninstallerSupport.appName(at: appURL)
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)

        target = Target(name: name, bundleID: bundleID, url: selectedURL, icon: icon)
        targetFileIdentity = selectedIdentity
        targetInfoIdentity = selectedInfoIdentity
        homebrewPackage = nil
        homebrewRemovalSize = 0
        homebrewRemovedApplication = false
        homebrewRemovalObservation?.cancel()
        homebrewRemovalObservation = nil
        items = []
        allowedRemovalPaths = []
        // A new selection supersedes any scan still running, even for the
        // same app, so only this scan can deliver results.
        scanCancellation?.cancel()
        let cancellation = UninstallerSupport.ScanCancellation()
        scanCancellation = cancellation
        phase = .scanning

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard !cancellation.isCancelled else { return }
            let ownedBundleIDs = Self.allBundleIDs(in: selectedURL, fm: .default)
            let mayClaimSharedData = UninstallerSupport.applicationIsInTrustedInstallRoot(
                selectedURL, home: FileManager.default.homeDirectoryForCurrentUser)
            let knownApplications = mayClaimSharedData
                ? Self.knownApplicationURLs(candidateBundleIDs: ownedBundleIDs)
                : []
            let knownApplicationIDs = Self.applicationBundleIdentifiers(in: knownApplications)
            let exclusiveBundleIDs = mayClaimSharedData
                ? Self.exclusiveOwnedBundleIDs(
                    in: selectedURL, candidates: ownedBundleIDs,
                    knownApplicationIDs: knownApplicationIDs)
                : []
            guard !cancellation.isCancelled else { return }
            let signing = Self.signingIdentity(in: selectedURL, requireValidSignature: true)
            let exclusiveGroupIDs = mayClaimSharedData
                ? Self.exclusiveGroupIDs(
                    signing.groupIDs, selectedURL: selectedURL,
                    knownApplications: knownApplications)
                : []
            let found = Self.collect(appURL: selectedURL,
                                     primaryBundleID: bundleID,
                                     exclusiveBundleIDs: exclusiveBundleIDs,
                                     teamIDs: signing.teamIDs,
                                     exclusiveGroupIDs: exclusiveGroupIDs,
                                     cancellation: cancellation)
            guard !cancellation.isCancelled else { return }
            DispatchQueue.main.async {
                guard let self, !cancellation.isCancelled,
                      self.phase == .scanning, self.target?.url == selectedURL else { return }
                guard UninstallerSupport.applicationIdentityMatches(
                    selectedURL, appIdentity: selectedIdentity,
                    infoIdentity: selectedInfoIdentity) else {
                    self.reset()
                    return
                }
                HomebrewManager.shared.packageManagingApplication(at: selectedURL) { [weak self] package in
                    // Drop the result if the user picked a different app (or reset)
                    // while this scan was running — never show A's files under B.
                    guard let self, !cancellation.isCancelled,
                          self.phase == .scanning, self.target?.url == selectedURL else { return }
                    guard UninstallerSupport.applicationIdentityMatches(
                        selectedURL, appIdentity: selectedIdentity,
                        infoIdentity: selectedInfoIdentity) else {
                        self.reset()
                        return
                    }
                    self.items = found
                    self.homebrewPackage = package
                    self.allowedRemovalPaths = Set(found.map { $0.url.standardizedFileURL.path })
                    self.scanCancellation = nil
                    self.phase = .results
                }
            }
        }
        return true
    }

    func setInclude(_ include: Bool, for id: UUID) {
        guard !isRemoving else { return }
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].include = include
    }

    /// Drops the refusal note, for an uninstaller view that opens or closes.
    func clearRefusal() {
        refusal = nil
    }

    func reset() {
        guard !isRemoving else { return }
        refusal = nil
        scanCancellation?.cancel()
        scanCancellation = nil
        target = nil
        targetFileIdentity = nil
        targetInfoIdentity = nil
        homebrewPackage = nil
        homebrewRemovalSize = 0
        homebrewRemovedApplication = false
        homebrewRemovalObservation?.cancel()
        homebrewRemovalObservation = nil
        items = []
        allowedRemovalPaths = []
        phase = .empty
    }
}
