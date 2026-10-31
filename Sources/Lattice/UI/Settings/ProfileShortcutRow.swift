import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ProfileShortcutRow: View {
    @Binding var shortcutValue: String
    let isEnabled: Bool
    let text: RadialMenuFeatureStrings
    let l10n: L10n
    /// Names whoever already answers to a combination, or nil when it is free.
    let conflictTitle: (GlobalShortcut) -> String?
    let onChange: () -> Void

    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(text.profileShortcutLabel)
                Spacer()
                CompactShortcutBindingRecorder(
                    recordingID: "radial-profile-\(shortcutValue)",
                    shortcut: GlobalShortcut(storageValue: shortcutValue),
                    isEnabled: isEnabled,
                    width: 140,
                    emptyTitle: l10n.s.shortcutNone,
                    canClear: !shortcutValue.isEmpty,
                    errorText: $message,
                    onClear: {
                        shortcutValue = ""
                        message = nil
                        onChange()
                    },
                    onReset: {},
                    onCapture: { newShortcut in
                        if let owner = conflictTitle(newShortcut) {
                            message = String(format: l10n.s.shortcutConflictFormat, owner)
                            return
                        }
                        shortcutValue = newShortcut.storageValue
                        message = nil
                        onChange()
                    })
            }
            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - Row
