// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct NotchOpeningStrings {
    let opening: String
    let clickToOpen: String
    let hoverToOpen: String
    let actionOnHover: String
    let preview: String
    let expand: String
    let previewOnHover: String
    let expandOnHover: String
    let hiddenUntilHover: String
    let hiddenUntilHoverHint: String
    let hoverDelay: String
    let hoverDelayHint: String
    let closeDelay: String
    let closeDelayHint: String
    let showLiveActivity: String
    let showLiveActivityHint: String
    let whenReopening: String
    let defaultPage: String
    let openVisibleActivity: String
    let openVisibleActivityHint: String
}

extension FeatureStrings {
    static func notchOpening(_ language: AppLanguage) -> NotchOpeningStrings {
        switch language {
        case .enUS:
            return NotchOpeningStrings(
                opening: "Opening",
                clickToOpen: "Click to open",
                hoverToOpen: "Hover to open",
                actionOnHover: "Action on hover",
                preview: "Preview",
                expand: "Expand",
                previewOnHover: "Hover to preview",
                expandOnHover: "Hover to expand",
                hiddenUntilHover: "Hide Dynamic Island when idle",
                hiddenUntilHoverHint: "The island only appears when you hover at the top of the screen.",
                hoverDelay: "Hover delay",
                hoverDelayHint: "Time before the island responds when you hover.",
                closeDelay: "Close delay",
                closeDelayHint: "Time before the island closes after you move away.",
                showLiveActivity: "Show live activity",
                showLiveActivityHint: "Display music, timers, and status indicators while hidden.",
                whenReopening: "Reopening",
                defaultPage: "Default page",
                openVisibleActivity: "Open live activity",
                openVisibleActivityHint: "Open a running activity instead of the default page.")
        case .ptBR:
            return NotchOpeningStrings(
                opening: "Abertura",
                clickToOpen: "Clique para abrir",
                hoverToOpen: "Passar o cursor para abrir",
                actionOnHover: "Ação ao passar o cursor",
                preview: "Pré-visualizar",
                expand: "Expandir",
                previewOnHover: "Passar o cursor para pré-visualizar",
                expandOnHover: "Passar o cursor para expandir",
                hiddenUntilHover: "Ocultar Dynamic Island quando ocioso",
                hiddenUntilHoverHint: "O Dynamic Island só aparece ao passar o cursor no topo da tela.",
                hoverDelay: "Atraso ao passar o cursor",
                hoverDelayHint: "Tempo até o Dynamic Island responder ao passar o cursor.",
                closeDelay: "Atraso para fechar",
                closeDelayHint: "Tempo até o Dynamic Island fechar após afastar o cursor.",
                showLiveActivity: "Mostrar atividade ao vivo",
                showLiveActivityHint: "Exibir música, temporizadores e indicadores de status enquanto oculto.",
                whenReopening: "Reabertura",
                defaultPage: "Página padrão",
                openVisibleActivity: "Abrir atividade ao vivo",
                openVisibleActivityHint: "Abrir uma atividade em execução em vez da página padrão.")
        case .es:
            return NotchOpeningStrings(
                opening: "Apertura",
                clickToOpen: "Hacer clic para abrir",
                hoverToOpen: "Pasar el cursor para abrir",
                actionOnHover: "Acción al pasar el cursor",
                preview: "Previsualizar",
                expand: "Expandir",
                previewOnHover: "Pasar el cursor para previsualizar",
                expandOnHover: "Pasar el cursor para expandir",
                hiddenUntilHover: "Ocultar Dynamic Island en reposo",
                hiddenUntilHoverHint: "Dynamic Island solo aparece al pasar el cursor por la parte superior de la pantalla.",
                hoverDelay: "Retardo al pasar el cursor",
                hoverDelayHint: "Tiempo hasta que Dynamic Island responde al pasar el cursor.",
                closeDelay: "Retardo de cierre",
                closeDelayHint: "Tiempo hasta que Dynamic Island se cierra al alejar el cursor.",
                showLiveActivity: "Mostrar actividad en vivo",
                showLiveActivityHint: "Mostrar música, temporizadores e indicadores de estado mientras esté oculto.",
                whenReopening: "Reapertura",
                defaultPage: "Página predeterminada",
                openVisibleActivity: "Abrir actividad en vivo",
                openVisibleActivityHint: "Abrir una actividad en ejecución en lugar de la página predeterminada.")
        case .sk:
            return NotchOpeningStrings(
                opening: "Otváranie",
                clickToOpen: "Kliknutím otvoriť",
                hoverToOpen: "Otvoriť prejdením",
                actionOnHover: "Akcia pri prejdení",
                preview: "Náhľad",
                expand: "Rozbaliť",
                previewOnHover: "Prejdením zobraziť náhľad",
                expandOnHover: "Prejdením rozbaliť",
                hiddenUntilHover: "Skryť Dynamic Island v nečinnosti",
                hiddenUntilHoverHint: "Ostrov sa zobrazí len pri umiestnení kurzora k hornému okraju obrazovky.",
                hoverDelay: "Oneskorenie prejdenia",
                hoverDelayHint: "Čas, kým ostrov zareaguje na kurzor.",
                closeDelay: "Oneskorenie zatvorenia",
                closeDelayHint: "Čas, kým sa ostrov zatvorí po odsunutí kurzora.",
                showLiveActivity: "Zobraziť živú aktivitu",
                showLiveActivityHint: "Zobraziť hudbu, časovače a indikátory stavu počas skrytia.",
                whenReopening: "Opätovné otvorenie",
                defaultPage: "Predvolená stránka",
                openVisibleActivity: "Otvoriť živú aktivitu",
                openVisibleActivityHint: "Otvoriť bežiacu aktivitu namiesto predvolenej stránky.")
        case .de:
            return NotchOpeningStrings(
                opening: "Öffnen",
                clickToOpen: "Zum Öffnen klicken",
                hoverToOpen: "Beim Zeigen öffnen",
                actionOnHover: "Aktion beim Zeigen",
                preview: "Vorschau",
                expand: "Vergrößern",
                previewOnHover: "Beim Zeigen Vorschau",
                expandOnHover: "Beim Zeigen vergrößern",
                hiddenUntilHover: "Dynamic Island im Leerlauf ausblenden",
                hiddenUntilHoverHint: "Die Insel erscheint nur, wenn der Zeiger am oberen Bildschirmrand liegt.",
                hoverDelay: "Zeigeverzögerung",
                hoverDelayHint: "Zeit, bis die Insel auf den Zeiger reagiert.",
                closeDelay: "Schließverzögerung",
                closeDelayHint: "Zeit, bis die Insel nach dem Wegbewegen schließt.",
                showLiveActivity: "Live-Aktivität anzeigen",
                showLiveActivityHint: "Musik, Timer und Statusanzeigen im ausgeblendeten Zustand anzeigen.",
                whenReopening: "Erneutes Öffnen",
                defaultPage: "Standardseite",
                openVisibleActivity: "Live-Aktivität öffnen",
                openVisibleActivityHint: "Eine aktive Aktivität statt der Standardseite öffnen.")
        case .fr:
            return NotchOpeningStrings(
                opening: "Ouverture",
                clickToOpen: "Cliquer pour ouvrir",
                hoverToOpen: "Survoler pour ouvrir",
                actionOnHover: "Action au survol",
                preview: "Aperçu",
                expand: "Développer",
                previewOnHover: "Aperçu au survol",
                expandOnHover: "Développer au survol",
                hiddenUntilHover: "Masquer Dynamic Island au repos",
                hiddenUntilHoverHint: "L’îlot apparaît uniquement au survol du haut de l’écran.",
                hoverDelay: "Délai de survol",
                hoverDelayHint: "Délai avant que l’îlot réagisse au survol.",
                closeDelay: "Délai de fermeture",
                closeDelayHint: "Délai avant que l’îlot se ferme après le départ du pointeur.",
                showLiveActivity: "Afficher l’activité en direct",
                showLiveActivityHint: "Afficher la musique, les minuteurs et les indicateurs d’état lorsqu’elle est masquée.",
                whenReopening: "Réouverture",
                defaultPage: "Page par défaut",
                openVisibleActivity: "Ouvrir l’activité en direct",
                openVisibleActivityHint: "Ouvrir une activité en cours au lieu de la page par défaut.")
        case .it:
            return NotchOpeningStrings(
                opening: "Apertura",
                clickToOpen: "Fai clic per aprire",
                hoverToOpen: "Passa sopra per aprire",
                actionOnHover: "Azione al passaggio",
                preview: "Anteprima",
                expand: "Espandi",
                previewOnHover: "Anteprima al passaggio",
                expandOnHover: "Espandi al passaggio",
                hiddenUntilHover: "Nascondi Dynamic Island quando inattivo",
                hiddenUntilHoverHint: "L’isola appare solo passando il puntatore nella parte superiore dello schermo.",
                hoverDelay: "Ritardo passaggio",
                hoverDelayHint: "Tempo prima che l’isola risponda al passaggio del puntatore.",
                closeDelay: "Ritardo chiusura",
                closeDelayHint: "Tempo prima che l’isola si chiuda quando allontani il puntatore.",
                showLiveActivity: "Mostra attività dal vivo",
                showLiveActivityHint: "Mostra musica, timer e indicatori di stato mentre è nascosto.",
                whenReopening: "Riapertura",
                defaultPage: "Pagina predefinita",
                openVisibleActivity: "Apri attività dal vivo",
                openVisibleActivityHint: "Apri un’attività in esecuzione anziché la pagina predefinita.")
        case .ru:
            return NotchOpeningStrings(
                opening: "Открытие",
                clickToOpen: "Нажмите для открытия",
                hoverToOpen: "Наведите для открытия",
                actionOnHover: "Действие при наведении",
                preview: "Предпросмотр",
                expand: "Развернуть",
                previewOnHover: "Предпросмотр при наведении",
                expandOnHover: "Разворачивать при наведении",
                hiddenUntilHover: "Скрывать Dynamic Island при простое",
                hiddenUntilHoverHint: "Остров появляется только при наведении указателя на верхний край экрана.",
                hoverDelay: "Задержка наведения",
                hoverDelayHint: "Время до реакции острова при наведении указателя.",
                closeDelay: "Задержка закрытия",
                closeDelayHint: "Время до закрытия острова после отвода указателя.",
                showLiveActivity: "Показывать эфир активности",
                showLiveActivityHint: "Показывать музыку, таймеры и индикаторы в скрытом состоянии.",
                whenReopening: "Повторное открытие",
                defaultPage: "Страница по умолчанию",
                openVisibleActivity: "Открывать эфир активности",
                openVisibleActivityHint: "Открывать активный процесс вместо страницы по умолчанию.")
        case .tr:
            return NotchOpeningStrings(
                opening: "Açılma",
                clickToOpen: "Açmak için tıkla",
                hoverToOpen: "Açmak için üzerine gelin",
                actionOnHover: "Üzerine gelindiğinde işlem",
                preview: "Önizleme",
                expand: "Genişlet",
                previewOnHover: "Üzerine gelindiğinde önizle",
                expandOnHover: "Üzerine gelindiğinde genişlet",
                hiddenUntilHover: "Boştayken Dynamic Island’ı gizle",
                hiddenUntilHoverHint: "Ada yalnızca ekranın üst kısmına işaretçiyi getirdiğinizde görünür.",
                hoverDelay: "Gecikme süresi",
                hoverDelayHint: "Üzerine geldiğinizde adanın yanıt vermesine kadar geçen süre.",
                closeDelay: "Kapanma gecikmesi",
                closeDelayHint: "Uzaklaştığınızda adanın kapanmasına kadar geçen süre.",
                showLiveActivity: "Canlı etkinliği göster",
                showLiveActivityHint: "Gizliyken müzik, sayaç ve durum göstergelerini göster.",
                whenReopening: "Yeniden açılma",
                defaultPage: "Varsayılan sayfa",
                openVisibleActivity: "Canlı etkinliği aç",
                openVisibleActivityHint: "Varsayılan sayfa yerine çalışan bir etkinliği aç.")
        case .ja:
            return NotchOpeningStrings(
                opening: "開き方",
                clickToOpen: "クリックして開く",
                hoverToOpen: "ポイントして開く",
                actionOnHover: "ポイント時の動作",
                preview: "プレビュー",
                expand: "展開",
                previewOnHover: "ポイントしてプレビュー",
                expandOnHover: "ポイントして展開",
                hiddenUntilHover: "待機中はDynamic Islandを隠す",
                hiddenUntilHoverHint: "画面上部にポインタを合わせたときだけ表示します。",
                hoverDelay: "ポイント遅延",
                hoverDelayHint: "ポインタを合わせてから反応するまでの時間。",
                closeDelay: "閉じる遅延",
                closeDelayHint: "ポインタを離してから閉じるまでの時間。",
                showLiveActivity: "ライブアクティビティを表示",
                showLiveActivityHint: "非表示中もミュージック、タイマー、ステータスを表示。",
                whenReopening: "再開時",
                defaultPage: "デフォルトのページ",
                openVisibleActivity: "ライブアクティビティを開く",
                openVisibleActivityHint: "デフォルトのページの代わりに実行中のアクティビティを開きます。")
        case .ko:
            return NotchOpeningStrings(
                opening: "열기",
                clickToOpen: "클릭하여 열기",
                hoverToOpen: "마우스를 올려 열기",
                actionOnHover: "마우스를 올릴 때 동작",
                preview: "미리보기",
                expand: "확장",
                previewOnHover: "마우스를 올려 미리보기",
                expandOnHover: "마우스를 올려 확장",
                hiddenUntilHover: "대기 중 Dynamic Island 숨기기",
                hiddenUntilHoverHint: "화면 상단에 포인터를 올릴 때만 아일랜드가 표시됩니다.",
                hoverDelay: "지연 시간",
                hoverDelayHint: "포인터를 올린 후 아일랜드가 반응할 때까지의 시간입니다.",
                closeDelay: "닫기 지연 시간",
                closeDelayHint: "포인터를 옮긴 후 아일랜드가 닫힐 때까지의 시간입니다.",
                showLiveActivity: "실시간 활동 표시",
                showLiveActivityHint: "숨겨진 상태에서도 음악, 타이머 및 상태 표시기를 표시합니다.",
                whenReopening: "다시 열기",
                defaultPage: "기본 페이지",
                openVisibleActivity: "실시간 활동 열기",
                openVisibleActivityHint: "기본 페이지 대신 실행 중인 활동을 엽니다.")
        case .zhHans:
            return NotchOpeningStrings(
                opening: "打开方式",
                clickToOpen: "点击打开",
                hoverToOpen: "悬停打开",
                actionOnHover: "悬停操作",
                preview: "预览",
                expand: "展开",
                previewOnHover: "悬停预览",
                expandOnHover: "悬停展开",
                hiddenUntilHover: "闲置时隐藏灵动岛",
                hiddenUntilHoverHint: "仅当指针悬停在屏幕顶部时显示灵动岛。",
                hoverDelay: "悬停延迟",
                hoverDelayHint: "悬停后灵动岛响应前的等待时间。",
                closeDelay: "关闭延迟",
                closeDelayHint: "移开指针后灵动岛关闭前的等待时间。",
                showLiveActivity: "显示实时活动",
                showLiveActivityHint: "隐藏状态下显示音乐、计时器和状态指示器。",
                whenReopening: "重新打开",
                defaultPage: "默认页面",
                openVisibleActivity: "打开实时活动",
                openVisibleActivityHint: "打开正在运行的活动，而非默认页面。")
        case .zhTW, .zhHK:
            return NotchOpeningStrings(
                opening: "開啟方式",
                clickToOpen: "點按開啟",
                hoverToOpen: "停留開啟",
                actionOnHover: "停留動作",
                preview: "預覽",
                expand: "展開",
                previewOnHover: "停留預覽",
                expandOnHover: "停留展開",
                hiddenUntilHover: "閒置時隱藏動態島",
                hiddenUntilHoverHint: "僅在游標停留於螢幕頂端時顯示動態島。",
                hoverDelay: "停留延遲",
                hoverDelayHint: "游標停留後動態島回應前的等待時間。",
                closeDelay: "關閉延遲",
                closeDelayHint: "移開游標後動態島關閉前的等待時間。",
                showLiveActivity: "顯示即時動態",
                showLiveActivityHint: "隱藏狀態下顯示音樂、計時器與狀態指示器。",
                whenReopening: "重新開啟",
                defaultPage: "預設頁面",
                openVisibleActivity: "開啟即時動態",
                openVisibleActivityHint: "開啟正在執行的活動，而非預設頁面。")
        case .uk:
            return NotchOpeningStrings(
                opening: "Відкривання",
                clickToOpen: "Натиснути для відкриття",
                hoverToOpen: "Наведіть для відкриття",
                actionOnHover: "Дія при наведенні",
                preview: "Перегляд",
                expand: "Розгорнути",
                previewOnHover: "Попередній перегляд при наведенні",
                expandOnHover: "Розгортати при наведенні",
                hiddenUntilHover: "Приховувати Dynamic Island під час простою",
                hiddenUntilHoverHint: "Острів з’являється лише при наведенні вказівника на верхній край екрана.",
                hoverDelay: "Затримка наведення",
                hoverDelayHint: "Час до реакції острова при наведенні вказівника.",
                closeDelay: "Затримка закриття",
                closeDelayHint: "Час до закриття острова після відведення вказівника.",
                showLiveActivity: "Показувати інтерактивну активність",
                showLiveActivityHint: "Показувати музику, таймери та індикатори стану у прихованому стані.",
                whenReopening: "Повторне відкриття",
                defaultPage: "Сторінка за замовчуванням",
                openVisibleActivity: "Відкривати інтерактивну активність",
                openVisibleActivityHint: "Відкривати активний процес замість стандартної сторінки.")
        }
    }
}
