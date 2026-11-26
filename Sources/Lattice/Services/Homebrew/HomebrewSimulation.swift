// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Developer simulator for Homebrew states so Dynamic Island, Floating Hub,
/// and Settings layouts can be exercised across outdated casks/formulae,
/// empty categories, cache cleanup, active progress, and error/cancelled states
/// without touching the live Homebrew installation.
final class HomebrewSimulator: ObservableObject {
    static let shared = HomebrewSimulator()

    enum Scenario: String, CaseIterable, Identifiable {
        case outdatedMixed
        case outdatedCasksOnly
        case outdatedFormulaeOnly
        case upToDateCache
        case upToDateClean
        case runningUpdate
        case runningCleanup
        case cancelled
        case failed

        var id: String { rawValue }

        var title: String {
            switch self {
            case .outdatedMixed: return "Updates (Casks + Formulae)"
            case .outdatedCasksOnly: return "Updates (Casks Only)"
            case .outdatedFormulaeOnly: return "Updates (Formulae Only)"
            case .upToDateCache: return "Up to Date (148.5 MB Cache)"
            case .upToDateClean: return "Up to Date (Already Clean)"
            case .runningUpdate: return "Running: Updating Packages (45%)"
            case .runningCleanup: return "Running: Cleaning Cache"
            case .cancelled: return "Cancelled (Red Octagon)"
            case .failed: return "Failed (Sample Error)"
            }
        }
    }

    @Published private(set) var activeScenario: Scenario?

    var isSimulating: Bool { activeScenario != nil }

    private var simulatedWork: DispatchWorkItem?

