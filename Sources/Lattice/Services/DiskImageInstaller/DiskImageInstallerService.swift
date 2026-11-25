// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Darwin
import Foundation
import SwiftUI

final class DiskImageInstallerService: ObservableObject {
    static let shared = DiskImageInstallerService()

    /// The image the install prompt is about, for the App Installer tab.
    @Published private(set) var detected: DetectedDiskImage?
    @Published private(set) var recentInstalls: [DiskImageRecentInstall] = DiskImageRecentInstalls.load()

    private struct FileIdentity: Equatable {
        let device: UInt64
        let inode: UInt64
    }

    private struct Candidate {
        let mountURL: URL
        let appURL: URL
        let imageURL: URL
        let imageIdentity: FileIdentity
        let displayName: String
        /// Copies already in the Applications folders, which an install
        /// moves to the Trash: an installed app is offered as an update.
        let replacing: [URL]
    }

    private enum InstallFailure {
        case alreadyInstalled
        case verification
        case copy
    }

    private enum InstallOutcome {
        case installed(downloadTrashed: Bool)
        case installedKeepingMount
        case installedKeepingDownload
        case failed(InstallFailure)

        var isInstalled: Bool {
            if case .failed = self { return false }
            return true
        }
    }

    private struct InstallResult {
        let outcome: InstallOutcome
        let destinationURL: URL?
    }

    private struct CommandResult {
        let status: Int32
        let output: Data
    }

    private let workQueue = DispatchQueue(label: "io.github.sam32j.lattice.disk-image-installer",
                                          qos: .utility)
    /// Whether the App Installer is on. It never watches mounts: a disk
    /// image another app mounts (an app updating itself) is left alone, and
    /// only one opened with Lattice is offered.
    private var isRunning = false
    private var pending: [Candidate] = []
    private var promptActive = false
    private var installPrompt: NonModalAlert?
    private var progressPanel: NSPanel?
    /// The volume the prompt is about, so the same image opened twice asks once.
    private var activeMountPath: String?
    /// Volumes Lattice mounted itself, hidden from Finder: a cancelled
    /// prompt ejects them again rather than leave them mounted out of sight.
    private var hiddenMounts = Set<String>()

    private init() {}

    func syncWithPreferences() {
        precondition(Thread.isMainThread)
        AppFeature.diskImageInstaller.isAvailable ? start() : stop()
    }

    private func start() {
        isRunning = true
    }

    private func stop() {
        isRunning = false
        pending.removeAll()
        installPrompt?.dismiss(with: .alertThirdButtonReturn)
        detected = nil
    }

    // MARK: The App Installer tab

    /// Installs the waiting image with the saved options, as the prompt's
    /// Install button does.
    func installDetected() {
        installPrompt?.dismiss(with: .alertFirstButtonReturn)
    }

    /// Leaves the waiting image mounted, as the prompt's Cancel does.
    func skipDetected() {
        installPrompt?.dismiss(with: .alertThirdButtonReturn)
    }

    /// Opens a disk image handed to Lattice (double-clicked while Lattice
    /// opens disk images, dropped on its menu bar or app icon or the island,
    /// chosen or dropped in the tab): it is mounted out of Finder's sight and
    /// the prompt asks before anything else happens. An image without a
    /// single app to install opens in Finder as usual.
    func open(diskImage url: URL) {
        guard url.pathExtension.caseInsensitiveCompare("dmg") == .orderedSame else { return }
        // A double-click that launches Lattice arrives before the features
        // start at launch; the App Installer starts for it.
        if !isRunning, AppFeature.diskImageInstaller.isAvailable { start() }
        guard isRunning else {
            DiskImageOpenHandler.openWithDiskImageMounter(url)
            return
        }
        workQueue.async { [weak self] in
            // No checksum pass over the whole image, which held the prompt
            // back for seconds: the app inside is still checked by its code
            // signature and Gatekeeper before it installs.
            let attach = Self.run("/usr/bin/hdiutil", arguments: ["attach", "-nobrowse", "-noverify", "-noautofsck",
                                                                  "-plist", url.path])
            let mountURL = attach.status == 0 ? DiskImageInstallerSupport.mountPoint(fromAttachPlist: attach.output) : nil
            let candidate = mountURL.flatMap { self?.candidate(mountedAt: $0) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard let mountURL else {
                    DiskImageOpenHandler.openWithDiskImageMounter(url)
                    return
                }
                guard let candidate else {
                    NSWorkspace.shared.open(mountURL)
                    return
                }
                let path = mountURL.standardizedFileURL.path
                self.hiddenMounts.insert(path)
                guard self.activeMountPath != path,
                      !self.pending.contains(where: { $0.mountURL.standardizedFileURL.path == path }) else { return }
                self.pending.append(candidate)
                self.presentNextCandidate()
            }
        }
    }

