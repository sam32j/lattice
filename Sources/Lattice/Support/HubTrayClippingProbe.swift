#if LATTICE_DEVELOPMENT
import AppKit

enum HubTrayClippingProbe {
    static func verifyVisibleTitle(host: NSView, tray: NSView) throws {
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw HubEditingProbe.failure("Cannot capture the native editor title")
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let frame = host.convert(tray.bounds, from: tray)
        let scale = CGFloat(bitmap.pixelsWide) / host.bounds.width
        var ink = 0
        for y in 1..<12 {
            for x in 0..<180 {
                let point = CGPoint(x: frame.minX + CGFloat(x), y: frame.minY + CGFloat(y))
                let imageY = host.isFlipped ? point.y - host.bounds.minY : host.bounds.maxY - point.y
                guard let color = bitmap.colorAt(x: Int((point.x - host.bounds.minX) * scale),
                    y: Int(imageY * scale))?.usingColorSpace(.deviceRGB) else { continue }
                if color.redComponent > 0.25, abs(color.redComponent - color.greenComponent) < 0.03,
                   abs(color.greenComponent - color.blueComponent) < 0.03 { ink += 1 }
            }
        }
        print("HUB_NATIVE_TRAY_TITLE ink=\(ink)"); fflush(stdout)
        try HubEditingProbe.require(ink > 5, "The native island must visibly render the Available Tools title")
    }

    static func run(host: NSView, output: URL) throws {
        guard let scroll = HubEditingProbe.descendants(host).compactMap({ $0 as? NSScrollView }).first(where: {
            abs($0.contentView.bounds.height - 36) < 1
                && ($0.documentView?.bounds.width ?? 0) > $0.contentView.bounds.width
        }), let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw HubEditingProbe.failure("Missing overflowing production Available Tools viewport")
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let frame = host.convert(scroll.bounds, from: scroll)
        let point = CGPoint(x: frame.maxX - 0.25, y: frame.minY + 5.25)
        let scaleX = CGFloat(bitmap.pixelsWide) / host.bounds.width
        let scaleY = CGFloat(bitmap.pixelsHigh) / host.bounds.height
        let y = host.isFlipped ? point.y - host.bounds.minY : host.bounds.maxY - point.y
        guard let color = bitmap.colorAt(x: Int((point.x - host.bounds.minX) * scaleX), y: Int(y * scaleY))?
            .usingColorSpace(.deviceRGB) else { throw HubEditingProbe.failure("Cannot sample rounded tray corner") }
        let brightness = max(color.redComponent, color.greenComponent, color.blueComponent)
        print("HUB_TRAY_CORNER brightness=\(brightness)"); fflush(stdout)
        try HubEditingProbe.capture(host, output: output.appendingPathComponent("tray-rounded-corner.png"))
        try HubEditingProbe.require(brightness < 0.02,
                                    "A partially visible option must not paint outside the rounded tray corner")
    }
}
#endif
