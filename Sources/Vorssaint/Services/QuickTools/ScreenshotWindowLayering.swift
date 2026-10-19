// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox

enum ScreenshotWindowLayering {
    static func previewLevel(above owner: NSWindow?) -> NSWindow.Level {
        NSWindow.Level(rawValue: max(NSWindow.Level.popUpMenu.rawValue - 1, (owner?.level.rawValue ?? 0) + 1))
    }
    static func editorLevel(above owner: NSWindow?) -> NSWindow.Level {
        guard let owner else { return .normal }
        return NSWindow.Level(rawValue: max(NSWindow.Level.normal.rawValue, owner.level.rawValue + 1))
    }
    static func isQuickLookShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard flags == .command else { return false }
        return matchesLetter("y", characters: event.charactersIgnoringModifiers,
                             keyCode: event.keyCode, fallback: kVK_ANSI_Y)
    }
    static func matchesLetter(_ letter: String, characters: String?, keyCode: UInt16, fallback: Int) -> Bool {
        let text = characters?.folding(options: [.caseInsensitive], locale: nil)
        let latin = text?.folding(options: [.diacriticInsensitive], locale: nil)
        // Accented Latin keys such as French é are not the plain E command.
        // Non-Latin layouts keep the established physical-key fallback.
        if let latin, latin.count == 1, latin.first?.isASCII == true, latin.first?.isLetter == true { return text == letter }
        return keyCode == UInt16(fallback)
    }
}
