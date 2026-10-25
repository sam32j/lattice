import Foundation

enum NotchCaptureVisibilityTests {
    static func run(_ suite: TestSuite) {
        typealias Contract = NotchCaptureKeyboardContract
        let notch = Contract.NotchService()
        let id = UUID()
        notch.captureID = id
        Contract.ScreenshotSelectionController.isSessionOnScreen = true
        defer { Contract.ScreenshotSelectionController.isSessionOnScreen = false }
        suite.expect(notch.isCaptureVisible(id: id),
                     "a new chooser does not change the visible previous preview's identity")
        let excluded = ScreenshotCapturePolicy.excludedWindowIDs(ownWindowIDs: [1, 2],
            protectedWindowIDs: notch.protectedWindowIDs, islandWindowIDs: notch.captureVisibleWindowIDs)
        suite.expect(excluded == [1] && notch.captureVisibleWindowIDs == [2] && notch.protectedWindowIDs == [1],
                     "a visible capture preview stays excluded while other island windows follow visibility settings")
    }
}
