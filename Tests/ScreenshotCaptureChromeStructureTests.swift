import AppKit
import Foundation
import SwiftUI

enum ScreenshotCaptureChromeStructureTests {
    static func run(_ suite: TestSuite) {
        let captureSelectionSource = (try? String(contentsOfFile:
            "Sources/Lattice/Services/QuickTools/ScreenshotSelectionController.swift", encoding: .utf8)) ?? ""
        let guide = (try? String(contentsOfFile:
            "Sources/Lattice/UI/Screenshot/UnifiedCaptureGuideContent.swift", encoding: .utf8)) ?? ""
        suite.expect(captureSelectionSource.contains(
            "screenCaptureOptions?.showsCaptureMenu == false ? 82 : 146")
                && guide.contains(
                    ".opacity(options.selectedTool == .recording ? 1 : 0)"),
               "capture modes reserve the recording controls' height so the chooser never jumps")
        let host = (try? String(contentsOfFile:
            "Sources/Lattice/UI/Screenshot/PassThroughHostingView.swift", encoding: .utf8)) ?? ""
        suite.expect(captureSelectionSource.contains("addSubview(fullScreenHost)")
                && captureSelectionSource.contains("guideHost.interactiveRegions = []")
                && host.contains("interactiveRegions.contains {")
                && !host.contains("if !isHovered {"),
               "capture strip buttons receive the first click, while empty overlay space remains draggable")
        let regions = (try? String(contentsOfFile:
            "Sources/Lattice/UI/Screenshot/ScreenshotCaptureGuideView.swift", encoding: .utf8)) ?? ""
        suite.expect(regions.contains("anchorPreference(key: CaptureGuideInteractiveRegionKey.self")
                && regions.contains("backgroundPreferenceValue(CaptureGuideInteractiveRegionKey.self")
                && host.contains("func containsCaptureControl(at local: NSPoint)")
                && host.contains("swiftUIPoint(from: local)")
                && captureSelectionSource.contains("guideHost.captureCursor(at: guideHost.convert(pointer, from: self))"),
               "capture strip uses measured root-space anchor bounds for click hit-testing and pointer feedback")
        suite.expect(host.contains("func captureCursor(at point: NSPoint)")
                && host.contains("interactiveRegions.contains {")
                && host.contains("selectionIsInProgress?() != true")
                && captureSelectionSource.contains("guideHost.selectionIsInProgress = isSelecting")
                && captureSelectionSource.contains("fullScreenHost.selectionIsInProgress = isSelecting")
                && captureSelectionSource.contains("refreshCaptureControlCursors()"),
               "capture controls show the arrow only over interactive regions and never during a drag")
        let cursorHost = PassThroughHostingView(interactiveRootView: Text("Controls"))
        cursorHost.frame = CGRect(x: 0, y: 0, width: 250, height: 60)
        cursorHost.interactiveRegions = [CGRect(x: 20, y: 10, width: 90, height: 35)]
        var dragging = false
        cursorHost.selectionIsInProgress = { dragging }
        suite.expect(cursorHost.captureCursor(at: CGPoint(x: 30, y: 20)) === NSCursor.arrow
                && cursorHost.captureCursor(at: CGPoint(x: 175, y: 20)) === NSCursor.crosshair,
               "the pointer is an arrow over the strip and a crosshair over the blank hosting area")
        dragging = true
        suite.expect(cursorHost.captureCursor(at: CGPoint(x: 30, y: 20)) === NSCursor.crosshair,
               "an active selection drag keeps the crosshair over the strip")
        dragging = false
        cursorHost.interactiveRegions = [CGRect(x: 20, y: 10, width: 90, height: 35),
                                         CGRect(x: 160, y: 10, width: 65, height: 35)]
        suite.expect(cursorHost.containsCaptureControl(at: CGPoint(x: 190, y: 20))
                && !cursorHost.containsCaptureControl(at: CGPoint(x: 135, y: 20))
                && cursorHost.captureCursor(at: CGPoint(x: 190, y: 20)) === NSCursor.arrow,
               "top and bottom capture-control groups remain clickable without shielding gaps")
        suite.expect(captureSelectionSource.contains("activeMode == .image || activeMode == .geometry")
                && captureSelectionSource.contains("controller.captureFullScreenFromControl(on: panel)"),
               "the screenshot and recording full-display actions share the existing capture route")
    }
}
