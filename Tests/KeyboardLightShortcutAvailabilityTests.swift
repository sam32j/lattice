import Foundation

enum KeyboardLightShortcutAvailabilityTests {
    static func run(_ suite: TestSuite) {
        defer { BrightnessService.keyboardLightIsSupported = true }
        for supported in [false, true] {
            BrightnessService.keyboardLightIsSupported = supported
            for role in [GlobalShortcutRole.keyboardBrightnessDecrease, .keyboardBrightnessIncrease] {
                suite.expect(role.isAvailable(using: { _ in false }) == supported,
                             "keyboard-light roles follow hardware support independently of display installation")
                suite.expect(GlobalShortcutRole.availableRoles(isAvailable: { _ in true }).contains(role) == supported,
                             "unsupported keyboard-light roles stay out of the shortcut editor")
                suite.expect(GlobalShortcutRole.activeRoles(isOn: { _ in true }).contains(role) == supported,
                             "saved preferences cannot activate unsupported keyboard-light roles")
                suite.expect(GlobalShortcutRole.conflict(for: role.defaultShortcut, excluding: nil,
                    isOn: { _ in true }, isAvailable: { _ in false },
                    shortcutForRole: { $0.defaultShortcut }, radialMenuShortcuts: { [] }) == (supported ? role : nil),
                             "unsupported keyboard-light roles do not reserve shortcuts")
            }
        }
    }
}
