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
            events.removeAll()
            // A hyper key remapped in two stages: Caps Lock arrives at the HID
            // head as Control, and an event-tap remapper adds Command and
            // Option downstream, where the preview's flagsChanged comes from.
            first.noteFlagsChanged([.control, .option, .command])
            TapBoundary.handler?(38, [.control], [.maskControl])
            expect(events.count == 1 && events.first?.keyCode == 38
                   && GlobalShortcutModifiers(eventFlags: events.first?.modifierFlags ?? [])
                       == [.control, .option, .command],
                   "a remapped hyper key records every modifier the preview showed")
            events.removeAll()
            first.noteFlagsChanged([])
            TapBoundary.handler?(38, [.control], [.maskControl])
            expect(GlobalShortcutModifiers(eventFlags: events.first?.modifierFlags ?? []) == [.control],
                   "released preview modifiers do not linger into the next press")
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
