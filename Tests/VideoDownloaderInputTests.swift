// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

enum VideoDownloaderInputTests {
    static func run(_ suite: TestSuite) {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent("io.github.sam32j.lattice.tests.video-input-\(UUID())")
        defer { try? fm.removeItem(at: folder) }
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: false)
            let tool = folder.appendingPathComponent("tool")
            try fm.copyItem(at: URL(fileURLWithPath: "Tests/Fixtures/VideoDownloader/tool.sh"), to: tool)
            try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: tool.path)
            let dependencies = VideoDownloadDependencies(tools: Dictionary(uniqueKeysWithValues:
                VideoDownloadDependencies.required.map { ($0, tool.path) }), environment: ["PATH": "/usr/bin:/bin"])
            let model = VideoDownloader(discover: { dependencies },
                historyStore: DownloadHistoryStore(storeURL: folder.appendingPathComponent("history.json")),
                completionFeedback: {}, readClipboard: { nil })
            defer { model.teardown() }
            func settle() {
                let deadline = Date().addingTimeInterval(5)
                while model.busy && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
            }
            model.link = "https://example.invalid/fixture"
            model.fetchInfo(); settle()
            suite.expect(model.hasCurrentSearchResult, "an unchanged successful search offers Clear")
            model.resetDownloadState()
            suite.expect(model.link.isEmpty && !model.hasCurrentSearchResult && model.info == nil,
                         "resetting download state clears link and current search result")
            model.link = "https://example.invalid/fixture"
            model.websiteFailure = .authentication
            model.error = VideoDownloaderStrings.loginRequiredNotice
            model.info = nil
            suite.expect(model.websiteFailure != nil && model.error == VideoDownloaderStrings.loginRequiredNotice && model.info == nil,
                         "failed fetch authentication error state has websiteFailure and unified loginRequiredNotice")
            model.resetDownloadState()
            suite.expect(model.link.isEmpty && model.error == nil && model.websiteFailure == nil,
                         "resetDownloadState on failed fetch clears link and error")
            model.link = "https://example.invalid/slow-inspect"
            model.fetchInfo()
            model.link = "https://example.invalid/new-draft"
            RunLoop.main.run(until: Date().addingTimeInterval(0.5))
            suite.expect(!model.busy && model.info == nil && !model.hasCurrentSearchResult,
                         "an edited in-flight search cannot put stale results back")
            model.link = "https://example.invalid/slow-download"
            model.fetchInfo(); settle()
            model.selectDestination(folder)
            model.download()
            model.link = "https://example.invalid/next-video"
            suite.expect(model.busy && model.isDownloading && !model.hasCurrentSearchResult,
                         "editing during download offers Search without canceling the captured download")
            settle()
            suite.expect(model.output != nil && model.error == nil && model.link == "https://example.invalid/next-video"
                         && !model.isCompletedSustaining,
                         "download completion preserves an edited draft rather than scheduling its removal")
            model.resetDownloadState()
            suite.expect(model.link == "https://example.invalid/next-video" && model.info == nil,
                         "leaving old results does not erase the next URL")
            model.link = "https://example.invalid/fail-download"
            model.fetchInfo(); settle()
            model.download()
            model.link = "https://example.invalid/replacement"
            settle()
            suite.expect(model.error != nil && model.info == nil && !model.hasCurrentSearchResult
                         && model.link == "https://example.invalid/replacement",
                         "a failed older download cannot expose stale Retry controls for an edited URL")
        } catch { suite.expect(false, "isolated downloader input lifecycle: \(error)") }
    }
}
