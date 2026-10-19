// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct CentralWindowLayoutShortcutRow: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var superKey = SuperKeyService.shared
    let action: WindowLayoutAction
    let shortcutsEnabled: Bool
    let showsSuperKeyAlternative: Bool
    let superKeyModifiers: GlobalShortcutModifiers
    let text: ShortcutSettingsStrings
    @AppStorage private var rawValue: String
    @State private var errorText: String?
    @State private var isRecording = false
    @State private var pendingTakeOver: GlobalShortcut?

    init(action: WindowLayoutAction,
         shortcutsEnabled: Bool,
         showsSuperKeyAlternative: Bool,
         superKeyModifiers: GlobalShortcutModifiers,
         text: ShortcutSettingsStrings) {
        self.action = action
        self.shortcutsEnabled = shortcutsEnabled
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
                    symbolName: AppFeature.windowLayout.symbolName,
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
                        rawValue = pendingTakeOver.storageValue
                        UserDefaults.standard.set(true, forKey: DefaultsKey.windowLayoutShortcutsEnabled)
                        SystemShortcutTakeover.setTakeOver(action.shortcutKey, true)
                        self.pendingTakeOver = nil
                        WindowLayoutService.shared.syncWithPreferences()
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
        rawValue = WindowLayoutAction.clearedShortcutStorageValue
        errorText = nil
        pendingTakeOver = nil
        SystemShortcutTakeover.setTakeOver(action.shortcutKey, false)
        WindowLayoutService.shared.syncWithPreferences()
    }

    private func reset() {
        rawValue = action.defaultShortcut?.storageValue
            ?? WindowLayoutAction.clearedShortcutStorageValue
        errorText = nil
        pendingTakeOver = nil
        UserDefaults.standard.set(true, forKey: DefaultsKey.windowLayoutShortcutsEnabled)
        SystemShortcutTakeover.setTakeOver(action.shortcutKey, false)
        WindowLayoutService.shared.syncWithPreferences()
    }

    private func save(_ shortcut: GlobalShortcut) {
        if let conflict = GlobalShortcutRole.conflict(for: shortcut,
                                                      excluding: nil,
                                                      includeInactive: true) {
            errorText = String(format: l10n.s.shortcutConflictFormat, conflict.title(l10n.s))
            return
        }
        if let conflict = WindowLayoutService.shared.shortcutConflictTitle(shortcut,
                                                                           excluding: action) {
            errorText = String(format: l10n.s.shortcutConflictFormat, conflict)
            return
        }
        // The offer is the last word on a combination: every other check has
        // already passed, so accepting it writes exactly what a save writes.
        switch SystemShortcutTakeoverSupport.recorderDecision(
            shortcut: shortcut,
            conflictsWithMacOS: SystemShortcutTakeover.conflictsWithMacOS(shortcut),
            takenOver: SystemShortcutTakeover.isTakenOver(action.shortcutKey),
            current: GlobalShortcut(storageValue: rawValue)) {
        case .offer:
            pendingTakeOver = shortcut
            errorText = nil
            return
        case .save(let clearTakeOver):
            rawValue = shortcut.storageValue
            UserDefaults.standard.set(true, forKey: DefaultsKey.windowLayoutShortcutsEnabled)
            errorText = nil
            if clearTakeOver { SystemShortcutTakeover.setTakeOver(action.shortcutKey, false) }
        }
        WindowLayoutService.shared.syncWithPreferences()
    }
}
