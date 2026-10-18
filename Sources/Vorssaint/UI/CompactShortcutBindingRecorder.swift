// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Compact recorder for shortcut owners that do not use GlobalShortcutRole.
struct CompactShortcutBindingRecorder: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var coordinator = CompactShortcutCoordinator.shared

    let recordingID: String
    let shortcut: GlobalShortcut?
    let isEnabled: Bool
    var width: CGFloat = 140
    var emptyTitle: String? = nil
    var canClear = false
    var canReset = false
    var captureModifiers: ((GlobalShortcutModifiers) -> Void)? = nil
    @Binding var errorText: String?
    let onClear: () -> Void
    let onReset: () -> Void
    let onCapture: (GlobalShortcut) -> Void
    var onRecordingChange: (Bool) -> Void = { _ in }

    @State private var pressedModifiers: GlobalShortcutModifiers = []
    @State private var modifierRecording = ModifierShortcutRecording()
    @State private var shakeAttempts: CGFloat = 0

    private var isRecording: Bool {
        coordinator.activeCustomID == recordingID
    }

    var body: some View {
        CompactShortcutField(
            shortcut: shortcut,
            isEnabled: isEnabled,
            isRecording: isRecording,
            pressedModifiers: pressedModifiers,
            errorText: errorText,
            emptyTitle: emptyTitle,
            width: width,
            shakeAttempts: shakeAttempts,
            onToggleRecording: toggleRecording,
            onClear: canClear ? clear : nil,
            onReset: canReset ? reset : nil
        )
        .onChange(of: errorText) { oldValue, newValue in
            guard newValue != nil, newValue != oldValue else { return }
            NSSound.beep()
            withAnimation(.default) { shakeAttempts += 1 }
            let shown = newValue
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if errorText == shown { errorText = nil }
            }
        }
        .onChange(of: coordinator.activeCustomID) { oldValue, newValue in
            if oldValue == recordingID, newValue != recordingID {
                pressedModifiers = []
                modifierRecording = ModifierShortcutRecording()
                onRecordingChange(false)
            }
        }
        .onDisappear { stopRecording() }
        .background {
            if isRecording {
                KeyCaptureBridgeView(
                    onKeyDown: handleKeyEvent,
                    onFlagsChanged: handleFlagsChanged,
                    onExit: stopRecording)
            }
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
            return
        }
        errorText = nil
        pressedModifiers = []
        modifierRecording = ModifierShortcutRecording()
        coordinator.startRecording(customID: recordingID)
        onRecordingChange(true)
    }

    private func stopRecording() {
        guard isRecording else { return }
        coordinator.stopRecording(customID: recordingID)
    }

    private func clear() {
        errorText = nil
        onClear()
        stopRecording()
    }

    private func reset() {
        errorText = nil
        onReset()
        stopRecording()
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let modifiers = GlobalShortcutModifiers(eventFlags: event.modifierFlags)
        pressedModifiers = modifiers
        guard let captureModifiers else { return }
        let unsupported = event.modifierFlags.contains(.function)
        let captured = modifierRecording.flagsChanged(
            modifiers, hasUnsupportedModifier: unsupported)
        if unsupported {
            errorText = l10n.s.shortcutInvalid
            return
        }
        if let captured {
            guard captured.isValidWindowDirectionalTrigger else {
                errorText = l10n.s.shortcutInvalid
                return
            }
            stopRecording()
            captureModifiers(captured)
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return
        }
        let modifiers = GlobalShortcutModifiers(eventFlags: event.modifierFlags)
        if canClear,
           GlobalShortcut.clearsShortcut(keyCode: Int64(event.keyCode),
                                         modifiers: modifiers) {
            clear()
            return
        }
        let captured = GlobalShortcut(keyCode: Int64(event.keyCode),
                                      modifiers: modifiers)
        guard captured.isValid else {
            errorText = l10n.s.shortcutInvalid
            return
        }
        onCapture(captured)
        if errorText == nil { stopRecording() }
    }
}
