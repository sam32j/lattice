// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum RecentCaptureThumbnailTests {
    class State {
        let capturesRoot: URL?
        let thumbnailRoot: URL?
        let thumbnailCache = NSCache<NSString, NSImage>()
        init(root: URL, cache: URL) { capturesRoot = root; thumbnailRoot = cache }
        static func isSafeRelativePath(_ name: String) -> Bool { RecentCaptureStore.isSafeRelativePath(name) }
    }
    static func run(_ suite: TestSuite) {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("CaptureThumb-\(UUID())")
        let cache = root.appendingPathComponent("cache")
        do {
            try manager.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? manager.removeItem(at: root) }
            let id = UUID()
            let name = "2026-10-20/\(id).png"
            let thumbnailName = "2026-10-20/\(id)-thumbnail.png"
            let image = CGContext(data: nil, width: 24, height: 12, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
            let png = ScreenshotRenderer.pngData(from: image, scale: 1)!
            try RecentCaptureEditableImage.save(original: png, rendered: png, annotations: [],
                to: RecentCaptureEditableImage.documentURL(for: root.appendingPathComponent(name)))
            let entry = RecentCaptureEntry(id: id, kind: .screenshot, createdAt: Date(), screenshotName: name,
                recordingPath: nil, thumbnailName: thumbnailName, scale: 1,
                anchorX: nil, anchorY: nil, anchorWidth: nil, anchorHeight: nil)
            let service = Service(root: root, cache: cache)
            let fullResolutionURL = root.appendingPathComponent(name)
            try RecentCaptureStore.write(png, to: fullResolutionURL)
            suite.expect(Service.screenshotDragURL(for: entry, capturesRoot: root) == fullResolutionURL,
                         "dragging a history card exports the stored full-resolution PNG, not the cached thumbnail")
            let recording = RecentCaptureEntry(id: id, kind: .recording, createdAt: Date(),
                screenshotName: name, recordingPath: nil, thumbnailName: thumbnailName, scale: 1,
                anchorX: nil, anchorY: nil, anchorWidth: nil, anchorHeight: nil)
            suite.expect(Service.screenshotDragURL(for: recording, capturesRoot: root) == nil,
                         "only image captures advertise PNG dragging")
            let missingID = UUID()
            let missingEntry = RecentCaptureEntry(id: missingID, kind: .screenshot, createdAt: Date(),
                screenshotName: "2026-10-20/\(missingID).png", recordingPath: nil, thumbnailName: nil, scale: 1,
                anchorX: nil, anchorY: nil, anchorWidth: nil, anchorHeight: nil)
            suite.expect(Service.screenshotDragURL(for: missingEntry, capturesRoot: root) == nil,
                         "missing captures cannot advertise a nonexistent drag file")
            suite.expect(service.thumbnail(for: entry)?.size.width == 24,
                         "an evicted thumbnail regenerates from the committed rendered document")
            suite.expect(manager.fileExists(atPath: cache.appendingPathComponent(thumbnailName).path)
                         && !manager.fileExists(atPath: cache.appendingPathComponent(name).path),
                         "regenerated thumbnails use their indexed thumbnail filename, not the screenshot filename")
        } catch { suite.expect(false, "thumbnail regeneration fixture failed: \(error)") }
    }
}
