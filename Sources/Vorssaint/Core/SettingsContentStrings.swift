import Foundation

enum SettingsContentStrings {
    static func enable(_ title: String, language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Enable \(title)"
        case .ptBR: return "Ativar \(title)"
        case .tr: return "\(title) özelliğini etkinleştir"
        case .ru: return "Включить \(title)"
        case .es: return "Activar \(title)"
        case .sk: return "Zapnúť \(title)"
        case .de: return "\(title) aktivieren"
        case .fr: return "Activer \(title)"
        case .it: return "Abilita \(title)"
        case .ja: return "\(title)を有効にする"
        case .ko: return "\(title) 활성화"
        case .uk: return "Увімкнути \(title)"
        case .zhHans: return "启用\(title)"
        case .zhTW: return "啟用\(title)"
        case .zhHK: return "啟用\(title)"
        }
    }

    static func status(enabled: Bool, language: AppLanguage) -> String {
        if enabled {
            switch language {
            case .enUS: return "Enabled"
            case .ptBR: return "Ativado"
            case .tr: return "Açık"
            case .ru: return "Вкл"
            case .es: return "Activado"
            case .sk: return "Zapnuté"
            case .de: return "Ein"
            case .fr: return "Activé"
            case .it: return "Attivo"
            case .ja: return "オン"
            case .ko: return "켜짐"
            case .uk: return "Увімк"
            case .zhHans: return "开启"
            case .zhTW: return "開啟"
            case .zhHK: return "開啟"
            }
        } else {
            switch language {
            case .enUS: return "Disabled"
            case .ptBR: return "Desativado"
            case .tr: return "Kapalı"
            case .ru: return "Выкл"
            case .es: return "Desactivado"
            case .sk: return "Vypnuté"
            case .de: return "Aus"
            case .fr: return "Désactivé"
            case .it: return "Non attivo"
            case .ja: return "オフ"
            case .ko: return "꺼짐"
            case .uk: return "Вимк"
            case .zhHans: return "关闭"
            case .zhTW: return "關閉"
            case .zhHK: return "關閉"
            }
        }
    }
}
