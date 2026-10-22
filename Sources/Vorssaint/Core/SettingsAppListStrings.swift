// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
import Foundation

struct SettingsAppListStrings {
    let disabledApps: String
    let edit: String
    let done: String

    static func text(_ language: AppLanguage) -> Self {
        switch language {
        case .enUS: return Self(disabledApps: "Disable in these apps", edit: "Edit…", done: "Done")
        case .ptBR: return Self(disabledApps: "Desativar para estes apps", edit: "Editar…", done: "Concluído")
        case .tr: return Self(disabledApps: "Bu uygulamalarda devre dışı bırak", edit: "Düzenle…", done: "Bitti")
        case .ru: return Self(disabledApps: "Отключать в этих приложениях", edit: "Изменить…", done: "Готово")
        case .es: return Self(disabledApps: "Desactivar en estas apps", edit: "Editar…", done: "Listo")
        case .sk: return Self(disabledApps: "Vypnúť pre tieto aplikácie", edit: "Upraviť…", done: "Hotovo")
        case .de: return Self(disabledApps: "Für diese Apps deaktivieren", edit: "Bearbeiten…", done: "Fertig")
        case .fr: return Self(disabledApps: "Désactiver pour ces apps", edit: "Modifier…", done: "Terminé")
        case .it: return Self(disabledApps: "Disabilita per queste app", edit: "Modifica…", done: "Fine")
        case .ja: return Self(disabledApps: "これらのアプリでは無効にする", edit: "編集…", done: "完了")
        case .ko: return Self(disabledApps: "다음 앱에서 비활성화", edit: "편집…", done: "완료")
        case .uk: return Self(disabledApps: "Вимкнути для цих програм", edit: "Змінити…", done: "Готово")
        case .zhHans: return Self(disabledApps: "在这些 App 中停用", edit: "编辑…", done: "完成")
        case .zhTW: return Self(disabledApps: "在這些 App 中停用", edit: "編輯…", done: "完成")
        case .zhHK: return Self(disabledApps: "在這些 App 停用", edit: "編輯…", done: "完成")
        }
    }
}
