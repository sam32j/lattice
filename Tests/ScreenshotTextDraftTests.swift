// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit

enum ScreenshotTextDraftTests {
    typealias Snapshot = (image: CGImage, annotations: [ScreenshotSupport.Annotation])
    class State {
        static let undoLimit = 60
        let baseImage: CGImage
        var annotations: [ScreenshotSupport.Annotation] = []
        var undoStack: [Snapshot] = [], redoStack: [Snapshot] = []
        var selectedID: UUID?, editingTextID: UUID?, newTextID: UUID?, draftID: UUID?
        var dragStart = CGPoint.zero, cropLoupePoint: CGPoint?
        var dragRegistered = false, editingSelectedAnnotation = false
        var duplicateOnDrag = false
        var activeHandle: ScreenshotSupport.Handle?
        var cropDraft: CGRect?, cropResizeOrigin: CGRect?, cropMoveOrigin: CGRect?, cropSelectionOrigin: CGRect?
        var tool = ScreenshotSupport.Tool.text
        var cropAspect = ScreenshotCropAspect.free
        var color = ScreenshotSupport.ColorID.red
        var stroke = ScreenshotSupport.StrokeID.medium
        var textSize = 18, blurLevel = 10
        var blurStyle = ScreenshotSupport.BlurStyleID.pixelate
        var blurTextOnly = false
        var arrowStyle = ScreenshotSupport.ArrowStyleID.filled
        var sticker = ScreenshotSupport.StickerID.allCases[0]
        var scale: CGFloat = 1
        var isDirty = false, canUndo = false, canRedo = false
        var imageSize: CGSize { CGSize(width: baseImage.width, height: baseImage.height) }
        var picksExisting = false
        init(_ image: CGImage) { baseImage = image }
        func selectedAnnotationOwns(_ point: CGPoint) -> Bool { false }
        func beginSelectDrag(at point: CGPoint) {}
        func finishSelectDrag(at point: CGPoint, isTap: Bool) {}
        func selectExistingAnnotation(at point: CGPoint) -> Bool { picksExisting }
        func ensureBlurSample(_ style: ScreenshotSupport.BlurStyleID, level: Int) {}
        func refreshUndoFlags() { canUndo = !undoStack.isEmpty; canRedo = !redoStack.isEmpty }
        func refreshDirtyState() { isDirty = !annotations.isEmpty }
    }
    final class NSWindow {
        var level = AppKit.NSWindow.Level.normal
    }
    final class NSAlert {
        enum Style { case warning }
        enum Response { case alertFirstButtonReturn, cancelled }
        static var presentations = 0
        var window = NSWindow()
        var messageText = "", informativeText = ""
        var alertStyle = Style.warning
        func addButton(withTitle title: String) {}
        func runModal() -> Response { Self.presentations += 1; return .cancelled }
    }
    class ControllerState {
        let model: Model
        let strings = FeatureStrings.screenshot(.enUS)
        init(_ model: Model) { self.model = model }
    }
    static func run(_ suite: TestSuite) {
        guard let image = CGContext(data: nil, width: 500, height: 500, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage() else { return }
        let model = Model(image)
        model.redoStack = [(image, [])]
        model.refreshUndoFlags()
        model.beginDrag(at: .zero)
        model.endDrag(at: CGPoint(x: 2, y: 2), isTap: false)
        suite.expect(model.annotations.isEmpty && !model.canUndo && model.canRedo && !model.isDirty,
                     "discarding an undersized text draft preserves redo and clean document state")
        model.picksExisting = true
        model.beginDrag(at: .zero)
        model.endDrag(at: .zero, isTap: true)
        suite.expect(model.annotations.isEmpty && model.redoStack.count == 1 && model.undoStack.isEmpty,
                     "using the text tool to select an existing mark preserves undo and redo")
        model.picksExisting = false
        model.beginDrag(at: .zero)
        model.annotations[0].rect = CGRect(x: 20, y: 30, width: 80, height: 60)
        model.endDrag(at: CGPoint(x: 100, y: 90), isTap: false)
        let emptyID = model.annotations[0].id
        let controller = Controller(model)
        suite.expect(model.isDirty && model.undoStack.isEmpty && model.canRedo,
                     "an active new text draft is dirty without consuming redo or creating undo")
        NSAlert.presentations = 0
        suite.expect(!controller.windowShouldClose(NSWindow()) && NSAlert.presentations == 1,
                     "native close asks before discarding text that is still being edited")
        model.commitText(emptyID, text: "  ")
        suite.expect(controller.windowShouldClose(NSWindow()) && NSAlert.presentations == 1,
                     "discarding an empty text draft restores clean close behavior")
        suite.expect(model.annotations.isEmpty && model.canRedo && !model.canUndo && !model.isDirty,
                     "discarding an empty accepted-size text box preserves redo and clean state")
        model.beginDrag(at: .zero)
        model.annotations[0].rect = CGRect(x: 20, y: 30, width: 80, height: 60)
        model.endDrag(at: CGPoint(x: 100, y: 90), isTap: false)
        let id = model.annotations[0].id
        model.commitText(id, text: "a long line of text that wraps over several lines")
        suite.expect(model.undoStack.count == 1 && model.undoStack[0].annotations.isEmpty
                     && model.redoStack.isEmpty, "committing new text records exactly one undo from the clean document")
        model.textSize = 28
        model.applyStyleToSelection()
        suite.expect(model.annotations[0].isBounded && abs(model.annotations[0].rect.width - 80) < 1,
                     "changing bounded text size preserves its wrap width")
        suite.expect(model.annotations[0].rect.height > 60,
                     "bounded text grows vertically after increasing its font size")
    }
}
