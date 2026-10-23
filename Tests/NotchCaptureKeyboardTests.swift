// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import Carbon.HIToolbox

/// Production monitor bodies run against plain value doubles. No windows are
/// shown, no native monitors are installed and no keyboard input is generated.
enum NotchCaptureKeyboardContract {
    class NSPanel {
        var isVisible = true
        var attachedSheet: NSPanel?
        var firstResponder: Any?
    }
    final class NSText {}
    final class ScreenshotOverlayPanel: NSPanel {
        var overlayView = Overlay()
        let screenFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
    }
    final class Overlay { var isDragging = false }
    enum ShortcutCapture { static var isCapturing = false }
    struct NSEvent {
        static let mouseLocation = CGPoint(x: 23, y: 61)
        struct ModifierFlags: OptionSet {
            let rawValue: Int
            static let command = Self(rawValue: 1)
            static let control = Self(rawValue: 2)
            static let option = Self(rawValue: 4)
            static let shift = Self(rawValue: 8)
            static let capsLock = Self(rawValue: 16)
            static let deviceIndependentFlagsMask = Self(rawValue: 31)
        }
        struct EventTypeMask: OptionSet {
            let rawValue: Int
            static let keyDown = Self(rawValue: 1)
            static let keyUp = Self(rawValue: 2)
        }
        enum EventType { case keyDown, keyUp }
        let window: NSPanel?
        let keyCode: UInt16
        var modifierFlags: ModifierFlags = []
        var type: EventType = .keyDown
        var isARepeat = false
        var charactersIgnoringModifiers: String?
        static var handler: ((Self) -> Self?)?
        static func addLocalMonitorForEvents(matching: EventTypeMask, handler: @escaping (Self) -> Self?) -> Any? {
            self.handler = handler
            return 1
        }
        static func addGlobalMonitorForEvents(matching: EventTypeMask, handler: @escaping (Self) -> Void) -> Any? { nil }
    }
}

enum NotchCaptureKeyboardTests {
    private typealias Contract = NotchCaptureKeyboardContract
    private typealias Event = Contract.NSEvent

    static func run(_ suite: TestSuite) {
        defer {
            Event.handler = nil
            Contract.ShortcutCapture.isCapturing = false
            Contract.NotchService.shared = Contract.NotchService()
        }
        preview(suite)
        chooser(suite)
    }

