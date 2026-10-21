// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum RecentCaptureEditableImageTests {
    static func run(_ suite: TestSuite) {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("CaptureEdit-\(UUID())")
        do {
            try manager.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? manager.removeItem(at: root) }
            let rendered = root.appendingPathComponent("rendered.png")
            let original = root.appendingPathComponent("original.png")
            let annotations = root.appendingPathComponent("annotations.json")
            func png(_ width: Int) throws -> Data {
                let context = CGContext(data: nil, width: width, height: 10, bitsPerComponent: 8,
                    bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                return ScreenshotRenderer.pngData(from: context.makeImage()!, scale: 1)!
            }
            try png(20).write(to: rendered)
            try png(10).write(to: original)
            let marks = [ScreenshotSupport.Annotation(tool: .text, text: "Keep editable")]
            try JSONEncoder().encode(marks).write(to: annotations)
            var loaded = RecentCaptureEditableImage.load(rendered: rendered, original: original, annotations: annotations)
            suite.expect(loaded?.image.width == 10 && loaded?.annotations == marks,
                         "an intact original and annotation pair restores editable marks")
            try manager.removeItem(at: original)
            loaded = RecentCaptureEditableImage.load(rendered: rendered, original: original, annotations: annotations)
            suite.expect(loaded?.image.width == 20 && loaded?.annotations.isEmpty == true,
                         "missing originals never reapply annotations over an already rendered image")
            try png(10).write(to: original)
            try Data("broken".utf8).write(to: annotations)
            loaded = RecentCaptureEditableImage.load(rendered: rendered, original: original, annotations: annotations)
            suite.expect(loaded?.image.width == 20 && loaded?.annotations.isEmpty == true,
                         "invalid annotation data preserves the complete rendered capture")
            let document = RecentCaptureEditableImage.documentURL(for: rendered)
            try RecentCaptureEditableImage.save(original: png(12), rendered: png(24), annotations: marks, scale: 2, to: document)
            loaded = RecentCaptureEditableImage.load(rendered: rendered, original: original, annotations: annotations)
            suite.expect(loaded?.image.width == 12 && loaded?.annotations == marks && loaded?.scale == 2,
                         "the atomic document supersedes legacy sidecars as one editable generation")
            suite.expect(RecentCaptureEditableImage.renderedImage(at: rendered)?.width == 24,
                         "derived thumbnails read the rendered image from the same committed generation")
            let saved = try Data(contentsOf: document)
            do {
                try RecentCaptureEditableImage.save(original: png(13), rendered: png(26), annotations: [], to: document,
                    write: { _, _ in throw CocoaError(.fileWriteOutOfSpace) })
                suite.expect(false, "an interrupted document save reports failure")
            } catch {
                suite.expect(try Data(contentsOf: document) == saved,
                             "an interrupted save preserves the entire previous editable generation")
            }
            try Data("truncated document".utf8).write(to: document)
            loaded = RecentCaptureEditableImage.load(rendered: rendered, original: original, annotations: annotations)
            suite.expect(loaded?.image.width == 20 && loaded?.annotations.isEmpty == true,
                         "a damaged document falls back to flattened pixels, not stale legacy marks")
        } catch { suite.expect(false, "editable capture fixture failed: \(error)") }
    }
}
