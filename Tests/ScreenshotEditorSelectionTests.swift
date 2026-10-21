// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// Runs the production selection methods without a window, OCR job or input tap.
enum ScreenshotEditorSelectionTests {
    class State {
        var annotations: [ScreenshotSupport.Annotation] = []
        var selectedIDs: Set<UUID> = []
        var selectedID: UUID? {
            get { selectedIDs.count == 1 ? selectedIDs.first : nil }
            set { selectedIDs = newValue.map { [$0] } ?? [] }
        }
        var editingTextID: UUID?, newTextID: UUID?
        var activeHandle: ScreenshotSupport.Handle?
        var moveOrigin = CGRect.zero
        var movePoints: [CGPoint] = []
        var dragStart = CGPoint.zero
        var dragRegistered = false
        var duplicateOnDrag = false
        var additiveSelectionClick = false
        var movingSelection: [ScreenshotSupport.Annotation] = []
        var moveTextSize = 18
        var scale: CGFloat = 1
        var tool = ScreenshotSupport.Tool.select
        var textSelectionEnabled = false
        var cornerRadiusEnabled = false
        var dirtyRefreshes = 0
        var textSelectionAnchor: CGPoint?
        var selectedWordIndexes: [Int] = []
        var textWords: [ScreenshotSupport.RecognizedWord] = []
        var imageSize = CGSize(width: 800, height: 600)
        var cropDraft: CGRect?
        var undoSnapshots: [[ScreenshotSupport.Annotation]] = []
        func registerUndo() { undoSnapshots.append(annotations) }
        func refreshDirtyState() { dirtyRefreshes += 1 }
        var color = ScreenshotSupport.ColorID.red
        var stroke = ScreenshotSupport.StrokeID.medium
        var textSize = 18
        var blurLevel = 3
        var blurStyle = ScreenshotSupport.BlurStyleID.pixelate
        var blurTextOnly = false
        var arrowStyle = ScreenshotSupport.ArrowStyleID.filled
        var sticker = ScreenshotSupport.StickerID.check
        func clearTextSelection() { selectedWordIndexes = [] }
        func wordIndex(at point: CGPoint) -> Int? { textWords.firstIndex { $0.rect.contains(point) } }
    }

