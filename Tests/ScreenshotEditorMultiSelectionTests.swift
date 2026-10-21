// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum ScreenshotEditorMultiSelectionTests {
    static func run(_ suite: TestSuite) {
        let model = ScreenshotEditorSelectionTests.Model()
        let first = ScreenshotSupport.Annotation(tool: .rect, rect: CGRect(x: 20, y: 20, width: 80, height: 60))
        let second = ScreenshotSupport.Annotation(tool: .ellipse, rect: CGRect(x: 140, y: 20, width: 80, height: 60))
        let retained = ScreenshotSupport.Annotation(tool: .text,
            rect: CGRect(x: 20, y: 180, width: 100, height: 30), text: "Keep")
        model.annotations = [first, second, retained]
        model.selectedIDs = [first.id, second.id]
        model.deleteSelected()
        suite.expect(model.annotations == [retained] && model.selectedIDs.isEmpty,
                     "deleting an object selection removes all selected objects and preserves the others")
        suite.expect(model.undoSnapshots == [[first, second, retained]],
                     "deleting multiple selected objects records one undo step")
        model.deleteSelected()
        suite.expect(model.undoSnapshots.count == 1, "deleting an empty selection is not an edit")
        let clicking = ScreenshotEditorSelectionTests.Model()
        clicking.annotations = [first, second]
        clicking.beginSelectDrag(at: CGPoint(x: 50, y: 50))
        clicking.finishSelectDrag(at: CGPoint(x: 50, y: 50), isTap: true)
        clicking.beginSelectDrag(at: CGPoint(x: 180, y: 50), extending: true)
        clicking.finishSelectDrag(at: CGPoint(x: 180, y: 50), isTap: true)
        suite.expect(clicking.selectedIDs == [first.id, second.id],
                     "Command-click adds an object without dropping the current selection")
        clicking.beginSelectDrag(at: CGPoint(x: 180, y: 50), extending: true)
        clicking.finishSelectDrag(at: CGPoint(x: 180, y: 50), isTap: true)
        suite.expect(clicking.selectedIDs == [first.id], "Command-click toggles a selected object off")
        let styled = ScreenshotEditorSelectionTests.Model()
        let text = ScreenshotSupport.Annotation(tool: .text,
            rect: CGRect(x: 20, y: 20, width: 80, height: 60), text: "Style", color: .blue, textSize: 36)
        styled.annotations = [text, second]
        styled.selectedIDs = [text.id, second.id]
        styled.beginSelectDrag(at: CGPoint(x: 180, y: 50), extending: true)
        suite.expect(styled.selectedID == text.id && styled.color == .blue && styled.textSize == 36,
                     "reducing a group to one text object restores its actual style controls")
        suite.expect(styled.annotations == [text, second] && styled.undoSnapshots.isEmpty,
                     "synchronizing controls after additive selection is not an annotation edit")
        clicking.selectedIDs = [first.id, second.id]
        clicking.dragStart = CGPoint(x: 50, y: 50)
        clicking.beginSelectDrag(at: clicking.dragStart)
        clicking.continueSelectDrag(to: CGPoint(x: 80, y: 90))
        clicking.finishSelectDrag(at: CGPoint(x: 80, y: 90), isTap: false)
        suite.expect(clicking.annotations[0].rect.origin == CGPoint(x: 50, y: 60)
                     && clicking.annotations[1].rect.origin == CGPoint(x: 170, y: 60)
                     && clicking.selectedIDs == [first.id, second.id],
                     "dragging a selected object moves the entire group by one shared delta")
        suite.expect(clicking.undoSnapshots.count == 1, "group movement records one undo step")
        clicking.dragRegistered = false
        clicking.beginSelectDrag(at: CGPoint(x: 80, y: 90))
        clicking.finishSelectDrag(at: CGPoint(x: 80, y: 90), isTap: true)
        suite.expect(clicking.selectedIDs == [first.id], "a plain click returns to single-object selection")
        clicking.activeHandle = nil
        suite.expect(clicking.resizeHandle(at: CGPoint(x: 50, y: 60)) == .topLeft,
                     "a shape's visible corner grip takes resize precedence over its movable body")
        clicking.selectedIDs = [first.id, second.id]
        suite.expect(clicking.resizeHandle(at: CGPoint(x: 50, y: 60)) == nil,
                     "group selection does not expose invisible individual resize grips")
        clicking.tool = .crop
        clicking.cropDraft = CGRect(x: 10, y: 10, width: 200, height: 140)
        suite.expect(clicking.resizeHandle(at: CGPoint(x: 210, y: 80)) == .right
                     && clicking.resizeHandle(at: CGPoint(x: 10, y: 10)) == .topLeft,
                     "crop edges and corners resolve to their matching resize directions")
    }
}