    /// Drops an install from the list, for an app that is no longer there.
    func forget(_ install: DiskImageRecentInstall) {
        recentInstalls.removeAll { $0.id == install.id }
        DiskImageRecentInstalls.save(recentInstalls)
    }

    func reveal(_ install: DiskImageRecentInstall) {
        let url = URL(fileURLWithPath: install.destinationPath)
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    /// Reads what the tab shows beyond the name, off the main thread.
    private func describe(_ candidate: Candidate) {
        let id = detected?.id
        workQueue.async { [weak self] in
            let bundle = Bundle(url: candidate.appURL)
            let version = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            let size = (try? candidate.imageURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
            let signature = Self.run("/usr/bin/codesign", arguments: ["-dv", "--verbose=2", candidate.appURL.path],
                                     capturingErrors: true)
            let developer = DiskImageRecentInstalls.developer(
                fromCodesignOutput: String(data: signature.output, encoding: .utf8) ?? "")
            let accepted = Self.gatekeeperAccepts(candidate.appURL)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.detected?.id == id else { return }
                self.detected?.version = version
                self.detected?.imageSize = size
                self.detected?.developer = developer
                self.detected?.gatekeeperAccepted = accepted
            }
        }
    }

    private func report(_ step: DiskImageInstallStep) {
        DispatchQueue.main.async { [weak self] in
            guard self?.detected != nil else { return }
            self?.detected?.phase = .installing(step)
        }
    }

    /// Only Homebrew's own images are excluded. An unrelated manual mount
    /// must still be offered while a cask installation is running.
    private static func isHomebrewImage(_ imageURL: URL) -> Bool {
        guard let libraryURL = FileManager.default.urls(for: .libraryDirectory,
                                                        in: .userDomainMask).first else { return false }
        let cacheURL = libraryURL.appendingPathComponent("Caches/Homebrew", isDirectory: true)
            .standardizedFileURL.resolvingSymlinksInPath()
        let imagePath = imageURL.standardizedFileURL.resolvingSymlinksInPath().path
        let cachePath = cacheURL.path
        return imagePath == cachePath || imagePath.hasPrefix(cachePath + "/")
    }

    private func candidate(mountedAt mountURL: URL) -> Candidate? {
        let fm = FileManager.default
        let info = Self.run("/usr/bin/hdiutil", arguments: ["info", "-plist"])
        guard info.status == 0,
              let imageURL = DiskImageInstallerSupport.imageURL(mountedAt: mountURL,
                                                                 hdiutilInfo: info.output),
              !Self.isHomebrewImage(imageURL),
              let imageIdentity = Self.fileIdentity(at: imageURL),
              let entries = try? fm.contentsOfDirectory(at: mountURL,
                                                        includingPropertiesForKeys: [
                                                            .isDirectoryKey,
                                                            .isSymbolicLinkKey,
                                                        ],
                                                        options: [.skipsHiddenFiles])
        else { return nil }

        let apps = entries.filter { url in
            guard url.pathExtension.caseInsensitiveCompare("app") == .orderedSame,
                  let values = try? url.resourceValues(forKeys: [.isDirectoryKey,
                                                                  .isSymbolicLinkKey]),
                  values.isDirectory == true,
                  values.isSymbolicLink != true
            else { return false }
            return Self.validBundle(at: url)
        }
        let useUserApplications = UserDefaults.standard.bool(
            forKey: DefaultsKey.diskImageInstallerUseUserApplications)
        guard apps.count == 1, let appURL = apps.first,
              let collisionURLs = DiskImageInstallerSupport.collisionURLs(for: appURL,
                useUserApplications: useUserApplications,
                fileManager: fm)
        else { return nil }
        let replacing = collisionURLs.filter { fm.fileExists(atPath: $0.path) }

        let preferredName = Bundle(url: appURL)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        return Candidate(mountURL: mountURL,
                         appURL: appURL,
                         imageURL: imageURL,
                         imageIdentity: imageIdentity,
                         displayName: DiskImageInstallerSupport.displayName(preferred: preferredName,
                                                                            appURL: appURL),
                         replacing: replacing)
    }

    private func presentNextCandidate() {
        guard !promptActive, isRunning, let candidate = pending.first else { return }
        pending.removeFirst()
        if pending.contains(where: { $0.mountURL.standardizedFileURL.path == candidate.mountURL.standardizedFileURL.path }) {
            pending.removeAll { $0.mountURL.standardizedFileURL.path == candidate.mountURL.standardizedFileURL.path }
        }
        promptActive = true
        detected = DetectedDiskImage(id: UUID(), displayName: candidate.displayName,
                                     appPath: candidate.appURL.path,
                                     imageFileName: candidate.imageURL.lastPathComponent,
                                     replacesExisting: !candidate.replacing.isEmpty)
        describe(candidate)

        activeMountPath = candidate.mountURL.standardizedFileURL.path
        let strings = FeatureStrings.diskImageInstaller(L10n.shared.language)
        let tab = FeatureStrings.appInstallerTab(L10n.shared.language)
        let defaults = UserDefaults.standard
        let usesUserApplications = defaults.bool(forKey: DefaultsKey.diskImageInstallerUseUserApplications)
        let trashesDownload = defaults.bool(forKey: DefaultsKey.diskImageInstallerTrashesDownload)
        let folder = usesUserApplications ? tab.folderUser : tab.folderSystem
        let body = candidate.replacing.isEmpty
            ? (trashesDownload ? tab.installTrashBodyFormat : tab.installBodyFormat)
            : (trashesDownload ? tab.replaceTrashBodyFormat : tab.replaceBodyFormat)
        let alert = NSAlert()
        alert.messageText = String(format: tab.installTitleFormat, candidate.displayName)
        alert.informativeText = String(format: body, candidate.displayName, folder)
        alert.icon = NSWorkspace.shared.icon(forFile: candidate.appURL.path)
        alert.addButton(withTitle: strings.installButton)
        alert.addButton(withTitle: tab.installManually)
        alert.addButton(withTitle: L10n.shared.s.uninstallerCancel)

        // Not runModal: this runs inside a main-queue block (the hop after the
        // mount check), and a modal loop started there holds back later
        // main-queue work, such as shortcut actions, until the alert closes.
        // Its modal panel mode also stops default-mode timers (issue #1665).
        // The options live on the App Manager's App Installer tab.
        NSApp.activate(ignoringOtherApps: true)
        installPrompt = NonModalAlert.present(alert) { [weak self] response in
            guard let self else { return }
            self.installPrompt = nil
            switch response {
            case .alertFirstButtonReturn:
                self.beginInstall(candidate, strings: strings,
                                  trashingDownload: trashesDownload,
                                  revealingApp: defaults.bool(forKey: DefaultsKey.diskImageInstallerRevealsApp),
                                  useUserApplications: usesUserApplications)
            case .alertSecondButtonReturn:
                // Install by hand: the volume opens in Finder, as a plain open would.
                self.hiddenMounts.remove(candidate.mountURL.standardizedFileURL.path)
                NSWorkspace.shared.open(candidate.mountURL)
                self.finishCurrentCandidate()
            default:
                if self.hiddenMounts.remove(candidate.mountURL.standardizedFileURL.path) != nil {
                    try? NSWorkspace.shared.unmountAndEjectDevice(at: candidate.mountURL)
                }
                self.finishCurrentCandidate()
            }
        }
    }

    private func beginInstall(_ candidate: Candidate, strings: DiskImageInstallerStrings,
                              trashingDownload trashesDownload: Bool, revealingApp revealsApp: Bool,
                              useUserApplications usesUserApplications: Bool) {
        showProgress(for: candidate, strings: strings)
        detected?.phase = .installing(.copying)
        let version = detected?.version

        workQueue.async { [weak self] in
            var verified = true
            let result = self?.install(candidate, trashingDownload: trashesDownload,
                                       useUserApplications: usesUserApplications, verified: &verified)
                ?? InstallResult(outcome: .failed(.copy), destinationURL: nil)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.hideProgress()
                if case let .installed(trashed) = result.outcome, let destination = result.destinationURL {
                    self.record(candidate, version: version, destination: destination, downloadTrashed: trashed)
                } else if result.outcome.isInstalled, let destination = result.destinationURL {
                    self.record(candidate, version: version, destination: destination, downloadTrashed: false)
                }
                self.detected = nil
                let announce: () -> Void = { [weak self] in
                    self?.present(result: result, candidate: candidate) { [weak self] in
                        if revealsApp, result.outcome.isInstalled, let destinationURL = result.destinationURL {
                            NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
                        }
                        self?.finishCurrentCandidate()
                    }
                }
                // An unverified app is settled first, so the result that
                // follows describes an app that opens, or one still blocked.
                guard !verified, result.outcome.isInstalled, let destinationURL = result.destinationURL,
                      UserDefaults.standard.bool(forKey: DefaultsKey.diskImageInstallerOpensDiskImages),
                      UserDefaults.standard.bool(forKey: DefaultsKey.diskImageInstallerOffersUnverifiedOpen),
                      Self.isQuarantined(destinationURL) else {
                    announce()
                    return
                }
                self.offerToAllow(destinationURL, name: candidate.displayName, completion: announce)
            }
        }
    }