    static func run(_ suite: TestSuite) {
        let style = Model()
        let shape = ScreenshotSupport.Annotation(tool: .rect, hasCornerRadius: false)
        style.annotations = [shape]
        style.selectedID = shape.id
        style.applyCornerRadiusToSelection()
        suite.expect(style.undoSnapshots.isEmpty && style.dirtyRefreshes == 0,
                     "selecting an unchanged corner style is not a document edit")
        style.cornerRadiusEnabled = true
        style.applyCornerRadiusToSelection()
        suite.expect(style.annotations[0].isRounded && style.undoSnapshots.first == [shape],
                     "changing corner style saves one undo snapshot of the unmodified shape")
        let model = Model()
        let resizing = Model()
        let box = ScreenshotSupport.Annotation(tool: .rect,
            rect: CGRect(x: 50, y: 50, width: 200, height: 120))
        resizing.annotations = [box]
        resizing.selectedID = box.id
        resizing.dragStart = CGPoint(x: 250, y: 170)
        resizing.beginSelectDrag(at: resizing.dragStart)
        resizing.duplicateOnDrag = true
        resizing.continueSelectDrag(to: CGPoint(x: 280, y: 200))
        suite.expect(resizing.annotations.count == 1 && resizing.annotations[0].id == box.id
                     && resizing.annotations[0].rect == CGRect(x: 50, y: 50, width: 230, height: 150),
                     "Option held on a resize grip resizes the original shape without duplicating it")
        for tool in [ScreenshotSupport.Tool.rect, .ellipse, .redact, .pixelate, .sticker] {
            let mark = ScreenshotSupport.Annotation(tool: tool, rect: box.rect)
            suite.expect(ScreenshotEditorGeometry.selectionHandle(at: CGPoint(x: 150, y: 50),
                mark: mark, tolerance: 8) == nil,
                "shape edges have no invisible midpoint resize grip: \(tool)")
            suite.expect(ScreenshotEditorGeometry.selectionHandle(at: CGPoint(x: 250, y: 170),
                mark: mark, tolerance: 8) == .bottomRight,
                "shape bounding-box corners remain resizable: \(tool)")
        }
        let text = ScreenshotSupport.Annotation(tool: .text,
            rect: CGRect(x: 40, y: 40, width: 120, height: 36), text: "Drag me", textSize: 18)
        model.annotations = [text]
        model.beginSelectDrag(at: CGPoint(x: 90, y: 55))
        model.finishSelectDrag(at: CGPoint(x: 90, y: 55), isTap: true)
        suite.expect(model.selectedID == text.id && model.editingTextID == nil,
                     "one click selects text without entering its native editor")
        model.editText(at: CGPoint(x: 90, y: 55))
        suite.expect(model.editingTextID == text.id, "explicit double-click action enters text editing")
        model.editingTextID = nil
        model.dragStart = CGPoint(x: 90, y: 55)
        model.beginSelectDrag(at: model.dragStart)
        model.continueSelectDrag(to: CGPoint(x: 120, y: 85))
        suite.expect(model.annotations[0].rect.origin == CGPoint(x: 70, y: 70),
                     "dragging anywhere inside text moves the entire annotation")

        let original = model.annotations[0]
        model.dragRegistered = false
        model.activeHandle = nil
        model.dragStart = CGPoint(x: 100, y: 85)
        model.beginSelectDrag(at: model.dragStart)
        model.duplicateOnDrag = true
        model.continueSelectDrag(to: CGPoint(x: 125, y: 100))
        model.continueSelectDrag(to: CGPoint(x: 130, y: 105))
        suite.expect(model.annotations.count == 2 && model.annotations[0] == original
                     && model.annotations[1].id != original.id
                     && model.annotations[1].text == original.text,
                     "Option-drag creates exactly one independent copy and preserves the original")
        suite.expect(model.undoSnapshots.count == 2 && model.undoSnapshots.last?.count == 1,
                     "duplication and movement form one undo step")

        model.annotations = [.init(tool: .highlight, rect: CGRect(x: 10, y: 10, width: 100, height: 20))]
        model.selectedID = model.annotations[0].id
        model.activeHandle = nil
        model.beginSelectDrag(at: CGPoint(x: 10, y: 10))
        suite.expect(model.activeHandle == nil, "highlights have no resize handles even at their corner")
        model.annotations = [.init(tool: .highlight, rect: CGRect(x: 10, y: 10, width: 200, height: 80))]
        let highlightID = model.annotations[0].id
        suite.expect(model.hitTest(CGPoint(x: 100, y: 50), includeShapeInteriors: false) == nil,
                     "creation tools can place new marks inside an existing highlight")
        suite.expect(model.hitTest(CGPoint(x: 10, y: 50), includeShapeInteriors: false) == highlightID
                     && model.hitTest(CGPoint(x: 100, y: 50)) == highlightID,
                     "highlight edges remain selectable and the pointer still selects their interiors")
        model.annotations = [.init(tool: .highlight, rect: CGRect(x: 10, y: 10, width: 200, height: 20))]
        suite.expect(model.hitTest(CGPoint(x: 100, y: 20), includeShapeInteriors: false) == nil,
                     "a normal text-line highlight leaves its center free for new text and counters")
        model.annotations = []
        model.selectedID = nil
        model.textWords = [.init(text: "Read", rect: CGRect(x: 10, y: 10, width: 80, height: 20), line: 0)]
        model.beginSelectDrag(at: CGPoint(x: 40, y: 20))
        suite.expect(model.selectedWordIndexes.isEmpty && model.textSelectionAnchor == nil,
                     "the pointer tool does not automatically select OCR text")
        model.textSelectionEnabled = true
        model.beginSelectDrag(at: CGPoint(x: 40, y: 20))
        suite.expect(model.selectedWordIndexes == [0], "the explicit OCR tool enables text selection")

        let retina = Model()
        retina.scale = 2
        let smallText = ScreenshotSupport.Annotation(tool: .text,
            rect: CGRect(x: 40, y: 40, width: 230, height: 47), text: "Resize me", textSize: 18)
        retina.annotations = [smallText]
        retina.selectedID = smallText.id
        retina.beginSelectDrag(at: CGPoint(x: 270, y: 63.5))
        suite.expect(retina.activeHandle == .right, "the right text-width grip remains reachable on Retina")
        retina.activeHandle = nil
        retina.dragStart = CGPoint(x: 270, y: 87)
        retina.beginSelectDrag(at: retina.dragStart)
        suite.expect(retina.activeHandle == .bottomRight, "the scale grip is not shadowed by a nearby width grip")
        retina.continueSelectDrag(to: CGPoint(x: 270, y: 134))
        suite.expect(retina.annotations[0].textSize > smallText.textSize,
                     "dragging a scale grip vertically also increases text scale")
        retina.continueSelectDrag(to: CGPoint(x: 5000, y: 5000))
        retina.finishSelectDrag(at: CGPoint(x: 5000, y: 5000), isTap: false)
        suite.expect(retina.annotations[0].textSize == 96 && retina.textSize == 96,
                     "text scale handles obey the same maximum as the font-size control")
        let stroke = ScreenshotSupport.Annotation(tool: .freehand,
            points: [CGPoint(x: 100, y: 300), CGPoint(x: 500, y: 300)])
        retina.annotations = [stroke]
        suite.expect(retina.hitTest(CGPoint(x: 300, y: 300)) == stroke.id,
                     "a pencil stroke can be selected between sparse input samples")
    }
}
