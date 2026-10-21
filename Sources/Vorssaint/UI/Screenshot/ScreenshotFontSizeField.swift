// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// A plain number field that takes keyboard focus only when clicked.
struct ScreenshotFontSizeField: NSViewRepresentable {
    @Binding var value: Int
    let title: String
    let onEditingChanged: (Bool) -> Void
    @Environment(\.isEnabled) private var isEnabled

    func makeNSView(context: Context) -> Control {
        let field = Control()
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.alignment = .center
        field.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        field.delegate = context.coordinator
        field.setAccessibilityLabel(title)
        return field
    }
    func updateNSView(_ field: Control, context: Context) {
        context.coordinator.parent = self
        field.isEnabled = isEnabled
        if field.currentEditor() == nil { field.stringValue = String(value) }
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Control: NSTextField {
        var clicked = false
        override var acceptsFirstResponder: Bool { clicked && isEnabled }
        override var needsPanelToBecomeKey: Bool { true }
        override func mouseDown(with event: NSEvent) {
            clicked = true
            window?.makeKey()
            window?.makeFirstResponder(self)
            super.mouseDown(with: event)
        }
    }
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ScreenshotFontSizeField
        init(_ parent: ScreenshotFontSizeField) { self.parent = parent }
        func controlTextDidBeginEditing(_ notification: Notification) { parent.onEditingChanged(true) }
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? Control,
                  let number = Int(field.stringValue), ScreenshotSupport.textSizeRange.contains(number) else { return }
            parent.value = number
        }
        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? Control else { return }
            if let number = Int(field.stringValue) { parent.value = min(96, max(8, number)) }
            field.stringValue = String(parent.value)
            field.clicked = false
            parent.onEditingChanged(false)
        }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy command: Selector) -> Bool {
            guard command == #selector(NSResponder.insertNewline(_:)) else { return false }
            control.window?.makeFirstResponder(nil)
            return true
        }
    }
}
