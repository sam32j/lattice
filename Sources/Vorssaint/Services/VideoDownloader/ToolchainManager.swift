// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import Foundation

enum ToolchainState: Equatable, Sendable {
    case ready
    case needsApproval
    case installing(step: Int, of: Int, fraction: Double, message: String)
    case failed(String)

    var isInstalling: Bool {
        if case .installing = self { return true }
        return false
    }
}

final class ToolchainManager: ObservableObject {
    static let shared = ToolchainManager()

    @Published private(set) var state: ToolchainState = .ready
    @Published private(set) var dependencies: VideoDownloadDependencies

    var isInstalling: Bool { state.isInstalling }

    private let discoverDependencies: () -> VideoDownloadDependencies
    private let binURL: URL

    #if arch(arm64)
    private static let arch = "arm64"
    #else
    private static let arch = "x64"
    #endif

    private static let downloadSources: [String: URL] = [
        "yt-dlp": URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!,
        "ffmpeg": URL(string: "https://github.com/eugeneware/ffmpeg-static/releases/download/b6.1.1/ffmpeg-darwin-\(arch)")!,
        "ffprobe": URL(string: "https://github.com/eugeneware/ffmpeg-static/releases/download/b6.1.1/ffprobe-darwin-\(arch)")!
    ]

    init(discover: @escaping () -> VideoDownloadDependencies = { .discover() },
         binURL: URL = VideoDownloadDependencies.managedDirectory) {
        self.discoverDependencies = discover
        self.binURL = binURL
        let initial = discover()
        self.dependencies = initial
        if initial.ready {
            self.state = .ready
        } else {
            self.state = .needsApproval
        }
    }

    func checkHealth() {
        let current = discoverDependencies()
        dependencies = current
        if current.ready {
            state = .ready
        } else {
            state = .needsApproval
        }
    }

    /// Removes downloaded tool binaries from Application Support upon uninstall
    func removeTools() {
        let fm = FileManager.default
        try? fm.removeItem(at: binURL)
        let previous = binURL.deletingLastPathComponent().appendingPathComponent("bin.previous")
        try? fm.removeItem(at: previous)
        checkHealth()
    }

    /// Download missing standalone binaries directly into Application Support/Lattice/VideoDownloader/bin/
    func install(completion: ((Bool) -> Void)? = nil) {
        let missingTools = dependencies.missing
        guard !missingTools.isEmpty else {
            state = .ready
            completion?(true)
            return
        }

        state = .installing(step: 1, of: missingTools.count, fraction: 0.05, message: VideoDownloaderStrings.gettingReady)

        Task {
            let fm = FileManager.default
            do {
                try fm.createDirectory(at: self.binURL, withIntermediateDirectories: true)

                for (index, tool) in missingTools.enumerated() {
                    guard let url = Self.downloadSources[tool] else { continue }
                    let stepNumber = index + 1
                    let totalSteps = missingTools.count
                    let baseFraction = Double(index) / Double(totalSteps)

                    await MainActor.run {
                        self.state = .installing(
                            step: stepNumber,
                            of: totalSteps,
                            fraction: baseFraction + 0.05,
                            message: "Downloading \(tool)… (\(stepNumber) of \(totalSteps))"
                        )
                    }

                    let (tempURL, response) = try await URLSession.shared.download(from: url)
                    guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                        throw NSError(domain: "ToolchainManager", code: 1, userInfo: [
                            NSLocalizedDescriptionKey: "Failed to download \(tool) (HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1))"
                        ])
                    }

                    let targetURL = self.binURL.appendingPathComponent(tool)
                    if fm.fileExists(atPath: targetURL.path) {
                        try? fm.removeItem(at: targetURL)
                    }
                    try fm.moveItem(at: tempURL, to: targetURL)
                    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: targetURL.path)

                    // Strip quarantine attribute so Gatekeeper allows execution
                    let xattr = Process()
                    xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
                    xattr.arguments = ["-c", targetURL.path]
                    try? xattr.run()
                    xattr.waitUntilExit()

                    await MainActor.run {
                        self.state = .installing(
                            step: stepNumber,
                            of: totalSteps,
                            fraction: Double(stepNumber) / Double(totalSteps),
                            message: "Installed \(tool)"
                        )
                    }
                }

                let finalDeps = self.discoverDependencies()
                await MainActor.run {
                    self.dependencies = finalDeps
                    if finalDeps.ready {
                        self.state = .ready
                        completion?(true)
                    } else {
                        self.state = .failed("Installation incomplete. Missing components: \(finalDeps.missing.joined(separator: ", "))")
                        completion?(false)
                    }
                }
            } catch {
                await MainActor.run {
                    self.state = .failed(error.localizedDescription)
                    completion?(false)
                }
            }
        }
    }

    /// Backward compatibility alias for repair
    func repair() {
        install()
    }

    /// Lazy installation of Deno when an extractor specifically requires it
    func ensureDeno(completion: @escaping (Bool) -> Void) {
        if dependencies.hasDeno {
            completion(true)
            return
        }
        let system = VideoDownloadDependencies.discover()
        if system.hasDeno {
            completion(true)
            return
        }
        completion(false)
    }
}
