import Foundation

enum PermissionResetHotkeyTests {
    enum InputEventTap { static var isBlocked = false }
    final class Instance { var onPress: (() -> Void)? }

    static func run(_ suite: TestSuite) {
        let instance = Instance()
        var presses = 0
        instance.onPress = { presses += 1 }
        InputEventTap.isBlocked = false
        deliverQueuedPress(instance)
        suite.expect(presses == 1, "ordinary queued global shortcuts still reach their tool")
        InputEventTap.isBlocked = true
        defer { InputEventTap.isBlocked = false }
        deliverQueuedPress(instance)
        suite.expect(presses == 1, "a global shortcut queued before reset cannot fire after reset begins")
    }
}
