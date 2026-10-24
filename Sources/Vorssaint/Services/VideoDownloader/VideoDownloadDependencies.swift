// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

struct VideoDownloadDependencies: Equatable {
    let tools: [String: String]
    let environment: [String: String]
    let isManaged: Bool

    static let coreRequired = ["yt-dlp", "ffmpeg", "ffprobe"]
    static var required: [String] { coreRequired }
    static let conditional = ["deno"]

    var missing: [String] { Self.coreRequired.filter { tools[$0] == nil } }
    var ready: Bool { missing.isEmpty }
    var brew: String? { tools["brew"] }
    var hasDeno: Bool { tools["deno"] != nil }

    static var managedDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return appSupport.appendingPathComponent("Lattice/VideoDownloader/bin", isDirectory: true)
    }

    init(tools: [String: String], environment: [String: String], isManaged: Bool = false) {
        self.tools = tools
        self.environment = environment
        self.isManaged = isManaged
    }

    static func discover(environment: [String: String] = ProcessInfo.processInfo.environment,
                         managedBinURL: URL = managedDirectory,
                         useSystemTools: Bool = UserDefaults.standard.bool(forKey: DefaultsKey.videoDownloaderUseSystemTools),
                         executable: (String) -> Bool = FileManager.default.isExecutableFile(atPath:)) -> Self {
        var paths: [String: String] = [:]
        let managedPath = managedBinURL.path

        // Check managed directory first unless user explicitly configured system tools
        if !useSystemTools {
            for tool in coreRequired + conditional {
                let candidate = (managedPath as NSString).appendingPathComponent(tool)
                if executable(candidate) {
                    paths[tool] = candidate
                }
            }
        }

        // If core tools still missing, check system PATH and Homebrew locations
        let systemDirs = (["/opt/homebrew/bin", "/usr/local/bin", NSHomeDirectory() + "/.local/bin"]
            + (environment["PATH"] ?? "").split(separator: ":").map(String.init)
            + ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]).filter { $0.hasPrefix("/") }

        for tool in coreRequired + conditional + ["brew"] {
            if paths[tool] == nil {
                paths[tool] = systemDirs.map { URL(fileURLWithPath: $0).appendingPathComponent(tool).path }.first(where: executable)
            }
        }

        var env = environment
        let combinedDirs = [managedPath] + systemDirs
        env["PATH"] = Array(NSOrderedSet(array: combinedDirs)).compactMap { $0 as? String }.joined(separator: ":")
        env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        env["HOMEBREW_NO_INSTALL_CLEANUP"] = "1"
        env["HOMEBREW_NO_ENV_HINTS"] = "1"

        let isManaged = paths["yt-dlp"]?.hasPrefix(managedPath) == true
        return Self(tools: paths, environment: env, isManaged: isManaged)
    }

    var installArguments: [String] {
        var formulae: [String] = []
        if missing.contains("yt-dlp") { formulae.append("yt-dlp") }
        if missing.contains("ffmpeg") || missing.contains("ffprobe") { formulae.append("ffmpeg") }
        if tools["deno"] == nil { formulae.append("deno") }
        return ["install"] + formulae
    }

    var runtimeArguments: [String] {
        guard let deno = tools["deno"] else { return [] }
        return ["--js-runtimes", "deno:\(deno)"]
    }
}
