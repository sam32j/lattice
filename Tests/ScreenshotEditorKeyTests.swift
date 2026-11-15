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
        func copySelectedText() {}
        func copyToClipboard() {}
        func save() {}
        func saveAs() {}
        func done() {}
        var keptChanges = 0
        func saveChanges() { keptChanges += 1 }
        func pin() {}
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
                         && controller.window?.closeRequests == 0,
                         "Delete and Command-Delete remove selected objects without closing the editor")
            if command {
                _ = controller.handleKey(event)
                suite.expect(controller.window?.closeRequests == 1,
                             "Command-Delete without an object selection asks to close, with the discard confirmation")
            }
        }
        let controller = Controller()
        let save = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command], timestamp: 0,
            windowNumber: 0, context: nil, characters: "s", charactersIgnoringModifiers: "s",
            isARepeat: false, keyCode: UInt16(kVK_ANSI_S))!
        suite.expect(controller.handleKey(save) && controller.keptChanges == 1
                     && controller.window?.closeRequests == 0,
                     "Command-S keeps the edits without closing the editor")
    }
}
