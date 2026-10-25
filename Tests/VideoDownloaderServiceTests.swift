import AppKit
import Foundation

enum VideoDownloaderServiceTests {
    static func run(_ suite: TestSuite) {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent("io.github.sam32j.lattice.tests.video-service-\(UUID())")
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
            let testHistory = DownloadHistoryStore(storeURL: folder.appendingPathComponent("test-history.json"))
            let model = VideoDownloader(discover: { dependencies }, historyStore: testHistory)
            model.link = "https://example.invalid/fixture"
            model.fetchInfo()
            suite.expect(model.isFetching && !model.isDownloading, "isFetching is true and isDownloading is false during fetchInfo")
            settle(model)
            suite.expect(!model.isFetching && model.info?.title == "Test video" && model.selectedHeight == 720 && model.error == nil,
                         "local tool metadata populates the quality selector without network access")
            model.selectDestination(folder)
            let existing = folder.appendingPathComponent("Test video.mp4")
            try Data("existing".utf8).write(to: existing)
            model.download()
            suite.expect(model.isDownloading && !model.isFetching, "isDownloading is true and isFetching is false during download")
            settle(model)
            suite.expect(!model.isDownloading && model.output?.lastPathComponent == "Test video (2).mp4" && model.error == nil,
                         "the complete inspect/select/download/probe workflow publishes without overwriting")
            suite.expect(try Data(contentsOf: existing) == Data("existing".utf8), "pre-existing downloads remain untouched")
            suite.expect(try fm.contentsOfDirectory(atPath: folder.path).allSatisfy { !$0.hasPrefix(".lattice-download-") },
                         "owned staging is cleaned after successful publication")
            suite.expect(model.destination == folder, "destination selection is preserved on the model")
            model.resetDownloadState()
            suite.expect(model.output == nil, "resetDownloadState clears the output so options can be adjusted")
            model.pause()
            suite.expect(!model.isPaused, "cannot pause when not actively downloading")
            model.link = "https://example.invalid/different"; model.linkChanged()
            suite.expect(model.info == nil && model.output == nil, "editing a link invalidates old quality/results")

            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("https://example.invalid/pasted-link", forType: .string)
            model.pasteFromClipboard()
            suite.expect(model.link == "https://example.invalid/pasted-link" && !model.isFetching && model.info == nil,
                         "pasting from clipboard only populates the link without triggering fetch")
        } catch { suite.expect(false, "isolated downloader workflow: \(error)") }
    }
}
