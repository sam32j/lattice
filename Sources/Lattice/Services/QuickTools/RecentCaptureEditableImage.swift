// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ImageIO

/// Never apply editable marks to a flattened image when its original is gone.
enum RecentCaptureEditableImage {
    private struct Document: Codable {
        let version: Int
        let original: Data
        let rendered: Data
        let annotations: [ScreenshotSupport.Annotation]
        let scale: Double
    }

    static func documentURL(for rendered: URL) -> URL {
        rendered.deletingPathExtension().appendingPathExtension("latticecapture")
    }

    /// The rendered mirror is derived; this atomic payload is the authority.
    static func save(original: Data, rendered: Data, annotations: [ScreenshotSupport.Annotation],
                     scale: CGFloat = 1, to url: URL,
                     write: (Data, URL) throws -> Void = RecentCaptureStore.write) throws {
        guard scale.isFinite, scale > 0, read(original) != nil, read(rendered) != nil else {
            throw CocoaError(.fileWriteUnknown)
        }
        let document = Document(version: 1, original: original, rendered: rendered,
                                annotations: annotations, scale: Double(scale))
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        try write(encoder.encode(document), url)
    }

    static func load(rendered: URL, original: URL, annotations: URL,
                     legacyOriginal: URL? = nil, legacyAnnotations: URL? = nil)
        -> (image: CGImage, annotations: [ScreenshotSupport.Annotation], scale: Double?)? {
        let url = documentURL(for: rendered)
        if FileManager.default.fileExists(atPath: url.path) {
            if let document = document(at: url), let image = read(document.original) {
                return (image, document.annotations, document.scale)
            }
            // A damaged new document must not revive stale legacy sidecars.
            return read(rendered).map { ($0, [], nil) }
        }
        var pairs = [(original, annotations)]
        if let legacyOriginal, let legacyAnnotations { pairs.append((legacyOriginal, legacyAnnotations)) }
        for (imageURL, marksURL) in pairs {
            guard RecentCaptureStore.isRegularFile(marksURL),
                  let data = try? Data(contentsOf: marksURL),
                  let marks = try? JSONDecoder().decode([ScreenshotSupport.Annotation].self, from: data),
                  let image = read(imageURL) else { continue }
            return (image, marks, nil)
        }
        return read(rendered).map { ($0, [], nil) }
    }

    static func renderedImage(at rendered: URL) -> CGImage? {
        if let document = document(at: documentURL(for: rendered)), let image = read(document.rendered) {
            return image
        }
        return read(rendered)
    }

    private static func document(at url: URL) -> Document? {
        guard RecentCaptureStore.isRegularFile(url), let data = try? Data(contentsOf: url),
              let document = try? PropertyListDecoder().decode(Document.self, from: data),
              document.version == 1, document.scale.isFinite, document.scale > 0 else { return nil }
        return document
    }

    private static func read(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func read(_ url: URL) -> CGImage? {
        guard RecentCaptureStore.isRegularFile(url),
              let source = CGImageSourceCreateWithURL(url as CFURL,
                  [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0,
            [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    }
}
