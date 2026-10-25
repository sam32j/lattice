// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

#if LATTICE_DEVELOPMENT
import AppKit
import SwiftUI

/// Opt-in synthetic rendering check. Runs before startup and refuses ordinary
/// app identities, so no features, input interception or hardware are installed.
enum CaptureEditorPresentationProbe {
    static func runAndExit() -> Never {
        guard let identity = Bundle.main.bundleIdentifier, identity.hasPrefix("io.github.sam32j.lattice.tests.") else {
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
        let window = ScreenshotEditorWindow(contentRect: CGRect(x: -10000, y: -10000, width: 960, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFront(nil)
        var failures: [String] = []
        func settle() {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.35))
            host.layoutSubtreeIfNeeded()
        }
        func helpViews(_ view: NSView) -> [NSView] {
            (view.toolTip == nil ? [] : [view]) + view.subviews.flatMap(helpViews)
        }
        func checkHelp(_ expected: String, maxWidth: CGFloat? = nil) {
            guard let view = helpViews(host).first(where: { $0.toolTip == expected }) else {
                failures.append("missing native tooltip: \(expected)"); return
            }
            if view.bounds.isEmpty { failures.append("empty tooltip target: \(expected)") }
            if let maxWidth, view.bounds.width > maxWidth {
                failures.append("oversized control: \(expected), \(view.bounds.width) pt")
            }
            if view.hitTest(CGPoint(x: view.bounds.midX, y: view.bounds.midY)) != nil {
                failures.append("tooltip intercepts input: \(expected)")
            }
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
        func buttons(_ element: AnyObject, label: String) -> [AnyObject] {
            var result: [AnyObject] = []
            if element.accessibilityRole?() == .button && element.accessibilityLabel?() == label {
                result.append(element)
            }
            for child in element.accessibilityChildren?() ?? [] {
                result += buttons(child as AnyObject, label: label)
            }
            return result
        }
        func renderTool(_ name: String, content: AnyView, size: CGSize, model: ScreenshotEditorModel? = nil) {
            let toolHost = NSHostingView(rootView: content.environment(\.controlActiveState, .active))
            let toolWindow = NSWindow(contentRect: CGRect(origin: CGPoint(x: -10000, y: -10000), size: size),
                                      styleMask: [.borderless], backing: .buffered, defer: false)
            toolWindow.isReleasedWhenClosed = false
            toolWindow.contentView = toolHost
            toolWindow.orderFront(nil)
            toolHost.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.6))
            toolHost.layoutSubtreeIfNeeded()
            defer { toolWindow.orderOut(nil); toolWindow.contentView = nil; toolWindow.close() }
            guard let bitmap = toolHost.bitmapImageRepForCachingDisplay(in: toolHost.bounds) else {
                failures.append("no bitmap for \(name)"); return
            }
            toolHost.cacheDisplay(in: toolHost.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else {
                failures.append("no PNG for \(name)"); return
            }
            do { try data.write(to: output.appendingPathComponent(name + ".png")) }
            catch { failures.append("cannot save \(name): \(error)") }
            if let model {
                guard let done = buttons(toolHost, label: "Done").first,
                      let reset = buttons(toolHost, label: "Reset").first else {
                    failures.append("missing composer actions: \(name)"); return
                }
                let hasInput = ScreenshotWatermarkDraft(model.watermarkStyle).hasInput
                if done.isAccessibilityEnabled?() != hasInput || reset.isAccessibilityEnabled?() != hasInput {
                    failures.append("incorrect empty composer action state: \(name)")
                }
                if hasInput {
                    let expected = model.watermarkStyle.sanitized()
                    if expected.kind == .text,
                       let red = buttons(toolHost, label: FeatureStrings.screenshot(.enUS).watermarkColorName(.red)).first {
                        _ = red.accessibilityPerformPress?()
                        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
                        if model.watermarkStyle.color != "red" { failures.append("color did not preview before Done: \(name)") }
                        if let original = ScreenshotSupport.ColorID(rawValue: expected.color),
                           let restore = buttons(toolHost, label: FeatureStrings.screenshot(.enUS).watermarkColorName(original)).first {
                            _ = restore.accessibilityPerformPress?()
                            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
                        }
                    }
                    model.watermarkStyle = .init()
                    _ = done.accessibilityPerformPress?()
                    if model.watermarkStyle != expected { failures.append("Done did not keep the preview: \(name)") }
                    _ = buttons(toolHost, label: "Reset").first?.accessibilityPerformPress?()
                    if model.watermarkStyle.kind != .none { failures.append("Reset did not clear the image: \(name)") }
                }
            }
        }
        let axGetter = NSSelectorFromString("accessibilityAttributeValue:")
        let axSetter = NSSelectorFromString("accessibilitySetValue:forAttribute:")
        let previousAX = NSApp.perform(axGetter, with: "AXEnhancedUserInterface")?.takeUnretainedValue() as? NSNumber ?? false
        NSApp.perform(axSetter, with: true, with: "AXEnhancedUserInterface")
        settle()
        window.layoutIfNeeded()
        if window.standardWindowButton(.closeButton)?.frame.minX != 13 {
            failures.append("editor traffic lights did not move 10 pt left")
        }
        if window.standardWindowButton(.closeButton)?.frame.minY != 23 {
            failures.append("editor traffic lights did not move 5 pt up")
        }
        func checkHistory(undo: Bool, redo: Bool) {
            settle()
            if model.canUndo != undo || model.canRedo != redo
                || buttons(host, label: "Undo").first?.isAccessibilityEnabled?() != undo
                || buttons(host, label: "Redo").first?.isAccessibilityEnabled?() != redo {
                failures.append("incorrect native history control availability: undo=\(undo), redo=\(redo)")
            }
        }
        checkHistory(undo: false, redo: false)
        model.selectedIDs = [pencil.id, highlight.id]
        model.deleteSelected()
        checkHistory(undo: true, redo: false)
        _ = buttons(host, label: "Undo").first?.accessibilityPerformPress?()
        checkHistory(undo: false, redo: true)
        _ = buttons(host, label: "Redo").first?.accessibilityPerformPress?()
        checkHistory(undo: true, redo: false)
        _ = buttons(host, label: "Undo").first?.accessibilityPerformPress?()
        checkHistory(undo: false, redo: true)
        checkHelp("Undo  (⌘Z)")
        checkHelp("Redo  (⇧⌘Z)")
        checkHelp("Fit image  (⌘0)")
        checkHelp("Actual size  (⌘1)")
        checkHelp("Drag & place")
        let retina = ScreenshotEditorModel(image: image, scale: 2)
        retina.backdropStyle = .init(kind: .none)
        retina.watermarkStyle = .init()
        retina.annotations = [text]
        UserDefaults.standard.set(true, forKey: DefaultsKey.screenshotDownscale)
        let canonical = retina.exportImage(withBackdrop: false, downscaleTo1x: false)
        let outputImage = retina.exportImage(withBackdrop: false)
        if canonical?.image.width != image.width || canonical?.scale != 2
            || outputImage?.image.width != image.width / 2 || outputImage?.scale != 1 {
            failures.append("canonical Retina history and downscaled output do not preserve their distinct scales")
        }
        UserDefaults.standard.set(false, forKey: DefaultsKey.screenshotDownscale)
        var baseline: CGFloat?
        for tool in [ScreenshotSupport.Tool.select, .rect, .text, .highlight, .crop, .select] {
            model.tool = tool
            settle()
            if let baseline, abs(model.currentDisplayZoom - baseline) > 0.0001 {
                failures.append("tool \(tool.rawValue) changed fit zoom from \(baseline) to \(model.currentDisplayZoom)")
            } else if baseline == nil { baseline = model.currentDisplayZoom }
            print("EDITOR_FIT tool=\(tool.rawValue) zoom=\(model.currentDisplayZoom) size=\(host.frame.size)")
        }
        model.selectedIDs = [pencil.id, highlight.id]
        snapshot("group-selection")
        model.selectedID = text.id
        snapshot("text-selection")
        model.selectedID = pencil.id
        snapshot("pencil-selection")
        model.selectedID = highlight.id
        snapshot("highlight-selection")
        for tool in [ScreenshotSupport.Tool.rect, .ellipse] {
            let shape = ScreenshotSupport.Annotation(tool: tool,
                rect: CGRect(x: 590, y: 260, width: 200, height: 140), color: .red)
            model.annotations = [highlight, pencil, text, shape]
            model.selectedID = shape.id
            snapshot("\(tool.rawValue)-selection-light")
        }
        for tool in [ScreenshotSupport.Tool.line, .arrow] {
            let mark = ScreenshotSupport.Annotation(tool: tool,
                points: [CGPoint(x: 590, y: 300), CGPoint(x: 800, y: 400)], color: .red)
            model.annotations = [highlight, pencil, text, mark]
            model.selectedID = mark.id
            snapshot("\(tool.rawValue)-selection")
        }
        model.annotations = [highlight, pencil, text]
        failures += CaptureEditorTextInteractionProbe.run(model: model, window: window, host: host)
        model.selectedID = text.id
        model.editingTextID = text.id
        snapshot("text-editing")
        model.editingTextID = nil
        model.tool = .crop
        model.cropAspect = .wide
        snapshot("crop-ratio")
        checkHelp("Aspect ratio: 16:9", maxWidth: 28)
        let toolModel = ScreenshotEditorModel(image: image, scale: 1)
        toolModel.watermarkStyle = .init()
        let toolSize = CGSize(width: 340, height: 540)
        renderTool("watermark-empty-light", content: AnyView(ScreenshotWatermarkPopover(model: toolModel)
            .preferredColorScheme(.light).background(Color(nsColor: .windowBackgroundColor))), size: toolSize, model: toolModel)
        for scheme in [ColorScheme.light, .dark] {
            toolModel.watermarkStyle = .init(kind: .text, text: "Copyright", color: "blue")
            renderTool("watermark-text-\(scheme == .light ? "light" : "dark")",
                content: AnyView(ScreenshotWatermarkPopover(model: toolModel)
                    .preferredColorScheme(scheme).background(Color(nsColor: .windowBackgroundColor))), size: toolSize, model: toolModel)
            renderTool("position-grid-\(scheme == .light ? "light" : "dark")", content: AnyView(
                CaptureAnchorPicker(selected: .bottomTrailing, strings: FeatureStrings.screenshot(.enUS)) { _ in }
                    .frame(width: 248).padding(16).preferredColorScheme(scheme).background(Color(nsColor: .windowBackgroundColor))),
                size: CGSize(width: 280, height: 120))
        }
        toolModel.watermarkStyle = .init(kind: .text, text: "White watermark", color: "white")
        renderTool("watermark-white-light", content: AnyView(ScreenshotWatermarkPopover(model: toolModel)
            .preferredColorScheme(.light).background(Color(nsColor: .windowBackgroundColor))), size: toolSize, model: toolModel)
        let fixtureURL = output.appendingPathComponent("watermark-fixture.png")
        do {
            guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { exit(2) }
            try data.write(to: fixtureURL)
            toolModel.watermarkStyle = .init(kind: .image, imagePath: fixtureURL.path)
            renderTool("watermark-image-light", content: AnyView(ScreenshotWatermarkPopover(model: toolModel)
                .preferredColorScheme(.light).background(Color(nsColor: .windowBackgroundColor))), size: toolSize, model: toolModel)
        } catch { failures.append("cannot create watermark image fixture: \(error)") }
        NSApp.perform(axSetter, with: previousAX, with: "AXEnhancedUserInterface")
        window.orderOut(nil)
        window.contentView = nil
        window.close()
        failures += CaptureEditorFollowupProbe.run(in: output)
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
