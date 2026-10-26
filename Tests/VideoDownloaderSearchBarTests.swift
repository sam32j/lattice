// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import SwiftUI

/// The actual island input/paste controls with a mutable injected clipboard.
enum VideoDownloaderSearchBarTests {
    static func run(_ suite: TestSuite) {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent("io.github.sam32j.lattice.tests.video-search-\(UUID())")
        defer { try? fm.removeItem(at: folder) }
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: false)
            let tool = folder.appendingPathComponent("tool")
            try fm.copyItem(at: URL(fileURLWithPath: "Tests/Fixtures/VideoDownloader/tool.sh"), to: tool)
            try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: tool.path)
            let dependencies = VideoDownloadDependencies(tools: Dictionary(uniqueKeysWithValues:
                VideoDownloadDependencies.required.map { ($0, tool.path) }), environment: ["PATH": "/usr/bin:/bin"])
            var clipboard: String? = "https://example.invalid/A"
            let model = VideoDownloader(discover: { dependencies },
                historyStore: DownloadHistoryStore(storeURL: folder.appendingPathComponent("history.json")),
                completionFeedback: {}, readClipboard: { clipboard })
            defer { model.teardown() }
            _ = NSApplication.shared
            let host = NSHostingView(rootView: VideoDownloaderSearchBar(downloader: model, isSettingsPreview: false))
            let window = NSWindow(contentRect: CGRect(x: -10_000, y: -10_000, width: 600, height: 80),
                                  styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            let getter = NSSelectorFromString("accessibilityAttributeValue:")
            let setter = NSSelectorFromString("accessibilitySetValue:forAttribute:")
            let prior = NSApp.perform(getter, with: "AXEnhancedUserInterface")?.takeUnretainedValue() as? NSNumber ?? false
            NSApp.perform(setter, with: true, with: "AXEnhancedUserInterface")
            defer {
                NSApp.perform(setter, with: prior, with: "AXEnhancedUserInterface")
                window.orderOut(nil); window.contentView = nil; window.close()
            }
            window.orderFront(nil)
            settle(0.15)
            let paste = find("video-downloader.paste", in: host)
            suite.expect(paste != nil, "a clipboard URL exposes the island Paste control")
            clipboard = "https://example.invalid/B"
            _ = paste?.accessibilityPerformPress?()
            suite.expect(model.link == clipboard, "Paste uses clipboard B without waiting for a mount or refresh")
            model.link = ""
            settle(0.05)
            clipboard = "https://example.invalid/C"
            _ = find("video-downloader.paste", in: host)?.accessibilityPerformPress?()
            suite.expect(model.link == clipboard, "clearing and pasting again reads the newest clipboard value")
            clipboard = nil
            model.link = ""
            settle(0.65)
            suite.expect(find("video-downloader.paste", in: host) == nil, "clipboard availability refreshes while the island remains open")
            clipboard = "https://example.invalid/D"
            settle(0.65)
            suite.expect(find("video-downloader.paste", in: host) != nil, "new clipboard URLs appear without remounting")
            model.link = "https://example.invalid/slow-download"
            model.fetchInfo()
            wait { !model.busy }
            model.selectDestination(folder)
            model.download()
            settle(0.05)
            suite.expect(textFields(in: host).contains { !$0.isEnabled }, "the native URL input is disabled while a download runs")
            model.pause()
            settle(0.05)
            suite.expect(textFields(in: host).contains { !$0.isEnabled }, "pausing a download keeps the URL input locked")
            model.resume()
            wait { !model.busy }
            settle(0.05)
            suite.expect(textFields(in: host).contains { $0.isEnabled }, "completion restores the URL input")
        } catch { suite.expect(false, "isolated island search controls: \(error)") }
    }
    private static func settle(_ interval: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(interval))
    }
    private static func wait(until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(5)
        while !condition(), Date() < deadline { settle(0.01) }
    }
    private static func find(_ identifier: String, in element: AnyObject) -> AnyObject? {
        if element.accessibilityIdentifier?() == identifier { return element }
        for child in element.accessibilityChildren?() ?? [] {
            if let found = find(identifier, in: child as AnyObject) { return found }
        }
        return nil
    }
    private static func textFields(in view: NSView) -> [NSTextField] {
        (view as? NSTextField).map { [$0] } ?? view.subviews.flatMap { textFields(in: $0) }
    }
}
