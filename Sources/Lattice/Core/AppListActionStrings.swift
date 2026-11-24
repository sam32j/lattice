// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// What an app list's button does: add an app the setting covers, or
/// exclude one from it. Every app list says one of these two, nothing else.
enum AppListAction {
    case add, exclude

    func title(_ language: AppLanguage) -> String {
        let strings = FeatureStrings.appListAction(language)
        switch self {
        case .add: return strings.addApp
        case .exclude: return strings.excludeApp
        }
    }
}

/// Copy for the two app list buttons.
struct AppListActionStrings {
    let addApp: String
    let excludeApp: String
}

extension FeatureStrings {
    static func appListAction(_ language: AppLanguage) -> AppListActionStrings {
        switch language {
        case .enUS: return AppListActionStrings(addApp: "Add app…", excludeApp: "Exclude app…")
        case .ptBR: return AppListActionStrings(addApp: "Adicionar app…", excludeApp: "Ignorar app…")
        case .tr: return AppListActionStrings(addApp: "Uygulama ekle…", excludeApp: "Uygulamayı hariç tut…")
        case .ru: return AppListActionStrings(addApp: "Добавить приложение…", excludeApp: "Исключить приложение…")
        case .es: return AppListActionStrings(addApp: "Añadir app…", excludeApp: "Excluir app…")
        case .sk: return AppListActionStrings(addApp: "Pridať aplikáciu…", excludeApp: "Vylúčiť aplikáciu…")
        case .de: return AppListActionStrings(addApp: "App hinzufügen …", excludeApp: "App ausschließen …")
        case .fr: return AppListActionStrings(addApp: "Ajouter une app…", excludeApp: "Exclure une app…")
        case .it: return AppListActionStrings(addApp: "Aggiungi app…", excludeApp: "Escludi app…")
        case .ja: return AppListActionStrings(addApp: "Appを追加…", excludeApp: "Appを除外…")
        case .ko: return AppListActionStrings(addApp: "앱 추가…", excludeApp: "앱 제외…")
        case .zhHans: return AppListActionStrings(addApp: "添加 App…", excludeApp: "排除 App…")
        case .zhTW: return AppListActionStrings(addApp: "加入 App⋯", excludeApp: "排除 App⋯")
        case .zhHK: return AppListActionStrings(addApp: "加入 App⋯", excludeApp: "排除 App⋯")
        case .uk: return AppListActionStrings(addApp: "Додати програму…", excludeApp: "Виключити програму…")
        }
    }
}
