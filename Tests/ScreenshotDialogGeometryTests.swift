import CoreGraphics

enum ScreenshotDialogGeometryTests {
    static func run(_ suite: TestSuite) {
        let context = CGContext(data: nil, width: 240, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 50, y: 40, width: 120, height: 100))
        let original = context.makeImage()!
        let content = ScreenshotDialogGeometry.content(in: original,
            windowFrame: CGRect(x: 100, y: 200, width: 240, height: 200))
        // Quartz draws the fixture at y=40 from the bottom. Its visible top
        // is 60 pixels from the top of the 200-pixel window, hence global 260.
        suite.expect(content?.frame == CGRect(x: 150, y: 260, width: 120, height: 100)
                     && content?.image.width == 120 && content?.image.height == 100,
                     "a padded system-dialog buffer selects and captures its visible body, not transparent margins: \(String(describing: content?.frame))")
        if let content {
            suite.expect(ScreenshotDialogGeometry.content(in: content.image, windowFrame: content.frame)?.frame == content.frame,
                         "the trimmed image actually contains the selected body without a transparent leftover strip")
        }
        context.clear(CGRect(x: 0, y: 0, width: 240, height: 200))
        suite.expect(ScreenshotDialogGeometry.content(in: context.makeImage()!,
            windowFrame: CGRect(x: 0, y: 0, width: 240, height: 200)) == nil,
                     "an empty or protected dialog buffer cannot invent a visible dialog")
    }
}
