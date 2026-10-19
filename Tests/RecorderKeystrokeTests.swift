// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum RecorderKeystrokeTests {
    static func run(_ suite: TestSuite) {
        var display = RecorderKeystrokeState()
        func event(_ text: String, flags: NSEvent.ModifierFlags = []) -> NSEvent {
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                windowNumber: 0, context: nil, characters: text, charactersIgnoringModifiers: text,
                isARepeat: false, keyCode: text == "a" ? 0 : 11)!
        }
        display.consume(event("a"), enabled: false, recording: true, paused: false, secureInput: false, at: 1)
        suite.expect(display.label(at: 1) == nil, "keystroke content is never retained while display is disabled")
        display.consume(event("a"), enabled: true, recording: true, paused: false, secureInput: false, at: 1)
        suite.expect(display.label(at: 1) == "A", "an enabled recording shows an individual key")
        display.consume(event("b"), enabled: true, recording: true, paused: false, secureInput: false, at: 1.1)
        suite.expect(display.label(at: 1.1) == "B", "individual keys replace each other rather than accumulating text")
        suite.expect(display.label(at: 2.1) == nil, "key feedback expires promptly")
        display.consume(event("a", flags: .command), enabled: true, recording: true, paused: false, secureInput: false, at: 3)
        suite.expect(display.label(at: 3) == "⌘A", "shortcut feedback includes the modifier")
        display.consume(event("a"), enabled: true, recording: true, paused: false, secureInput: true, at: 3.1)
        suite.expect(display.label(at: 3.1) == nil, "Secure Input clears feedback without retaining the key")
        display.consume(event("b"), enabled: true, recording: true, paused: true, secureInput: false, at: 4)
        suite.expect(display.label(at: 4) == nil, "paused recording does not capture keys")
        display.consume(event("b"), enabled: true, recording: false, paused: false, secureInput: false, at: 5)
        suite.expect(display.label(at: 5) == nil, "selection and pre-recording states do not capture keys")
    }
}
