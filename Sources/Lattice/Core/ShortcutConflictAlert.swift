// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct ShortcutConflictAlert: Identifiable, Equatable {
    var id: String { "\(shortcut.storageValue)-\(assignedBehavior)" }
    let shortcut: GlobalShortcut
    let assignedBehavior: String

    var title: String {
        switch L10n.shared.language {
        case .enUS: return "Shortcut is used for another action"
        case .ptBR: return "O atalho já é usado por outra ação"
        case .es: return "El atajo se usa para otra acción"
        case .de: return "Kurzbefehl wird für eine andere Aktion verwendet"
        case .fr: return "Ce raccourci est utilisé pour une autre action"
        case .it: return "La scorciatoia è usata per un’altra azione"
        case .ja: return "ショートカットは別の操作で使用されています"
        case .ko: return "단축키가 다른 동작에 사용 중입니다"
        case .zhHans: return "快捷键已被用于其他操作"
        case .zhTW, .zhHK: return "快速鍵已用於其他動作"
        case .ru: return "Сочетание клавиш используется для другого действия"
        case .uk: return "Поєднання клавіш використовується для іншої дії"
        case .tr: return "Kısayol başka bir eylem için kullanılıyor"
        case .sk: return "Skratka sa používa pre inú akciu"
        }
    }

    var message: String {
        let shortcutText = shortcut.displayString
        switch L10n.shared.language {
        case .enUS: return "\(shortcutText) is assigned to \(assignedBehavior)."
        case .ptBR: return "\(shortcutText) está atribuído a \(assignedBehavior)."
        case .es: return "\(shortcutText) está asignado a \(assignedBehavior)."
        case .de: return "\(shortcutText) ist zugewiesen an \(assignedBehavior)."
        case .fr: return "\(shortcutText) est attribué à \(assignedBehavior)."
        case .it: return "\(shortcutText) è assegnata a \(assignedBehavior)."
        case .ja: return "\(shortcutText) は「\(assignedBehavior)」に割り当てられています。"
        case .ko: return "\(shortcutText) 단축키가 \(assignedBehavior)에 지정되어 있습니다."
        case .zhHans: return "\(shortcutText) 已分配给 \(assignedBehavior)。"
        case .zhTW, .zhHK: return "\(shortcutText) 已指定給 \(assignedBehavior)。"
        case .ru: return "\(shortcutText) назначено для: \(assignedBehavior)."
        case .uk: return "\(shortcutText) призначено для: \(assignedBehavior)."
        case .tr: return "\(shortcutText) kısayolu \(assignedBehavior) için atanmış."
        case .sk: return "\(shortcutText) je priradená k: \(assignedBehavior)."
        }
    }
}

extension View {
    func shortcutConflictAlert(_ alert: Binding<ShortcutConflictAlert?>) -> some View {
        self.alert(
            alert.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { alert.wrappedValue != nil },
                set: { if !$0 { alert.wrappedValue = nil } }
            ),
            presenting: alert.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) {
                alert.wrappedValue = nil
            }
        } message: { current in
            Text(current.message)
        }
    }
}
