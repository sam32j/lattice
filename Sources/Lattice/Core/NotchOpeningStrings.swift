// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct NotchOpeningStrings {
    let opening: String
    let clickToOpen: String
    let previewOnHover: String
    let expandOnHover: String
    let hiddenUntilHover: String
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
                previewOnHover: "Preview on hover",
                expandOnHover: "Expand on hover",
                hiddenUntilHover: "Hidden until hover",
                hoverDelay: "Hover delay",
                hoverDelayHint: "How long to hover before the island responds.",
                closeDelay: "Close delay",
                closeDelayHint: "How long the island stays open after the pointer leaves.",
                showLiveActivity: "Show live activity",
                showLiveActivityHint: "Display music, timers, and status indicators while hidden.",
                whenReopening: "When reopening",
                defaultPage: "Default page",
                openVisibleActivity: "Open visible activity",
                openVisibleActivityHint: "Open a running activity instead of the default page.")
        case .ptBR:
            return NotchOpeningStrings(
                opening: "Abertura",
                clickToOpen: "Clique para abrir",
                previewOnHover: "Pré-visualizar ao passar o cursor",
                expandOnHover: "Expandir ao passar o cursor",
                hiddenUntilHover: "Oculto até passar o cursor",
                hoverDelay: "Atraso ao passar o cursor",
                hoverDelayHint: "Tempo até o Dynamic Island responder ao cursor.",
                closeDelay: "Atraso para fechar",
                closeDelayHint: "Tempo que o Dynamic Island permanece aberto após o cursor sair.",
                showLiveActivity: "Mostrar atividade ao vivo",
                showLiveActivityHint: "Exibir música, temporizadores e indicadores de status enquanto oculto.",
                whenReopening: "Ao reabrir",
                defaultPage: "Página padrão",
                openVisibleActivity: "Abrir atividade visível",
                openVisibleActivityHint: "Abrir uma atividade em execução em vez da página padrão.")
        case .es:
            return NotchOpeningStrings(
                opening: "Apertura",
                clickToOpen: "Hacer clic para abrir",
                previewOnHover: "Previsualizar al pasar el cursor",
                expandOnHover: "Expandir al pasar el cursor",
                hiddenUntilHover: "Oculto hasta pasar el cursor",
                hoverDelay: "Retardo al pasar el cursor",
                hoverDelayHint: "Tiempo antes de que el Dynamic Island responda.",
                closeDelay: "Retardo de cierre",
                closeDelayHint: "Tiempo que el Dynamic Island permanece abierto después de quitar el cursor.",
                showLiveActivity: "Mostrar actividad en vivo",
                showLiveActivityHint: "Mostrar música, temporizadores e indicadores de estado mientras esté oculto.",
                whenReopening: "Al reabrir",
                defaultPage: "Página predeterminada",
                openVisibleActivity: "Abrir actividad visible",
                openVisibleActivityHint: "Abrir una actividad en ejecución en lugar de la página predeterminada.")
        case .sk:
            return NotchOpeningStrings(
                opening: "Otváranie",
                clickToOpen: "Kliknutím otvoriť",
                previewOnHover: "Náhľad pri prejdení",
                expandOnHover: "Rozbaliť pri prejdení",
                hiddenUntilHover: "Skryté do prejdenia",
                hoverDelay: "Oneskorenie prejdenia",
                hoverDelayHint: "Ako dlho podržať kurzor, kým ostrovček zareaguje.",
                closeDelay: "Oneskorenie zatvorenia",
                closeDelayHint: "Ako dlho zostane ostrovček otvorený po odchode kurzora.",
                showLiveActivity: "Zobraziť živú aktivitu",
                showLiveActivityHint: "Zobraziť hudbu, časovače a indikátory stavu počas skrytia.",
                whenReopening: "Pri opätovnom otvorení",
                defaultPage: "Predvolená stránka",
                openVisibleActivity: "Otvoriť viditeľnú aktivitu",
                openVisibleActivityHint: "Otvoriť bežiacu aktivitu namiesto predvolenej stránky.")
        case .de:
            return NotchOpeningStrings(
                opening: "Öffnen",
                clickToOpen: "Zum Öffnen klicken",
                previewOnHover: "Vorschau beim Zeigen",
                expandOnHover: "Beim Zeigen vergrößern",
                hiddenUntilHover: "Bis zum Zeigen ausgeblendet",
                hoverDelay: "Zeigeverzögerung",
                hoverDelayHint: "Wie lange der Zeiger verweilen muss, bevor die Insel reagiert.",
                closeDelay: "Schließverzögerung",
                closeDelayHint: "Wie lange die Insel nach Verlassen des Zeigers geöffnet bleibt.",
                showLiveActivity: "Live-Aktivität anzeigen",
                showLiveActivityHint: "Musik, Timer und Statusanzeigen im ausgeblendeten Zustand anzeigen.",
                whenReopening: "Beim erneuten Öffnen",
                defaultPage: "Standardseite",
                openVisibleActivity: "Sichtbare Aktivität öffnen",
                openVisibleActivityHint: "Eine aktive Aktivität statt der Standardseite öffnen.")
        case .fr:
            return NotchOpeningStrings(
                opening: "Ouverture",
                clickToOpen: "Cliquer pour ouvrir",
                previewOnHover: "Aperçu au survol",
                expandOnHover: "Développer au survol",
                hiddenUntilHover: "Masqué jusqu’au survol",
                hoverDelay: "Délai de survol",
                hoverDelayHint: "Durée de survol avant que l’île ne réagisse.",
                closeDelay: "Délai de fermeture",
                closeDelayHint: "Durée pendant laquelle l’île reste ouverte après le départ du curseur.",
                showLiveActivity: "Afficher l’activité en direct",
                showLiveActivityHint: "Afficher la musique, les minuteurs et les indicateurs d’état lorsqu’elle est masquée.",
                whenReopening: "À la réouverture",
                defaultPage: "Page par défaut",
                openVisibleActivity: "Ouvrir l’activité visible",
                openVisibleActivityHint: "Ouvrir une activité en cours au lieu de la page par défaut.")
        case .it:
            return NotchOpeningStrings(
                opening: "Apertura",
                clickToOpen: "Fai clic per aprire",
                previewOnHover: "Anteprima al passaggio",
                expandOnHover: "Espandi al passaggio",
                hiddenUntilHover: "Nascosto fino al passaggio",
                hoverDelay: "Ritardo passaggio",
                hoverDelayHint: "Tempo di attesa prima che l’isola risponda.",
                closeDelay: "Ritardo chiusura",
                closeDelayHint: "Tempo per cui l’isola rimane aperta dopo l’uscita del cursore.",
                showLiveActivity: "Mostra attività dal vivo",
                showLiveActivityHint: "Mostra musica, timer e indicatori di stato mentre è nascosto.",
                whenReopening: "Alla riapertura",
                defaultPage: "Pagina predefinita",
                openVisibleActivity: "Apri attività visibile",
                openVisibleActivityHint: "Apri un’attività in esecuzione anziché la pagina predefinita.")
        case .ru:
            return NotchOpeningStrings(
                opening: "Открытие",
                clickToOpen: "Нажмите для открытия",
                previewOnHover: "Предпросмотр при наведении",
                expandOnHover: "Разворачивать при наведении",
                hiddenUntilHover: "Скрывать до наведения",
                hoverDelay: "Задержка наведения",
                hoverDelayHint: "Сколько удерживать курсор перед откликом острова.",
                closeDelay: "Задержка закрытия",
                closeDelayHint: "Сколько остров остается открытым после ухода курсора.",
                showLiveActivity: "Показывать эфир активности",
                showLiveActivityHint: "Показывать музыку, таймеры и индикаторы в скрытом состоянии.",
                whenReopening: "При повторном открытии",
                defaultPage: "Страница по умолчанию",
                openVisibleActivity: "Открывать видимую активность",
                openVisibleActivityHint: "Открывать активный процесс вместо страницы по умолчанию.")
        case .tr:
            return NotchOpeningStrings(
                opening: "Açılma",
                clickToOpen: "Açmak için tıkla",
                previewOnHover: "Üzerine gelindiğinde önizle",
                expandOnHover: "Üzerine gelindiğinde genişlet",
                hiddenUntilHover: "Üzerine gelene kadar gizli",
                hoverDelay: "Gecikme süresi",
                hoverDelayHint: "Ada yanıt vermeden önce imlecin ne kadar duracağı.",
                closeDelay: "Kapanma gecikmesi",
                closeDelayHint: "İmleç ayrıldıktan sonra adanın ne kadar açık kalacağı.",
                showLiveActivity: "Canlı etkinliği göster",
                showLiveActivityHint: "Gizliyken müzik, sayaç ve durum göstergelerini göster.",
                whenReopening: "Yeniden açıldığında",
                defaultPage: "Varsayılan sayfa",
                openVisibleActivity: "Görünen etkinliği aç",
                openVisibleActivityHint: "Varsayılan sayfa yerine çalışan bir etkinliği aç.")
        case .ja:
            return NotchOpeningStrings(
                opening: "開き方",
                clickToOpen: "クリックして開く",
                previewOnHover: "ポイントしてプレビュー",
                expandOnHover: "ポイントして展開",
                hiddenUntilHover: "ポイントするまで非表示",
                hoverDelay: "ポイント遅延",
                hoverDelayHint: "アイランドが反応するまでのポインタ静止時間。",
                closeDelay: "閉じる遅延",
                closeDelayHint: "ポインタが離れてからアイランドが開いたままでいる時間。",
                showLiveActivity: "ライブアクティビティを表示",
                showLiveActivityHint: "非表示中もミュージック、タイマー、ステータスを表示。",
                whenReopening: "再度開くとき",
                defaultPage: "デフォルトのページ",
                openVisibleActivity: "表示中のアクティビティを開く",
                openVisibleActivityHint: "デフォルトのページの代わりに実行中のアクティビティを開きます。")
        case .ko:
            return NotchOpeningStrings(
                opening: "열기",
                clickToOpen: "클릭하여 열기",
                previewOnHover: "마우스를 올려 미리보기",
                expandOnHover: "마우스를 올려 확장",
                hiddenUntilHover: "마우스를 올릴 때까지 숨김",
                hoverDelay: "지연 시간",
                hoverDelayHint: "아일랜드가 반응하기까지 마우스를 올려두는 시간입니다.",
                closeDelay: "닫기 지연 시간",
                closeDelayHint: "마우스가 벗어난 후 아일랜드가 열려 있는 시간입니다.",
                showLiveActivity: "실시간 활동 표시",
                showLiveActivityHint: "숨겨진 상태에서도 음악, 타이머 및 상태 표시기를 표시합니다.",
                whenReopening: "다시 열 때",
                defaultPage: "기본 페이지",
                openVisibleActivity: "표시 중인 활동 열기",
                openVisibleActivityHint: "기본 페이지 대신 실행 중인 활동을 엽니다.")
        case .zhHans:
            return NotchOpeningStrings(
                opening: "打开方式",
                clickToOpen: "点击打开",
                previewOnHover: "悬停预览",
                expandOnHover: "悬停展开",
                hiddenUntilHover: "悬停前隐藏",
                hoverDelay: "悬停延迟",
                hoverDelayHint: "指针悬停多久后灵动岛作出响应。",
                closeDelay: "关闭延迟",
                closeDelayHint: "指针移开后灵动岛保持打开的时长。",
                showLiveActivity: "显示实时活动",
                showLiveActivityHint: "隐藏状态下显示音乐、计时器和状态指示器。",
                whenReopening: "重新打开时",
                defaultPage: "默认页面",
                openVisibleActivity: "打开显示中的活动",
                openVisibleActivityHint: "打开正在运行的活动，而非默认页面。")
        case .zhTW, .zhHK:
            return NotchOpeningStrings(
                opening: "開啟方式",
                clickToOpen: "點按開啟",
                previewOnHover: "停留預覽",
                expandOnHover: "停留展開",
                hiddenUntilHover: "停留前隱藏",
                hoverDelay: "停留延遲",
                hoverDelayHint: "游標停留多久後動態島作出回應。",
                closeDelay: "關閉延遲",
                closeDelayHint: "游標移開後動態島保持開啟的時長。",
                showLiveActivity: "顯示即時動態",
                showLiveActivityHint: "隱藏狀態下顯示音樂、計時器與狀態指示器。",
                whenReopening: "重新開啟時",
                defaultPage: "預設頁面",
                openVisibleActivity: "開啟顯示中的活動",
                openVisibleActivityHint: "開啟正在執行的活動，而非預設頁面。")
        case .uk:
            return NotchOpeningStrings(
                opening: "Відкривання",
                clickToOpen: "Натиснути для відкриття",
                previewOnHover: "Попередній перегляд при наведенні",
                expandOnHover: "Розгортати при наведенні",
                hiddenUntilHover: "Приховано до наведення",
                hoverDelay: "Затримка наведення",
                hoverDelayHint: "Скільки утримувати курсор, щоб острівець відреагував.",
                closeDelay: "Затримка закриття",
                closeDelayHint: "Скільки часу острівець залишається відкритим після відведення курсора.",
                showLiveActivity: "Показувати інтерактивну активність",
                showLiveActivityHint: "Показувати музику, таймери та індикатори стану у прихованому стані.",
                whenReopening: "При повторному відкритті",
                defaultPage: "Сторінка за замовчуванням",
                openVisibleActivity: "Відкривати видиму активність",
                openVisibleActivityHint: "Відкривати активний процес замість стандартної сторінки.")
        }
    }
}