    private static func preview(_ suite: TestSuite) {
        let notch = Contract.NotchService()
        Contract.NotchService.shared = notch
        let preview = Contract.Preview()
        notch.captureID = preview.presentationID
        let panel = notch.presentationWindow!
        preview.attach(panel)
        let commands: [(Int, Event.ModifierFlags, Contract.Preview.Action)] = [
            (kVK_ANSI_E, [], .edit), (kVK_ANSI_E, .command, .edit), (kVK_Return, [], .edit), (kVK_Delete, [], .discard),
            (kVK_ForwardDelete, [], .discard), (kVK_ANSI_C, .command, .copy),
            (kVK_ANSI_S, .command, .save), (kVK_Delete, .command, .discard),
        ]
        func check(_ label: String, accepts: Bool) {
            for (key, flags, action) in commands {
                preview.actions = []
                let event = Event(window: panel, keyCode: UInt16(key), modifierFlags: flags)
                let forwarded = Event.handler?(event) != nil
                suite.expect(forwarded == !accepts && preview.actions == (accepts ? [action] : []), label)
            }
            let wasClosed = preview.closed
            preview.actions = []
            let close = Event(window: panel, keyCode: UInt16(kVK_ANSI_W), modifierFlags: .command,
                              charactersIgnoringModifiers: "w")
            suite.expect((Event.handler?(close) == nil) == accepts
                         && preview.closed == (wasClosed || accepts) && preview.actions.isEmpty, label)
            preview.closed = wasClosed
        }
        check("visible capture retains its existing keyboard actions", accepts: true)
        _ = Event.handler?(Event(window: panel, keyCode: UInt16(kVK_ANSI_Y), modifierFlags: .command))
        suite.expect(preview.quickLookRequests == 1, "Command-Y opens Quick Look from the visible preview")
        _ = Event.handler?(Event(window: panel, keyCode: UInt16(kVK_ANSI_Z), modifierFlags: .command,
                                charactersIgnoringModifiers: "y"))
        suite.expect(preview.quickLookRequests == 2, "Quick Look follows the Y character on an alternate keyboard layout")
        let forwardedZ = Event.handler?(Event(window: panel, keyCode: UInt16(kVK_ANSI_Y), modifierFlags: .command,
                                               charactersIgnoringModifiers: "z"))
        suite.expect(forwardedZ != nil && preview.quickLookRequests == 2,
                     "Command-Z on QWERTZ does not accidentally open Quick Look")
        preview.actions = []
        _ = Event.handler?(Event(window: panel, keyCode: UInt16(kVK_ANSI_D), modifierFlags: .command,
                                charactersIgnoringModifiers: "e"))
        suite.expect(preview.actions == [.edit], "Command-E follows the displayed letter on an alternate layout")
        for module in NotchModule.allCases where module != .captures {
            notch.selected = module
            check("a hidden capture never edits, copies, saves or discards while another section owns the window", accepts: false)
        }
        notch.selected = .captures
        notch.showingSections = true
        check("section search keeps typing, deletion and clipboard shortcuts", accepts: false)
        notch.showingSections = false
        notch.showingAppPanel = true
        check("the app panel never inherits hidden capture commands", accepts: false)
        notch.showingAppPanel = false
        notch.expanded = false
        check("a collapsed capture cannot consume keyboard input", accepts: false)
        notch.expanded = true
        Contract.NotchService.ScreenshotSelectionController.isSessionOnScreen = true
        check("an active chooser cannot trigger actions on the previous capture", accepts: false)
        Contract.NotchService.ScreenshotSelectionController.isSessionOnScreen = false
        notch.captureID = UUID()
        check("a replaced preview cannot act on its successor", accepts: false)
        notch.captureID = preview.presentationID
        panel.firstResponder = Contract.NSText()
        check("text editing retains every preview shortcut", accepts: false)
        panel.firstResponder = nil
        panel.attachedSheet = Contract.NSPanel()
        check("a sheet owns input over its parent preview", accepts: false)
        panel.attachedSheet = nil
        Contract.ShortcutCapture.isCapturing = true
        check("shortcut recording cannot execute preview actions", accepts: false)
        Contract.ShortcutCapture.isCapturing = false
        preview.shownInNotch = false
        notch.expanded = false
        check("floating previews retain shortcuts independently of notch state", accepts: true)
        preview.actions = []
        _ = Event.handler?(Event(window: panel, keyCode: UInt16(kVK_Escape)))
        suite.expect(preview.closed && preview.actions.isEmpty, "Escape closes without dispatching a destructive action")
        check("a closed preview ignores late keyboard callbacks", accepts: false)
        preview.closed = false
        let unrelated = Contract.NSPanel()
        let unrelatedClose = Event(window: unrelated, keyCode: UInt16(kVK_ANSI_W), modifierFlags: .command,
                                   charactersIgnoringModifiers: "w")
        suite.expect(Event.handler?(unrelatedClose) != nil && !preview.closed,
                     "Command W leaves unrelated windows alone")
        for (character, key, closes) in [("w", kVK_ANSI_W, true), ("W", kVK_ANSI_W, true),
                                         ("w", kVK_ANSI_Z, true), ("z", kVK_ANSI_W, false),
                                         ("é", kVK_ANSI_W, false), ("ц", kVK_ANSI_W, true),
                                         ("ц", kVK_ANSI_Z, false)] {
            for flags in 0..<32 {
                preview.closed = false
                preview.actions = []
                let accepts = closes && flags & ~Event.ModifierFlags.capsLock.rawValue
                    == Event.ModifierFlags.command.rawValue
                let event = Event(window: panel, keyCode: UInt16(key), modifierFlags: .init(rawValue: flags),
                                  charactersIgnoringModifiers: character)
                suite.expect((Event.handler?(event) == nil) == accepts
                             && preview.closed == accepts && preview.actions.isEmpty,
                             "Command W follows French and Latin letters, falls back for non-Latin input, and excludes extra modifiers")
            }
        }
    }

