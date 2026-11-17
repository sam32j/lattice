// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

struct WindowStageManagerStrings {
    let title: String
    let caption: String

    static func localized(_ language: AppLanguage) -> WindowStageManagerStrings {
        switch language {
        case .enUS: return .init(title: "Reserve space for Stage Manager", caption: "Prevent window covering Stage Manager recent apps.")
        case .ptBR: return .init(title: "Reservar espaço para o Organizador Visual", caption: "Evita que janelas cubram os apps recentes do Organizador Visual.")
        case .tr: return .init(title: "Sahne Yöneticisi için yer ayır", caption: "Pencerelerin Sahne Yöneticisi son uygulamalarını kapatmasını engeller.")
        case .ru: return .init(title: "Оставлять место для Постановщика", caption: "Не позволяет окнам перекрывать недавние приложения Постановщика.")
        case .es: return .init(title: "Reservar espacio para el Organizador Visual", caption: "Evita que las ventanas cubran las apps recientes del Organizador Visual.")
        case .sk: return .init(title: "Vyhradiť miesto pre Stage Manager", caption: "Zabráni oknám zakrývať nedávne apky v Stage Manageri.")
        case .de: return .init(title: "Platz für Stage Manager reservieren", caption: "Verhindert, dass Fenster die zuletzt verwendeten Apps von Stage Manager verdecken.")
        case .fr: return .init(title: "Réserver de l’espace pour Stage Manager", caption: "Empêche les fenêtres de masquer les apps récentes de Stage Manager.")
        case .it: return .init(title: "Riserva spazio per Stage Manager", caption: "Impedisce alle finestre di coprire le app recenti di Stage Manager.")
        case .ja: return .init(title: "ステージマネージャの領域を確保", caption: "ウインドウがステージマネージャの最近使ったアプリを覆わないようにします。")
        case .ko: return .init(title: "스테이지 매니저 공간 확보", caption: "윈도우가 스테이지 매니저의 최근 앱을 가리지 않도록 합니다.")
        case .zhHans: return .init(title: "为台前调度预留空间", caption: "防止窗口遮挡台前调度的最近使用 App。")
        case .zhTW: return .init(title: "為幕前調度保留空間", caption: "防止視窗遮擋幕前調度的最近使用 App。")
        case .zhHK: return .init(title: "為幕前調度預留空間", caption: "防止視窗遮擋幕前調度的最近使用 App。")
        case .uk: return .init(title: "Залишати місце для Постановника", caption: "Запобігає перекриванню недавніх програм Постановника вікнами.")
        }
    }
}
