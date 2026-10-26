// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine

extension UpdateService {
    // MARK: - Download & install

    func downloadAndInstall() {
        if AppInfo.isDeveloperBuild { return }  // never replace the local dev build over itself
        guard let downloadURL else { return }
        // Pre-flight BEFORE spending the download: a translocated app or one
        // running from a read-only volume (the mounted DMG) can never be
        // replaced in place, so say so now instead of after the download.
        if UpdateInstallerSupport.runsFromImmutableLocation(appPath: Bundle.main.bundlePath,
                                                            volumeIsReadOnly: Self.volumeIsReadOnly) {
            let s = L10n.shared.s
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = s.updateNeedsApplicationsTitle
            alert.informativeText = s.updateNeedsApplicationsBody
            alert.runModal()
            return
        }
        // Remember the offer so a failed download restores it (the user can retry)
        // instead of dropping to a dead .failed state that hides the update and
        // blocks checkIfStale for 15 min.
        let offered: String?
        if case let .available(version) = state { offered = version } else { offered = nil }
        state = .downloading(progress: nil)

        let expectedBytes = downloadExpectedBytes
        let byteLimit = UpdateInstallerSupport.downloadByteLimit(expectedBytes: expectedBytes)
        let delegate: BoundedUpdateDownloadDelegate
        do {
            delegate = try BoundedUpdateDownloadDelegate(
                byteLimit: byteLimit,
                progress: { [weak self] receivedBytes, responseExpectedBytes in
                    let totalBytes = expectedBytes ?? responseExpectedBytes
                    guard let totalBytes, totalBytes > 0 else { return }
                    let fraction = min(Double(receivedBytes) / Double(totalBytes), 1)
                    DispatchQueue.main.async {
                        guard let self, case let .downloading(current) = self.state else { return }
                        if UpdateInstallerSupport.progressStepAdvanced(from: current, to: fraction) {
                            self.state = .downloading(progress: fraction)
                        }
                    }
                },
                completion: { [weak self] tempURL, response, error in
                    guard let self else { return }
                    self.downloadSession?.finishTasksAndInvalidate()
                    DispatchQueue.main.async {
                        self.downloadSession = nil
                    }
                    guard let tempURL, error == nil else {
                        DispatchQueue.main.async {
                            self.state = offered.map { State.available(version: $0) }
                                ?? .failed(error?.localizedDescription ?? "-")
                        }
                        return
                    }
                    // A response that cannot be the asset is dropped here, before it is
                    // moved out of the scratch space and mounted. The installer still
                    // verifies the signature; this only keeps a wrong body from getting
                    // that far.
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    let received = (try? FileManager.default.attributesOfItem(atPath: tempURL.path))
                        .flatMap { $0[.size] as? NSNumber }?.int64Value ?? 0
                    guard UpdateInstallerSupport.downloadIsUsable(status: status,
                                                                  receivedBytes: received,
                                                                  expectedBytes: expectedBytes) else {
                        try? FileManager.default.removeItem(at: tempURL)
                        DispatchQueue.main.async {
                            self.state = offered.map { State.available(version: $0) }
                                ?? .failed("HTTP \(status)")
                        }
                        return
                    }
                    // Move out of the session's scratch space before handing off.
                    let dmgURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("Lattice-update.dmg")
                    try? FileManager.default.removeItem(at: dmgURL)
                    do {
                        try FileManager.default.moveItem(at: tempURL, to: dmgURL)
                    } catch {
                        DispatchQueue.main.async {
                            self.state = offered.map { State.available(version: $0) }
                                ?? .failed(error.localizedDescription)
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        self.state = .installing
                        self.launchInstaller(dmgPath: dmgURL.path, offered: offered)
                    }
                })
        } catch {
            DispatchQueue.main.async {
                self.state = offered.map { State.available(version: $0) }
                    ?? .failed(error.localizedDescription)
            }
            return
        }
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        downloadSession = session
        let task = session.dataTask(with: downloadURL)
        task.resume()
    }

    /// Hands the swap to a detached shell script: it waits for this process to
    /// quit, verifies and mounts the DMG, replaces the bundle, clears
    /// quarantine and relaunches. Running it outside the app means the bundle
    /// can be replaced safely while we exit. When the app's folder is not
    /// writable by this user (standard account with the app in /Applications),
    /// the script runs through an admin prompt instead of failing silently.
    func launchInstaller(dmgPath: String, offered: String?) {
        let appPath = Bundle.main.bundlePath
        let pid = ProcessInfo.processInfo.processIdentifier
        let fm = FileManager.default

        guard let resultURL = Self.installResultURL, let expectedVersion = offered else {
            abortInstall(dmgPath: dmgPath, offered: offered)
            return
        }
        try? fm.createDirectory(at: resultURL.deletingLastPathComponent(),
                                withIntermediateDirectories: true)
        try? fm.removeItem(at: resultURL)
        try? fm.removeItem(at: resultURL.appendingPathExtension("progress"))

        let appDirectory = (appPath as NSString).deletingLastPathComponent
        let lastFailure = UserDefaults.standard.string(forKey: DefaultsKey.updateLastInstallFailure)
        if fm.isWritableFile(atPath: appDirectory),
           !UpdateInstallerSupport.shouldForceAdminInstall(afterFailureCode: lastFailure) {
            launchUserInstaller(appPath: appPath, dmgPath: dmgPath, pid: pid,
                                resultPath: resultURL.path, expectedVersion: expectedVersion)
        } else {
            // Either the folder is not writable, or the last attempt died at
            // the copy/swap step: retry with admin rights instead of failing
            // the same way twice.
            launchAdminInstaller(appPath: appPath, dmgPath: dmgPath, pid: pid,
                                 resultPath: resultURL.path, expectedVersion: expectedVersion)
        }
    }

    func launchUserInstaller(appPath: String, dmgPath: String, pid: Int32,
                                     resultPath: String, expectedVersion: String) {
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lattice-update-\(pid)-\(UUID().uuidString).sh")
        do {
            try UpdateInstallerSupport.installerScript()
                .write(to: scriptURL, atomically: true, encoding: .utf8)
        } catch {
            failInstall(dmgPath: dmgPath, message: error.localizedDescription)
            return
        }

        do {
            // Its own session: a plain child would be swept away with this
            // app's session and launchd job, before the swap it is here for.
            try DetachedProcess.spawn("/bin/sh",
                                      [scriptURL.path, appPath, dmgPath, "\(pid)", resultPath,
                                       "\(getuid())", expectedVersion])
        } catch {
            try? FileManager.default.removeItem(at: scriptURL)
            failInstall(dmgPath: dmgPath, message: error.localizedDescription)
            return
        }
        // Quit so the installer can replace the bundle; it relaunches us.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NSApp.terminate(nil)
        }
    }

