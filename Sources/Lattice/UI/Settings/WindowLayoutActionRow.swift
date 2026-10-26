import SwiftUI

struct WindowLayoutActionRow: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.windowLayoutShortcutsEnabled) private var actionsEnabled = true
    let action: WindowLayoutAction
    let title: String
    let symbol: String
    let applyEnabled: Bool
    let shortcutEnabled: Bool
    @AppStorage private var rawValue: String
    var onConflict: ((ShortcutConflictAlert) -> Void)? = nil
    @State private var errorText: String?
    @State private var isRecording = false
    @State private var pendingTakeOver: GlobalShortcut?
    @State private var conflictAlert: ShortcutConflictAlert?

    init(action: WindowLayoutAction,
         title: String,
         symbol: String,
         applyEnabled: Bool,
         shortcutEnabled: Bool,
         onConflict: ((ShortcutConflictAlert) -> Void)? = nil) {
        self.action = action
        self.title = title
        self.symbol = symbol
        self.applyEnabled = applyEnabled
        self.shortcutEnabled = shortcutEnabled
        self.onConflict = onConflict
        _rawValue = AppStorage(
            wrappedValue: action.defaultShortcut?.storageValue
                ?? WindowLayoutAction.clearedShortcutStorageValue,
            action.shortcutKey
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Label(title, systemImage: symbol)
                if !actionsEnabled, shortcut != nil {
                    Text(FeatureStrings.shortcuts(l10n.language).inactive)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                CompactShortcutBindingRecorder(
                    recordingID: "window-layout-\(String(describing: action))",
                    shortcut: pendingTakeOver ?? shortcut,
                    isEnabled: shortcutEnabled,
                    emptyTitle: l10n.s.shortcutNone,
                    canClear: shortcut != nil,
                    canReset: shortcut != action.defaultShortcut,
                    errorText: $errorText,
                    onClear: clear,
                    onReset: reset,
                    onCapture: save,
                    onRecordingChange: { isRecording = $0 })
            }
            if let pendingTakeOver {
                SystemShortcutTakeOverOffer(
                    shortcut: pendingTakeOver,
                    onAccept: {
                        save(pendingTakeOver, approvingSystemConflict: true)
                    },
                    onDismiss: {
                        let attempted = self.pendingTakeOver
                        self.pendingTakeOver = nil
                        if let attempted {
                            let alert = ShortcutConflictAlert(shortcut: attempted, assignedBehavior: "macOS")
                            if let onConflict {
                                onConflict(alert)
                            } else {
                                conflictAlert = alert
                            }
                        }
                    }
                )
            }
        }
        .shortcutConflictAlert($conflictAlert)
        .onChange(of: l10n.language) { _, _ in errorText = nil }
    }

    private var shortcut: GlobalShortcut? {
        WindowLayoutAction.resolvedShortcut(storedValue: rawValue,
                                            defaultShortcut: action.defaultShortcut)
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
        case .conflict(let message, let assignedBehavior):
            pendingTakeOver = nil
            if let offered, let assignedBehavior {
                errorText = nil
                let alert = ShortcutConflictAlert(shortcut: offered, assignedBehavior: assignedBehavior)
                if let onConflict {
                    onConflict(alert)
                } else {
                    conflictAlert = alert
                }
            } else {
                conflictAlert = nil
                errorText = message
            }
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
