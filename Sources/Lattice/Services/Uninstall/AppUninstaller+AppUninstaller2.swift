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

    // MARK: - Removal

    func removeSelected() {
        guard AppFeature.uninstaller.isAvailable else { return }
        guard phase == .results, !isRemoving else { return }
        let chosen = items.filter(\.include)
        guard !chosen.isEmpty else { return }
        phase = .removing

        // Quit the app and any background app embedded inside it before the
        // bundle moves. Embedded helpers do not always share the main bundle ID.
        if let targetURL = target?.url {
            for app in NSWorkspace.shared.runningApplications where
                app.bundleURL?.resolvingSymlinksInPath().standardizedFileURL == targetURL
                || UninstallerSupport.isNestedBundle(app.bundleURL, in: targetURL) {
                app.terminate()
            }
        }

        let allowedPaths = allowedRemovalPaths
        let targetURL = target?.url
        let targetBundleID = target?.bundleID
        let expectedTargetIdentity = targetFileIdentity
        let expectedInfoIdentity = targetInfoIdentity
        let candidateBundleIDs = Set(chosen.compactMap(\.ownerBundleID))
        let candidateGroupIDs = Set(chosen.compactMap(\.ownerGroupID))
        let evidenceBundleIDs = Set(chosen.compactMap(\.evidenceBundleID))
        let alreadyFreed = homebrewRemovalSize
        let packageRemovedApplication = homebrewRemovedApplication

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.3) { [weak self] in
            let fm = FileManager.default
            var freed = alreadyFreed
            var stubborn: [Leftover] = []
            var failed: [Leftover] = []
            let targetIsOriginal = targetURL.map {
                UninstallerSupport.applicationIdentityMatches(
                    $0, appIdentity: expectedTargetIdentity,
                    infoIdentity: expectedInfoIdentity)
            } ?? false
            let targetWasRemovedByPackageManager = packageRemovedApplication
                && targetURL.map { UninstallerSupport.isConfirmedAbsent(at: $0) } == true
            let mayClaimSharedData = targetIsOriginal || targetWasRemovedByPackageManager
            let lookupBundleIDs = candidateBundleIDs.union(evidenceBundleIDs)
            // Only the shared-data claims below read this roster, and building
            // it opens every installed app. Same gate `select()` already uses.
            let knownApplications = mayClaimSharedData
                ? Self.knownApplicationURLs(candidateBundleIDs: lookupBundleIDs)
                : []
            let knownApplicationIDs = Self.applicationBundleIdentifiers(in: knownApplications)
            let exclusiveBundleIDs = mayClaimSharedData ? targetURL.map {
                Self.exclusiveOwnedBundleIDs(
                    in: $0, candidates: candidateBundleIDs,
                    knownApplicationIDs: knownApplicationIDs,
                    requiresCurrentOwnership: !targetWasRemovedByPackageManager)
            } ?? [] : []
            let exclusiveEvidenceBundleIDs = mayClaimSharedData ? targetURL.map {
                UninstallerSupport.exclusiveBundleIDs(
                    evidenceBundleIDs, selectedURL: $0,
                    knownApplications: knownApplicationIDs)
            } ?? [] : []
            let currentGroupIDs: Set<String>
            if targetIsOriginal, let targetURL {
                currentGroupIDs = Self.signingIdentity(
                    in: targetURL, requireValidSignature: true).groupIDs
                    .intersection(candidateGroupIDs)
            } else if targetWasRemovedByPackageManager {
                currentGroupIDs = candidateGroupIDs
            } else {
                currentGroupIDs = []
            }
            let exclusiveGroupIDs = mayClaimSharedData ? targetURL.map {
                Self.exclusiveGroupIDs(currentGroupIDs, selectedURL: $0,
                                       knownApplications: knownApplications)
            } ?? [] : []
            for item in chosen {
                if item.category != .app {
                    let keepsOwnership: Bool
                    if let groupID = item.ownerGroupID {
                        keepsOwnership = exclusiveGroupIDs.contains(groupID)
                    } else if let bundleID = item.ownerBundleID {
                        let evidenceIsExclusive = item.evidenceBundleID.map(
                            exclusiveEvidenceBundleIDs.contains) ?? true
                        keepsOwnership = exclusiveBundleIDs.contains(bundleID)
                            && evidenceIsExclusive
                    } else {
                        keepsOwnership = false
                    }
                    guard keepsOwnership else {
                        failed.append(item)
                        continue
                    }
                }
                guard Self.removalIsStillSafe(item.url,
                                              expectedIdentity: item.fileIdentity,
                                              allowedPaths: allowedPaths,
                                              targetURL: targetURL) else {
                    // The package manager or another pass may have taken the path.
                    // Only a confirmed absence counts as success; a still-present
                    // path, or one we can no longer read, stays a failure.
                    if UninstallerSupport.isConfirmedAbsent(at: item.url) {
                        freed += item.size
                    } else {
                        failed.append(item)
                    }
                    continue
                }
                do {
                    try fm.trashItem(at: item.url, resultingItemURL: nil)
                    freed += item.size
                } catch {
                    if UninstallerSupport.isConfirmedAbsent(at: item.url) {
                        freed += item.size
                    } else if fm.fileExists(atPath: item.url.path) {
                        stubborn.append(item)
                    } else {
                        failed.append(item)
                    }
                }
            }

            // Items we lack rights for (root-owned apps, /Library files) go
            // through Finder, which shows the administrator prompt and moves
            // them to the Trash exactly like a drag would. One batch, one
            // prompt; afterwards whatever still exists counts as failed.
            if !stubborn.isEmpty {
                let stillSafe = stubborn.filter {
                    Self.removalIsStillSafe($0.url,
                                            expectedIdentity: $0.fileIdentity,
                                            allowedPaths: allowedPaths,
                                            targetURL: targetURL)
                }
                failed.append(contentsOf: stubborn.filter { item in
                    !stillSafe.contains(where: { $0.id == item.id })
                })
                Self.trashViaFinder(stillSafe.map(\.url))
                for item in stillSafe {
                    if UninstallerSupport.isConfirmedAbsent(at: item.url) {
                        freed += item.size
                    } else {
                        failed.append(item)
                    }
                }
            }

            DispatchQueue.main.async {
                // The user may have dismissed the flow while files moved.
                guard let self, self.phase == .removing else { return }
                self.items = []
                self.phase = .done(freed: freed, failed: failed)
                if let targetURL {
                    Self.removeCommandBarState(ofRemovedAppAt: targetURL, bundleID: targetBundleID)
                }
            }
        }
    }

    /// After Homebrew has removed its package receipt and app artifact, clean
    /// only the other items the person selected. The app itself is excluded so
    /// this flow never tries to remove the same bundle twice.
    func removeSelectedWithHomebrew(confirmation: HomebrewRemovalConfirmation) {
        guard AppFeature.uninstaller.isAvailable else { return }
        guard phase == .results, !isRemoving,
              target?.url == confirmation.targetURL,
              selectedHomebrewPackage?.id == confirmation.package.id,
              Set(items.filter(\.include).map(\.id)) == confirmation.selectedIDs else {
            QuickToolHUD.show(icon: "exclamationmark.circle",
                              message: L10n.shared.s.uninstallerConfirmationExpired)
            return
        }
        let package = confirmation.package
        let manager = HomebrewManager.shared
        guard manager.operation == nil else { return }
        manager.clearLog()
        homebrewRemovalObservation?.cancel()
        homebrewRemovalObservation = manager.$operationStatus
            .compactMap { $0 }
            .filter { $0.action == .uninstall && $0.package?.id == package.id }
            .sink { [weak self] status in
                guard status.result != .running else { return }
                self?.homebrewRemovalObservation?.cancel()
                self?.homebrewRemovalObservation = nil
                if status.result == .succeeded {
                    self?.finishRemovalAfterHomebrew(package: package)
                }
            }
        manager.uninstall(package, owner: .uninstaller)
    }

    func finishRemovalAfterHomebrew(package: HomebrewPackage) {
        guard phase == .results,
              homebrewPackage?.id == package.id,
              let app = items.first(where: { $0.category == .app && $0.include }),
              let targetURL = target?.url else { return }
        // Completion is published before the stored status stops reading as
        // active. Clear the package before changing the guarded selection,
        // and credit the app only after its absence is confirmed.
        homebrewRemovedApplication = true
        homebrewPackage = nil
        setInclude(false, for: app.id)
        if UninstallerSupport.isConfirmedAbsent(at: targetURL) {
            homebrewRemovalSize = app.size
        } else if FileManager.default.fileExists(atPath: targetURL.path) {
            // Package removal succeeded but left the bundle. Re-select only the
            // app so removeSelected can finish it under the package flag,
            // counting size once when it is actually gone.
            homebrewRemovalSize = 0
            setInclude(true, for: app.id)
        } else {
            // A failed lookup is not proof of removal. Keep the failure visible.
            homebrewRemovalSize = 0
            homebrewRemovedApplication = false
            setInclude(true, for: app.id)
            phase = .done(freed: 0, failed: [app])
            return
        }
        if items.contains(where: \.include) {
            removeSelected()
        } else {
            phase = .done(freed: homebrewRemovalSize, failed: [])
            Self.removeCommandBarState(ofRemovedAppAt: targetURL, bundleID: target?.bundleID)
        }
    }

    /// A remaining copy keeps the preferences shared under its bundle ID.
    /// Only apps with shared preferences need the folder and Spotlight scan;
    /// path-specific state can go without it, even while the bar is disabled.
    static func removeCommandBarState(ofRemovedAppAt url: URL, bundleID: String?) {
        let bundleIDs: Set<String> = bundleID.map {
            CommandBarService.shared.hasStoredApplicationState(bundleID: $0) ? [$0] : []
        } ?? []
        DispatchQueue.global(qos: .utility).async {
            guard UninstallerSupport.isConfirmedAbsent(at: url) else { return }
            let remaining: Set<String> = bundleIDs.isEmpty ? [] : Set(InstalledApps.installedApplications(
                includeSystemApplications: true,
                spotlightPaths: CommandBarService.spotlightApplicationPaths())
                .compactMap(\.bundleID))
            DispatchQueue.main.async {
                // A reinstall while the scan was pending must keep its state.
                guard UninstallerSupport.isConfirmedAbsent(at: url) else { return }
                CommandBarService.shared.removeApplicationState(
                    bundleIDs: bundleIDs, urls: [url], remainingBundleIDs: remaining)
            }
        }
    }

    /// Asks Finder to trash `urls` in one batch. Finder owns the privilege
    /// elevation (the standard administrator prompt) and the result is a
    /// reversible move to the Trash, never a permanent delete. Waits until the
    /// user answers the prompt; a cancel simply leaves the items in place.
    static func trashViaFinder(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        guard AppleScriptRunner.consentToAutomate(bundleID: "com.apple.finder") else { return }
        // In-process Apple Events (see AppleScriptRunner): the Finder Automation
        // consent is attributed to this app and re-requested if it was lost,
        // instead of a fragile osascript subprocess. Paths are embedded as
        // escaped string literals (no argv).
        let targets = urls
            .map { "set end of targets to POSIX file \(AppleScriptRunner.literal($0.path))" }
            .joined(separator: "\n")
        let source = """
        set targets to {}
        \(targets)
        tell application "Finder" to delete targets
        """
        _ = AppleScriptRunner.run(source)
    }
}