    func apply(_ scenario: Scenario) {
        let manager = HomebrewManager.shared
        // Never interrupt a real in-flight Homebrew operation from the simulator.
        guard isSimulating || manager.operation == nil else { return }
        simulatedWork?.cancel()
        simulatedWork = nil
        activeScenario = scenario

        manager.completedOperationCleanup?.cancel()
        manager.completedOperationCleanup = nil
        manager.activeProcess?.terminate()
        manager.activeProcess = nil
        manager.cancelRequested = false
        manager.operation = nil
        manager.installedRead = nil
        manager.clearOutdatedRead(owner: .homebrew)
        manager.cleanupEstimateRead = nil
        manager.brewPath = manager.detectBrewPath() ?? "/opt/homebrew/bin/brew"
        manager.isLoadingInstalled = false
        manager.isLoadingOutdated = false
        manager.isCheckingCleanup = false
        manager.isShellConfigured = true
        manager.untrustedTap = nil
        manager.terminalFallbackCommand = nil
        manager.errorMessage = nil
        manager.lastCleanupSummary = nil
        manager.isOperationDetailsExpanded = false
        manager.log = ""
        manager.operationOwner = .homebrew

        switch scenario {
        case .outdatedMixed:
            let packages = Self.mixedOutdatedPackages()
            applyPackages(packages,
                          cache: HomebrewCleanupSummary(freedSizeText: "148.5 MB", removedCount: 5),
                          latestBrew: "4.4.14")
            manager.operationStatus = nil

        case .outdatedCasksOnly:
            applyPackages(Self.caskOnlyOutdatedPackages(),
                          cache: HomebrewCleanupSummary(freedSizeText: "96.2 MB", removedCount: 3),
                          latestBrew: nil)
            manager.operationStatus = nil

        case .outdatedFormulaeOnly:
            applyPackages(Self.formulaOnlyOutdatedPackages(),
                          cache: HomebrewCleanupSummary(freedSizeText: "64.0 MB", removedCount: 2),
                          latestBrew: nil)
            manager.operationStatus = nil

        case .upToDateCache:
            applyPackages(Self.upToDatePackages(),
                          cache: HomebrewCleanupSummary(freedSizeText: "148.5 MB", removedCount: 5),
                          latestBrew: "4.4.14")
            manager.operationStatus = nil

        case .upToDateClean:
            applyPackages(Self.upToDatePackages(),
                          cache: HomebrewCleanupSummary(freedSizeText: nil, removedCount: 0),
                          latestBrew: nil)
            manager.operationStatus = nil

        case .runningUpdate:
            let packages = Self.mixedOutdatedPackages()
            applyPackages(packages,
                          cache: HomebrewCleanupSummary(freedSizeText: "148.5 MB", removedCount: 5),
                          latestBrew: nil)
            manager.operation = HomebrewOperation(action: .upgradeAll, package: nil)
            manager.operationStatus = HomebrewOperationStatus(
                action: .upgradeAll,
                package: nil,
                phase: .upgrading,
                result: .running,
                progressFraction: 0.45,
                startedAt: Date().addingTimeInterval(-12),
                finishedAt: nil,
                lastActivity: "Updating raycast (1.83.2 → 1.84.0)…"
            )
            manager.log = "$ brew upgrade\n==> Updating 5 outdated packages...\n==> Downloading raycast 1.84.0\n"

        case .runningCleanup:
            applyPackages(Self.upToDatePackages(),
                          cache: HomebrewCleanupSummary(freedSizeText: "148.5 MB", removedCount: 5),
                          latestBrew: nil)
            manager.operation = HomebrewOperation(action: .cleanup, package: nil)
            manager.operationStatus = HomebrewOperationStatus(
                action: .cleanup,
                package: nil,
                phase: .cleaning,
                result: .running,
                progressFraction: nil,
                startedAt: Date().addingTimeInterval(-6),
                finishedAt: nil,
                lastActivity: "Removing stale downloads in ~/Library/Caches/Homebrew…"
            )
            manager.log = "$ brew cleanup --prune=all -s\nRemoving: ~/Library/Caches/Homebrew/downloads/raycast.dmg\n"

        case .cancelled:
            let packages = Self.mixedOutdatedPackages()
            applyPackages(packages,
                          cache: HomebrewCleanupSummary(freedSizeText: "148.5 MB", removedCount: 5),
                          latestBrew: nil)
            manager.operationStatus = HomebrewOperationStatus(
                action: .upgradeAll,
                package: nil,
                phase: .upgrading,
                result: .cancelled,
                progressFraction: 0.3,
                startedAt: Date().addingTimeInterval(-9),
                finishedAt: Date(),
                lastActivity: "Cancelled."
            )
            manager.log = "$ brew upgrade\n==> Downloading raycast\nCancelled.\n"

        case .failed:
            let packages = Self.mixedOutdatedPackages()
            applyPackages(packages,
                          cache: HomebrewCleanupSummary(freedSizeText: "148.5 MB", removedCount: 5),
                          latestBrew: nil)
            let err = "Error: raycast: Download failed: curl error 7."
            manager.errorMessage = err
            manager.operationStatus = HomebrewOperationStatus(
                action: .upgradeAll,
                package: nil,
                phase: .downloading,
                result: .failed,
                progressFraction: 0.25,
                startedAt: Date().addingTimeInterval(-5),
                finishedAt: Date(),
                lastActivity: err
            )
            manager.log = "$ brew upgrade\n\(err)\n"
        }
    }

    func refreshCurrent() {
        guard let scenario = activeScenario else { return }
        apply(scenario)
    }

    func reset() {
        simulatedWork?.cancel()
        simulatedWork = nil
        guard activeScenario != nil else { return }
        activeScenario = nil

        let manager = HomebrewManager.shared
        manager.operation = nil
        manager.operationStatus = nil
        manager.errorMessage = nil
        manager.lastCleanupSummary = nil
        manager.cleanupEstimate = nil
        manager.cleanupEstimateCheckedAt = nil
        manager.isOperationDetailsExpanded = false
        manager.log = ""
        manager.brewPath = manager.detectBrewPath()
        manager.installed = []
        manager.outdatedPackagesByID = [:]
        onMainActor {
            HomebrewOnlineCatalog.shared.clearSimulatedVersion()
        }
        manager.refreshInstalled()
        onMainActor {
            HomebrewOnlineCatalog.shared.checkVersion(force: true)
        }
        manager.refreshCleanupEstimate(force: true)
    }

