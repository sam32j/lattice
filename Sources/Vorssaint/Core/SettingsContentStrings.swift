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
}
