// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

enum PermissionDetailsSheetTests {
    final class Model: ObservableObject {
        @Published var presented = false
    }

    struct Host: View {
        @ObservedObject var model: Model
        var body: some View {
            Text("Permissions").frame(width: 600, height: 500)
                .sheet(isPresented: $model.presented) {
                    PermissionDetailsSheet(title: "Accessibility",
                                           explanation: "Lets features react to clicks and keys.",
                                           featureNames: ["Window layout", "Displays"],
                                           isUnused: false, hub: FeatureStrings.hub(.enUS))
                }
        }
    }

    static func run(_ expect: (Bool, String) -> Void) {
        MainActor.assumeIsolated {
            let model = Model()
            let window = NSWindow(contentViewController: NSHostingController(rootView: Host(model: model)))
            window.isReleasedWhenClosed = false
            window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
            defer {
                if let sheet = window.attachedSheet { window.endSheet(sheet) }
                window.close()
            }
            window.orderFront(nil)
            model.presented = true
            pump { window.attachedSheet != nil }
            guard let sheet = window.attachedSheet else {
                expect(false, "permission details opens a native sheet")
                return
            }
            let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                          timestamp: 0, windowNumber: sheet.windowNumber, context: nil,
                                          characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
                                          isARepeat: false, keyCode: 53)!
            _ = sheet.performKeyEquivalent(with: escape)
            pump { !model.presented && window.attachedSheet == nil }
            expect(!model.presented && window.attachedSheet == nil && window.isVisible,
                   "Escape dismisses permission details without closing Settings")
            model.presented = true
            pump { window.attachedSheet != nil }
            expect(window.attachedSheet != nil, "permission details can reopen after dismissal")
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
