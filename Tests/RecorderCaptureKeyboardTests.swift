import Foundation
import Carbon.HIToolbox

enum RecorderCaptureKeyboardContract {
    typealias NSPanel = NotchCaptureKeyboardContract.NSPanel
    typealias NSText = NotchCaptureKeyboardContract.NSText
    typealias NSEvent = NotchCaptureKeyboardContract.NSEvent
    typealias NotchService = NotchCaptureKeyboardContract.NotchService
    typealias ScreenshotSelectionController = NotchCaptureKeyboardContract.ScreenshotSelectionController
    typealias ShortcutCapture = NotchCaptureKeyboardContract.ShortcutCapture
}

enum RecorderCaptureKeyboardTests {
    static func run(_ suite: TestSuite) {
        typealias Contract = RecorderCaptureKeyboardContract
        typealias Event = Contract.NSEvent
        let previous = Contract.NotchService.shared
        defer {
            Contract.NotchService.shared = previous
            Contract.ScreenshotSelectionController.isSessionOnScreen = false
            Event.handler = nil
        }
        let notch = Contract.NotchService()
        Contract.NotchService.shared = notch
        let preview = Contract.Preview()
        notch.captureID = preview.presentationID
        let panel = notch.presentationWindow!
        preview.attach(panel)
        let copy = Event(window: panel, keyCode: UInt16(kVK_ANSI_C), modifierFlags: .command,
                         charactersIgnoringModifiers: "c")
        suite.expect(Event.handler?(copy) == nil && preview.copies == 1,
                     "visible recorder preview handles its copy shortcut")
        Contract.ScreenshotSelectionController.isSessionOnScreen = true
        suite.expect(notch.isCaptureVisible(id: preview.presentationID)
                     && Event.handler?(copy) != nil && preview.copies == 1,
                     "a new capture blocks recorder commands without falsifying preview visibility")
        Contract.ScreenshotSelectionController.isSessionOnScreen = false
        suite.expect(Event.handler?(copy) == nil && preview.copies == 2,
                     "recorder shortcuts resume after capture selection ends")
        Contract.ScreenshotSelectionController.isSessionOnScreen = true
        preview.shownInNotch = false
        suite.expect(Event.handler?(copy) == nil && preview.copies == 3,
                     "standalone recorder shortcuts keep their existing independent behavior")
    }
}
