// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum ScreenshotShapeResizeTests {
    static func run(_ suite: TestSuite) {
        let bounds = CGRect(x: 50, y: 50, width: 200, height: 120)
        let cases: [(ScreenshotSupport.Handle, CGPoint, CGRect)] = [
            (.topLeft, CGPoint(x: 20, y: 20), CGRect(x: 20, y: -60, width: 230, height: 230)),
            (.topRight, CGPoint(x: 280, y: 20), CGRect(x: 50, y: -60, width: 230, height: 230)),
            (.bottomRight, CGPoint(x: 280, y: 200), CGRect(x: 50, y: 50, width: 230, height: 230)),
            (.bottomLeft, CGPoint(x: 20, y: 200), CGRect(x: 20, y: 50, width: 230, height: 230))
        ]
        for tool in [ScreenshotSupport.Tool.rect, .ellipse, .redact] {
            for (handle, point, expected) in cases {
                let model = ScreenshotEditorSelectionTests.Model()
                let shape = ScreenshotSupport.Annotation(tool: tool, rect: bounds)
                model.annotations = [shape]
                model.selectedID = shape.id
                model.dragStart = handle.position(in: bounds)
                model.beginSelectDrag(at: model.dragStart)
                model.duplicateOnDrag = true
                model.continueSelectDrag(to: point, constrained: true)
                suite.expect(model.annotations.count == 1 && model.annotations[0].rect == expected,
                             "Shift-resizing \(tool) from \(handle) makes equal sides around the fixed opposite corner")
                model.continueSelectDrag(to: point, constrained: false)
                suite.expect(model.annotations[0].rect == ScreenshotSupport.resizedRect(bounds, dragging: handle, to: point)
                             && model.undoSnapshots.count == 1,
                             "releasing Shift restores free resizing in the same undo step without Option duplication")
            }
        }
    }
}
