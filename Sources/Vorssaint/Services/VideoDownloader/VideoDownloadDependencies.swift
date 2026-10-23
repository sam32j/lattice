import Foundation

struct VideoDownloadDependencies {
    let tools: [String: String]
    let environment: [String: String]
    static let required = ["yt-dlp", "ffmpeg", "ffprobe", "deno"]
    var missing: [String] { Self.required.filter { tools[$0] == nil } }
    var ready: Bool { missing.isEmpty }
    var brew: String? { tools["brew"] }

    static func discover(environment: [String: String] = ProcessInfo.processInfo.environment,
                         executable: (String) -> Bool = FileManager.default.isExecutableFile(atPath:)) -> Self {
        let directories = (["/opt/homebrew/bin", "/usr/local/bin", NSHomeDirectory() + "/.local/bin"]
            + (environment["PATH"] ?? "").split(separator: ":").map(String.init)
            + ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]).filter { $0.hasPrefix("/") }
        var paths: [String: String] = [:]
        for tool in required + ["brew"] {
            paths[tool] = directories.map { URL(fileURLWithPath: $0).appendingPathComponent(tool).path }.first(where: executable)
        }
        var env = environment
        env["PATH"] = Array(NSOrderedSet(array: directories)) .compactMap { $0 as? String }.joined(separator: ":")
        env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        env["HOMEBREW_NO_INSTALL_CLEANUP"] = "1"
        env["HOMEBREW_NO_ENV_HINTS"] = "1"
        return Self(tools: paths, environment: env)
    }

    var installArguments: [String] {
        var formulae: [String] = []
        if missing.contains("yt-dlp") { formulae.append("yt-dlp") }
        if missing.contains("ffmpeg") || missing.contains("ffprobe") { formulae.append("ffmpeg") }
        if missing.contains("deno") { formulae.append("deno") }
        return ["install"] + formulae
    }

    var runtimeArguments: [String] {
        guard let deno = tools["deno"] else { return [] }
        return ["--js-runtimes", "deno:\(deno)"]
    }
}