    func handlePerform(_ action: HomebrewOperation.Action, package: HomebrewPackage?, owner: AppFeature) -> Bool {
        guard isSimulating else { return false }
        let manager = HomebrewManager.shared
        guard owner.isAvailable, manager.operation == nil else { return true }

        simulatedWork?.cancel()
        manager.completedOperationCleanup?.cancel()
        manager.completedOperationCleanup = nil
        manager.operationOwner = owner
        manager.operation = HomebrewOperation(action: action, package: package)
        manager.errorMessage = nil
        manager.terminalFallbackCommand = nil
        manager.lastCleanupSummary = nil
        manager.isOperationDetailsExpanded = false
        manager.operationStatus = HomebrewOperationStatus(
            action: action,
            package: package,
            phase: manager.initialPhase(for: action),
            result: .running,
            progressFraction: 0.35,
            startedAt: Date(),
            finishedAt: nil,
            lastActivity: simulatedActivity(for: action, package: package)
        )
        manager.log = "$ simulated \(action)\n"

        let work = DispatchWorkItem { [weak self] in
            self?.finishSimulatedOperation(action: action, package: package)
        }
        simulatedWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85, execute: work)
        return true
    }

    func handleCancel() -> Bool {
        guard isSimulating else { return false }
        let manager = HomebrewManager.shared
        guard let active = manager.operation else { return true }
        simulatedWork?.cancel()
        simulatedWork = nil
        manager.operation = nil
        let status = HomebrewOperationStatus(
            action: active.action,
            package: active.package,
            phase: manager.operationStatus?.phase ?? .finalizing,
            result: .cancelled,
            progressFraction: manager.operationStatus?.progressFraction,
            startedAt: manager.operationStatus?.startedAt ?? Date(),
            finishedAt: Date(),
            lastActivity: "Cancelled."
        )
        manager.operationStatus = status
        manager.appendLog("\nCancelled.\n")
        manager.scheduleCompletedOperationCleanup(result: status.result,
                                                  targetID: status.targetID,
                                                  finishedAt: status.finishedAt)
        return true
    }

    func handleClearLog() -> Bool {
        guard isSimulating else { return false }
        let manager = HomebrewManager.shared
        manager.completedOperationCleanup?.cancel()
        manager.completedOperationCleanup = nil
        manager.isOperationDetailsExpanded = false
        manager.log = ""
        manager.errorMessage = nil
        manager.terminalFallbackCommand = nil
        if manager.operation == nil {
            manager.operationStatus = nil
            manager.lastCleanupSummary = nil
        }
        return true
    }

    private func finishSimulatedOperation(action: HomebrewOperation.Action, package: HomebrewPackage?) {
        guard isSimulating else { return }
        let manager = HomebrewManager.shared
        manager.operation = nil

        switch action {
        case .install:
            if let package {
                let installed = HomebrewPackage(
                    kind: package.kind,
                    name: package.name,
                    displayName: package.displayName,
                    desc: package.desc,
                    installedVersion: package.stableVersion ?? "1.0.0",
                    stableVersion: package.stableVersion ?? "1.0.0",
                    homepage: package.homepage,
                    requires: package.requires
                )
                if !manager.installed.contains(where: { $0.id == installed.id }) {
                    manager.installed.append(installed)
                }
            }
        case .uninstall:
            if let package {
                manager.installed.removeAll { $0.id == package.id }
                manager.outdatedPackagesByID.removeValue(forKey: package.id)
            }
        case .upgrade:
            if let package {
                manager.outdatedPackagesByID.removeValue(forKey: package.id)
                if let index = manager.installed.firstIndex(where: { $0.id == package.id }),
                   let target = package.update?.currentVersion ?? package.stableVersion {
                    let old = manager.installed[index]
                    manager.installed[index] = HomebrewPackage(
                        kind: old.kind,
                        name: old.name,
                        displayName: old.displayName,
                        desc: old.desc,
                        installedVersion: target,
                        stableVersion: target,
                        homepage: old.homepage,
                        requires: old.requires
                    )
                }
            }
        case .upgradeAll:
            manager.outdatedPackagesByID = [:]
            manager.installed = manager.installed.map { pkg in
                guard let target = pkg.update?.currentVersion else { return pkg }
                return HomebrewPackage(
                    kind: pkg.kind,
                    name: pkg.name,
                    displayName: pkg.displayName,
                    desc: pkg.desc,
                    installedVersion: target,
                    stableVersion: target,
                    homepage: pkg.homepage,
                    requires: pkg.requires
                )
            }
        case .cleanup:
            let freed = manager.cleanupEstimate ?? HomebrewCleanupSummary(freedSizeText: nil, removedCount: 0)
            manager.lastCleanupSummary = freed
            manager.cleanupEstimate = HomebrewCleanupSummary(freedSizeText: nil, removedCount: 0)
        case .updateHomebrew:
            onMainActor {
                HomebrewOnlineCatalog.shared.setSimulatedVersion(installed: "4.4.14", latest: "4.4.14")
            }
        }

        let status = HomebrewOperationStatus(
            action: action,
            package: package,
            phase: .finalizing,
            result: .succeeded,
            progressFraction: 1,
            startedAt: manager.operationStatus?.startedAt ?? Date(),
            finishedAt: Date(),
            lastActivity: "Completed (simulated)."
        )
        manager.operationStatus = status
        manager.scheduleCompletedOperationCleanup(result: status.result,
                                                  targetID: status.targetID,
                                                  finishedAt: status.finishedAt)
    }

    private func simulatedActivity(for action: HomebrewOperation.Action, package: HomebrewPackage?) -> String {
        switch action {
        case .install: return "Installing \(package?.displayName ?? "package")…"
        case .uninstall: return "Uninstalling \(package?.displayName ?? "package")…"
        case .upgrade: return "Updating \(package?.displayName ?? "package")…"
        case .upgradeAll: return "Updating outdated packages…"
        case .updateHomebrew: return "Updating Homebrew metadata…"
        case .cleanup: return "Removing cached downloads and old versions…"
        }
    }

    private func applyPackages(_ packages: [HomebrewPackage],
                               cache: HomebrewCleanupSummary,
                               latestBrew: String?) {
        let manager = HomebrewManager.shared
        var updates: [String: HomebrewPackageUpdate] = [:]
        for package in packages {
            if let update = package.update {
                updates[package.id] = update
            }
        }
        manager.outdatedPackagesByID = updates
        manager.installed = HomebrewPackageOrdering.updatesFirst(packages)
        manager.cleanupEstimate = cache
        onMainActor {
            HomebrewOnlineCatalog.shared.setSimulatedVersion(installed: "4.4.12", latest: latestBrew ?? "4.4.12")
        }
    }

    private func onMainActor(_ work: @MainActor @escaping () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated(work)
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    // MARK: Sample Packages

    private static func makePackage(kind: HomebrewPackageKind, name: String, displayName: String? = nil,
                                    desc: String, current: String, updateTo: String? = nil,
                                    homepage: String, requires: [String] = [],
                                    installedOnRequest: Bool? = nil) -> HomebrewPackage {
        let update = updateTo.map {
            HomebrewPackageUpdate(kind: kind, name: name, installedVersions: [current], currentVersion: $0, isPinned: false)
        }
        return HomebrewPackage(kind: kind, name: name, displayName: displayName ?? name,
                               desc: desc, installedVersion: current,
                               stableVersion: updateTo ?? current,
                               homepage: homepage, update: update,
                               installedOnRequest: installedOnRequest, requires: requires)
    }

    private static func mixedOutdatedPackages() -> [HomebrewPackage] {
        [
            makePackage(kind: .cask, name: "raycast", displayName: "Raycast",
                        desc: "Control your tools with a few keystrokes", current: "1.83.2", updateTo: "1.84.0",
                        homepage: "https://raycast.com"),
            makePackage(kind: .cask, name: "tableplus", displayName: "TablePlus",
                        desc: "Native GUI database client for macOS", current: "5.9.0", updateTo: "6.1.0",
                        homepage: "https://tableplus.com"),
            makePackage(kind: .cask, name: "visual-studio-code", displayName: "Visual Studio Code",
                        desc: "Open-source code editor", current: "1.95.0",
                        homepage: "https://code.visualstudio.com"),
            makePackage(kind: .formula, name: "neovim",
                        desc: "Ambitious Vim-fork focused on extensibility and agility",
                        current: "0.10.2", updateTo: "0.10.4", homepage: "https://neovim.io",
                        requires: ["libuv"], installedOnRequest: true),
            makePackage(kind: .formula, name: "ripgrep",
                        desc: "Search tool like grep and The Silver Searcher",
                        current: "14.1.0", updateTo: "14.1.1", homepage: "https://github.com/BurntSushi/ripgrep",
                        installedOnRequest: true),
            makePackage(kind: .formula, name: "jq",
                        desc: "Lightweight and flexible command-line JSON processor",
                        current: "1.7.0", updateTo: "1.7.1", homepage: "https://jqlang.github.io/jq/",
                        installedOnRequest: true),
            makePackage(kind: .formula, name: "git",
                        desc: "Distributed revision control system",
                        current: "2.47.0", homepage: "https://git-scm.com", installedOnRequest: true),
            makePackage(kind: .formula, name: "fzf",
                        desc: "Command-line fuzzy finder written in Go",
                        current: "0.56.0", homepage: "https://github.com/junegunn/fzf", installedOnRequest: true),
            makePackage(kind: .formula, name: "libuv",
                        desc: "Multi-platform support library with a focus on asynchronous I/O",
                        current: "1.49.0", homepage: "https://libuv.org", installedOnRequest: false),
            makePackage(kind: .formula, name: "gettext",
                        desc: "GNU internationalization (i18n) and localization library",
                        current: "0.22.5", homepage: "https://www.gnu.org/software/gettext/",
                        installedOnRequest: false),
        ]
    }

    private static func caskOnlyOutdatedPackages() -> [HomebrewPackage] {
        [
            makePackage(kind: .cask, name: "raycast", displayName: "Raycast",
                        desc: "Control your tools with a few keystrokes", current: "1.83.2", updateTo: "1.84.0",
                        homepage: "https://raycast.com"),
            makePackage(kind: .cask, name: "tableplus", displayName: "TablePlus",
                        desc: "Native GUI database client for macOS", current: "5.9.0", updateTo: "6.1.0",
                        homepage: "https://tableplus.com"),
            makePackage(kind: .cask, name: "visual-studio-code", displayName: "Visual Studio Code",
                        desc: "Open-source code editor", current: "1.95.0",
                        homepage: "https://code.visualstudio.com"),
        ]
    }

    private static func formulaOnlyOutdatedPackages() -> [HomebrewPackage] {
        [
            makePackage(kind: .formula, name: "neovim",
                        desc: "Ambitious Vim-fork focused on extensibility and agility",
                        current: "0.10.2", updateTo: "0.10.4", homepage: "https://neovim.io"),
            makePackage(kind: .formula, name: "ripgrep",
                        desc: "Search tool like grep and The Silver Searcher",
                        current: "14.1.0", updateTo: "14.1.1", homepage: "https://github.com/BurntSushi/ripgrep"),
            makePackage(kind: .formula, name: "git",
                        desc: "Distributed revision control system",
                        current: "2.47.0", homepage: "https://git-scm.com"),
        ]
    }

    private static func upToDatePackages() -> [HomebrewPackage] {
        [
            makePackage(kind: .cask, name: "raycast", displayName: "Raycast",
                        desc: "Control your tools with a few keystrokes", current: "1.84.0",
                        homepage: "https://raycast.com"),
            makePackage(kind: .cask, name: "visual-studio-code", displayName: "Visual Studio Code",
                        desc: "Open-source code editor", current: "1.95.0",
                        homepage: "https://code.visualstudio.com"),
            makePackage(kind: .formula, name: "neovim",
                        desc: "Ambitious Vim-fork focused on extensibility and agility",
                        current: "0.10.4", homepage: "https://neovim.io", requires: ["libuv"]),
            makePackage(kind: .formula, name: "git",
                        desc: "Distributed revision control system",
                        current: "2.47.0", homepage: "https://git-scm.com"),
            makePackage(kind: .formula, name: "libuv",
                        desc: "Multi-platform support library with a focus on asynchronous I/O",
                        current: "1.49.0", homepage: "https://libuv.org"),
        ]
    }
}
