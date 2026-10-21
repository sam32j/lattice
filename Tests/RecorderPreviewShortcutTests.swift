// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox

enum RecorderPreviewShortcutTests {
    static func run(_ suite: TestSuite) {
        func action(_ key: Int, _ text: String?, _ flags: NSEvent.ModifierFlags) -> RecorderPreviewShortcut? {
            RecorderPreviewShortcut.match(keyCode: UInt16(key), characters: text, modifiers: flags)
        }
        suite.expect(action(kVK_ANSI_Z, "y", .command) == .quickLook
                     && action(kVK_ANSI_Y, "z", .command) == nil,
                     "video Quick Look follows the typed command letter on QWERTZ")
        suite.expect(action(kVK_ANSI_E, "é", .command) == nil,
                     "accented Latin keys cannot accidentally invoke Edit")
        suite.expect(action(kVK_ANSI_S, "s", [.command, .shift]) == .saveAs
                     && action(kVK_ANSI_S, "s", [.command, .control]) == nil
                     && action(kVK_ANSI_C, "c", [.command, .option]) == nil,
                     "only the advertised modifier combinations perform preview commands")
        suite.expect(action(kVK_Space, " ", []) == .quickLook
                     && action(kVK_Return, "\r", []) == .edit
                     && action(kVK_Escape, nil, []) == .close,
                     "Space previews, Return edits, and Escape dismisses")
    }
}
