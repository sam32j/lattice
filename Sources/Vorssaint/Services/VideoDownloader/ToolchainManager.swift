// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import Foundation

enum ToolchainState: Equatable, Sendable {
    case ready
    case installing(step: Int, of: Int, fraction: Double, message: String)
    case needsRepair(String)
}

final class ToolchainManager: ObservableObject {
    static let shared = ToolchainManager()

    @Published private(set) var state: ToolchainState = .ready
    @Published private(set) var dependencies: VideoDownloadDependencies

    private let discoverDependencies: () -> VideoDownloadDependencies
    private let binURL: URL

    init(discover: @escaping () -> VideoDownloadDependencies = { .discover() },
         binURL: URL = VideoDownloadDependencies.managedDirectory) {
        self.discoverDependencies = discover
        self.binURL = binURL
        let initial = discover()
        self.dependencies = initial
        if initial.ready {
            self.state = .ready
        } else {
            self.state = .needsRepair(VideoDownloaderStrings.repairSubtitle)
        }
    }

    func checkHealth() {
        let current = discoverDependencies()
        dependencies = current
        if current.ready {
            state = .ready
        } else {
            state = .needsRepair(VideoDownloaderStrings.repairSubtitle)
        }
    }

    /// Auto-setup or repair the toolchain into Application Support/Lattice/VideoDownloader/bin/
    func repair() {
        state = .installing(step: 1, of: 3, fraction: 0.1, message: VideoDownloaderStrings.gettingReady)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let fm = FileManager.default
            do {
                try fm.createDirectory(at: self.binURL, withIntermediateDirectories: true)

                // 1. If system tools or Homebrew exist, we can link/copy them
                let system = VideoDownloadDependencies.discover(useSystemTools: true)
                for (name, path) in system.tools {
                    let target = self.binURL.appendingPathComponent(name)
                    if !fm.fileExists(atPath: target.path) && fm.fileExists(atPath: path) {
                        try? fm.copyItem(atPath: path, toPath: target.path)
                        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target.path)
                    }
                }

                // If still missing and Homebrew exists, install via brew if needed
                let afterLocal = self.discoverDependencies()
                if !afterLocal.ready, let brew = afterLocal.brew {
                    DispatchQueue.main.async {
                        self.state = .installing(step: 2, of: 3, fraction: 0.5, message: "Fetching required components…")
                    }
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: brew)
                    process.arguments = afterLocal.installArguments
                    process.environment = afterLocal.environment
                    try? process.run()
                    process.waitUntilExit()
                }

                let finalDeps = self.discoverDependencies()
                DispatchQueue.main.async {
                    self.dependencies = finalDeps
                    if finalDeps.ready {
                        self.state = .ready
                    } else {
                        self.state = .needsRepair("Components could not be installed automatically. Check your connection or use system tools.")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.state = .needsRepair(error.localizedDescription)
                }
            }
        }
    }

    /// Lazy installation of Deno when an extractor specifically requires it
    func ensureDeno(completion: @escaping (Bool) -> Void) {
        if dependencies.hasDeno {
            completion(true)
            return
        }
        state = .installing(step: 1, of: 1, fraction: 0.5, message: VideoDownloaderStrings.denoRequired)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let system = VideoDownloadDependencies.discover(useSystemTools: true)
            if let denoPath = system.tools["deno"] {
                let target = self.binURL.appendingPathComponent("deno")
                try? FileManager.default.copyItem(atPath: denoPath, toPath: target.path)
                try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target.path)
            } else if let brew = system.brew {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: brew)
                process.arguments = ["install", "deno"]
                process.environment = system.environment
                try? process.run()
                process.waitUntilExit()
            }
            let updated = self.discoverDependencies()
            DispatchQueue.main.async {
                self.dependencies = updated
                self.state = updated.ready ? .ready : .needsRepair(VideoDownloaderStrings.repairSubtitle)
                completion(updated.hasDeno)
            }
        }
    }
}
