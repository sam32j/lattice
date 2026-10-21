// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox

/// Production shortcut routing with inert file/window actions.
enum ScreenshotEditorKeyTests {
    class ModelState {
        var annotations: [ScreenshotSupport.Annotation] = []
        var selectedIDs: Set<UUID> = []
        var selectedID: UUID? {
            get { selectedIDs.count == 1 ? selectedIDs.first : nil }
            set { selectedIDs = newValue.map { [$0] } ?? [] }
        }
        var editingTextID: UUID?, newTextID: UUID?
        var textSelectionEnabled = false
        var tool = ScreenshotSupport.Tool.select
        var selectedWordIndexes: [Int] = []
        var lastPointerActivityUptime: TimeInterval = 0
        var zoomOverride: CGFloat?, cropDraft: CGRect?
        let scale: CGFloat = 1
        func registerUndo() {}
        func undo() {}
        func redo() {}
        func applyCrop() {}
        func clearTextSelection() { selectedWordIndexes = [] }
        func adjustZoom(by factor: CGFloat) {}
    }
    final class Window {
        var closeRequests = 0
        func performClose(_ sender: Any?) { closeRequests += 1 }
    }
    class State {
        let model = Model()
        var window: Window? = Window()
        var discarded = 0
        func copySelectedText() {}
        func copyToClipboard() {}
        func save() {}
        func saveAs() {}
        func done() {}
        func pin() {}
        func discardAndClose() { discarded += 1 }
    }
    static func run(_ suite: TestSuite) {
        for command in [false, true] {
            let controller = Controller()
            let first = ScreenshotSupport.Annotation(tool: .rect)
            let second = ScreenshotSupport.Annotation(tool: .ellipse)
            controller.model.annotations = [first, second]
            controller.model.selectedIDs = [first.id, second.id]
            let event = NSEvent.keyEvent(with: .keyDown, location: .zero,
                modifierFlags: command ? [.command] : [], timestamp: 0, windowNumber: 0,
                context: nil, characters: "\u{7f}", charactersIgnoringModifiers: "\u{7f}",
                isARepeat: false, keyCode: UInt16(kVK_Delete))!
            suite.expect(controller.handleKey(event) && controller.model.annotations.isEmpty
                         && controller.discarded == 0 && controller.window?.closeRequests == 0,
                         "Delete and Command-Delete remove selected objects without closing the editor")
            if command {
                _ = controller.handleKey(event)
                suite.expect(controller.discarded == 1,
                             "Command-Delete without an object selection retains the existing discard action")
            }
        }
    }
}
