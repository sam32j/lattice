// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit

/// Native sheet ownership and dismissal, using disposable offscreen windows.
enum FeedbackWindowPresentationTests {
    static func run(_ suite: TestSuite) {
        _ = NSApplication.shared
        let parent = NSWindow(contentRect: CGRect(x: -10_000, y: -10_000, width: 800, height: 800),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let feedback = NSWindow(contentRect: CGRect(x: -10_000, y: -10_000, width: 600, height: 680),
                                styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        parent.isReleasedWhenClosed = false
        feedback.isReleasedWhenClosed = false
        defer {
            FeedbackWindowPresentation.dismiss(feedback)
            settle()
            feedback.close(); parent.close()
        }
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 1000)
        parent.orderFront(nil)
        FeedbackWindowPresentation.present(feedback, from: parent, fallbackVisibleFrame: visible)
        suite.expect(parent.attachedSheet === feedback && feedback.sheetParent === parent,
                     "feedback from Settings is a native modal sheet rather than an ordinary child window")
        FeedbackWindowPresentation.present(feedback, from: parent, fallbackVisibleFrame: visible)
        suite.expect(parent.attachedSheet === feedback,
                     "opening an already-presented feedback sheet does not queue a duplicate")
        FeedbackWindowPresentation.dismiss(feedback)
        settle()
        suite.expect(parent.attachedSheet == nil && feedback.sheetParent == nil && !feedback.isVisible,
                     "Cancel ends the sheet and restores the parent instead of leaving modal ownership behind")
        FeedbackWindowPresentation.present(feedback, from: parent, fallbackVisibleFrame: visible)
        suite.expect(parent.attachedSheet === feedback,
                     "feedback may reopen after its previous sheet has been dismissed")
        FeedbackWindowPresentation.dismiss(feedback)
        FeedbackWindowPresentation.present(feedback, from: parent, fallbackVisibleFrame: visible)
        settle()
        suite.expect(parent.attachedSheet === feedback && feedback.isVisible,
                     "reopening during dismissal is not hidden by the old sheet completion")
        FeedbackWindowPresentation.dismiss(feedback)
        settle()
        parent.orderOut(nil)
        FeedbackWindowPresentation.present(feedback, from: parent, fallbackVisibleFrame: visible)
        suite.expect(feedback.sheetParent == nil && feedback.isVisible
                     && feedback.frame == FeedbackWindowGeometry.targetFrame(settingsFrame: nil, visibleFrame: visible),
                     "without visible Settings, feedback retains its centered standalone presentation")
        FeedbackWindowPresentation.dismiss(feedback)
        suite.expect(!feedback.isVisible, "standalone feedback closes without requiring a sheet parent")
    }

    private static func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.35))
    }
}
