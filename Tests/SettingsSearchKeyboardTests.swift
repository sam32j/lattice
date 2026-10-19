import AppKit

enum SettingsSearchKeyboardTests {
    static func run(_ suite: TestSuite) {
        func command(_ character: String, physicalKey: UInt16,
                     flags: NSEvent.ModifierFlags = .command) -> NSEvent {
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                             timestamp: 0, windowNumber: 0, context: nil,
                             characters: character, charactersIgnoringModifiers: character,
                             isARepeat: false, keyCode: physicalKey)!
        }
        suite.expect(isFindCommand(command("f", physicalKey: 3)),
                     "Command-F focuses Settings search on the standard layout")
        suite.expect(isFindCommand(command("f", physicalKey: 17)),
                     "logical Command-F works when another physical key produces F")
        suite.expect(!isFindCommand(command("e", physicalKey: 3)),
                     "the US physical F position does not hijack a different layout’s command")
        suite.expect(!isFindCommand(command("f", physicalKey: 3, flags: [.command, .shift])),
                     "modified Command-Shift-F is not consumed as Find")
    }
}
