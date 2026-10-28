// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import CryptoKit
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
        "yt-dlp": URL(string: "https://github.com/yt-dlp/yt-dlp/releases/download/2026.10.21/yt-dlp_macos")!,
        "ffmpeg": URL(string: "https://github.com/eugeneware/ffmpeg-static/releases/download/b6.1.1/ffmpeg-darwin-\(arch)")!,
        "ffprobe": URL(string: "https://github.com/eugeneware/ffmpeg-static/releases/download/b6.1.1/ffprobe-darwin-\(arch)")!
    ]

    private static let expectedSHA256: [String: String] = [
        "yt-dlp": "7a6fe71d7d680f1fb0ac18d4949873d77db2859e90017c0f44bd94b23be4ee40",
        "ffmpeg": arch == "arm64"
            ? "a90e3db6a3fd35f6074b013f948b1aa45b31c6375489d39e572bea3f18336584"
            : "ebdddc936f61e14049a2d4b549a412b8a40deeff6540e58a9f2a2da9e6b18894",
        "ffprobe": arch == "arm64"
            ? "bb2db6f5d8cef919da12fbf592119a987202a8c060a886f3cab091f9cab90b64"
            : "fa3add0ce901f7241abe0dfc0155d958fc834aca3f8ce61f87cc712ae669c1e0"
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
        guard !state.isInstalling else { return }
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
        guard !state.isInstalling else { return }
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

                    // Verify SHA-256 digest before moving or making executable
                    let data = try Data(contentsOf: tempURL, options: .mappedIfSafe)
                    let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                    guard let expected = Self.expectedSHA256[tool], digest.lowercased() == expected.lowercased() else {
                        throw NSError(domain: "ToolchainManager", code: 2, userInfo: [
                            NSLocalizedDescriptionKey: "Downloaded \(tool) failed integrity verification (SHA-256 mismatch)."
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
                    xattr.arguments = ["-d", "com.apple.quarantine", targetURL.path]
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
}
