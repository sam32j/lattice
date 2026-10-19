// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Opt-in synthetic rendering check. Runs before startup and refuses ordinary
/// app identities, so no features, input interception or hardware are installed.
enum CaptureEditorPresentationProbe {
    static func runAndExit() -> Never {
        guard let identity = Bundle.main.bundleIdentifier, identity.hasPrefix("com.vorssaint.tests.") else {
            fputs("Capture rendering requires an isolated test bundle identifier.\n", stderr)
            exit(2)
        }
        _ = NSApplication.shared
        UserDefaults.standard.register(defaults: Defaults.registeredDefaults)
        UserDefaults.standard.set(AppLanguage.enUS.rawValue, forKey: DefaultsKey.language)
        let output: URL
        if let index = CommandLine.arguments.firstIndex(of: "--output-directory"),
           CommandLine.arguments.indices.contains(index + 1) {
            output = URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
        } else {
            output = FileManager.default.temporaryDirectory.appendingPathComponent("Lattice-Capture-Rendering-\(UUID())")
        }
        do { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }
        catch { fputs("Cannot create rendering output: \(error)\n", stderr); exit(2) }
        guard let image = fixture() else { exit(2) }
        let capture = ScreenshotSelectionController.Capture(image: image, scale: 1, anchorRect: .zero)
        let controller = ScreenshotEditorController(capture: capture)
        let model = controller.model
        model.tool = .select
        model.backdropStyle = ScreenshotSupport.BackdropStyle()
        model.annotationShadowsEnabled = false
        let text = ScreenshotSupport.Annotation(tool: .text,
            rect: CGRect(x: 100, y: 120, width: 230, height: 42), text: "Drag or double-click", color: .red, textSize: 22)
        let highlight = ScreenshotSupport.Annotation(tool: .highlight,
            rect: CGRect(x: 96, y: 230, width: 310, height: 28), color: .yellow)
        let pencil = ScreenshotSupport.Annotation(tool: .freehand,
            points: [CGPoint(x: 100, y: 390), CGPoint(x: 160, y: 360), CGPoint(x: 220, y: 400), CGPoint(x: 300, y: 365)],
            color: .red, stroke: .medium)
        model.annotations = [highlight, pencil, text]
        let host = NSHostingView(rootView: ScreenshotEditorView(model: model, controller: controller))
        let window = NSWindow(contentRect: CGRect(x: -10000, y: -10000, width: 960, height: 720),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = host
        window.orderFront(nil)
        var failures: [String] = []
        func settle() {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.35))
            host.layoutSubtreeIfNeeded()
        }
        func snapshot(_ name: String) {
            settle()
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
                failures.append("no bitmap for \(name)"); return
            }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else {
                failures.append("no PNG for \(name)"); return
            }
            do { try data.write(to: output.appendingPathComponent(name + ".png")) }
            catch { failures.append("cannot save \(name): \(error)") }
        }
        settle()
        var baseline: CGFloat?
        for tool in [ScreenshotSupport.Tool.select, .rect, .text, .highlight, .crop, .select] {
            model.tool = tool
            settle()
            if let baseline, abs(model.currentDisplayZoom - baseline) > 0.0001 {
                failures.append("tool \(tool.rawValue) changed fit zoom from \(baseline) to \(model.currentDisplayZoom)")
            } else if baseline == nil { baseline = model.currentDisplayZoom }
            print("EDITOR_FIT tool=\(tool.rawValue) zoom=\(model.currentDisplayZoom) size=\(host.frame.size)")
        }
        model.selectedID = text.id
        snapshot("text-selection")
        model.selectedID = pencil.id
        snapshot("pencil-selection")
        model.selectedID = highlight.id
        snapshot("highlight-selection")
        model.selectedID = text.id
        model.editingTextID = text.id
        snapshot("text-editing")
        model.editingTextID = nil
        model.tool = .crop
        model.cropAspect = .wide
        snapshot("crop-ratio")
        window.orderOut(nil)
        window.contentView = nil
        window.close()
        if failures.isEmpty { print("CAPTURE_RENDERING_OK output=\(output.path)") }
        else { for failure in failures { print("CAPTURE_RENDERING_FAILED \(failure)") } }
        UserDefaults.standard.removePersistentDomain(forName: identity)
        exit(failures.isEmpty ? 0 : 1)
    }

    private static func fixture() -> CGImage? {
        let size = CGSize(width: 1000, height: 600)
        guard let context = CGContext(data: nil, width: 1000, height: 600, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSColor.white.setFill()
        CGRect(origin: .zero, size: size).fill()
        ("Capture editor reference" as NSString).draw(at: CGPoint(x: 96, y: 520),
            withAttributes: [.font: NSFont.systemFont(ofSize: 30, weight: .semibold), .foregroundColor: NSColor.black])
        ("A line-aware highlight follows the text.\nSelection borders never change the export." as NSString)
            .draw(in: CGRect(x: 100, y: 285, width: 760, height: 84),
                  withAttributes: [.font: NSFont.systemFont(ofSize: 22), .foregroundColor: NSColor.black])
        return context.makeImage()
    }
}
#endif
