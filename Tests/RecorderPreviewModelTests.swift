// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum RecorderPreviewModelTests {
    static func run(_ suite: TestSuite) {
        MainActor.assumeIsolated { RecorderPreviewEditTests.run(suite) }
        RecorderPreviewShortcutTests.run(suite)
        final class Loader {
            var pending: [URL: CheckedContinuation<CGImage?, Never>] = [:]
            func load(_ url: URL) async -> CGImage? {
                await withCheckedContinuation { pending[url] = $0 }
            }
        }
        func settle(_ ready: () -> Bool) {
            let deadline = Date().addingTimeInterval(1)
            while !ready(), Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        }
        func image(_ width: Int) -> CGImage {
            CGContext(data: nil, width: width, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
        }
        let loader = Loader()
        let model = RecorderQuickPreviewModel(loadThumbnail: loader.load)
        let a = URL(fileURLWithPath: "/synthetic/a.mov"), b = URL(fileURLWithPath: "/synthetic/b.mov")
        model.show(url: a)
        settle { loader.pending[a] != nil }
        model.show(url: b, initialThumbnail: image(2))
        loader.pending.removeValue(forKey: a)?.resume(returning: image(1))
        // Allow the stale task to resume even if its loader ignored cancellation.
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        suite.expect(model.thumbnail?.width == 2, "an old thumbnail cannot replace the current video preview")
        model.show(url: a)
        settle { loader.pending[a] != nil }
        model.close()
        loader.pending.removeValue(forKey: a)?.resume(returning: image(3))
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        suite.expect(model.thumbnail == nil, "closed previews cannot publish late thumbnails")
    }
}
