// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

enum SettingsChangelogTests {
    final class Model: ObservableObject {
        @Published var presented = false
    }

    struct Host: View {
        @ObservedObject var model: Model

        var body: some View {
            Text("Settings")
                .frame(width: 700, height: 650)
                .sheet(isPresented: $model.presented) {
                    ReleaseNotesSettings().frame(width: 620, height: 600)
                }
        }
    }

    static func run(_ expect: (Bool, String) -> Void) {
        MainActor.assumeIsolated {
            let model = Model()
            let window = NSWindow(contentViewController: NSHostingController(rootView: Host(model: model)))
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
            window.isReleasedWhenClosed = false
            let chrome = (window.styleMask, window.titleVisibility, window.titlebarAppearsTransparent)
            defer {
                if let sheet = window.attachedSheet { window.endSheet(sheet) }
                window.close()
            }
            window.orderFront(nil)
            model.presented = true
            pump { window.attachedSheet != nil }
            guard let sheet = window.attachedSheet else {
                expect(false, "the actual changelog presents as a sheet")
                return
            }
            expect(window.styleMask == chrome.0 && window.titleVisibility == chrome.1
                   && window.titlebarAppearsTransparent == chrome.2,
                   "showing the changelog preserves its parent window's chrome")
            let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                          timestamp: 0, windowNumber: sheet.windowNumber, context: nil,
                                          characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
                                          isARepeat: false, keyCode: 53)!
            _ = sheet.performKeyEquivalent(with: escape)
            pump { !model.presented && window.attachedSheet == nil }
            expect(!model.presented && window.attachedSheet == nil && window.isVisible,
                   "Escape dismisses the changelog while Settings stays open")
            model.presented = true
            pump { window.attachedSheet != nil }
            expect(window.attachedSheet != nil,
                   "the changelog can reopen after dismissal")
            model.presented = false
            pump { window.attachedSheet == nil }
        }
    }

    private static func pump(until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
    }
}
