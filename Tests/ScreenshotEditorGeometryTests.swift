// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum ScreenshotEditorGeometryTests {
    static func run(_ suite: TestSuite) {
        ScreenshotPreviewTransformTests.run(suite)
        let rounded = ScreenshotSupport.Annotation(tool: .rect,
            rect: CGRect(x: 10, y: 20, width: 100, height: 60), hasCornerRadius: true)
        suite.expect(ScreenshotEditorGeometry.duplicate(rounded).isRounded,
                     "Option-drag preserves a shape's rounded-corner style")
        for language in AppLanguage.allCases {
            let camera = FeatureStrings.recorderOverlay(language)
            let editor = FeatureStrings.editorRefinements(language)
            suite.expect(Mirror(reflecting: camera).children.allSatisfy { !($0.value as? String ?? "").isEmpty }
                         && Mirror(reflecting: editor).children.allSatisfy { !($0.value as? String ?? "").isEmpty },
                         "capture refinements provide copy in every supported language")
            suite.expect(Set(RecorderCameraLayout.Shape.allCases.map { camera.title($0) }).count == 4,
                         "camera shape names remain distinct without embedding aspect ratios")
        }
        let origin = CGPoint(x: 20, y: 30)
        let end = CGPoint(x: 100, y: 60)
        let square = ScreenshotEditorGeometry.shapeEnd(from: origin, to: end, tool: .rect, constrained: true)
        suite.expectClose(abs(square.x - origin.x), abs(square.y - origin.y),
                          "Shift draws a square rather than an arbitrary rectangle")
        let circle = ScreenshotEditorGeometry.shapeEnd(from: origin, to: end, tool: .ellipse, constrained: true)
        suite.expect(circle == square, "Shift uses the same equal sides for circles")
        let redactSquare = ScreenshotEditorGeometry.shapeEnd(from: origin, to: end, tool: .redact, constrained: true)
        suite.expect(redactSquare == square, "Shift draws a square for filled rectangles (redact)")
        let line = ScreenshotEditorGeometry.shapeEnd(from: origin, to: end, tool: .line, constrained: true)
        suite.expectClose(line.y, origin.y, "Shift snaps a nearly horizontal line to a perfect horizontal")
        suite.expect(ScreenshotEditorGeometry.shapeEnd(from: origin, to: end, tool: .rect, constrained: false) == end,
                     "unmodified drawing preserves free geometry")
        let font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        for width: CGFloat? in [nil, 180] {
            let newline = ScreenshotEditorGeometry.textSize("a\n", font: font, width: width)
            let typed = ScreenshotEditorGeometry.textSize("a\nb", font: font, width: width)
            suite.expectClose(newline.height, typed.height,
                              "typing after a newline does not remove a phantom line")
            suite.expect(ScreenshotEditorGeometry.textSize("a\n\n", font: font, width: width).height > newline.height,
                         "a second newline adds exactly another real text line")
        }
        let boxes = [CGRect(x: 10, y: 10, width: 30, height: 15),
                     CGRect(x: 45, y: 10, width: 35, height: 15),
                     CGRect(x: 10, y: 40, width: 30, height: 15)]
        let runs = ScreenshotEditorGeometry.highlightRuns(anchor: CGPoint(x: 12, y: 15),
            current: CGPoint(x: 35, y: 45), words: boxes, padding: 2)
        suite.expect(runs.count == 2 && runs[0].maxX > 78 && runs[1].maxX < 45,
                     "a multiline highlight follows text runs rather than filling the intervening box")
        let crop = ScreenshotEditorGeometry.aspectRect(from: .zero, to: CGPoint(x: 90, y: 30), aspect: 1.5)
        suite.expectClose(crop.width / crop.height, 1.5, "crop geometry preserves its selected aspect ratio")
        let aspectProj = ScreenshotEditorGeometry.aspectRect(from: .zero, to: CGPoint(x: 100, y: 0), aspect: 1)
        suite.expectClose(aspectProj.width, 50, "aspect ratio cropper orthogonally projects onto aspect diagonal")
        let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        let edge = ScreenshotCropAspect.square.resized(CGRect(x: 100, y: 100, width: 300, height: 300),
            handle: .topLeft, to: CGPoint(x: -100, y: -100), within: bounds, imageSize: bounds.size)
        suite.expect(edge.maxX == 400 && edge.maxY == 400 && bounds.contains(edge),
                     "aspect-constrained crop keeps its opposite corner fixed at the image edge")
        for aspect in ScreenshotCropAspect.allCases {
            let fitted = aspect.fitted(bounds, within: bounds, imageSize: bounds.size)
            suite.expect(bounds.contains(fitted), "a crop ratio always fits the source image")
            for handle in ScreenshotSupport.Handle.allCases {
                let resized = aspect.resized(fitted, handle: handle, to: CGPoint(x: 120, y: 100),
                    within: bounds, imageSize: bounds.size)
                if let ratio = aspect.ratio(imageSize: bounds.size), resized.height > 0 {
                    suite.expectClose(resized.width / resized.height, ratio, "all crop handles retain the selected ratio")
                }
            }
        }
    }
}
