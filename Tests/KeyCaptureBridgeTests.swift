// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Replace only the global event-tap boundary, never suppress desktop input.
enum KeyCaptureBridgeTests {
    typealias ShortcutRecordingTap = TapBoundary
    enum TapBoundary {
        static var handler: ((Int64, GlobalShortcutModifiers, CGEventFlags) -> Void)?
        static var ends = 0
        static func begin(_ handler: @escaping (Int64, GlobalShortcutModifiers, CGEventFlags) -> Void) -> Bool {
            self.handler = handler
            return true
        }
        static func end() { handler = nil; ends += 1 }
    }

    static func run(_ expect: (Bool, String) -> Void) {
        MainActor.assumeIsolated {
            var events: [NSEvent] = []
            let first = KeyCaptureBridgeView.Coordinator(onKeyDown: { events.append($0) }, onFlagsChanged: { _ in })
            let second = KeyCaptureBridgeView.Coordinator(onKeyDown: { events.append($0) }, onFlagsChanged: { _ in })
            defer {
                first.remove(); second.remove()
                TapBoundary.handler = nil; TapBoundary.ends = 0
            }
            let view = NSView()
            first.install(view: view)
            TapBoundary.handler?(48, [.command, .control], [.maskCommand, .maskSecondaryFn])
            expect(events.count == 1 && events.first?.keyCode == 48
                   && events.first?.modifierFlags.contains([.command, .control, .function]) == true,
                   "system-intercepted keys reach the compact recorder with all effective modifiers")
            second.install(view: view)
            first.remove()
            expect(TapBoundary.ends == 0 && TapBoundary.handler != nil,
                   "dismantling an old recorder cannot stop its replacement's global capture")
            second.remove()
            expect(TapBoundary.ends == 1 && TapBoundary.handler == nil,
                   "the active recorder releases global capture on removal")
        }
    }
}
