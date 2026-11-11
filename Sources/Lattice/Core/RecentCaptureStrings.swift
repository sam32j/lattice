// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct RecentCaptureStrings {
    let title: String
    let allCaptures: String
    let close: String
    let empty: String
    let screenshot: String
    let recording: String
    let restore: String
    let open: String
    let remove: String
    let clear: String
}

extension FeatureStrings {
    /// The shortcut setting is an action, not a second Recent Captures page.
    static func recentCapturesShortcutTitle(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Open recent captures with shortcut"
        case .ptBR: return "Abrir capturas recentes com atalho"
        case .tr: return "Son yakalamaları kısayolla aç"
        case .ru: return "Открывать недавние снимки сочетанием клавиш"
        case .es: return "Abrir capturas recientes con atajo"
        case .sk: return "Otvoriť nedávne snímky skratkou"
        case .de: return "Letzte Aufnahmen per Tastenkürzel öffnen"
        case .fr: return "Ouvrir les captures récentes avec un raccourci"
        case .it: return "Apri le acquisizioni recenti con una scorciatoia"
        case .ja: return "ショートカットで最近のキャプチャを開く"
        case .ko: return "단축키로 최근 캡처 열기"
        case .zhHans: return "使用快捷键打开最近捕获"
        case .zhTW, .zhHK: return "使用快速鍵開啟最近擷取"
        case .uk: return "Відкрити нещодавні знімки комбінацією клавіш"
        }
    }

    static func recentCaptures(_ language: AppLanguage) -> RecentCaptureStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        case .uk: return .uk
        }
    }
}

extension RecentCaptureStrings {
    static let enUS = RecentCaptureStrings(
        title: "Recent captures",
        allCaptures: "All Captures",
        close: "Close",
        empty: "No recent activity",
        screenshot: "Screenshot",
        recording: "Recording",
        restore: "Restore",
        open: "Open",
        remove: "Remove from history",
        clear: "Clear history"
    )

    static let ptBR = RecentCaptureStrings(
        title: "Capturas recentes",
        allCaptures: "Todas as capturas",
        close: "Fechar",
        empty: "Nenhuma atividade recente",
        screenshot: "Captura de tela",
        recording: "Gravação",
        restore: "Restaurar",
        open: "Abrir",
        remove: "Remover do histórico",
        clear: "Limpar histórico"
    )

    static let tr = RecentCaptureStrings(
        title: "Son yakalamalar",
        allCaptures: "Tüm yakalamalar",
        close: "Kapat",
        empty: "Son etkinlik yok",
        screenshot: "Ekran görüntüsü",
        recording: "Kayıt",
        restore: "Geri getir",
        open: "Aç",
        remove: "Geçmişten kaldır",
        clear: "Geçmişi temizle"
    )

    static let ru = RecentCaptureStrings(
        title: "Недавние снимки",
        allCaptures: "Все снимки",
        close: "Закрыть",
        empty: "Нет недавней активности",
        screenshot: "Снимок экрана",
        recording: "Запись",
        restore: "Вернуть",
        open: "Открыть",
        remove: "Удалить из истории",
        clear: "Очистить историю"
    )

    static let es = RecentCaptureStrings(
        title: "Capturas recientes",
        allCaptures: "Todas las capturas",
        close: "Cerrar",
        empty: "Sin actividad reciente",
        screenshot: "Captura de pantalla",
        recording: "Grabación",
        restore: "Restaurar",
        open: "Abrir",
        remove: "Quitar del historial",
        clear: "Borrar historial"
    )

    static let sk = RecentCaptureStrings(
        title: "Nedávne zábery",
        allCaptures: "Všetky zábery",
        close: "Zavrieť",
        empty: "Žiadna nedávna aktivita",
        screenshot: "Snímka obrazovky",
        recording: "Nahrávka",
        restore: "Obnoviť",
        open: "Otvoriť",
        remove: "Odstrániť z histórie",
        clear: "Vymazať históriu"
    )

    static let de = RecentCaptureStrings(
        title: "Letzte Aufnahmen",
        allCaptures: "Alle Aufnahmen",
        close: "Schließen",
        empty: "Keine aktuellen Aktivitäten",
        screenshot: "Bildschirmfoto",
        recording: "Aufnahme",
        restore: "Wiederherstellen",
        open: "Öffnen",
        remove: "Aus Verlauf entfernen",
        clear: "Verlauf löschen"
    )

    static let fr = RecentCaptureStrings(
        title: "Captures récentes",
        allCaptures: "Toutes les captures",
        close: "Fermer",
        empty: "Aucune activité récente",
        screenshot: "Capture d’écran",
        recording: "Enregistrement",
        restore: "Restaurer",
        open: "Ouvrir",
        remove: "Retirer de l’historique",
        clear: "Effacer l’historique"
    )

    static let it = RecentCaptureStrings(
        title: "Catture recenti",
        allCaptures: "Tutte le catture",
        close: "Chiudi",
        empty: "Nessuna attività recente",
        screenshot: "Schermata",
        recording: "Registrazione",
        restore: "Ripristina",
        open: "Apri",
        remove: "Rimuovi dalla cronologia",
        clear: "Cancella cronologia"
    )

    static let ja = RecentCaptureStrings(
        title: "最近のキャプチャ",
        allCaptures: "すべてのキャプチャ",
        close: "閉じる",
        empty: "最近のアクティビティはありません",
        screenshot: "スクリーンショット",
        recording: "録画",
        restore: "復元",
        open: "開く",
        remove: "履歴から削除",
        clear: "履歴を消去"
    )

    static let ko = RecentCaptureStrings(
        title: "최근 캡처",
        allCaptures: "모든 캡처",
        close: "닫기",
        empty: "최근 활동 없음",
        screenshot: "스크린샷",
        recording: "녹화",
        restore: "복원",
        open: "열기",
        remove: "기록에서 제거",
        clear: "기록 지우기"
    )

    static let zhHans = RecentCaptureStrings(
        title: "最近捕捉",
        allCaptures: "所有截图",
        close: "关闭",
        empty: "暂无最近活动",
        screenshot: "截图",
        recording: "录屏",
        restore: "恢复",
        open: "打开",
        remove: "从历史记录中移除",
        clear: "清除历史记录"
    )

    static let zhTW = RecentCaptureStrings(
        title: "最近擷取",
        allCaptures: "所有擷取",
        close: "關閉",
        empty: "沒有最近活動",
        screenshot: "截圖",
        recording: "螢幕錄影",
        restore: "回復",
        open: "開啟",
        remove: "從記錄中移除",
        clear: "清除記錄"
    )

    static let zhHK = RecentCaptureStrings(
        title: "最近擷取",
        allCaptures: "所有擷取",
        close: "關閉",
        empty: "沒有最近活動",
        screenshot: "截圖",
        recording: "螢幕錄影",
        restore: "還原",
        open: "開啟",
        remove: "從記錄移除",
        clear: "清除記錄"
    )
    static let uk = RecentCaptureStrings(
        title: "Недавні знімки",
        allCaptures: "Усі знімки",
        close: "Закрити",
        empty: "Немає нещодавньої активності",
        screenshot: "Знімок екрана",
        recording: "Запис",
        restore: "Відновити",
        open: "Відкрити",
        remove: "Видалити з історії",
        clear: "Очистити історію"
    )
}
