// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox

enum ScreenshotWindowLayering {
    // Liftoff uses the screen-saver level (1000). Keep the capture workspace
    // immediately below it, with room for its editors and modal dialogs.
    static let pinLevel = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 3)
    private static let editorBase = NSWindow.Level.screenSaver.rawValue - 2
    private static let dialogBase = NSWindow.Level.screenSaver.rawValue - 1
    static func previewLevel(above owner: NSWindow?) -> NSWindow.Level {
        NSWindow.Level(rawValue: min(dialogBase, max(pinLevel.rawValue, (owner?.level.rawValue ?? 0) + 1)))
    }
    static func editorLevel(above owner: NSWindow?) -> NSWindow.Level {
        NSWindow.Level(rawValue: editorBase)
    }
    static func dialogLevel(above window: AnyObject?) -> NSWindow.Level {
        NSWindow.Level(rawValue: dialogBase)
    }
    static func runModalPanel(_ panel: NSSavePanel, above window: NSWindow?) -> NSApplication.ModalResponse {
        var observers: [NSObjectProtocol] = []
        if let window, window.isVisible {
            let level = dialogLevel(above: window)
            let raise: (Notification) -> Void = { _ in panel.level = level }
            observers = [NSWindow.didBecomeKeyNotification, NSApplication.didBecomeActiveNotification].map {
                NotificationCenter.default.addObserver(forName: $0, object: nil, queue: .main, using: raise)
            }
            panel.level = level
            DispatchQueue.main.async { panel.level = level }
        }
        NSApp.activate(ignoringOtherApps: true)
        let response = panel.runModal()
        observers.forEach(NotificationCenter.default.removeObserver)
        if let window, window.isVisible { window.makeKey() }
        return response
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
