// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum NotchEditorDropTests {
    private typealias Context = ShelfDropRoutingContract
    static func run(_ suite: TestSuite) {
        let board = NSPasteboard.withUniqueName()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let screenshotWasAvailable = Context.AppFeature.screenshot.isAvailable
        let shelfWasAvailable = Context.AppFeature.shelf.isAvailable
        defer {
            Context.AppFeature.screenshot.isAvailable = screenshotWasAvailable
            Context.AppFeature.shelf.isAvailable = shelfWasAvailable
            Context.MediaEditorFileOpener.shared.opened = []
            board.releaseGlobally()
            try? FileManager.default.removeItem(at: folder)
        }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let image = folder.appendingPathComponent("image.png")
            try Data([0]).write(to: image)
            board.writeObjects([image as NSURL])
            Context.AppFeature.screenshot.isAvailable = true
            Context.AppFeature.shelf.isAvailable = false
            let service = Context.Notch()
            service.modules = [.captures]
            service.beginFileDrop(board)
            suite.expect(service.editorDropAvailable && service.choosingFileDropDestination
                         && service.opened == [.captures],
                         "an installed image editor offers Island drops without requiring Shelf")
            let area = NotchFileToolsSupport.mediaDropArea(in: service.expandedGeometry, size: service.surfaceSize)
            suite.expect(service.updateFileDrop(at: CGPoint(x: area.midX, y: area.midY)) && service.targetsEditorDrop,
                         "the editor-only right destination accepts the supported file")
            suite.expect(service.accept(board) && Context.MediaEditorFileOpener.shared.opened == [image]
                         && !service.choosingFileDropDestination && !service.targetsEditorDrop,
                         "editor drops deliver the file and clear transient drop state")
            Context.MediaEditorFileOpener.shared.opened = []
            service.beginFileDrop(board)
            _ = service.updateFileDrop(at: CGPoint(x: area.midX, y: area.midY))
            Context.AppFeature.screenshot.isAvailable = false
            suite.expect(!service.accept(board) && Context.MediaEditorFileOpener.shared.opened.isEmpty,
                         "uninstalling the editor during a drag prevents delivery")
        } catch { suite.expect(false, "editor drop fixture: \(error)") }
    }
}
