import Foundation

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
    }
}
