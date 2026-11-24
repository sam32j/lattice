// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Strings for the Kill Process feature. Same contract as the other
/// FeatureStrings structs: memberwise init in declaration order, one static
/// per language, all in this file.
struct KillProcessFeatureStrings {
    let pageTitle: String
    let browseSubtitle: String
    let hubDescription: String
    /// Under the title on the off page.
    let emptyStateDescription: String
    let searchPlaceholder: String
    let pidLabelFormat: String
    let processCountFormat: String
    let killButton: String
    let forceKillButton: String
    let killAllFormat: String
    let killTreeButton: String
    let restartButton: String
    let copyPID: String
    let confirmKillFormat: String
    let confirmForceKillFormat: String
    let confirmKillAllFormat: String
    let confirmKillTreeFormat: String
    let adminPromptFormat: String
}

extension FeatureStrings {
    static func killProcess(_ language: AppLanguage) -> KillProcessFeatureStrings {
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

extension KillProcessFeatureStrings {
    static let enUS = KillProcessFeatureStrings(
        pageTitle: "Process Manager",
        browseSubtitle: "Browse & Kill",
        hubDescription: "Search running processes and force quit, restart, or kill process trees",
        emptyStateDescription: "Search and manage running processes",
        searchPlaceholder: "Filter by name",
        pidLabelFormat: "PID %d",
        processCountFormat: "Processes: %d",
        killButton: "Kill",
        forceKillButton: "Force Kill",
        killAllFormat: "Kill All “%@”",
        killTreeButton: "Kill Process Tree",
        restartButton: "Restart",
        copyPID: "Copy PID",
        confirmKillFormat: "Kill %@?",
        confirmForceKillFormat: "Force Kill %@?",
        confirmKillAllFormat: "Kill all “%@” processes?",
        confirmKillTreeFormat: "Kill %@ and all its child processes?",
        adminPromptFormat: "Lattice needs administrator access to end “%@”."
    )

    static let ptBR = KillProcessFeatureStrings(
        pageTitle: "Gerenciador de Processos",
        browseSubtitle: "Ver e Encerrar",
        hubDescription: "Pesquise processos em execução e force o encerramento, reinicie ou encerre árvores de processos",
        emptyStateDescription: "Pesquise e gerencie processos em execução",
        searchPlaceholder: "Filtrar por nome",
        pidLabelFormat: "PID %d",
        processCountFormat: "Processos: %d",
        killButton: "Encerrar",
        forceKillButton: "Forçar encerramento",
        killAllFormat: "Encerrar todos “%@”",
        killTreeButton: "Encerrar árvore de processos",
        restartButton: "Reiniciar",
        copyPID: "Copiar PID",
        confirmKillFormat: "Encerrar %@?",
        confirmForceKillFormat: "Forçar encerramento de %@?",
        confirmKillAllFormat: "Encerrar todos os processos “%@”?",
        confirmKillTreeFormat: "Encerrar %@ e todos os seus processos filhos?",
        adminPromptFormat: "O Lattice precisa de acesso de administrador para encerrar “%@”."
    )

    static let tr = KillProcessFeatureStrings(
        pageTitle: "İşlem Yöneticisi",
        browseSubtitle: "Görüntüle ve Sonlandır",
        hubDescription: "Çalışan işlemleri arayın; zorla kapatın, yeniden başlatın veya işlem ağaçlarını sonlandırın",
        emptyStateDescription: "Çalışan işlemleri arayın ve yönetin",
        searchPlaceholder: "Ada göre filtrele",
        pidLabelFormat: "PID %d",
        processCountFormat: "%d işlem",
        killButton: "Sonlandır",
        forceKillButton: "Zorla Sonlandır",
        killAllFormat: "Tüm “%@” işlemlerini sonlandır",
        killTreeButton: "İşlem Ağacını Sonlandır",
        restartButton: "Yeniden Başlat",
        copyPID: "PID’yi Kopyala",
        confirmKillFormat: "%@ sonlandırılsın mı?",
        confirmForceKillFormat: "%@ zorla sonlandırılsın mı?",
        confirmKillAllFormat: "Tüm “%@” işlemleri sonlandırılsın mı?",
        confirmKillTreeFormat: "%@ ve tüm alt işlemleri sonlandırılsın mı?",
        adminPromptFormat: "Lattice’in “%@” işlemini sonlandırması için yönetici erişimi gerekiyor."
    )

    static let ru = KillProcessFeatureStrings(
        pageTitle: "Диспетчер процессов",
        browseSubtitle: "Просмотр и завершение",
        hubDescription: "Поиск запущенных процессов, принудительное завершение, перезапуск или завершение дерева процессов",
        emptyStateDescription: "Поиск и управление запущенными процессами",
        searchPlaceholder: "Фильтр по имени",
        pidLabelFormat: "PID %d",
        processCountFormat: "Процессов: %d",
        killButton: "Завершить",
        forceKillButton: "Завершить принудительно",
        killAllFormat: "Завершить все «%@»",
        killTreeButton: "Завершить дерево процессов",
        restartButton: "Перезапустить",
        copyPID: "Скопировать PID",
        confirmKillFormat: "Завершить %@?",
        confirmForceKillFormat: "Принудительно завершить %@?",
        confirmKillAllFormat: "Завершить все процессы «%@»?",
        confirmKillTreeFormat: "Завершить %@ и все его дочерние процессы?",
        adminPromptFormat: "Lattice нужны права администратора, чтобы завершить «%@»."
    )

    static let es = KillProcessFeatureStrings(
        pageTitle: "Gestor de procesos",
        browseSubtitle: "Ver y Finalizar",
        hubDescription: "Busca procesos en ejecución y fuerza su cierre, reinícialos o finaliza árboles de procesos",
        emptyStateDescription: "Busca y gestiona los procesos en ejecución",
        searchPlaceholder: "Filtrar por nombre",
        pidLabelFormat: "PID %d",
        processCountFormat: "Procesos: %d",
        killButton: "Finalizar",
        forceKillButton: "Forzar finalización",
        killAllFormat: "Finalizar todos “%@”",
        killTreeButton: "Finalizar árbol de procesos",
        restartButton: "Reiniciar",
        copyPID: "Copiar PID",
        confirmKillFormat: "¿Finalizar %@?",
        confirmForceKillFormat: "¿Forzar la finalización de %@?",
        confirmKillAllFormat: "¿Finalizar todos los procesos “%@”?",
        confirmKillTreeFormat: "¿Finalizar %@ y todos sus procesos hijos?",
        adminPromptFormat: "Lattice necesita acceso de administrador para finalizar “%@”."
    )

    static let sk = KillProcessFeatureStrings(
        pageTitle: "Správca procesov",
        browseSubtitle: "Prehľadávať a ukončiť",
        hubDescription: "Hľadajte bežiace procesy a vynútene ich ukončite, reštartujte alebo ukončite celé stromy procesov",
        emptyStateDescription: "Vyhľadávajte a spravujte bežiace procesy",
        searchPlaceholder: "Filtrovať podľa názvu",
        pidLabelFormat: "PID %d",
        processCountFormat: "Procesy: %d",
        killButton: "Ukončiť",
        forceKillButton: "Vynútene ukončiť",
        killAllFormat: "Ukončiť všetky „%@“",
        killTreeButton: "Ukončiť strom procesu",
        restartButton: "Reštartovať",
        copyPID: "Kopírovať PID",
        confirmKillFormat: "Ukončiť %@?",
        confirmForceKillFormat: "Vynútene ukončiť %@?",
        confirmKillAllFormat: "Ukončiť všetky procesy „%@“?",
        confirmKillTreeFormat: "Ukončiť %@ a všetky jeho podradené procesy?",
        adminPromptFormat: "Lattice potrebuje prístup správcu na ukončenie „%@“."
    )

    static let de = KillProcessFeatureStrings(
        pageTitle: "Prozessverwaltung",
        browseSubtitle: "Anzeigen & Beenden",
        hubDescription: "Laufende Prozesse durchsuchen, erzwungen beenden, neu starten oder Prozessbäume beenden",
        emptyStateDescription: "Laufende Prozesse suchen und verwalten",
        searchPlaceholder: "Nach Namen filtern",
        pidLabelFormat: "PID %d",
        processCountFormat: "Prozesse: %d",
        killButton: "Beenden",
        forceKillButton: "Beenden erzwingen",
        killAllFormat: "Alle „%@“ beenden",
        killTreeButton: "Prozessbaum beenden",
        restartButton: "Neu starten",
        copyPID: "PID kopieren",
        confirmKillFormat: "%@ beenden?",
        confirmForceKillFormat: "%@ zwangsweise beenden?",
        confirmKillAllFormat: "Alle „%@“-Prozesse beenden?",
        confirmKillTreeFormat: "%@ und alle untergeordneten Prozesse beenden?",
        adminPromptFormat: "Lattice benötigt Administratorrechte, um „%@“ zu beenden."
    )

    static let fr = KillProcessFeatureStrings(
        pageTitle: "Gestionnaire de processus",
        browseSubtitle: "Parcourir et arrêter",
        hubDescription: "Recherchez les processus en cours et forcez-les à quitter, redémarrez-les ou arrêtez leurs arborescences",
        emptyStateDescription: "Recherchez et gérez les processus en cours",
        searchPlaceholder: "Filtrer par nom",
        pidLabelFormat: "PID %d",
        processCountFormat: "Processus\u{00A0}: %d",
        killButton: "Arrêter",
        forceKillButton: "Forcer l’arrêt",
        killAllFormat: "Arrêter tous les «\u{00A0}%@\u{00A0}»",
        killTreeButton: "Arrêter l’arborescence du processus",
        restartButton: "Redémarrer",
        copyPID: "Copier le PID",
        confirmKillFormat: "Arrêter %@\u{00A0}?",
        confirmForceKillFormat: "Forcer l’arrêt de %@\u{00A0}?",
        confirmKillAllFormat: "Arrêter tous les processus «\u{00A0}%@\u{00A0}»\u{00A0}?",
        confirmKillTreeFormat: "Arrêter %@ et tous ses processus enfants\u{00A0}?",
        adminPromptFormat: "Lattice a besoin d’un accès administrateur pour arrêter «\u{00A0}%@\u{00A0}»."
    )

    static let it = KillProcessFeatureStrings(
        pageTitle: "Gestione processi",
        browseSubtitle: "Sfoglia e Termina",
        hubDescription: "Cerca i processi in esecuzione e forzane l’uscita, riavviali o termina intere alberature di processi",
        emptyStateDescription: "Cerca e gestisci i processi in esecuzione",
        searchPlaceholder: "Filtra per nome",
        pidLabelFormat: "PID %d",
        processCountFormat: "Processi: %d",
        killButton: "Termina",
        forceKillButton: "Forza terminazione",
        killAllFormat: "Termina tutti “%@”",
        killTreeButton: "Termina alberatura del processo",
        restartButton: "Riavvia",
        copyPID: "Copia PID",
        confirmKillFormat: "Terminare %@?",
        confirmForceKillFormat: "Forzare la terminazione di %@?",
        confirmKillAllFormat: "Terminare tutti i processi “%@”?",
        confirmKillTreeFormat: "Terminare %@ e tutti i suoi processi figli?",
        adminPromptFormat: "Lattice richiede l’accesso da amministratore per terminare “%@”."
    )

    static let ja = KillProcessFeatureStrings(
        pageTitle: "プロセスマネージャ",
        browseSubtitle: "表示して終了",
        hubDescription: "実行中のプロセスを検索し、強制終了、再起動、プロセスツリーの終了ができます",
        emptyStateDescription: "実行中のプロセスを検索して管理",
        searchPlaceholder: "名前で絞り込む",
        pidLabelFormat: "PID %d",
        processCountFormat: "%d個のプロセス",
        killButton: "終了",
        forceKillButton: "強制終了",
        killAllFormat: "「%@」をすべて終了",
        killTreeButton: "プロセスツリーを終了",
        restartButton: "再起動",
        copyPID: "PIDをコピー",
        confirmKillFormat: "%@を終了しますか？",
        confirmForceKillFormat: "%@を強制終了しますか？",
        confirmKillAllFormat: "「%@」のプロセスをすべて終了しますか？",
        confirmKillTreeFormat: "%@とすべての子プロセスを終了しますか？",
        adminPromptFormat: "「%@」を終了するには管理者アクセスが必要です。"
    )

    static let ko = KillProcessFeatureStrings(
        pageTitle: "프로세스 관리자",
        browseSubtitle: "보기 및 종료",
        hubDescription: "실행 중인 프로세스를 검색하고 강제 종료, 재시작 또는 프로세스 트리 종료를 수행합니다",
        emptyStateDescription: "실행 중인 프로세스를 검색하고 관리",
        searchPlaceholder: "이름으로 필터링",
        pidLabelFormat: "PID %d",
        processCountFormat: "프로세스 %d개",
        killButton: "종료",
        forceKillButton: "강제 종료",
        killAllFormat: "“%@” 모두 종료",
        killTreeButton: "프로세스 트리 종료",
        restartButton: "재시작",
        copyPID: "PID 복사",
        confirmKillFormat: "%@을(를) 종료할까요?",
        confirmForceKillFormat: "%@을(를) 강제 종료할까요?",
        confirmKillAllFormat: "“%@” 프로세스를 모두 종료할까요?",
        confirmKillTreeFormat: "%@와(과) 모든 하위 프로세스를 종료할까요?",
        adminPromptFormat: "“%@”을(를) 종료하려면 관리자 권한이 필요합니다."
    )

    static let zhHans = KillProcessFeatureStrings(
        pageTitle: "进程管理器",
        browseSubtitle: "浏览并结束",
        hubDescription: "搜索正在运行的进程，强制退出、重新启动或结束整个进程树",
        emptyStateDescription: "搜索和管理正在运行的进程",
        searchPlaceholder: "按名称筛选",
        pidLabelFormat: "PID %d",
        processCountFormat: "%d 个进程",
        killButton: "结束",
        forceKillButton: "强制结束",
        killAllFormat: "结束所有“%@”",
        killTreeButton: "结束进程树",
        restartButton: "重新启动",
        copyPID: "拷贝 PID",
        confirmKillFormat: "要结束“%@”吗？",
        confirmForceKillFormat: "要强制结束“%@”吗？",
        confirmKillAllFormat: "要结束所有“%@”进程吗？",
        confirmKillTreeFormat: "要结束“%@”及其所有子进程吗？",
        adminPromptFormat: "Lattice 需要您的管理员密码才能结束“%@”。"
    )

    static let zhTW = KillProcessFeatureStrings(
        pageTitle: "程序管理器",
        browseSubtitle: "瀏覽並結束",
        hubDescription: "搜尋正在執行的處理程序，強制結束、重新啟動或結束整個處理程序樹",
        emptyStateDescription: "搜尋和管理正在執行的處理程序",
        searchPlaceholder: "依名稱篩選",
        pidLabelFormat: "PID %d",
        processCountFormat: "%d 個處理程序",
        killButton: "結束",
        forceKillButton: "強制結束",
        killAllFormat: "結束所有「%@」",
        killTreeButton: "結束處理程序樹",
        restartButton: "重新啟動",
        copyPID: "拷貝 PID",
        confirmKillFormat: "要結束「%@」嗎？",
        confirmForceKillFormat: "要強制結束「%@」嗎？",
        confirmKillAllFormat: "要結束所有「%@」處理程序嗎？",
        confirmKillTreeFormat: "要結束「%@」及其所有子處理程序嗎？",
        adminPromptFormat: "Lattice 需要管理員權限才能結束「%@」。"
    )

    static let zhHK = KillProcessFeatureStrings(
        pageTitle: "程序管理器",
        browseSubtitle: "瀏覽並結束",
        hubDescription: "搜尋正在執行的處理程序，強制結束、重新啟動或結束整個處理程序樹",
        emptyStateDescription: "搜尋和管理正在執行的處理程序",
        searchPlaceholder: "依名稱篩選",
        pidLabelFormat: "PID %d",
        processCountFormat: "%d 個處理程序",
        killButton: "結束",
        forceKillButton: "強制結束",
        killAllFormat: "結束所有「%@」",
        killTreeButton: "結束處理程序樹",
        restartButton: "重新啟動",
        copyPID: "拷貝 PID",
        confirmKillFormat: "要結束「%@」嗎？",
        confirmForceKillFormat: "要強制結束「%@」嗎？",
        confirmKillAllFormat: "要結束所有「%@」處理程序嗎？",
        confirmKillTreeFormat: "要結束「%@」及其所有子處理程序嗎？",
        adminPromptFormat: "Lattice 需要管理員權限才能結束「%@」。"
    )
    static let uk = KillProcessFeatureStrings(
        pageTitle: "Диспетчер процесів",
        browseSubtitle: "Огляд та завершення",
        hubDescription: "Шукайте запущені процеси та примусово завершуйте, перезапускайте або вбивайте дерева процесів",
        emptyStateDescription: "Шукайте та керуйте запущеними процесами",
        searchPlaceholder: "Фільтр за ім’ям",
        pidLabelFormat: "PID %d",
        processCountFormat: "Процесів: %d",
        killButton: "Завершити",
        forceKillButton: "Примусово завершити",
        killAllFormat: "Завершити всі «%@»",
        killTreeButton: "Завершити дерево процесів",
        restartButton: "Почати заново",
        copyPID: "Скопіювати PID",
        confirmKillFormat: "Завершити %@?",
        confirmForceKillFormat: "Примусово завершити %@?",
        confirmKillAllFormat: "Завершити всі процеси «%@»?",
        confirmKillTreeFormat: "Завершити %@ та всі його дочірні процеси?",
        adminPromptFormat: "Lattice потрібен адміністративний доступ для завершення «%@»."
    )
}
