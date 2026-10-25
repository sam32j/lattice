// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Copy shared by the row and the app-list sheet it opens.
enum SettingsFollowupLabels {
    enum Key: Int { case lockSound, pauseApps, fullScreenApps, dontQuitApps, clipboardActivity, appManagement }
    static func text(_ key: Key, _ language: AppLanguage) -> String {
        let values: [String]
        switch language {
        case .enUS: values = ["Lock Sound", "Pause in these apps", "Keep full screen in these apps", "Don’t quit these apps", "Clipboard activity", "App Management"]
        case .ptBR: values = ["Som de bloqueio", "Pausar nestes apps", "Manter tela cheia nestes apps", "Não encerrar estes apps", "Atividade da área de transferência", "Gerenciamento de Apps"]
        case .es: values = ["Sonido de bloqueo", "Pausar en estas apps", "Mantener pantalla completa en estas apps", "No cerrar estas apps", "Actividad del portapapeles", "Gestión de apps"]
        case .de: values = ["Sperrton", "In diesen Apps pausieren", "In diesen Apps Vollbild beibehalten", "Diese Apps nicht beenden", "Zwischenablageaktivität", "App-Verwaltung"]
        case .fr: values = ["Son de verrouillage", "Mettre en pause dans ces apps", "Conserver le plein écran dans ces apps", "Ne pas quitter ces apps", "Activité du presse-papiers", "Gestion des apps"]
        case .it: values = ["Suono di blocco", "Sospendi in queste app", "Mantieni lo schermo intero in queste app", "Non chiudere queste app", "Attività degli appunti", "Gestione app"]
        case .ja: values = ["ロック音", "これらのアプリでは一時停止", "これらのアプリではフルスクリーンを維持", "これらのアプリを終了しない", "クリップボードのアクティビティ", "アプリ管理"]
        case .ko: values = ["잠금 소리", "다음 앱에서 일시 정지", "다음 앱에서 전체 화면 유지", "다음 앱을 종료하지 않음", "클립보드 활동", "앱 관리"]
        case .zhHans: values = ["锁定音效", "在这些 App 中暂停", "在这些 App 中保持全屏", "不要退出这些 App", "剪贴板活动", "App 管理"]
        case .zhTW, .zhHK: values = ["鎖定音效", "在這些 App 中暫停", "在這些 App 中保持全螢幕", "不要結束這些 App", "剪貼簿活動", "App 管理"]
        case .ru: values = ["Звук блокировки", "Приостанавливать в этих приложениях", "Сохранять полный экран в этих приложениях", "Не завершать эти приложения", "Активность буфера обмена", "Управление приложениями"]
        case .uk: values = ["Звук блокування", "Призупиняти в цих програмах", "Зберігати повний екран у цих програмах", "Не завершувати ці програми", "Активність буфера обміну", "Керування програмами"]
        case .tr: values = ["Kilit sesi", "Bu uygulamalarda duraklat", "Bu uygulamalarda tam ekranı koru", "Bu uygulamaları kapatma", "Pano etkinliği", "Uygulama Yönetimi"]
        case .sk: values = ["Zvuk uzamknutia", "Pozastaviť v týchto apkách", "V týchto apkách ponechať celú obrazovku", "Tieto apky neukončovať", "Aktivita schránky", "Správa aplikácií"]
        }
        return values[key.rawValue]
    }
}
