// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
// Independent native geometric artwork. No upstream trademark assets.
import AppKit

let directory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

func render(width: Int, height: Int, app: Bool, mark: Bool = false) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let w = CGFloat(width), h = CGFloat(height)
    if app {
        let rect = CGRect(x: w * 0.08, y: h * 0.08, width: w * 0.84, height: h * 0.84)
        let shape = NSBezierPath(roundedRect: rect, xRadius: w * 0.19, yRadius: h * 0.19)
        NSColor(calibratedRed: 0.04, green: 0.12, blue: 0.19, alpha: 1).setFill(); shape.fill()
    }
    let size = app ? w * 0.51 : (mark ? min(w, h) * 0.85 : h * 0.625)
    let x = (w - size) / 2, y = (h - size) / 2
    let path = NSBezierPath(); path.lineWidth = size * 0.095; path.lineCapStyle = .round
    for step in 0...2 {
        let offset = CGFloat(step) * size / 2
        path.move(to: NSPoint(x: x + offset, y: y)); path.line(to: NSPoint(x: x + offset, y: y + size))
        path.move(to: NSPoint(x: x, y: y + offset)); path.line(to: NSPoint(x: x + size, y: y + offset))
    }
    (app || mark ? NSColor(calibratedRed: 0.25, green: 0.88, blue: 0.80, alpha: 1) : .black).setStroke()
    path.stroke()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

let sizes: [(String, Int, String?)] = [
    ("16x16", 16, nil), ("16x16@2x", 32, "ic11"),
    ("32x32", 32, nil), ("32x32@2x", 64, "ic12"),
    ("128x128", 128, "ic07"), ("128x128@2x", 256, "ic13"),
    ("256x256", 256, "ic08"), ("256x256@2x", 512, "ic14"),
    ("512x512", 512, "ic09"), ("512x512@2x", 1024, "ic10"),
]
func be(_ number: Int) -> Data {
    var value = UInt32(number).bigEndian
    return withUnsafeBytes(of: &value) { Data($0) }
}
var entries = Data()
for (name, size, type) in sizes {
    let png = render(width: size, height: size, app: true)
    try png.write(to: URL(fileURLWithPath: "\(directory)/icon_\(name).png"))
    if let type { entries.append(Data(type.utf8)); entries.append(be(png.count + 8)); entries.append(png) }
}
var icns = Data("icns".utf8); icns.append(be(entries.count + 8)); icns.append(entries)
let parent = URL(fileURLWithPath: directory).deletingLastPathComponent()
try icns.write(to: parent.appendingPathComponent("AppIcon.icns"))
for scale in [1, 2] {
    let suffix = scale == 1 ? "" : "@2x"
    try render(width: 26 * scale, height: 20 * scale, app: false)
        .write(to: parent.appendingPathComponent("MenuBarIcon\(suffix).png"))
}
try render(width: 640, height: 640, app: false, mark: true)
    .write(to: parent.appendingPathComponent("BrandMark.png"))
