// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
// The app icon comes from Resources/Brand/Lattice.icon. Its compiled fallback
// supports older macOS and builds without Xcode's adaptive-icon compiler.
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

let darkFallback = project.appendingPathComponent("Resources/Brand/Lattice-Dark.icns")
// An earlier build's dark icon must not be packaged when this one has none.
let darkOutput = output.appendingPathComponent("AppIcon-Dark.icns")
try? FileManager.default.removeItem(at: darkOutput)
if FileManager.default.fileExists(atPath: darkFallback.path),
   let darkData = try? Data(contentsOf: darkFallback),
   NSImage(data: darkData) != nil {
    try darkData.write(to: darkOutput)
}

let svgFilename = isDev ? "MenuBarIcon-Dev.svg" : "MenuBarIcon.svg"
let projectSvgURL = project.appendingPathComponent("Resources/Brand/\(svgFilename)")
let svgURL = FileManager.default.fileExists(atPath: projectSvgURL.path)
    ? projectSvgURL
    : URL(fileURLWithPath: "Resources/Brand/\(svgFilename)")

guard let svgImage = NSImage(contentsOf: svgURL) else {
    fatalError("Cannot load menu bar icon SVG from \(svgURL.path)")
}

func renderGlyph(width: Int, height: Int, mark: Bool = false) -> Data {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Cannot render brand glyph") }
    bitmap.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let w = CGFloat(width), h = CGFloat(height)
    let size: CGFloat = mark ? min(w, h) * 0.85 : h * 0.80
    let x = (w - size) / 2, y = (h - size) / 2
    let targetRect = NSRect(x: x, y: y, width: size, height: size)

    svgImage.draw(in: targetRect, from: .zero, operation: .sourceOver, fraction: 1.0)

    let tintColor: NSColor
    if isDev {
        tintColor = NSColor(calibratedRed: 0.204, green: 0.780, blue: 0.349, alpha: 1.0)
    } else {
        tintColor = .white
    }
    tintColor.setFill()
    NSRect(x: 0, y: 0, width: w, height: h).fill(using: .sourceIn)

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
