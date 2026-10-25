import Foundation

enum SettingsWindowGroupStrings {
    static func text(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Windows & Spaces"
        case .ptBR: return "Janelas e Espaços"
        case .tr: return "Pencereler ve Masaüstleri"
        case .ru: return "Окна и рабочие столы"
        case .es: return "Ventanas y espacios"
        case .sk: return "Okná a plochy"
        case .de: return "Fenster und Spaces"
        case .fr: return "Fenêtres et espaces"
        case .it: return "Finestre e spazi"
        case .ja: return "ウインドウと操作スペース"
        case .ko: return "윈도우 및 Spaces"
        case .uk: return "Вікна та простори"
        case .zhHans: return "窗口与空间"
        case .zhTW: return "視窗與空間"
        case .zhHK: return "視窗與空間"
        }
    }
}
