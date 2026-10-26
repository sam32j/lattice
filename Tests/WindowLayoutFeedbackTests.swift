import Foundation

enum WindowLayoutFeedbackTests {
    class State {
        var errorText: String?
        var pendingTakeOver: GlobalShortcut?
        var conflictAlert: ShortcutConflictAlert?
        var onConflict: ((ShortcutConflictAlert) -> Void)?
        var rawValue = ""
        let action = WindowLayoutAction.leftHalf
    }
    enum SystemShortcutTakeover {
        static func setTakeOver(_ key: String, _ value: Bool) {}
    }
    final class WindowLayoutService {
        static let shared = WindowLayoutService()
        func syncWithPreferences() {}
    }
    static func run(_ suite: TestSuite) {
        let shortcut = GlobalShortcut(keyCode: 18, modifiers: [.control, .option, .command])
        let central = CentralRow()
        let action = ActionRow()
        for (state, apply) in [(central as State, central.apply), (action as State, action.apply)] {
            apply(.conflict("Invalid shortcut", assignedBehavior: nil), shortcut)
            suite.expect(state.errorText == "Invalid shortcut" && state.conflictAlert == nil,
                         "invalid input retains its real message rather than claiming another assignment")
            apply(.conflict("Already used", assignedBehavior: "Open Clipboard History"), shortcut)
            suite.expect(state.errorText == nil && state.conflictAlert?.assignedBehavior == "Open Clipboard History"
                         && state.conflictAlert?.shortcut == shortcut,
                         "both shortcut surfaces show the assigned behavior through the conflict alert")
        }
        var forwarded: ShortcutConflictAlert?
        action.onConflict = { forwarded = $0 }
        action.apply(.conflict("Already used", assignedBehavior: "Another window action"), offered: shortcut)
        suite.expect(forwarded?.assignedBehavior == "Another window action",
                     "the window action forwards its conflict to the owning page when supplied")
    }
}
