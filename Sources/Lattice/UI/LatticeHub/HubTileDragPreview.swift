// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit

enum HubTileDragPreview {
    /// Capture once before the source dims. The native drag manager moves this
    /// bitmap; no SwiftUI layout or image rendering runs for pointer movement.
    static func image(in view: NSView, rect: CGRect, cornerRadius: CGFloat) -> NSImage? {
        guard rect.width > 0, rect.height > 0,
              let renderer = view.enclosingScrollView?.documentView ?? view.window?.contentView else { return nil }
        let region = renderer.convert(rect, from: view)
        guard let bitmap = renderer.bitmapImageRepForCachingDisplay(in: region) else { return nil }
        renderer.cacheDisplay(in: region, to: bitmap)
        guard let source = bitmap.cgImage,
              let context = CGContext(data: nil, width: source.width, height: source.height,
                bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.scaleBy(x: CGFloat(source.width) / rect.width, y: CGFloat(source.height) / rect.height)
        let bounds = CGRect(origin: .zero, size: rect.size)
        context.addPath(CGPath(roundedRect: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
        context.clip()
        context.draw(source, in: bounds)
        guard let image = context.makeImage() else { return nil }
        return NSImage(cgImage: image, size: rect.size)
    }
}