    private static func chooser(_ suite: TestSuite) {
        let selection = Contract.Selection()
        let notch = Contract.NotchService()
        Contract.NotchService.shared = notch
        let panel = Contract.ScreenshotOverlayPanel()
        selection.attach()
        let enter = Event(window: panel, keyCode: UInt16(kVK_Return))
        suite.expect(Event.handler?(enter) == nil && selection.actions == ["fullDisplay"],
                     "Return captures the display in the on-screen chooser")
        selection.actions = []
        let dragging = Contract.ScreenshotOverlayPanel()
        dragging.overlayView.isDragging = true
        selection.draggingPanel = dragging
        suite.expect(Event.handler?(Event(window: panel, keyCode: UInt16(kVK_Space))) == nil && selection.spaceIsDown,
                     "Space moves an on-screen selection")
        dragging.overlayView.isDragging = false
        suite.expect(Event.handler?(Event(window: panel, keyCode: UInt16(kVK_Space), type: .keyUp)) == nil && !selection.spaceIsDown,
                     "releasing Space clears movement after dragging ends")
        suite.expect(Event.handler?(Event(window: panel, keyCode: UInt16(kVK_Escape))) == nil && selection.actions == ["cancel"],
                     "Escape cancels the on-screen chooser")
        selection.actions = []
        suite.expect(Event.handler?(Event(window: notch.presentationWindow, keyCode: UInt16(kVK_Return))) != nil,
                     "the Dynamic Island is not a capture-control input surface")
        let unrelated = Contract.NSPanel()
        suite.expect(Event.handler?(Event(window: unrelated, keyCode: UInt16(kVK_Return))) != nil,
               "capture selection leaves unrelated windows alone")
        let overlay = Contract.ScreenshotOverlayPanel()
        for destination in [panel, overlay] {
            for flags in 0..<16 {
                for (character, key, matches) in [("x", kVK_ANSI_R, true),
                                                   ("X", kVK_ANSI_R, true),
                                                   ("r", kVK_ANSI_X, true),
                                                   ("r", kVK_ANSI_R, false)] {
                    selection.actions = []
                    let accepts = matches && flags & 7 == 0
                    let event = Event(window: destination, keyCode: UInt16(key),
                                      modifierFlags: .init(rawValue: flags),
                                      charactersIgnoringModifiers: character)
                    suite.expect((Event.handler?(event) == nil) == accepts
                           && selection.actions == (accepts ? ["repeat"] : []),
                           "repeat follows the typed letter or physical key, but never command, control or option")
                }
            }
        }
        selection.actions = []
        for key in [kVK_Return, kVK_ANSI_KeypadEnter] {
            selection.actions = []
            suite.expect(Event.handler?(Event(window: overlay, keyCode: UInt16(key))) == nil
                         && selection.actions == ["fullDisplay"],
                   "Return and keypad Enter keep full-display capture in the floating chooser")
        }
        selection.isPickingColor = true
        selection.draggingPanel = overlay
        selection.panels = [overlay]
        for key in [kVK_Return, kVK_ANSI_KeypadEnter] {
            selection.actions = []
            suite.expect(Event.handler?(Event(window: overlay, keyCode: UInt16(key))) == nil
                         && selection.actions == ["color"],
                   "Return and keypad Enter confirm the color instead of capturing the display")
        }
        selection.isPickingColor = false
        selection.activeTool = .recording
        selection.waitingRecordingPanel = overlay
        selection.actions = []
        suite.expect(Event.handler?(Event(window: overlay, keyCode: UInt16(kVK_Return))) == nil
                     && selection.actions == ["start"], "Enter starts the accepted recording draft")
        suite.expect(Event.handler?(Event(window: overlay, keyCode: UInt16(kVK_ANSI_A))) == nil,
                     "unrelated typing cannot leak through the waiting recording selection")
        for key in [kVK_ANSI_S, kVK_ANSI_M] {
            _ = Event.handler?(Event(window: overlay, keyCode: UInt16(key)))
        }
        suite.expect(selection.screenCaptureOptions?.recorderAudio.systemAudio.enabled == true
                     && selection.screenCaptureOptions?.recorderAudio.microphone.enabled == true,
                     "waiting selection retains both audio control shortcuts")
        let overlays = RecorderOverlayController.shared
        defer { overlays.stop() }
        let cameraWasEnabled = overlays.cameraEnabled
        let keysWereEnabled = overlays.keysEnabled
        for key in [kVK_ANSI_C, kVK_ANSI_K] {
            _ = Event.handler?(Event(window: overlay, keyCode: UInt16(key)))
            _ = Event.handler?(Event(window: overlay, keyCode: UInt16(key), isARepeat: true))
        }
        suite.expect(overlays.cameraEnabled != cameraWasEnabled && overlays.keysEnabled != keysWereEnabled,
                     "C and K remain active while waiting but repeats cannot toggle either twice")
        selection.actions = []
        _ = Event.handler?(Event(window: overlay, keyCode: UInt16(kVK_Escape)))
        suite.expect(selection.actions == ["cancel"], "Escape cancels a waiting recording draft")
    }
}
