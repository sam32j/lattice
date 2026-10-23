import Foundation

enum VideoDownloaderServiceTests {
    static func run(_ suite: TestSuite) {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent("com.vorssaint.tests.video-service-\(UUID())")
        defer { try? fm.removeItem(at: folder) }
        func settle(_ model: VideoDownloader) {
            let deadline = Date().addingTimeInterval(5)
            while model.busy && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        }
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: false)
            let tool = folder.appendingPathComponent("tool")
            try fm.copyItem(at: URL(fileURLWithPath: "Tests/Fixtures/VideoDownloader/tool.sh"), to: tool)
            try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: tool.path)
            let tools = Dictionary(uniqueKeysWithValues: VideoDownloadDependencies.required.map { ($0, tool.path) })
            let dependencies = VideoDownloadDependencies(tools: tools, environment: ["PATH": "/usr/bin:/bin"])
            let model = VideoDownloader(discover: { dependencies })
            model.link = "https://example.invalid/fixture"
            model.fetchInfo(); settle(model)
            suite.expect(model.info?.title == "Test video" && model.selectedHeight == 720 && model.error == nil,
                         "local tool metadata populates the quality selector without network access")
            model.selectDestination(folder)
            let existing = folder.appendingPathComponent("Test video.mp4")
            try Data("existing".utf8).write(to: existing)
            model.download(); settle(model)
            suite.expect(model.output?.lastPathComponent == "Test video (2).mp4" && model.error == nil,
                         "the complete inspect/select/download/probe workflow publishes without overwriting")
            suite.expect(try Data(contentsOf: existing) == Data("existing".utf8), "pre-existing downloads remain untouched")
            suite.expect(try fm.contentsOfDirectory(atPath: folder.path).allSatisfy { !$0.hasPrefix(".lattice-download-") },
                         "owned staging is cleaned after successful publication")
            model.link = "https://example.invalid/different"; model.linkChanged()
            suite.expect(model.info == nil && model.output == nil, "editing a link invalidates old quality/results")
        } catch { suite.expect(false, "isolated downloader workflow: \(error)") }
    }
}
