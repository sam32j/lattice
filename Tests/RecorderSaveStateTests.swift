// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum RecorderSaveStateTests {
    /// Only encoding is delayed; the model and controller completion bodies are production code.
    final class RecorderExporter {
        enum Output { case video }
        enum Failure { case failed, cancelled }
        static var reply: CheckedContinuation<Failure?, Never>?
        static var encoded: RecorderEditDocument?
        func export(take: Int, document: RecorderEditDocument, output: Output,
                    to url: URL, progress: @escaping (Double) -> Void) async -> Failure? {
            Self.encoded = document
            return await withCheckedContinuation { Self.reply = $0 }
        }
    }
    class ModelState {
        var document = RecorderEditDocument()
        var initialDocument: RecorderEditDocument? = RecorderEditDocument()
        let take = 1
        var isExporting = false
        var exportProgress = 0.0
        enum Phase { case saving }
        var exportPhase = Phase.saving
        var exporter: RecorderExporter?
        var lastExportedURL: URL?
        func pause() {}
    }
    class ControllerState {
        let model = Model()
        var preservedExportURL: URL?
        struct Strings { let savedHUDFormat = "Saved in %@"; let exportFailed = "failed" }
        let strings = Strings()
    }
    enum NSSound { static func beep() {} }
    enum QuickToolHUD { static func show(icon: String, message: String) {} }
    final class RecentCaptureService {
        static let shared = RecentCaptureService()
        func recordRecording(at url: URL) {}
    }

    static func wait(until finished: () -> Bool) {
        let deadline = Date().addingTimeInterval(2)
        while !finished(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    static func run(_ suite: TestSuite) {
        let destination = URL(fileURLWithPath: "/fixture/export.mp4")
        for changeDuringExport in [false, true] {
            RecorderExporter.reply = nil
            let controller = Controller()
            controller.model.document.exportSpeed = 2
            var completed = false
            controller.run(.video, to: destination) { _ in completed = true }
            wait { RecorderExporter.reply != nil }
            suite.expect(RecorderExporter.reply != nil && RecorderExporter.encoded?.exportSpeed == 2,
                         "export captures the document that was submitted to the encoder")
            if changeDuringExport { controller.model.document.exportSpeed = 3 }
            RecorderExporter.reply?.resume(returning: nil)
            RecorderExporter.reply = nil
            wait { completed }
            suite.expect(completed && controller.preservedExportURL == destination
                         && controller.model.isModified == changeDuringExport,
                         "only exported edits become saved; changeDuringExport=\(changeDuringExport)")
            if changeDuringExport {
                controller.model.document.exportSpeed = 2
                suite.expect(!controller.model.isModified,
                             "undoing later edits to the exported snapshot restores saved state")
            }
        }
        for failure in [RecorderExporter.Failure.failed, .cancelled] {
            let controller = Controller()
            controller.model.document.exportSpeed = 2
            controller.run(.video, to: destination)
            wait { RecorderExporter.reply != nil }
            RecorderExporter.reply?.resume(returning: failure)
            RecorderExporter.reply = nil
            wait { !controller.model.isExporting }
            suite.expect(controller.model.isModified && controller.preservedExportURL == nil,
                         "failed or cancelled exports never mark edits saved")
        }
    }
}
