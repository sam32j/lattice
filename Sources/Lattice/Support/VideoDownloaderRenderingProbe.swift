#if LATTICE_DEVELOPMENT
import AppKit
import SwiftUI

enum VideoDownloaderRenderingProbe {
    static func run(output: URL, failures: inout [String]) {
        guard Bundle.main.bundleIdentifier?.hasPrefix("io.github.sam32j.lattice.tests.") == true else {
            failures.append("Downloader rendering requires an isolated test bundle."); return
        }
        let absentDeps = { VideoDownloadDependencies.discover(environment: [:], executable: { _ in false }) }
        let absent = VideoDownloader(discover: absentDeps)
        let absentToolchain = ToolchainManager(discover: absentDeps)
        SettingsRefactorProbe.render("video-downloader-setup", view: AnyView(VideoDownloaderSettings(model: absent, toolchain: absentToolchain)),
            size: CGSize(width: 760, height: 900), output: output, failures: &failures)
        guard let index = CommandLine.arguments.firstIndex(of: "--video-fixture"),
              CommandLine.arguments.indices.contains(index + 1) else {
            failures.append("Downloader detail rendering needs a local protocol fixture."); return
        }
        let tool = CommandLine.arguments[index + 1]
        guard tool.hasPrefix("/tmp/") || tool.hasPrefix(NSTemporaryDirectory()) else {
            failures.append("Downloader fixture must live in a temporary directory."); return
        }
        let tools = Dictionary(uniqueKeysWithValues: VideoDownloadDependencies.required.map { ($0, tool) })
        let readyDeps = { VideoDownloadDependencies(tools: tools, environment: ["PATH": "/usr/bin:/bin"]) }
        let model = VideoDownloader(discover: readyDeps)
        let readyToolchain = ToolchainManager(discover: readyDeps)
        model.link = "https://example.invalid/fixture"; model.fetchInfo()
        let deadline = Date().addingTimeInterval(5)
        while model.busy && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        if model.info == nil { failures.append("Downloader fixture did not populate the details.") }
        SettingsRefactorProbe.render("video-downloader-details", view: AnyView(VideoDownloaderSettings(model: model, toolchain: readyToolchain)),
            size: CGSize(width: 760, height: 1100), output: output, failures: &failures)
    }
}
#endif
