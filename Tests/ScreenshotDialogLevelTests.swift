import AppKit

enum ScreenshotDialogLevelTests {
    static func run(_ suite: TestSuite) {
        let owner = NSPanel(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
        owner.isReleasedWhenClosed = false
        defer { owner.close() }
        owner.level = .statusBar
        suite.expect(ScreenshotWindowLayering.dialogLevel(above: owner).rawValue > owner.level.rawValue,
                     "recorder Save As dialogs clear their status-bar-level preview owner")
        for level in [ScreenshotWindowLayering.pinLevel, ScreenshotWindowLayering.editorLevel(above: nil)] {
            owner.level = level
            let dialog = ScreenshotWindowLayering.dialogLevel(above: owner).rawValue
            suite.expect(dialog > level.rawValue && dialog < 26,
                         "pin/editor dialogs clear their owner while staying below Liftoff")
        }
        for owner: AnyObject? in [nil, NSObject()] {
            let dialog = ScreenshotWindowLayering.dialogLevel(above: owner).rawValue
            suite.expect(dialog > ScreenshotWindowLayering.editorLevel(above: nil).rawValue && dialog < 26,
                         "no-window dialog fallback retains the workspace band")
        }
    }
}
