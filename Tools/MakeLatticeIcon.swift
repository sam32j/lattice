// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
// The app icon comes from Resources/Brand/Lattice.icon. Its compiled fallback
// supports older macOS and builds without Xcode's adaptive-icon compiler.
// Keep the independent menu-bar template and brand glyph unchanged.
import AppKit

var directory = "build"
var isDev = false
for arg in CommandLine.arguments.dropFirst() {
    if arg == "--dev" { isDev = true }
    else if !arg.hasPrefix("--") { directory = arg }
}
let output = URL(fileURLWithPath: directory, isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let project = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let fallback = project.appendingPathComponent("Resources/Brand/Lattice.icns")
guard NSImage(contentsOf: fallback) != nil else { fatalError("Cannot load app icon fallback: \(fallback.path)") }
try Data(contentsOf: fallback).write(to: output.appendingPathComponent("AppIcon.icns"))

func renderGlyph(width: Int, height: Int, mark: Bool = false) -> Data {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Cannot render brand glyph") }
    bitmap.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let w = CGFloat(width), h = CGFloat(height)
    let size = mark ? min(w, h) * 0.85 : h * 0.625
    let x = (w - size) / 2, y = (h - size) / 2
    let path = NSBezierPath(); path.lineWidth = size * 0.095; path.lineCapStyle = .round
    for step in 0...2 {
        let offset = CGFloat(step) * size / 2
        path.move(to: NSPoint(x: x + offset, y: y)); path.line(to: NSPoint(x: x + offset, y: y + size))
        path.move(to: NSPoint(x: x, y: y + offset)); path.line(to: NSPoint(x: x + size, y: y + offset))
    }
    if isDev && mark {
        NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.11, alpha: 1).setStroke()
    } else if mark {
        NSColor(calibratedRed: 0.25, green: 0.88, blue: 0.80, alpha: 1).setStroke()
    } else {
        NSColor.black.setStroke()
    }
    path.stroke()
    if !mark && isDev {
        let dotR = min(w, h) * 0.12
        let dotRect = CGRect(x: w * 0.78, y: h * 0.66, width: dotR * 2, height: dotR * 2)
        NSColor.black.setFill()
        NSBezierPath(ovalIn: dotRect).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else { fatalError("Cannot encode brand glyph") }
    return data
}
for scale in [1, 2] {
    let suffix = scale == 1 ? "" : "@2x"
    try renderGlyph(width: 26 * scale, height: 20 * scale)
        .write(to: output.appendingPathComponent("MenuBarIcon\(suffix).png"))
}
try renderGlyph(width: 640, height: 640, mark: true)
    .write(to: output.appendingPathComponent("BrandMark.png"))
