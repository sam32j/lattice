import AppKit
import CoreGraphics

enum CapturePresentationPolicyTests {
    static func run(_ suite: TestSuite) {
        ScreenshotExitOrderingTests.run(suite)
        ScreenshotDialogGeometryTests.run(suite)
        ScreenshotDialogLevelTests.run(suite)
        suite.expect(ScreenshotCapturePolicy.isPickableWindowLayer(102, ownerName: "CoreServicesUIAgent")
                     && ScreenshotCapturePolicy.isPickableWindowLayer(1000, ownerName: "SecurityAgent")
                     && !ScreenshotCapturePolicy.isPickableWindowLayer(1000, ownerName: "Window Server")
                     && !ScreenshotCapturePolicy.isPickableWindowLayer(2000, ownerName: "SecurityAgent"),
                     "ordinary system-dialog layers can be selected without admitting compositor or protected higher layers")
        suite.expect(CapturePresentationPolicy.overlayLevel.rawValue > 1000,
                     "selection chrome stays above eligible elevated dialogs")
        suite.expect(ScreenshotWindowLayering.pinLevel.rawValue > NSWindow.Level.floating.rawValue
                     && ScreenshotWindowLayering.dialogLevel(above: nil).rawValue < 26,
                     "capture pins, editors and dialogs stay below Liftoff's full-size layer-26 launcher")
        let selection = CGRect(x: 20, y: 20, width: 100, height: 100)
        suite.expect(CapturePresentationPolicy.overlaps(chrome: CGRect(x: 50, y: 50, width: 30, height: 20), selection: selection)
                     && !CapturePresentationPolicy.overlaps(chrome: CGRect(x: 200, y: 50, width: 30, height: 20), selection: selection)
                     && !CapturePresentationPolicy.overlaps(chrome: selection, selection: .zero),
                     "only a nonempty selection intersecting capture chrome requests a clear preview")
        suite.expect(CapturePresentationPolicy.toolbarOpacity(overlapsSelection: true, isDragging: true) <= 0.2
                     && CapturePresentationPolicy.toolbarOpacity(overlapsSelection: true, isDragging: false) == 1
                     && CapturePresentationPolicy.toolbarOpacity(overlapsSelection: false, isDragging: true) == 1,
                     "only an actively dragged overlapping area fades the toolbar; hover and completed selection stay readable")
    }
}
