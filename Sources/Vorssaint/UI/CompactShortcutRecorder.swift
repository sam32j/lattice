// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox
import SwiftUI

struct CompactShortcutPreferenceRow: View {
    let title: String
    let role: GlobalShortcutRole
    let enabledKey: String
    var onChange: () -> Void = {}

    var body: some View {
        HStack {
            Text(title).lineLimit(1)
            Spacer()
            CompactShortcutRecorder(role: role, enabledKey: enabledKey,
                                    onChange: onChange)
        }
    }
}

struct CompactShortcutRecorder: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var coordinator = CompactShortcutCoordinator.shared

    let role: GlobalShortcutRole
    let includeInactiveConflicts: Bool
    let additionalConflict: (GlobalShortcut) -> String?
    var onChange: () -> Void = {}

    @AppStorage private var isEnabled: Bool
    @AppStorage private var rawValue: String
    @State private var pressedModifiers: GlobalShortcutModifiers = []
    @State private var errorText: String?
    @State private var shakeAttempts: CGFloat = 0
    @State private var pendingTakeOver: GlobalShortcut?

    init(role: GlobalShortcutRole,
         enabledKey: String,
         includeInactiveConflicts: Bool = false,
         additionalConflict: @escaping (GlobalShortcut) -> String? = { _ in nil },
         onChange: @escaping () -> Void = {}) {
        self.role = role
        self.includeInactiveConflicts = includeInactiveConflicts
        self.additionalConflict = additionalConflict
        self.onChange = onChange
        _isEnabled = AppStorage(wrappedValue: false, enabledKey)
        _rawValue = AppStorage(wrappedValue: role.defaultShortcut.storageValue,
                               role.storageKey)
    }

    private var isRecording: Bool { coordinator.activeRole == role }
    private var shortcut: GlobalShortcut {
        GlobalShortcut(storageValue: rawValue) ?? role.defaultShortcut
    }
    private var isModifiedFromDefault: Bool {
        !isEnabled || shortcut != role.defaultShortcut
    }

    private var hasShortcut: Bool { isEnabled && !rawValue.isEmpty }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            CompactShortcutField(
                shortcut: hasShortcut ? (pendingTakeOver ?? shortcut) : nil,
                isEnabled: true,
                isRecording: isRecording,
                pressedModifiers: pressedModifiers,
                errorText: errorText,
                emptyTitle: nil,
                width: 140,
                shakeAttempts: shakeAttempts,
                onToggleRecording: toggleRecording,
                onClear: hasShortcut ? clearShortcut : nil,
                onReset: !hasShortcut || isModifiedFromDefault ? resetToDefault : nil)
            if let pendingTakeOver {
                SystemShortcutTakeOverOffer(
                    shortcut: pendingTakeOver,
                    onAccept: { acceptTakeOver(pendingTakeOver) },
                    onDismiss: {
                        self.pendingTakeOver = nil
                        showError(String(format: l10n.s.shortcutConflictFormat,
                                         "macOS"))
                    })
            }
        }
        .onChange(of: coordinator.activeRole) { _, newRole in
            if newRole != role { pressedModifiers = [] }
        }
        .onDisappear { coordinator.stopRecording(role: role) }
        .background {
            if isRecording {
                KeyCaptureBridgeView(
                    onKeyDown: handleKeyEvent,
                    onFlagsChanged: {
                        pressedModifiers = GlobalShortcutModifiers(
                            eventFlags: $0.modifierFlags)
                    },
                    onExit: { coordinator.stopRecording(role: role) })
            }
        }
    }

    private func toggleRecording() {
        if isRecording {
            coordinator.stopRecording(role: role)
        } else {
            errorText = nil
            pendingTakeOver = nil
            pressedModifiers = []
            coordinator.startRecording(role: role)
        }
    }

    private func showError(_ text: String) {
        errorText = text
        NSSound.beep()
        withAnimation(.default) { shakeAttempts += 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if errorText == text { errorText = nil }
        }
    }

    private func resetToDefault() {
        guard case .save(let clearTakeOver)? =
                validationDecision(role.defaultShortcut) else { return }
        rawValue = role.defaultShortcut.storageValue
        isEnabled = true
        errorText = nil
        if clearTakeOver {
            SystemShortcutTakeover.setTakeOver(role.storageKey, false)
        }
        onChange()
    }

    private func validationDecision(
        _ shortcut: GlobalShortcut
    ) -> RecorderTakeOverDecision? {
        guard shortcut.isValid else {
            showError(l10n.s.shortcutInvalid)
            return nil
        }
        if let conflict = GlobalShortcutRole.conflict(
            for: shortcut, excluding: role,
            includeInactive: includeInactiveConflicts) {
            showError(String(format: l10n.s.shortcutConflictFormat,
                             conflict.title(l10n.s)))
            return nil
        }
        if let conflict = additionalConflict(shortcut) {
            showError(String(format: l10n.s.shortcutConflictFormat, conflict))
            return nil
        }
        let conflictsWithMacOS = role.supportsTakeOver
            ? SystemShortcutTakeover.conflictsWithMacOS(shortcut, for: role)
            : shortcut.conflictsWithSystemShortcut(for: role)
        if conflictsWithMacOS, !role.supportsTakeOver {
            showError(String(format: l10n.s.shortcutConflictFormat, "macOS"))
            return nil
        }
        let decision = SystemShortcutTakeoverSupport.recorderDecision(
            shortcut: shortcut,
            conflictsWithMacOS: conflictsWithMacOS,
            takenOver: SystemShortcutTakeover.isTakenOver(role.storageKey),
            current: GlobalShortcut(storageValue: rawValue))
        if case .offer = decision {
            pendingTakeOver = shortcut
            errorText = nil
            return nil
        }
        return decision
    }

    private func acceptTakeOver(_ shortcut: GlobalShortcut) {
        rawValue = shortcut.storageValue
        isEnabled = true
        pendingTakeOver = nil
        errorText = nil
        SystemShortcutTakeover.setTakeOver(role.storageKey, true)
        onChange()
    }

    private func clearShortcut() {
        rawValue = ""
        switch role {
        case .switcher, .switcherWindow, .displayBrightnessDecrease,
             .displayBrightnessIncrease, .keyboardBrightnessDecrease,
             .keyboardBrightnessIncrease:
            break
        default:
            isEnabled = false
        }
        pendingTakeOver = nil
        SystemShortcutTakeover.setTakeOver(role.storageKey, false)
        errorText = nil
        onChange()
    }

    private func handleKeyEvent(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            coordinator.stopRecording(role: role)
            return
        }
        let modifiers = GlobalShortcutModifiers(eventFlags: event.modifierFlags)
        if GlobalShortcut.clearsShortcut(keyCode: Int64(event.keyCode),
                                         modifiers: modifiers) {
            clearShortcut()
            coordinator.stopRecording(role: role)
            return
        }
        let captured = GlobalShortcut(keyCode: Int64(event.keyCode),
                                      modifiers: modifiers)
        guard case .save(let clearTakeOver)? = validationDecision(captured) else {
            if pendingTakeOver != nil { coordinator.stopRecording(role: role) }
            return
        }
        rawValue = captured.storageValue
        if clearTakeOver {
            SystemShortcutTakeover.setTakeOver(role.storageKey, false)
        }
        isEnabled = true
        errorText = nil
        coordinator.stopRecording(role: role)
        onChange()
    }
}

struct CompactRecorderShakeEffect: GeometryEffect {
    var amount: CGFloat = 6
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: amount * sin(animatableData * .pi * shakesPerUnit),
            y: 0))
    }
}
