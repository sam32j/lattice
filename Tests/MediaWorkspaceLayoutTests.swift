// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Measures production layout and native drop registration without displaying
/// a window, capturing pixels, or sending any input to the user's session.
enum MediaWorkspaceLayoutTests {
    final class Fixture: ObservableObject {
        @Published var height: CGFloat = 180
    }

    final class DropFixture {
        var tool = MediaTool.videoCompressor
        var running = false
        var pendingDrop: UUID?
        var inputs: [URL] = []
        var rejections = 0
        func rejectUnsupportedInput() { rejections += 1 }
    }

    final class Selection {
        var events: [String] = []
        var tool = MediaTool.videoCompressor {
            didSet { events.append("content:\(tool.rawValue)") }
        }
    }

    final class Presentation {
        let archives: ShelfDropRoutingContract.NotchFileToolsService
        var heights: [CGFloat] = []
        init(_ archives: ShelfDropRoutingContract.NotchFileToolsService) { self.archives = archives }
        func refreshPresentation() {
            if let height = archives.mediaContentHeight { heights.append(height) }
        }
    }

    class HeightState {
        let archives = ShelfDropRoutingContract.NotchFileToolsService()
        lazy var service = Presentation(archives)
    }

    static func run(_ suite: TestSuite) {
        func settle(_ condition: () -> Bool) -> Bool {
            let deadline = Date().addingTimeInterval(2)
            while !condition(), Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.01))
            }
            return condition()
        }
        let fixture = Fixture()
        let fileView = FileView()
        _ = fileView.archives.openMedia(.videoCompressor, inputs: [])
        let sessionID = fileView.archives.mediaSession!.id
        var measured: CGFloat = 0
        let host = NSHostingView(rootView: Workspace(fixture: fixture, onContentHeightChange: {
            measured = $0
            fileView.mediaHeightChanged($0, id: sessionID)
        }))
        host.frame = CGRect(x: 0, y: 0, width: 380, height: 700)
        host.layoutSubtreeIfNeeded()
        suite.expect(settle { measured == 246 },
               "embedded media reports the intrinsic height of header, picker, spacing and content instead of the viewport")
        for height: CGFloat in [80, 550, 180] {
            fixture.height = height
            host.layoutSubtreeIfNeeded()
            suite.expect(settle { measured == height + 66 },
                   "media's reported height follows options and results as they grow or shrink")
            suite.expect(fileView.service.heights.last == measured,
                   "the native window receives its new size in the measurement callback, before a later preferences refresh")
        }
        let frames = fileView.service.heights
        fileView.mediaHeightChanged(measured, id: sessionID)
        fileView.mediaHeightChanged(999, id: UUID())
        fileView.mediaHeightChanged(.nan, id: sessionID)
        suite.expect(fileView.service.heights == frames,
               "duplicate, invalid and stale measurements never restart the resize")

        let selection = Selection()
        let picker = ToolPicker(fixture: selection, onToolChange: {
            selection.events.append("transition:\(selection.tool.rawValue)")
        })
        for tool in [MediaTool.gifMaker, .textExtractor, .imageCompressor, .videoCompressor] {
            let previous = selection.tool
            selection.events = []
            picker.selectedToolBinding.wrappedValue = tool
            suite.expect(selection.events == ["transition:\(previous.rawValue)", "content:\(tool.rawValue)"],
                   "each tool change captures the old content for its transition before replacing the controls")
            selection.events = []
            picker.selectedToolBinding.wrappedValue = tool
            suite.expect(selection.events.isEmpty, "reselecting the current tool does not reset work or restart its animation")
        }

        func types(in view: NSView) -> Set<NSPasteboard.PasteboardType> {
            view.subviews.reduce(into: Set(view.registeredDraggedTypes)) { $0.formUnion(types(in: $1)) }
        }
        for direct in [true, false] {
            let input = NSHostingView(rootView: Input(acceptsDirectDrops: direct))
            input.frame = CGRect(x: 0, y: 0, width: 300, height: 70)
            input.layoutSubtreeIfNeeded()
            _ = input.fittingSize
            suite.expect(direct ? settle { !types(in: input).isEmpty } : types(in: input).isEmpty,
                         "the media tool accepts a direct drop while the Files session leaves its chooser in control")
        }
        inputDelivery(suite, settle: settle)
    }

    private static func inputDelivery(_ suite: TestSuite, settle: (() -> Bool) -> Bool) {
        typealias Routing = ShelfDropRoutingContract
        let board = NSPasteboard.withUniqueName()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let previousShelf = Routing.UserDefaults.standard.enabled
        defer {
            board.releaseGlobally()
            try? FileManager.default.removeItem(at: directory)
            Routing.UserDefaults.standard.enabled = previousShelf
        }
        func provider(_ url: URL) -> NSItemProvider {
            NSItemProvider(item: url as NSURL, typeIdentifier: UTType.fileURL.identifier)
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
            let image = directory.appendingPathComponent("sample.png")
            let video = directory.appendingPathComponent("clip.mp4")
            let note = directory.appendingPathComponent("notes.txt")
            for url in [image, video, note] { try Data([0]).write(to: url) }
            let selection = DropFixture()
            let receiver = Input(acceptsDirectDrops: true, fixture: selection)
            let notch = Routing.Notch()
            notch.directMediaDropWorkspace = selection
            for shelfEnabled in [false, true] {
                Routing.UserDefaults.standard.enabled = shelfEnabled
                for (tool, url) in [(MediaTool.videoCompressor, video), (.gifMaker, video),
                                    (.imageCompressor, image), (.textExtractor, image)] {
                    board.clearContents()
                    board.writeObjects([url as NSURL])
                    notch.beginFileDrop(board)
                    suite.expect(notch.opened.isEmpty && !notch.choosingFileDropDestination,
                                 "entering from the edge leaves the active media card visible with Shelf on or off")
                    selection.tool = tool
                    selection.inputs = []
                    suite.expect(receiver.acceptDrop([provider(url)]) && settle { selection.inputs == [url] },
                                 "Finder file reaches the selected \(tool.rawValue) tool with Shelf enabled=\(shelfEnabled)")
                }
            }
            selection.tool = .imageCompressor
            selection.inputs = []
            suite.expect(receiver.acceptDrop([provider(image), provider(note)])
                            && settle { selection.rejections == 1 } && selection.inputs.isEmpty,
                         "unsupported companions cannot be dropped silently from an image batch")
            let second = directory.appendingPathComponent("second.png")
            try Data([1]).write(to: second)
            suite.expect(receiver.acceptDrop([provider(second), provider(image)])
                            && settle { selection.inputs == [second, image] },
                         "a supported image batch arrives together in provider order")
            selection.running = true
            suite.expect(!receiver.acceptDrop([provider(image)]) && selection.inputs == [second, image],
                         "dropping on a running conversion cannot replace the active inputs")
            selection.running = false
            suite.expect(receiver.acceptDrop([provider(image)]), "a drop can start loading while idle")
            selection.running = true
            suite.expect(settle { selection.pendingDrop == nil } && selection.inputs == [second, image]
                            && selection.rejections == 1,
                         "a conversion started during provider loading keeps its inputs and running state")
            notch.directMediaDropWorkspace = nil
            notch.beginFileDrop(board)
            suite.expect(notch.choosingFileDropDestination && notch.opened == [.files],
                         "after closing the media tool, the island offers Files and Optimize again")
        } catch {
            suite.expect(false, "could not create media drop fixture: \(error)")
        }
    }
}
