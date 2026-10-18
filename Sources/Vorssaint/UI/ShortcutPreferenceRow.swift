// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct ShortcutPreferenceRow: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var superKey = SuperKeyService.shared

    private let role: GlobalShortcutRole
    private let label: String?
    private let symbolName: String?
    private let contextLabel: String?
    private let statusText: String?
    private let statusIsActive: Bool
    private let showsSuperKeyAlternative: Bool
    private let superKeyModifiers: GlobalShortcutModifiers
    private let includeInactiveConflicts: Bool
    private let reservesClearButtonSpace: Bool
    private let onChange: () -> Void
    private let additionalConflict: (GlobalShortcut) -> String?
    @AppStorage private var rawValue: String

    init(role: GlobalShortcutRole,
         isEnabled _: Bool = true,
         label: String? = nil,
         symbolName: String? = nil,
         contextLabel: String? = nil,
         statusText: String? = nil,
         statusIsActive: Bool = false,
         showsSuperKeyAlternative: Bool = false,
         superKeyModifiers: GlobalShortcutModifiers = .validMask,
         includeInactiveConflicts: Bool = false,
         reservesClearButtonSpace: Bool = false,
         additionalConflict: @escaping (GlobalShortcut) -> String? = { _ in nil },
         onChange: @escaping () -> Void) {
        self.role = role
        self.label = label
        self.symbolName = symbolName
        self.contextLabel = contextLabel
        self.statusText = statusText
        self.statusIsActive = statusIsActive
        self.showsSuperKeyAlternative = showsSuperKeyAlternative
        self.superKeyModifiers = superKeyModifiers
        self.includeInactiveConflicts = includeInactiveConflicts
        self.reservesClearButtonSpace = reservesClearButtonSpace
        self.additionalConflict = additionalConflict
        self.onChange = onChange
        _rawValue = AppStorage(wrappedValue: role.defaultShortcut.storageValue,
                               role.storageKey)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ShortcutRowLabel(title: label ?? l10n.s.shelfHotkeyLabel,
                             symbolName: symbolName,
                             contextLabel: contextLabel,
                             statusText: statusText,
                             statusIsActive: statusIsActive)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                CompactShortcutRecorder(
                    role: role,
                    enabledKey: role == .screenshotUpload
                        ? DefaultsKey.screenshotUploadShortcutEnabled
                        : role.requiredEnableKeys.last ?? "",
                    isAvailable: true,
                    includeInactiveConflicts: includeInactiveConflicts,
                    additionalConflict: additionalConflict,
                    onChange: onChange)
                if let alternative = superKeyAlternative {
                    Text(String(format: FeatureStrings.shortcuts(l10n.language)
                        .superKeyAlternativeFormat, alternative))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(alternative)
                }
            }
            if reservesClearButtonSpace {
                Color.clear.frame(width: 0, height: 0)
            }
        }
    }

    private var shortcut: GlobalShortcut {
        GlobalShortcut(storageValue: rawValue) ?? role.defaultShortcut
    }

    private var superKeyAlternative: String? {
        guard showsSuperKeyAlternative else { return nil }
        return shortcut.superKeyAlternative(
            sourceLabel: FeatureStrings.superKey(l10n.language).sourceLabel(superKey.source),
            superKeyModifiers: superKeyModifiers)
    }
}

struct ShortcutRowLabel: View {
    let title: String
    let symbolName: String?
    let contextLabel: String?
    let statusText: String?
    let statusIsActive: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            if let symbolName {
                Image(systemName: symbolName)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 18)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if contextLabel != nil || statusText != nil {
                    HStack(spacing: 5) {
                        if let contextLabel { Text(contextLabel) }
                        if contextLabel != nil, statusText != nil { Text("•") }
                        if let statusText {
                            Circle()
                                .fill(statusIsActive ? Color.green : Color.secondary)
                                .frame(width: 5, height: 5)
                            Text(statusText)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}
