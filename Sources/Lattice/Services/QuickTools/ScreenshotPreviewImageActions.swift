// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import UniformTypeIdentifiers

enum ScreenshotPreviewImageActions {
    enum Transform { case rotateLeft, flipHorizontal }

    static func transformed(_ image: CGImage, _ operation: Transform) -> CGImage? {
        let rotates = operation == .rotateLeft
        let width = rotates ? image.height : image.width, height = rotates ? image.width : image.height
        let space = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .none
        if rotates {
            context.translateBy(x: CGFloat(width), y: 0)
            context.rotate(by: .pi / 2)
        } else {
            context.translateBy(x: CGFloat(width), y: 0)
            context.scaleBy(x: -1, y: 1)
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }

    @MainActor static func saveAs(image: CGImage, scale: CGFloat, owner: NSWindow?, strings: ScreenshotFeatureStrings) -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = ScreenshotSupport.fileName(prefix: strings.fileNamePrefix, date: Date())
        panel.level = ScreenshotWindowLayering.previewLevel(above: owner)
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        guard let data = ScreenshotRenderer.pngData(from: image, scale: scale) else { NSSound.beep(); return false }
        do { try data.write(to: url, options: .atomic); return true }
        catch { NSSound.beep(); return false }
    }

    @MainActor static func printImage(_ image: CGImage, scale: CGFloat) {
        let size = CGSize(width: CGFloat(image.width) / max(1, scale), height: CGFloat(image.height) / max(1, scale))
        let view = NSImageView(frame: CGRect(origin: .zero, size: size))
        view.image = NSImage(cgImage: image, size: size)
        view.imageScaling = .scaleProportionallyDown
        NSPrintOperation(view: view).run()
    }
}
