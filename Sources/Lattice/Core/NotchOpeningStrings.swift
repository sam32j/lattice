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
                hiddenUntilHover: "Hidden until hover",
                hiddenUntilHoverHint: "Keep the island hidden on screens without a notch until hovered.",
                hoverDelay: "Hover delay",
                hoverDelayHint: "How long to hover before the island responds.",
                closeDelay: "Close delay",
                closeDelayHint: "How long the island stays open after the pointer leaves.",
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
                hiddenUntilHover: "Oculto até passar o cursor",
                hiddenUntilHoverHint: "Mantenha o Dynamic Island oculto em telas sem entalhe até passar o cursor.",
                hoverDelay: "Atraso ao passar o cursor",
                hoverDelayHint: "Tempo até o Dynamic Island responder ao cursor.",
                closeDelay: "Atraso para fechar",
                closeDelayHint: "Tempo que o Dynamic Island permanece aberto após o cursor sair.",
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
                hiddenUntilHover: "Oculto hasta pasar el cursor",
                hiddenUntilHoverHint: "Mantener el Dynamic Island oculto en pantallas sin notch hasta pasar el cursor.",
                hoverDelay: "Retardo al pasar el cursor",
                hoverDelayHint: "Tiempo antes de que el Dynamic Island responda.",
                closeDelay: "Retardo de cierre",
                closeDelayHint: "Tiempo que el Dynamic Island permanece abierto después de quitar el cursor.",
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
                hiddenUntilHover: "Skryté do prejdenia",
                hiddenUntilHoverHint: "Ponechať ostrovček skrytý na obrazovkách bez výrezu, kým naň neprejdete.",
                hoverDelay: "Oneskorenie prejdenia",
                hoverDelayHint: "Ako dlho podržať kurzor, kým ostrovček zareaguje.",
                closeDelay: "Oneskorenie zatvorenia",
                closeDelayHint: "Ako dlho zostane ostrovček otvorený po odchode kurzora.",
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
                hiddenUntilHover: "Bis zum Zeigen ausgeblendet",
                hiddenUntilHoverHint: "Die Insel auf Bildschirmen ohne Notch ausgeblendet lassen, bis darauf gezeigt wird.",
                hoverDelay: "Zeigeverzögerung",
                hoverDelayHint: "Wie lange der Zeiger verweilen muss, bevor die Insel reagiert.",
                closeDelay: "Schließverzögerung",
                closeDelayHint: "Wie lange die Insel nach Verlassen des Zeigers geöffnet bleibt.",
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
                hiddenUntilHover: "Masqué jusqu’au survol",
                hiddenUntilHoverHint: "Garder l’île masquée sur les écrans sans encoche jusqu’au survol.",
                hoverDelay: "Délai de survol",
                hoverDelayHint: "Durée de survol avant que l’île ne réagisse.",
                closeDelay: "Délai de fermeture",
                closeDelayHint: "Durée pendant laquelle l’île reste ouverte après le départ du curseur.",
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
                hiddenUntilHover: "Nascosto fino al passaggio",
                hiddenUntilHoverHint: "Mantieni l’isola nascosta sugli schermi senza notch finché non ci passi sopra.",
                hoverDelay: "Ritardo passaggio",
                hoverDelayHint: "Tempo di attesa prima che l’isola risponda.",
                closeDelay: "Ritardo chiusura",
                closeDelayHint: "Tempo per cui l’isola rimane aperta dopo l’uscita del cursore.",
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
                hiddenUntilHover: "Скрывать до наведения",
                hiddenUntilHoverHint: "Скрывать остров на экранах без выреза до наведения курсора.",
                hoverDelay: "Задержка наведения",
                hoverDelayHint: "Сколько удерживать курсор перед откликом острова.",
                closeDelay: "Задержка закрытия",
                closeDelayHint: "Сколько остров остается открытым после ухода курсора.",
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
                hiddenUntilHover: "Üzerine gelene kadar gizli",
                hiddenUntilHoverHint: "İmleç üzerine gelene kadar çentiksiz ekranlarda adayı gizli tutun.",
                hoverDelay: "Gecikme süresi",
                hoverDelayHint: "Ada yanıt vermeden önce imlecin ne kadar duracağı.",
                closeDelay: "Kapanma gecikmesi",
                closeDelayHint: "İmleç ayrıldıktan sonra adanın ne kadar açık kalacağı.",
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
                hiddenUntilHover: "ポイントするまで非表示",
                hiddenUntilHoverHint: "ノッチのない画面でポイントするまでアイランドを非表示にします。",
                hoverDelay: "ポイント遅延",
                hoverDelayHint: "アイランドが反応するまでのポインタ静止時間。",
                closeDelay: "閉じる遅延",
                closeDelayHint: "ポインタが離れてからアイランドが開いたままでいる時間。",
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
                hiddenUntilHover: "마우스를 올릴 때까지 숨김",
                hiddenUntilHoverHint: "노치가 없는 화면에서 마우스를 올릴 때까지 아일랜드를 숨깁니다.",
                hoverDelay: "지연 시간",
                hoverDelayHint: "아일랜드가 반응하기까지 마우스를 올려두는 시간입니다.",
                closeDelay: "닫기 지연 시간",
                closeDelayHint: "마우스가 벗어난 후 아일랜드가 열려 있는 시간입니다.",
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
                hiddenUntilHover: "悬停前隐藏",
                hiddenUntilHoverHint: "在无刘海屏幕上保持隐藏，直到鼠标悬停。",
                hoverDelay: "悬停延迟",
                hoverDelayHint: "指针悬停多久后灵动岛作出响应。",
                closeDelay: "关闭延迟",
                closeDelayHint: "指针移开后灵动岛保持打开的时长。",
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
                hiddenUntilHover: "停留前隱藏",
                hiddenUntilHoverHint: "在無瀏海螢幕上保持隱藏，直到游標停留。",
                hoverDelay: "停留延遲",
                hoverDelayHint: "游標停留多久後動態島作出回應。",
                closeDelay: "關閉延遲",
                closeDelayHint: "游標移開後動態島保持開啟的時長。",
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
                hiddenUntilHover: "Приховано до наведення",
                hiddenUntilHoverHint: "Приховувати острівець на екранах без вирізу до наведення курсора.",
                hoverDelay: "Затримка наведення",
                hoverDelayHint: "Скільки утримувати курсор, щоб острівець відреагував.",
                closeDelay: "Затримка закриття",
                closeDelayHint: "Скільки часу острівець залишається відкритим після відведення курсора.",
                showLiveActivity: "Показувати інтерактивну активність",
                showLiveActivityHint: "Показувати музику, таймери та індикатори стану у прихованому стані.",
                whenReopening: "Повторне відкриття",
                defaultPage: "Сторінка за замовчуванням",
                openVisibleActivity: "Відкривати інтерактивну активність",
                openVisibleActivityHint: "Відкривати активний процес замість стандартної сторінки.")
        }
    }
}
