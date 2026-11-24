import Foundation

enum PermissionResetHotkeyTests {
    enum InputEventTap { static var isBlocked = false }
    final class Instance {
        var onPress: (() -> Void)?
        var onRelease: (() -> Void)?
    }
    enum QuickToolHotkey { static var instances: [UInt32: Instance] = [:] }

    static func run(_ suite: TestSuite) {
        let instance = Instance()
        QuickToolHotkey.instances = [1: instance]
        defer { QuickToolHotkey.instances = [:] }
        var presses = 0
        instance.onPress = { presses += 1 }
        InputEventTap.isBlocked = false
        deliverQueuedPress(instance)
        suite.expect(presses == 1, "ordinary queued global shortcuts still reach their tool")
        var releases = 0
        instance.onRelease = { releases += 1 }
        deliverQueued(instance, released: true)
        suite.expect(presses == 1 && releases == 1,
                     "a hotkey's key-up reaches its owner as a release, not as another press")
        InputEventTap.isBlocked = true
        defer { InputEventTap.isBlocked = false }
        deliverQueuedPress(instance)
        deliverQueued(instance, released: true)
        suite.expect(presses == 1 && releases == 1, "a global shortcut queued before reset cannot fire after reset begins")
        InputEventTap.isBlocked = false
        QuickToolHotkey.instances = [:]
        deliverQueuedPress(instance)
        suite.expect(presses == 1, "a press queued before its hotkey was unregistered does not reach the tool")
    }
}
