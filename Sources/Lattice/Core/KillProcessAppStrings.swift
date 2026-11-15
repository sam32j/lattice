// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Strings for Kill Process's Apps view: graceful Quit, the Keep Running
/// list and the Quit All / Quit Others bar. Same contract as the other
/// FeatureStrings structs: memberwise init in declaration order, one static
/// per language, all in this file.
struct KillProcessAppStrings {
    let scopeApps: String
    let scopeProcesses: String
    let appCountFormat: String
    let quitButton: String
    let forceQuitButton: String
    let keepRunning: String
    let stopKeepingRunning: String
    let alwaysKept: String
    let frontBadge: String
    let keptBadge: String
    let keptCountFormat: String
    let quitOthers: String
    let quitAll: String
    let confirmQuitFormat: String
    let confirmQuitMessage: String
    let confirmBatchFormat: String
    let emptyApps: String
    let opensInAppsToggle: String
    let opensInAppsCaption: String
}

extension FeatureStrings {
    static func killProcessApps(_ language: AppLanguage) -> KillProcessAppStrings {
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

extension KillProcessAppStrings {
    static let enUS = KillProcessAppStrings(
        scopeApps: "Apps",
        scopeProcesses: "All Processes",
        appCountFormat: "Apps: %d",
        quitButton: "Quit",
        forceQuitButton: "Force Quit",
        keepRunning: "Keep Running",
        stopKeepingRunning: "Don’t Keep Running",
        alwaysKept: "Always keeps running",
        frontBadge: "Front",
        keptBadge: "Kept",
        keptCountFormat: "Kept running: %d",
        quitOthers: "Quit Others",
        quitAll: "Quit All",
        confirmQuitFormat: "Quit %@?",
        confirmQuitMessage: "The app can still ask you to save your work.",
        confirmBatchFormat: "Quit %d apps?",
        emptyApps: "No apps to show",
        opensInAppsToggle: "Open in the Apps view",
        opensInAppsCaption: "Shows running apps first. Switch to All Processes to see everything else."
    )
    static let ptBR = KillProcessAppStrings(
        scopeApps: "Apps",
        scopeProcesses: "Todos os processos",
        appCountFormat: "Apps: %d",
        quitButton: "Encerrar",
        forceQuitButton: "Forçar encerramento",
        keepRunning: "Manter aberto",
        stopKeepingRunning: "Não manter aberto",
        alwaysKept: "Sempre continua aberto",
        frontBadge: "Frente",
        keptBadge: "Mantido",
        keptCountFormat: "Mantidos abertos: %d",
        quitOthers: "Encerrar outros",
        quitAll: "Encerrar todos",
        confirmQuitFormat: "Encerrar %@?",
        confirmQuitMessage: "O app ainda pode pedir para você salvar o trabalho.",
        confirmBatchFormat: "Encerrar %d apps?",
        emptyApps: "Nenhum app para mostrar",
        opensInAppsToggle: "Abrir na visualização de apps",
        opensInAppsCaption: "Mostra primeiro os apps abertos. Mude para Todos os processos para ver o resto."
    )
    static let tr = KillProcessAppStrings(
        scopeApps: "Uygulamalar",
        scopeProcesses: "Tüm işlemler",
        appCountFormat: "Uygulamalar: %d",
        quitButton: "Kapat",
        forceQuitButton: "Zorla kapat",
        keepRunning: "Açık tut",
        stopKeepingRunning: "Açık tutma",
        alwaysKept: "Her zaman açık kalır",
        frontBadge: "Önde",
        keptBadge: "Korunuyor",
        keptCountFormat: "Açık tutulan: %d",
        quitOthers: "Diğerlerini kapat",
        quitAll: "Tümünü kapat",
        confirmQuitFormat: "%@ kapatılsın mı?",
        confirmQuitMessage: "Uygulama yine de çalışmanızı kaydetmenizi isteyebilir.",
        confirmBatchFormat: "%d uygulama kapatılsın mı?",
        emptyApps: "Gösterilecek uygulama yok",
        opensInAppsToggle: "Uygulamalar görünümünde aç",
        opensInAppsCaption: "Önce açık uygulamaları gösterir. Diğer her şey için Tüm işlemler’e geçin."
    )
    static let ru = KillProcessAppStrings(
        scopeApps: "Приложения",
        scopeProcesses: "Все процессы",
        appCountFormat: "Приложения: %d",
        quitButton: "Завершить",
        forceQuitButton: "Завершить принудительно",
        keepRunning: "Не завершать",
        stopKeepingRunning: "Разрешить завершать",
        alwaysKept: "Всегда остаётся открытым",
        frontBadge: "Активное",
        keptBadge: "Сохранено",
        keptCountFormat: "Не завершаются: %d",
        quitOthers: "Завершить остальные",
        quitAll: "Завершить все",
        confirmQuitFormat: "Завершить %@?",
        confirmQuitMessage: "Приложение ещё может предложить сохранить вашу работу.",
        confirmBatchFormat: "Завершить приложения (%d)?",
        emptyApps: "Нет приложений",
        opensInAppsToggle: "Открывать на вкладке «Приложения»",
        opensInAppsCaption: "Сначала показывает открытые приложения. Чтобы увидеть остальное, выберите «Все процессы»."
    )
    static let es = KillProcessAppStrings(
        scopeApps: "Apps",
        scopeProcesses: "Todos los procesos",
        appCountFormat: "Apps: %d",
        quitButton: "Salir",
        forceQuitButton: "Forzar salida",
        keepRunning: "Mantener abierta",
        stopKeepingRunning: "No mantener abierta",
        alwaysKept: "Siempre sigue abierta",
        frontBadge: "Al frente",
        keptBadge: "Conservada",
        keptCountFormat: "Mantenidas abiertas: %d",
        quitOthers: "Salir de las demás",
        quitAll: "Salir de todas",
        confirmQuitFormat: "¿Salir de %@?",
        confirmQuitMessage: "La app todavía puede pedirte que guardes tu trabajo.",
        confirmBatchFormat: "¿Salir de %d apps?",
        emptyApps: "No hay apps para mostrar",
        opensInAppsToggle: "Abrir en la vista de apps",
        opensInAppsCaption: "Muestra primero las apps abiertas. Cambia a Todos los procesos para ver el resto."
    )
    static let sk = KillProcessAppStrings(
        scopeApps: "Aplikácie",
        scopeProcesses: "Všetky procesy",
        appCountFormat: "Aplikácie: %d",
        quitButton: "Ukončiť",
        forceQuitButton: "Vynútiť ukončenie",
        keepRunning: "Nechať spustenú",
        stopKeepingRunning: "Nenechávať spustenú",
        alwaysKept: "Vždy zostáva spustená",
        frontBadge: "Vpredu",
        keptBadge: "Ponechaná",
        keptCountFormat: "Ponechané spustené: %d",
        quitOthers: "Ukončiť ostatné",
        quitAll: "Ukončiť všetky",
        confirmQuitFormat: "Ukončiť „%@“?",
        confirmQuitMessage: "Aplikácia vás ešte môže požiadať o uloženie práce.",
        confirmBatchFormat: "Ukončiť aplikácie (%d)?",
        emptyApps: "Žiadne aplikácie na zobrazenie",
        opensInAppsToggle: "Otvárať v zobrazení aplikácií",
        opensInAppsCaption: "Najprv zobrazí spustené aplikácie. Ostatné uvidíte vo Všetkých procesoch."
    )
    static let de = KillProcessAppStrings(
        scopeApps: "Apps",
        scopeProcesses: "Alle Prozesse",
        appCountFormat: "Apps: %d",
        quitButton: "Beenden",
        forceQuitButton: "Sofort beenden",
        keepRunning: "Geöffnet lassen",
        stopKeepingRunning: "Nicht geöffnet lassen",
        alwaysKept: "Bleibt immer geöffnet",
        frontBadge: "Vorne",
        keptBadge: "Behalten",
        keptCountFormat: "Geöffnet gelassen: %d",
        quitOthers: "Andere beenden",
        quitAll: "Alle beenden",
        confirmQuitFormat: "„%@“ beenden?",
        confirmQuitMessage: "Die App kann dich noch bitten, deine Arbeit zu sichern.",
        confirmBatchFormat: "%d Apps beenden?",
        emptyApps: "Keine Apps vorhanden",
        opensInAppsToggle: "In der App-Ansicht öffnen",
        opensInAppsCaption: "Zeigt zuerst geöffnete Apps. Wechsle zu „Alle Prozesse“, um alles andere zu sehen."
    )
    static let fr = KillProcessAppStrings(
        scopeApps: "Apps",
        scopeProcesses: "Tous les processus",
        appCountFormat: "Apps\u{00A0}: %d",
        quitButton: "Quitter",
        forceQuitButton: "Forcer à quitter",
        keepRunning: "Garder ouverte",
        stopKeepingRunning: "Ne plus garder ouverte",
        alwaysKept: "Reste toujours ouverte",
        frontBadge: "Au premier plan",
        keptBadge: "Gardée",
        keptCountFormat: "Gardées ouvertes\u{00A0}: %d",
        quitOthers: "Quitter les autres",
        quitAll: "Tout quitter",
        confirmQuitFormat: "Quitter %@\u{00A0}?",
        confirmQuitMessage: "L’app peut encore vous proposer d’enregistrer votre travail.",
        confirmBatchFormat: "Quitter %d apps\u{00A0}?",
        emptyApps: "Aucune app à afficher",
        opensInAppsToggle: "Ouvrir dans la vue Apps",
        opensInAppsCaption: "Affiche d’abord les apps ouvertes. Passez à Tous les processus pour voir le reste."
    )
    static let it = KillProcessAppStrings(
        scopeApps: "App",
        scopeProcesses: "Tutti i processi",
        appCountFormat: "App: %d",
        quitButton: "Esci",
        forceQuitButton: "Uscita forzata",
        keepRunning: "Mantieni aperta",
        stopKeepingRunning: "Non mantenere aperta",
        alwaysKept: "Resta sempre aperta",
        frontBadge: "In primo piano",
        keptBadge: "Mantenuta",
        keptCountFormat: "Mantenute aperte: %d",
        quitOthers: "Esci dalle altre",
        quitAll: "Esci da tutte",
        confirmQuitFormat: "Uscire da %@?",
        confirmQuitMessage: "L’app può ancora chiederti di salvare il lavoro.",
        confirmBatchFormat: "Uscire da %d app?",
        emptyApps: "Nessuna app da mostrare",
        opensInAppsToggle: "Apri nella vista App",
        opensInAppsCaption: "Mostra prima le app aperte. Passa a Tutti i processi per vedere il resto."
    )
    static let ja = KillProcessAppStrings(
        scopeApps: "アプリ",
        scopeProcesses: "すべてのプロセス",
        appCountFormat: "アプリ: %d",
        quitButton: "終了",
        forceQuitButton: "強制終了",
        keepRunning: "実行したままにする",
        stopKeepingRunning: "実行したままにしない",
        alwaysKept: "常に実行したまま",
        frontBadge: "最前面",
        keptBadge: "保持",
        keptCountFormat: "実行したまま: %d",
        quitOthers: "ほかを終了",
        quitAll: "すべて終了",
        confirmQuitFormat: "“%@”を終了しますか?",
        confirmQuitMessage: "アプリは作業の保存を求めることがあります。",
        confirmBatchFormat: "%d個のアプリを終了しますか?",
        emptyApps: "表示するアプリはありません",
        opensInAppsToggle: "アプリ表示で開く",
        opensInAppsCaption: "実行中のアプリを先に表示します。ほかはすべてのプロセスで確認できます。"
    )
    static let ko = KillProcessAppStrings(
        scopeApps: "앱",
        scopeProcesses: "모든 프로세스",
        appCountFormat: "앱: %d",
        quitButton: "종료",
        forceQuitButton: "강제 종료",
        keepRunning: "계속 실행",
        stopKeepingRunning: "계속 실행 안 함",
        alwaysKept: "항상 계속 실행됨",
        frontBadge: "맨 앞",
        keptBadge: "유지됨",
        keptCountFormat: "계속 실행: %d",
        quitOthers: "나머지 종료",
        quitAll: "모두 종료",
        confirmQuitFormat: "%@을(를) 종료하시겠습니까?",
        confirmQuitMessage: "앱이 작업을 저장할지 물어볼 수 있습니다.",
        confirmBatchFormat: "앱 %d개를 종료하시겠습니까?",
        emptyApps: "표시할 앱 없음",
        opensInAppsToggle: "앱 보기로 열기",
        opensInAppsCaption: "실행 중인 앱을 먼저 보여줍니다. 나머지는 모든 프로세스에서 볼 수 있습니다."
    )
    static let zhHans = KillProcessAppStrings(
        scopeApps: "App",
        scopeProcesses: "所有进程",
        appCountFormat: "App：%d",
        quitButton: "退出",
        forceQuitButton: "强制退出",
        keepRunning: "保持运行",
        stopKeepingRunning: "不再保持运行",
        alwaysKept: "始终保持运行",
        frontBadge: "前台",
        keptBadge: "已保留",
        keptCountFormat: "保持运行：%d",
        quitOthers: "退出其他",
        quitAll: "全部退出",
        confirmQuitFormat: "要退出“%@”吗？",
        confirmQuitMessage: "App 仍可能请你存储工作。",
        confirmBatchFormat: "要退出 %d 个 App 吗？",
        emptyApps: "没有可显示的 App",
        opensInAppsToggle: "以 App 视图打开",
        opensInAppsCaption: "先显示正在运行的 App。切换到“所有进程”查看其余内容。"
    )
    static let zhTW = KillProcessAppStrings(
        scopeApps: "App",
        scopeProcesses: "所有程序",
        appCountFormat: "App：%d",
        quitButton: "結束",
        forceQuitButton: "強制結束",
        keepRunning: "保持執行",
        stopKeepingRunning: "不再保持執行",
        alwaysKept: "一律保持執行",
        frontBadge: "前景",
        keptBadge: "已保留",
        keptCountFormat: "保持執行：%d",
        quitOthers: "結束其他",
        quitAll: "全部結束",
        confirmQuitFormat: "要結束「%@」嗎？",
        confirmQuitMessage: "App 仍可能請你儲存工作。",
        confirmBatchFormat: "要結束 %d 個 App 嗎？",
        emptyApps: "沒有可顯示的 App",
        opensInAppsToggle: "以 App 檢視開啟",
        opensInAppsCaption: "先顯示執行中的 App。切換到「所有程序」查看其餘內容。"
    )
    static let zhHK = KillProcessAppStrings(
        scopeApps: "App",
        scopeProcesses: "所有程序",
        appCountFormat: "App：%d",
        quitButton: "結束",
        forceQuitButton: "強制結束",
        keepRunning: "保持執行",
        stopKeepingRunning: "不再保持執行",
        alwaysKept: "一律保持執行",
        frontBadge: "前景",
        keptBadge: "已保留",
        keptCountFormat: "保持執行：%d",
        quitOthers: "結束其他",
        quitAll: "全部結束",
        confirmQuitFormat: "要結束「%@」嗎？",
        confirmQuitMessage: "App 仍可能請你儲存工作。",
        confirmBatchFormat: "要結束 %d 個 App 嗎？",
        emptyApps: "沒有可顯示的 App",
        opensInAppsToggle: "以 App 檢視開啟",
        opensInAppsCaption: "先顯示執行中的 App。切換至「所有程序」查看其餘內容。"
    )
    static let uk = KillProcessAppStrings(
        scopeApps: "Програми",
        scopeProcesses: "Усі процеси",
        appCountFormat: "Програми: %d",
        quitButton: "Завершити",
        forceQuitButton: "Завершити примусово",
        keepRunning: "Не завершувати",
        stopKeepingRunning: "Дозволити завершувати",
        alwaysKept: "Завжди залишається відкритою",
        frontBadge: "Активна",
        keptBadge: "Збережено",
        keptCountFormat: "Не завершуються: %d",
        quitOthers: "Завершити інші",
        quitAll: "Завершити всі",
        confirmQuitFormat: "Завершити %@?",
        confirmQuitMessage: "Програма ще може запропонувати зберегти вашу роботу.",
        confirmBatchFormat: "Завершити програми (%d)?",
        emptyApps: "Немає програм",
        opensInAppsToggle: "Відкривати на вкладці «Програми»",
        opensInAppsCaption: "Спершу показує відкриті програми. Щоб побачити решту, виберіть «Усі процеси»."
    )
}
