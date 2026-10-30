// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

enum NotchSettingsCopy {
    static func idleHint(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "What the island shows when there’s no live activity."
        case .ptBR: return "O que o Dynamic Island mostra quando não há atividade ao vivo."
        case .es: return "Lo que muestra Dynamic Island cuando no hay actividad en vivo."
        case .sk: return "Čo ostrov zobrazuje, keď nie je spustená živá aktivita."
        case .de: return "Was die Insel anzeigt, wenn keine Live-Aktivität läuft."
        case .fr: return "Ce que l’îlot affiche lorsqu’aucune activité en direct n’est en cours."
        case .it: return "Cosa mostra l’isola quando non ci sono attività in tempo reale."
        case .ru: return "Что показывает остров, когда нет текущих активностей."
        case .tr: return "Canlı etkinlik yokken adanın gösterdiği içerik."
        case .ja: return "ライブアクティビティがないときに表示する内容。"
        case .ko: return "실시간 활동이 없을 때 아일랜드에 표시할 내용입니다."
        case .uk: return "Що показує острів, коли немає поточних активностей."
        case .zhHans: return "没有实时活动时灵动岛显示的内容。"
        case .zhTW: return "沒有即時動態時動態島顯示的內容。"
        case .zhHK: return "沒有即時動態時動態島顯示的內容。"
        }
    }

    static func liveActivity(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Live activity"
        case .ptBR: return "Atividade ao vivo"
        case .es: return "Actividad en vivo"
        case .sk: return "Živá aktivita"
        case .de: return "Live-Aktivität"
        case .fr: return "Activité en direct"
        case .it: return "Attività in tempo reale"
        case .ru: return "Текущая активность"
        case .tr: return "Canlı etkinlik"
        case .ja: return "ライブアクティビティ"
        case .ko: return "실시간 활동"
        case .uk: return "Поточна активність"
        case .zhHans: return "实时活动"
        case .zhTW, .zhHK: return "即時動態"
        }
    }
}
