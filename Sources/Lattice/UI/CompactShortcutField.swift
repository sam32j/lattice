// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Shared fixed-size chrome for every editable shortcut. Owners keep capture,
/// validation and persistence; this view keeps the interaction visually stable.
struct CompactShortcutField: View {
    @ObservedObject private var l10n = L10n.shared

    let shortcut: GlobalShortcut?
    let isEnabled: Bool
    let isRecording: Bool
    let pressedModifiers: GlobalShortcutModifiers
    let errorText: String?
    let emptyTitle: String?
    let width: CGFloat
    let shakeAttempts: CGFloat
    let onToggleRecording: () -> Void
    let onClear: (() -> Void)?
    let onReset: (() -> Void)?

    @State private var isHovering = false

    var body: some View {
        ZStack {
            Button(action: onToggleRecording) {
                HStack(spacing: 4) {
                    content
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)

            if isEnabled, !isRecording, errorText == nil {
                HStack(spacing: 4) {
                    Spacer()
                    if let onReset {
                        actionButton("arrow.uturn.backward", help: l10n.s.shortcutReset,
                                     action: onReset)
                    }
                    if let onClear {
                        actionButton("xmark.circle.fill", help: l10n.s.shortcutClear,
                                     action: onClear)
                    }
                }
                .padding(.trailing, 6)
            }
        }
        .frame(width: width, height: 26)
        .modifier(CompactRecorderShakeEffect(animatableData: shakeAttempts))
        .background(backgroundColor,
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(borderColor, lineWidth: borderWidth)
        }
        .opacity(isEnabled ? 1 : 0.48)
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var content: some View {
        if let errorText {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.red)
            Text(errorText)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Color.red)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        } else if isRecording {
            Text(pressedModifiers.isEmpty
                 ? cancelPrompt
                 : pressedModifiers.keyCaps.joined(separator: " "))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        } else if let shortcut {
            Text(shortcut.displayString)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.leading, 8)
                .padding(.trailing, trailingInset)
                .lineLimit(1)
        } else if let emptyTitle {
            Text(emptyTitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.leading, 8)
                .padding(.trailing, trailingInset)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        } else {
            Spacer()
        }
    }

    private var trailingInset: CGFloat {
        switch (onReset != nil, onClear != nil) {
        case (true, true): return 44
        case (true, false), (false, true): return 26
        case (false, false): return 8
        }
    }

    private var backgroundColor: Color {
        if errorText != nil { return .red.opacity(0.12) }
        if isRecording { return .accentColor.opacity(0.12) }
        if isHovering { return .primary.opacity(0.06) }
        return .primary.opacity(0.03)
    }

    private var borderColor: Color {
        if errorText != nil { return .red }
        if isRecording { return .accentColor }
        if isHovering { return .primary.opacity(0.25) }
        return .primary.opacity(0.12)
    }

    private var borderWidth: CGFloat {
        (isRecording || errorText != nil) ? 1.5 : (isHovering ? 0.8 : 0.5)
    }

    private func actionButton(_ symbol: String, help: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: symbol.hasPrefix("arrow") ? 9 : 11,
                              weight: symbol.hasPrefix("arrow") ? .bold : .regular))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private var cancelPrompt: String {
        switch l10n.language {
        case .enUS: return "esc to cancel"
        case .ptBR: return "esc para cancelar"
        case .es: return "esc para cancelar"
        case .de: return "esc zum Abbrechen"
        case .fr: return "esc pour annuler"
        case .it: return "esc per annullare"
        case .ja: return "esc でキャンセル"
        case .ko: return "esc 취소"
        case .zhHans: return "esc 取消"
        case .zhTW, .zhHK: return "esc 取消"
        case .ru: return "esc для отмены"
        case .uk: return "esc для скасування"
        case .tr: return "esc iptal etmek için"
        case .sk: return "esc zrušiť"
        }
    }
}
