// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum RecorderExportControlsTests {
    static func run(_ suite: TestSuite) {
        let model = RecorderExportControlsFixture()
        model.document.exportFormat = "gif"
        model.document.gifScalePercent = 50
        suite.expect(model.exportSize == CGSize(width: 960, height: 540),
                     "editor dimensions follow selected GIF scale independently of video quality")
        model.document.gifScalePercent = 1
        suite.expect(model.exportSize == CGSize(width: 56, height: 32),
                     "editor GIF dimensions reflect the encoder minimum short side")
        model.setExportFormat(.video)
        suite.expect(model.exportSize == CGSize(width: 1920, height: 1080),
                     "switching back to video restores its independent quality dimensions")
        model.setGIFScalePercent(75)
        model.setGIFFrameRate(20)
        model.setExportFormat(.gif)
        suite.expect(model.document.quality == "balanced"
            && model.document.resolvedGIFScalePercent == 75
            && model.document.resolvedGIFFrameRate == 20,
                     "format, GIF size and FPS edits preserve independent video quality")
        let beforeBusyEdit = model.document
        model.isExporting = true
        model.setExportFormat(.video)
        model.setGIFScalePercent(50)
        model.setGIFFrameRate(10)
        suite.expect(model.document == beforeBusyEdit,
                     "export controls reject edits while export is in progress")

        let actions = RecorderExportActionFixture()
        for format in [RecorderSupport.ExportFormat.video, .gif] {
            actions.model.setExportFormat(format)
            actions.save()
            let ext = format == .gif ? "gif" : "mp4"
            suite.expect(actions.saved?.1.pathExtension == ext,
                         "primary save chooses the selected format extension")
            switch (format, actions.saved?.0) {
            case (.video, .video?), (.gif, .gif?): break
            default: suite.expect(false, "primary save chooses the selected encoder")
            }
            actions.copySelected()
            suite.expect(actions.copied?.0 == format && actions.copied?.1 == false,
                         "primary copy chooses the selected encoder without deleting")
            actions.copyAndDelete()
            suite.expect(actions.copied?.0 == format && actions.copied?.1 == true,
                         "copy and delete chooses the selected encoder")
            let selection = RecorderEditorExportSelection(format: format)
            suite.expect(selection.contentType.identifier == (format == .gif ? "com.compuserve.gif" : "public.mpeg-4"),
                         "Save As uses the selected format content type")
        }
        let pendingCopy = RecorderExportActionFixture()
        var didProduceClipboardFile = false
        pendingCopy.run(.gif, to: URL(fileURLWithPath: "/tmp/copy.gif"),
                        rememberDestination: false) { _ in didProduceClipboardFile = true }
        pendingCopy.model.completion?(nil)
        suite.expect(didProduceClipboardFile && !(pendingCopy.preservedExportURL != nil),
                     "producing a clipboard file does not mark the recording safe before publication")
        pendingCopy.finishClipboardPublication(false, url: nil, deletesRecording: true)
        suite.expect(!(pendingCopy.preservedExportURL != nil) && !pendingCopy.confirmedClose && pendingCopy.window?.closes == 0,
                     "failed publication after a successful GIF export preserves close confirmation")
        let failedSave = RecorderExportActionFixture()
        failedSave.save()
        failedSave.model.completion?(.writeFailed)
        suite.expect(!(failedSave.preservedExportURL != nil),
                     "failed save does not mark the recording safely exported")
        let successfulSave = RecorderExportActionFixture()
        successfulSave.save()
        successfulSave.model.completion?(nil)
        suite.expect((successfulSave.preservedExportURL != nil),
                     "successful save still marks a recording safely exported")
        let lane = RecorderExportActionFixture.GeneralPasteboardAccess.shared
        let cancelledCopy = RecorderExportActionFixture()
        cancelledCopy.model.document.exportSpeed = 2
        cancelledCopy.startGIFCopy(true)
        suite.expect(!cancelledCopy.model.lastMarksSaved,
                     "GIF clipboard export defers marking the document saved until publication succeeds")
        cancelledCopy.model.completion?(nil)
        suite.expect(cancelledCopy.model.isModified,
                     "completing the GIF encode does not mark the edit saved before clipboard publication")
        let cancelledWork = lane.pending.removeFirst()
        suite.expect(cancelledCopy.model.isExporting,
                     "GIF publication remains busy while queued")
        cancelledCopy.model.cancelExport()
        suite.expect(!cancelledCopy.model.isExporting,
                     "cancelling queued GIF publication immediately releases the editor")
        let publicationsBeforeCancel = RecorderExportActionFixture.RecorderGIFClipboard.publications
        let queuedResult = cancelledWork.work()
        suite.expect(RecorderExportActionFixture.RecorderGIFClipboard.publications == publicationsBeforeCancel,
                     "cancelled queued GIF work never touches the clipboard")
        cancelledWork.completion(queuedResult)
        cancelledWork.completion(true)
        suite.expect(!(cancelledCopy.preservedExportURL != nil) && !cancelledCopy.confirmedClose
            && cancelledCopy.window?.closes == 0 && cancelledCopy.model.isModified,
                     "late GIF publication success after cancellation cannot mark saved, mark safe, or close and delete")

        let committedCopy = RecorderExportActionFixture()
        committedCopy.model.document.exportSpeed = 2
        committedCopy.startGIFCopy(true)
        committedCopy.model.completion?(nil)
        let committedWork = lane.pending.removeFirst()
        let committedResult = committedWork.work() // Claims commit before cancel arrives.
        committedCopy.model.cancelExport()
        suite.expect(committedResult && committedCopy.model.isExporting,
                     "a cancel after the pasteboard commit is claimed does not suppress the publication")
        committedWork.completion(committedResult)
        suite.expect(!committedCopy.model.isExporting && committedCopy.preservedExportURL != nil
            && committedCopy.confirmedClose && committedCopy.window?.closes == 1
            && !committedCopy.model.isModified,
                     "a committed GIF publication still completes and marks the exported snapshot saved")

        let staleCopy = RecorderExportActionFixture()
        staleCopy.startGIFCopy(true)
        staleCopy.model.completion?(nil)
        let firstWork = lane.pending.removeFirst()
        staleCopy.model.cancelExport()
        _ = firstWork.work()
        staleCopy.model.isExporting = true // A later encoder now owns busy state.
        firstWork.completion(true)
        suite.expect(staleCopy.model.isExporting && !(staleCopy.preservedExportURL != nil) && staleCopy.window?.closes == 0,
                     "stale publication completion cannot clear a later export's busy state or close it")

        let normalCopy = RecorderExportActionFixture()
        normalCopy.model.document.exportSpeed = 2
        normalCopy.startGIFCopy(true)
        normalCopy.model.document.exportSpeed = 3 // Edit made while export is in flight.
        normalCopy.model.completion?(nil)
        let normalWork = lane.pending.removeFirst()
        normalWork.completion(normalWork.work())
        suite.expect(!normalCopy.model.isExporting && (normalCopy.preservedExportURL != nil)
            && normalCopy.confirmedClose && normalCopy.window?.closes == 1
            && normalCopy.model.isModified && normalCopy.model.initialDocument?.exportSpeed == 2,
                     "uncancelled GIF publication marks the exported snapshot saved, not later edits")

        let failedCopy = RecorderExportActionFixture()
        failedCopy.model.document.exportSpeed = 2
        failedCopy.startGIFCopy(false)
        failedCopy.model.completion?(nil)
        let failedWork = lane.pending.removeFirst()
        _ = failedWork.work()
        failedWork.completion(false)
        suite.expect(failedCopy.model.isModified && failedCopy.preservedExportURL == nil,
                     "failed GIF clipboard publication leaves the document modified")
        actions.finishClipboardPublication(false, url: nil, deletesRecording: true)
        suite.expect(!(actions.preservedExportURL != nil) && !actions.confirmedClose && actions.window?.closes == 0,
                     "failed clipboard publication never marks a source safe or closes and deletes it")
        actions.finishClipboardPublication(true, url: URL(fileURLWithPath: "/tmp/copy.gif"), deletesRecording: false)
        suite.expect((actions.preservedExportURL != nil) && !actions.confirmedClose && actions.window?.closes == 0,
                     "successful copy keeps the editor open")
        actions.finishClipboardPublication(true, url: URL(fileURLWithPath: "/tmp/copy.gif"), deletesRecording: true)
        suite.expect(actions.confirmedClose && actions.window?.closes == 1,
                     "successful clipboard publication closes only when deletion was requested")
    }
}
