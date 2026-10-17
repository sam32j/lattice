// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum RecorderCloseSafetyTests {
    final class NSWindow {
        var closes = 0
        func close() { closes += 1 }
    }
    final class Model {
        var isModified = false
        var isExporting = false
        func cancelExport() { isExporting = false }
    }
    class State {
        let model = Model()
        var window: NSWindow? = NSWindow()
        var preservedRecordingURL: URL?
        var preservedExportURL: URL?
        var confirmedClose = false
        var confirmation: (() -> Void)?
        func askBeforeLosingTheRecording(_ confirmed: @escaping () -> Void) {
            confirmation = confirmed
        }
    }

    static func run(_ suite: TestSuite) {
        let unsafe = Controller()
        suite.expect(!unsafe.windowShouldClose(unsafe.window!) && unsafe.confirmation != nil,
                     "an unedited recording without a committed backup requires confirmation")
        let discard = Controller()
        discard.discard()
        suite.expect(discard.window?.closes == 0 && discard.confirmation != nil,
                     "discard does not silently delete an unpreserved recording")
        discard.confirmation?()
        suite.expect(discard.window?.closes == 1 && discard.windowShouldClose(discard.window!),
                     "explicit confirmation still permits discarding an unpreserved recording")

        let backup = FileManager.default.temporaryDirectory.appendingPathComponent("CloseSafety-\(UUID()).mov")
        defer { try? FileManager.default.removeItem(at: backup) }
        do {
            try Data("preserved recording".utf8).write(to: backup)
            let safe = Controller()
            safe.preservedRecordingURL = backup
            suite.expect(safe.windowShouldClose(safe.window!) && safe.confirmation == nil,
                         "a committed original permits closing an unchanged recording")
            safe.model.isModified = true
            suite.expect(!safe.windowShouldClose(safe.window!) && safe.confirmation != nil,
                         "preserving the original does not discard unsaved edits without confirmation")
            safe.model.isModified = false
            try FileManager.default.removeItem(at: backup)
            suite.expect(!safe.windowShouldClose(safe.window!),
                         "clearing history revokes permission to silently delete the editor's original")
            let saved = Controller()
            saved.preservedExportURL = backup
            try Data("exported recording".utf8).write(to: backup)
            suite.expect(saved.windowShouldClose(saved.window!),
                         "an unchanged recording with a successful export remains closable")
            try FileManager.default.removeItem(at: backup)
            suite.expect(!saved.windowShouldClose(saved.window!),
                         "removing the only exported copy requires confirmation before deleting the take")
        } catch {
            suite.expect(false, "close safety fixture: \(error)")
        }
    }
}