    /// Same installer, behind the system admin prompt via AdminShell, which
    /// serializes prompts and brings this menu bar app forward so the dialog
    /// cannot open behind another window. The script goes inline inside the
    /// elevated command (never a user-writable file run as root), started in
    /// its own session so the prompt returns while the installer waits for our
    /// exit — and so it survives that exit.
    func launchAdminInstaller(appPath: String, dmgPath: String, pid: Int32,
                                      resultPath: String, expectedVersion: String) {
        let command = UpdateInstallerSupport.elevatedInstallCommand(appPath: appPath,
                                                                    dmgPath: dmgPath,
                                                                    pid: pid,
                                                                    resultPath: resultPath,
                                                                    uid: getuid(),
                                                                    expectedVersion: expectedVersion)
        // The in-process authorization holds the main thread until it is
        // answered, and the system dialog never appears while the Extra
        // Brightness overlay is on screen (#1917). Once the request waits,
        // nothing can take the overlay down, not even the menu, so it
        // leaves first and returns if the prompt is declined; an approved
        // install quits.
        ExtraBrightnessService.stopIfLoaded()
        AdminShell.runInProcess(command, prompt: L10n.shared.s.adminPromptUpdate) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                if granted {
                    NSApp.terminate(nil)
                } else {
                    ExtraBrightnessService.resumeIfLoaded()
                    // The user dismissed the admin prompt: keep the offer so
                    // the button simply works again.
                    self.abortInstall(dmgPath: dmgPath, offered: expectedVersion)
                }
            }
        }
    }

    /// Puts the world back as if the install had not been attempted: the
    /// downloaded DMG is discarded and the offer (or idle state) returns.
    func abortInstall(dmgPath: String, offered: String?) {
        try? FileManager.default.removeItem(atPath: dmgPath)
        if let offered {
            state = .available(version: offered)
        } else {
            state = .idle
        }
    }

    func failInstall(dmgPath: String, message: String) {
        try? FileManager.default.removeItem(atPath: dmgPath)
        state = .failed(message)
    }

    /// Whether the volume holding `path` is mounted read-only (the DMG). An
    /// unanswerable query counts as read-only: refusing with a clear message
    /// beats quitting for an install that cannot happen.
    static func volumeIsReadOnly(_ path: String) -> Bool {
        let values = try? URL(fileURLWithPath: path)
            .resourceValues(forKeys: [.volumeIsReadOnlyKey])
        return values?.volumeIsReadOnly ?? true
    }

    // MARK: - Install result

    /// Marker the installer script writes; read on the next launch so a swap
    /// that failed after the app quit is reported instead of looking like the
    /// update was simply ignored.
    static var installResultURL: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask).first,
              let bundleID = Bundle.main.bundleIdentifier
        else { return nil }
        return base
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("update-install-result", isDirectory: false)
    }

    func consumeInstallResult() {
        guard let url = Self.installResultURL else { return }
        // A leftover progress file means an installer died mid-run (or is
        // still running right now); it is never a finished verdict.
        try? FileManager.default.removeItem(at: url.appendingPathExtension("progress"))
        guard let marker = try? String(contentsOf: url, encoding: .utf8) else { return }
        try? FileManager.default.removeItem(at: url)
        guard let code = UpdateInstallerSupport.installFailureCode(fromMarker: marker) else {
            // The swap finished: this launch IS the new version, so any
            // remembered failure no longer applies.
            UserDefaults.standard.removeObject(forKey: DefaultsKey.updateLastInstallFailure)
            return
        }
        // Remember the failing step so the next attempt can route around it
        // (copy/swap failures retry through the admin prompt), and check
        // again soon so the update offer comes right back instead of
        // looking silently dropped.
        UserDefaults.standard.set(code, forKey: DefaultsKey.updateLastInstallFailure)
        let s = L10n.shared.s
        Notifier.post(title: s.updateNotifyTitle,
                      body: "\(s.updateInstallFailedBody) (\(code))")
        if !AppInfo.isDeveloperBuild {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.check(manual: false)
            }
        }
    }

}
