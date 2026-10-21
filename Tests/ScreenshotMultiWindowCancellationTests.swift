// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

extension ScreenshotAttachedCaptureTests {
    @MainActor static func cancellationChecks(_ suite: TestSuite) async {
        let bounds = CGRect(x: 0, y: 0, width: 8, height: 8)
        let context = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(NSColor.red.cgColor)
        context.fill(bounds)
        let fallback = context.makeImage()!
        var resolutions = 0
        let beforeStart = Task { @MainActor in
            await Engine.captureMultipleWindows([1], scale: 1, frames: [1: bounds], resolveCapture: { _, _ in
                resolutions += 1
                return (fallback, 1)
            })
        }
        beforeStart.cancel()
        let early = await beforeStart.value
        suite.expect(early == nil && resolutions == 0,
                     "a cancelled selection does not start resolving selected windows")
        WindowPreviewProvider.cancelDuringCapture = true
        defer { WindowPreviewProvider.cancelDuringCapture = false }
        let duringCapture = Task { @MainActor in
            await Engine.captureMultipleWindows([1], scale: 1, frames: [1: bounds], resolveCapture: { _, _ in
                resolutions += 1
                return (fallback, 1)
            })
        }
        let interrupted = await duringCapture.value
        suite.expect(interrupted == nil && resolutions == 0,
                     "cancellation while acquiring a window cannot turn into successful frozen-image fallback")
    }
}
