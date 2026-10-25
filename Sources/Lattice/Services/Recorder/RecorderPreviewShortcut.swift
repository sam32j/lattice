// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox

enum RecorderPreviewShortcut {
    case edit, quickLook, copy, save, saveAs, close

    static func match(keyCode: UInt16, characters: String?, modifiers: NSEvent.ModifierFlags) -> Self? {
        let flags = modifiers.intersection([.command, .shift, .option, .control])
        func letter(_ text: String, _ fallback: Int) -> Bool {
            ScreenshotWindowLayering.matchesLetter(text, characters: characters, keyCode: keyCode, fallback: fallback)
        }
        if flags == [.command, .shift], letter("s", kVK_ANSI_S) { return .saveAs }
        if flags == .command {
            if letter("e", kVK_ANSI_E) { return .edit }
            if letter("y", kVK_ANSI_Y) { return .quickLook }
            if letter("c", kVK_ANSI_C) { return .copy }
            if letter("s", kVK_ANSI_S) { return .save }
            if letter("w", kVK_ANSI_W) { return .close }
            return nil
        }
        guard flags.isEmpty else { return nil }
        switch Int(keyCode) {
        case kVK_Space: return .quickLook
        case kVK_Return, kVK_ANSI_KeypadEnter: return .edit
        case kVK_Escape: return .close
        default: return letter("e", kVK_ANSI_E) ? .edit : nil
        }
    }
}
