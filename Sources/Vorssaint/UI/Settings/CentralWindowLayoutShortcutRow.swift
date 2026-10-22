// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct CentralWindowLayoutShortcutRow: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var superKey = SuperKeyService.shared
    let action: WindowLayoutAction
    @AppStorage(DefaultsKey.windowLayoutShortcutsEnabled) private var shortcutsEnabled = true
    let showsSuperKeyAlternative: Bool
    let superKeyModifiers: GlobalShortcutModifiers
    let text: ShortcutSettingsStrings
    @AppStorage private var rawValue: String
    @State private var errorText: String?
    @State private var isRecording = false
    @State private var pendingTakeOver: GlobalShortcut?

    init(action: WindowLayoutAction,
         showsSuperKeyAlternative: Bool,
         superKeyModifiers: GlobalShortcutModifiers,
         text: ShortcutSettingsStrings) {
        self.action = action
        self.showsSuperKeyAlternative = showsSuperKeyAlternative
        self.superKeyModifiers = superKeyModifiers
        self.text = text
        _rawValue = AppStorage(
            wrappedValue: action.defaultShortcut?.storageValue
                ?? WindowLayoutAction.clearedShortcutStorageValue,
            action.shortcutKey
        )
    }

    private var windowText: WindowLayoutFeatureStrings {
        FeatureStrings.windowLayout(l10n.language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 8) {
                ShortcutRowLabel(
                    title: action.title(windowText),
                    symbolName: action.symbolName,
                    contextLabel: nil,
                    statusText: isActive ? text.active : text.inactive,
                    statusIsActive: isActive
                )
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    CompactShortcutBindingRecorder(
                        recordingID: "central-window-layout-\(String(describing: action))",
                        shortcut: pendingTakeOver ?? shortcut,
                        isEnabled: true,
                        emptyTitle: l10n.s.shortcutNone,
                        canClear: shortcut != nil,
                        canReset: shortcut != action.defaultShortcut,
                        errorText: $errorText,
                        onClear: clear,
                        onReset: reset,
                        onCapture: save,
                        onRecordingChange: { isRecording = $0 })
                    if let alternative = superKeyAlternative {
                        Text(String(format: text.superKeyAlternativeFormat, alternative))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(alternative)
                    }
                }
            }
            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if isRecording {
                Text(ShortcutRecordingCaption.text(l10n.s, canClear: true))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let pendingTakeOver {
                SystemShortcutTakeOverOffer(
                    shortcut: pendingTakeOver,
                    onAccept: {
                        save(pendingTakeOver, approvingSystemConflict: true)
                    },
                    onDismiss: {
                        self.pendingTakeOver = nil
                        errorText = String(format: l10n.s.shortcutConflictFormat, "macOS")
                    }
                )
            }
        }
        .onChange(of: l10n.language) { _, _ in errorText = nil }
    }

    private var shortcut: GlobalShortcut? {
        WindowLayoutAction.resolvedShortcut(storedValue: rawValue,
                                            defaultShortcut: action.defaultShortcut)
    }

    private var isActive: Bool {
        shortcutsEnabled && shortcut != nil
    }

    private var superKeyAlternative: String? {
        guard showsSuperKeyAlternative, let shortcut else { return nil }
        return shortcut.superKeyAlternative(
            sourceLabel: FeatureStrings.superKey(l10n.language).sourceLabel(superKey.source),
            superKeyModifiers: superKeyModifiers)
    }

    private func clear() {
        apply(WindowLayoutShortcutEditor.clear(action))
    }

    private func reset() {
        if let shortcut = action.defaultShortcut { save(shortcut) }
        else { clear() }
    }

    private func save(_ shortcut: GlobalShortcut) {
        save(shortcut, approvingSystemConflict: false)
    }

    private func save(_ shortcut: GlobalShortcut, approvingSystemConflict: Bool) {
        apply(WindowLayoutShortcutEditor.save(shortcut, for: action, language: l10n.language,
            conflictsWithSystem: SystemShortcutTakeover.conflictsWithMacOS(shortcut),
            takenOver: SystemShortcutTakeover.isTakenOver(action.shortcutKey),
            approveSystemConflict: approvingSystemConflict), offered: shortcut)
    }

    private func apply(_ result: WindowLayoutShortcutEditor.Result, offered: GlobalShortcut? = nil) {
        switch result {
        case .conflict(let message):
            errorText = message
            pendingTakeOver = nil
        case .offer:
            pendingTakeOver = offered
            errorText = nil
        case .saved(let value, let takeOver):
            rawValue = value
            errorText = nil
            pendingTakeOver = nil
            SystemShortcutTakeover.setTakeOver(action.shortcutKey, takeOver)
            WindowLayoutService.shared.syncWithPreferences()
        }
    }
}