    /// Copying and verifying take a few seconds with nothing else on screen,
    /// which reads as a failure. A quiet floating card keeps the wait honest.
    private func showProgress(for candidate: Candidate, strings: DiskImageInstallerStrings) {
        let host = NSHostingController(rootView: DiskImageInstallProgressView(
            icon: NSWorkspace.shared.icon(forFile: candidate.appURL.path),
            message: String(format: strings.installingFormat, candidate.displayName)))
        host.view.layoutSubtreeIfNeeded()
        let size = host.view.fittingSize

        let panel = progressPanel ?? Self.makeProgressPanel()
        progressPanel = panel
        panel.contentViewController = host
        let screen = NSScreen.pointerVisibleFrame
        panel.setFrame(NSRect(x: (screen.midX - size.width / 2).rounded(),
                              y: (screen.maxY - size.height - 24).rounded(),
                              width: size.width,
                              height: size.height),
                       display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    private func hideProgress() {
        progressPanel?.orderOut(nil)
        progressPanel?.contentViewController = nil
    }

    private static func makeProgressPanel() -> NSPanel {
        let panel = OverlayPanel(contentRect: .zero,
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered,
                                 defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        return panel
    }

    private func finishCurrentCandidate() {
        promptActive = false
        // The same volume queued again while it was being asked about is done.
        if let finished = activeMountPath {
            pending.removeAll { $0.mountURL.standardizedFileURL.path == finished }
        }
        activeMountPath = nil
        if case .installing = detected?.phase {} else { detected = nil }
        presentNextCandidate()
    }

    private func record(_ candidate: Candidate, version: String?, destination: URL, downloadTrashed: Bool) {
        let install = DiskImageRecentInstall(id: UUID(), name: candidate.displayName, version: version,
                                             destinationPath: destination.path,
                                             downloadTrashed: downloadTrashed, date: Date())
        recentInstalls = DiskImageRecentInstalls.adding(install, to: recentInstalls)
        DiskImageRecentInstalls.save(recentInstalls)
    }

    private func install(_ candidate: Candidate, trashingDownload: Bool,
                         useUserApplications: Bool, verified: inout Bool) -> InstallResult {
        let fm = FileManager.default
        let applicationsDomain = DiskImageInstallerSupport.applicationsDomain(
            useUserApplications: useUserApplications)
        guard let applicationsURL = try? fm.url(for: .applicationDirectory,
                                                in: applicationsDomain,
                                                appropriateFor: nil,
                                                create: true),
              let destinationURL = DiskImageInstallerSupport.destinationURL(
                for: candidate.appURL,
                applicationsURL: applicationsURL),
              let collisionURLs = DiskImageInstallerSupport.collisionURLs(for: candidate.appURL,
                useUserApplications: useUserApplications,
                fileManager: fm),
              collisionURLs.contains(destinationURL)
        else {
            return InstallResult(outcome: .failed(.copy), destinationURL: nil)
        }
        guard Self.onlyReplaces(collisionURLs, candidate.replacing, fileManager: fm) else {
            return InstallResult(outcome: .failed(.alreadyInstalled),
                                 destinationURL: destinationURL)
        }

        let stagingDirectory: URL
        do {
            stagingDirectory = try fm.url(for: .itemReplacementDirectory,
                                          in: .userDomainMask,
                                          appropriateFor: destinationURL.deletingLastPathComponent(),
                                          create: true)
        } catch {
            return InstallResult(outcome: .failed(.copy), destinationURL: destinationURL)
        }
        defer { try? fm.removeItem(at: stagingDirectory) }

        let stagedApp = stagingDirectory.appendingPathComponent(candidate.appURL.lastPathComponent,
                                                                 isDirectory: true)
        // Carrying the mounted image's quarantine over leaves the installed app eligible for
        // path randomization, so macOS runs it from a read-only random location instead of
        // Applications. The checks below are the same assessment that flag defers to.
        report(.copying)
        let copy = Self.run("/usr/bin/ditto", arguments: [
            "--rsrc", "--extattr", "--acl", "--noqtn",
            candidate.appURL.path, stagedApp.path,
        ])
        guard copy.status == 0, Self.validBundle(at: stagedApp) else {
            return InstallResult(outcome: .failed(.copy), destinationURL: destinationURL)
        }
        report(.verifying)
        // An app macOS would refuse still installs, keeping the download mark
        // the copy above left behind, so macOS goes on blocking it at launch
        // unless the person allows it afterwards.
        verified = Self.gatekeeperAccepts(stagedApp)
        if !verified, !Self.carryQuarantine(from: [candidate.imageURL, candidate.appURL], to: stagedApp) {
            return InstallResult(outcome: .failed(.verification), destinationURL: destinationURL)
        }

        var trashed: [(original: URL, trashed: URL)] = []
        do {
            guard let finalCollisionURLs = DiskImageInstallerSupport.collisionURLs(
                for: candidate.appURL,
                useUserApplications: useUserApplications,
                fileManager: fm),
                finalCollisionURLs.contains(destinationURL)
            else {
                return InstallResult(outcome: .failed(.copy), destinationURL: destinationURL)
            }
            guard Self.onlyReplaces(finalCollisionURLs, candidate.replacing, fileManager: fm) else {
                return InstallResult(outcome: .failed(.alreadyInstalled),
                                     destinationURL: destinationURL)
            }
            // The copy being updated goes to the Trash, where it can be put back.
            for existing in finalCollisionURLs where fm.fileExists(atPath: existing.path) {
                var trashedURL: NSURL?
                try fm.trashItem(at: existing, resultingItemURL: &trashedURL)
                if let resultURL = trashedURL as URL? {
                    trashed.append((original: existing, trashed: resultURL))
                }
            }
            report(.moving)
            try fm.moveItem(at: stagedApp, to: destinationURL)
        } catch {
            for item in trashed.reversed() {
                try? fm.moveItem(at: item.trashed, to: item.original)
            }
            return InstallResult(outcome: .failed(.copy), destinationURL: destinationURL)
        }

        report(.ejecting)
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: candidate.mountURL)
        } catch {
            return InstallResult(outcome: .installedKeepingMount, destinationURL: destinationURL)
        }

        guard trashingDownload else {
            return InstallResult(outcome: .installed(downloadTrashed: false),
                                 destinationURL: destinationURL)
        }
        guard Self.fileIdentity(at: candidate.imageURL) == candidate.imageIdentity else {
            return InstallResult(outcome: .installedKeepingDownload,
                                 destinationURL: destinationURL)
        }
        report(.trashing)
        do {
            try fm.trashItem(at: candidate.imageURL, resultingItemURL: nil)
            return InstallResult(outcome: .installed(downloadTrashed: true),
                                 destinationURL: destinationURL)
        } catch {
            return InstallResult(outcome: .installedKeepingDownload,
                                 destinationURL: destinationURL)
        }
    }

    private func present(result: InstallResult, candidate: Candidate,
                         completion: @escaping () -> Void) {
        let strings = FeatureStrings.diskImageInstaller(L10n.shared.language)
        let alert = NSAlert()
        let folder = result.destinationURL?.deletingLastPathComponent().path == "/Applications"
            ? strings.applicationsFolder : strings.userApplicationsFolder
        alert.icon = NSWorkspace.shared.icon(forFile: result.destinationURL?.path
                                              ?? candidate.appURL.path)
        switch result.outcome {
        case let .installed(downloadTrashed):
            alert.messageText = strings.installedTitle
            alert.informativeText = String(format: downloadTrashed
                                               ? strings.installedBodyFormat
                                               : strings.installedKeptDownloadBodyFormat,
                                           candidate.displayName, folder)
        case .installedKeepingMount:
            alert.alertStyle = .warning
            alert.messageText = strings.installedTitle
            alert.informativeText = String(format: strings.installedKeepingMountBodyFormat,
                                           candidate.displayName, folder)
        case .installedKeepingDownload:
            alert.alertStyle = .warning
            alert.messageText = strings.installedTitle
            alert.informativeText = String(format: strings.installedKeepingDownloadBodyFormat,
                                           candidate.displayName, folder)
        case let .failed(failure):
            alert.alertStyle = .warning
            alert.messageText = strings.failedTitle
            switch failure {
            case .alreadyInstalled:
                alert.informativeText = String(format: strings.alreadyInstalledBodyFormat,
                                               candidate.displayName)
            case .verification:
                alert.informativeText = strings.verificationFailedBody
            case .copy:
                alert.informativeText = strings.failedBody
            }
        }
        // Not runModal either: this runs inside the hop after the install.
        NSApp.activate(ignoringOtherApps: true)
        NonModalAlert.present(alert) { _ in completion() }
    }

    // MARK: Unverified apps

    private static let quarantineAttribute = "com.apple.quarantine"

    static func isQuarantined(_ url: URL) -> Bool {
        getxattr(url.path, quarantineAttribute, nil, 0, 0, 0) > 0
    }

    /// Puts the download mark on the staged copy, which the copy dropped, so
    /// macOS still treats the app as downloaded and blocks it at launch. The
    /// mark is on the downloaded .dmg; a volume Lattice mounts carries none.
    /// Returns `false` only when a source carried quarantine and restoring it
    /// to `destination` failed.
    private static func carryQuarantine(from sources: [URL], to destination: URL) -> Bool {
        var foundQuarantine = false
        for source in sources {
            let size = getxattr(source.path, quarantineAttribute, nil, 0, 0, 0)
            guard size > 0 else { continue }
            foundQuarantine = true
            var value = [UInt8](repeating: 0, count: size)
            guard getxattr(source.path, quarantineAttribute, &value, size, 0, 0) == size else { continue }
            if setxattr(destination.path, quarantineAttribute, value, size, 0, 0) == 0 {
                return true
            }
        }
        return !foundQuarantine
    }

    /// Asks whether an installed app macOS could not verify may open, with
    /// what that means; only a yes removes the download mark.
    private func offerToAllow(_ app: URL, name: String, completion: @escaping () -> Void) {
        let tab = FeatureStrings.appInstallerTab(L10n.shared.language)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.icon = NSWorkspace.shared.icon(forFile: app.path)
        alert.messageText = String(format: tab.allowTitleFormat, name)
        alert.informativeText = String(format: tab.allowBodyFormat, name)
        // The safe choice is the default one.
        alert.addButton(withTitle: tab.keepBlockedButton)
        alert.addButton(withTitle: tab.allowButton)
        NSApp.activate(ignoringOtherApps: true)
        NonModalAlert.present(alert) { [weak self] response in
            guard response == .alertSecondButtonReturn, let self else { completion(); return }
            self.workQueue.async {
                _ = Self.run("/usr/bin/xattr", arguments: ["-dr", Self.quarantineAttribute, app.path])
                DispatchQueue.main.async(execute: completion)
            }
        }
    }

    /// Whether every copy now in the way is one the prompt said it would
    /// replace: one that appeared since then still stops the install.
    private static func onlyReplaces(_ collisions: [URL], _ replacing: [URL], fileManager fm: FileManager) -> Bool {
        let allowed = Set(replacing.map { $0.standardizedFileURL.path })
        return collisions.allSatisfy { !fm.fileExists(atPath: $0.path) || allowed.contains($0.standardizedFileURL.path) }
    }

    private static func validBundle(at appURL: URL) -> Bool {
        guard let bundle = Bundle(url: appURL),
              let executableURL = bundle.executableURL,
              FileManager.default.isExecutableFile(atPath: executableURL.path)
        else { return false }
        let root = appURL.standardizedFileURL.resolvingSymlinksInPath().path + "/"
        let executable = executableURL.standardizedFileURL.resolvingSymlinksInPath().path
        return executable.hasPrefix(root)
    }

    private static func gatekeeperAccepts(_ appURL: URL) -> Bool {
        let signature = run("/usr/bin/codesign",
                            arguments: ["--verify", "--deep", "--strict", appURL.path])
        guard signature.status == 0 else { return false }
        let status = run("/usr/sbin/spctl", arguments: ["--status"])
        if String(data: status.output, encoding: .utf8)?.localizedCaseInsensitiveContains("disabled") == true {
            return true
        }
        return run("/usr/sbin/spctl", arguments: ["-a", "-t", "exec", appURL.path]).status == 0
    }

    private static func fileIdentity(at url: URL) -> FileIdentity? {
        var info = stat()
        guard url.path.withCString({ lstat($0, &info) }) == 0,
              (info.st_mode & S_IFMT) == S_IFREG
        else { return nil }
        return FileIdentity(device: UInt64(info.st_dev), inode: UInt64(info.st_ino))
    }

    private static func run(_ executable: String, arguments: [String],
                            capturingErrors: Bool = false) -> CommandResult {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        // codesign -d writes what it displays to standard error.
        process.standardError = capturingErrors ? output : FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return CommandResult(status: -1, output: Data())
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return CommandResult(status: process.terminationStatus, output: data)
    }
}

private struct DiskImageInstallProgressView: View {
    let icon: NSImage
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 6) {
                Text(message)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                ProgressView()
                    .progressViewStyle(.linear)
                    .controlSize(.small)
            }
            .frame(width: 220, alignment: .leading)
        }
        .padding(14)
        .background(HUDBackdrop(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
    }
}
