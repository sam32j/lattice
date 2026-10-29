// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct NotchLiveActivitySettingsStrings {
    let openWithShortcut: String
    let openIn: String
    let useScrollGestures: String
    let turnOnHapticFeedback: String
    let showInScreenshots: String
    let onlyShowActivityWhenRoom: String
    let onlyShowActivityWhenRoomHint: String
    let hideActivityInFullscreen: String
    let hideActivityInFullscreenHint: String
    let showActivityOnLockScreen: String
}

extension FeatureStrings {
    static func notchLiveActivitySettings(_ language: AppLanguage) -> NotchLiveActivitySettingsStrings {
        switch language {
        case .enUS:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "Open Dynamic Island with shortcut",
                openIn: "Open Dynamic Island in",
                useScrollGestures: "Use Scroll Gestures",
                turnOnHapticFeedback: "Turn on Haptic feedback",
                showInScreenshots: "Show Dynamic Island in screenshots",
                onlyShowActivityWhenRoom: "Only show live activity when there’s room",
                onlyShowActivityWhenRoomHint: "Turn off to let it cover menu items.",
                hideActivityInFullscreen: "Hide live activity in full screen",
                hideActivityInFullscreenHint: "Live activity stays hidden while an app is full screen.",
                showActivityOnLockScreen: "Show Live Activity on Lock Screen")
        case .ptBR:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "Abrir o Dynamic Island com atalho",
                openIn: "Abrir o Dynamic Island em",
                useScrollGestures: "Usar gestos de rolagem",
                turnOnHapticFeedback: "Ativar retorno tátil",
                showInScreenshots: "Mostrar o Dynamic Island em capturas de tela",
                onlyShowActivityWhenRoom: "Mostrar atividade ao vivo apenas quando houver espaço",
                onlyShowActivityWhenRoomHint: "Desative para permitir que cubra itens de menu.",
                hideActivityInFullscreen: "Ocultar atividade ao vivo em tela cheia",
                hideActivityInFullscreenHint: "A atividade ao vivo permanece oculta enquanto um app estiver em tela cheia.",
                showActivityOnLockScreen: "Mostrar atividade ao vivo na Tela Bloqueada")
        case .es:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "Abrir Dynamic Island con atajo",
                openIn: "Abrir Dynamic Island en",
                useScrollGestures: "Usar gestos de desplazamiento",
                turnOnHapticFeedback: "Activar vibración táctil",
                showInScreenshots: "Mostrar Dynamic Island en capturas de pantalla",
                onlyShowActivityWhenRoom: "Mostrar actividad en vivo solo cuando haya espacio",
                onlyShowActivityWhenRoomHint: "Desactiva para permitir que cubra elementos del menú.",
                hideActivityInFullscreen: "Ocultar actividad en vivo en pantalla completa",
                hideActivityInFullscreenHint: "La actividad en vivo permanece oculta mientras una app está en pantalla completa.",
                showActivityOnLockScreen: "Mostrar actividad en vivo en la pantalla de bloqueo")
        case .sk:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "Otvoriť Dynamic Island skratkou",
                openIn: "Otvoriť Dynamic Island na",
                useScrollGestures: "Používať gestá posúvania",
                turnOnHapticFeedback: "Zapnúť haptickú odozvu",
                showInScreenshots: "Zobraziť Dynamic Island na snímkach obrazovky",
                onlyShowActivityWhenRoom: "Zobrazovať živú aktivitu iba pri dostatku miesta",
                onlyShowActivityWhenRoomHint: "Vypnutím povolíte prekrývanie položiek ponuky.",
                hideActivityInFullscreen: "Skryť živú aktivitu na celej obrazovke",
                hideActivityInFullscreenHint: "Živá aktivita zostáva skrytá, kým je aplikácia na celej obrazovke.",
                showActivityOnLockScreen: "Zobraziť živú aktivitu na zamknutej obrazovke")
        case .de:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "Dynamic Island mit Kurzbefehl öffnen",
                openIn: "Dynamic Island öffnen auf",
                useScrollGestures: "Scrollgesten verwenden",
                turnOnHapticFeedback: "Haptisches Feedback aktivieren",
                showInScreenshots: "Dynamic Island in Screenshots anzeigen",
                onlyShowActivityWhenRoom: "Live-Aktivität nur bei ausreichend Platz anzeigen",
                onlyShowActivityWhenRoomHint: "Ausschalten, um Menüobjekte verdecken zu dürfen.",
                hideActivityInFullscreen: "Live-Aktivität im Vollbildmodus ausblenden",
                hideActivityInFullscreenHint: "Live-Aktivitäten bleiben ausgeblendet, während eine App im Vollbildmodus ist.",
                showActivityOnLockScreen: "Live-Aktivität auf dem Sperrbildschirm anzeigen")
        case .fr:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "Ouvrir le Dynamic Island avec un raccourci",
                openIn: "Ouvrir le Dynamic Island sur",
                useScrollGestures: "Utiliser les gestes de défilement",
                turnOnHapticFeedback: "Activer le retour haptique",
                showInScreenshots: "Afficher le Dynamic Island dans les captures d’écran",
                onlyShowActivityWhenRoom: "Afficher l’activité en direct uniquement s’il y a de la place",
                onlyShowActivityWhenRoomHint: "Désactivez pour lui permettre de masquer les éléments de menu.",
                hideActivityInFullscreen: "Masquer l’activité en direct en plein écran",
                hideActivityInFullscreenHint: "L’activité en direct reste masquée lorsqu’une app est en plein écran.",
                showActivityOnLockScreen: "Afficher l’activité en direct sur l’écran verrouillé")
        case .it:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "Apri Dynamic Island con abbreviazione",
                openIn: "Apri Dynamic Island su",
                useScrollGestures: "Usa gesti di scorrimento",
                turnOnHapticFeedback: "Attiva feedback aptico",
                showInScreenshots: "Mostra Dynamic Island nelle istantanee dello schermo",
                onlyShowActivityWhenRoom: "Mostra attività dal vivo solo quando c’è spazio",
                onlyShowActivityWhenRoomHint: "Disattiva per consentirle di coprire gli elementi del menu.",
                hideActivityInFullscreen: "Nascondi attività dal vivo a schermo intero",
                hideActivityInFullscreenHint: "L’attività dal vivo rimane nascosta quando un’app è a schermo intero.",
                showActivityOnLockScreen: "Mostra attività dal vivo sulla schermata di blocco")
        case .ru:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "Открыть Dynamic Island сочетанием клавиш",
                openIn: "Открывать Dynamic Island на",
                useScrollGestures: "Использовать жесты прокрутки",
                turnOnHapticFeedback: "Включить тактильный отклик",
                showInScreenshots: "Показывать Dynamic Island на снимках экрана",
                onlyShowActivityWhenRoom: "Показывать эфир активности только при наличии места",
                onlyShowActivityWhenRoomHint: "Отключите, чтобы разрешить перекрытие элементов меню.",
                hideActivityInFullscreen: "Скрывать эфир активности в полноэкранном режиме",
                hideActivityInFullscreenHint: "Эфир активности остаётся скрытым, пока приложение работает на весь экран.",
                showActivityOnLockScreen: "Показывать эфир активности на экране блокировки")
        case .tr:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "Dynamic Island’ı kestirmeyle aç",
                openIn: "Dynamic Island’ı şurada aç:",
                useScrollGestures: "Kaydırma hareketlerini kullan",
                turnOnHapticFeedback: "Dokunsal geri bildirimi aç",
                showInScreenshots: "Dynamic Island’ı ekran görüntülerinde göster",
                onlyShowActivityWhenRoom: "Canlı etkinliği yalnızca yer olduğunda göster",
                onlyShowActivityWhenRoomHint: "Menü öğelerini kapatmasına izin vermek için kapatın.",
                hideActivityInFullscreen: "Tam ekranda canlı etkinliği gizle",
                hideActivityInFullscreenHint: "Bir uygulama tam ekrandayken canlı etkinlik gizli kalır.",
                showActivityOnLockScreen: "Canlı Etkinliği Kilit Ekranında Göster")
        case .ja:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "ショートカットでDynamic Islandを開く",
                openIn: "Dynamic Islandを開く画面",
                useScrollGestures: "スクロールジェスチャを使用",
                turnOnHapticFeedback: "触覚フィードバックを有効にする",
                showInScreenshots: "スクリーンショットにDynamic Islandを表示",
                onlyShowActivityWhenRoom: "空きスペースがある時のみライブアクティビティを表示",
                onlyShowActivityWhenRoomHint: "オフにするとメニュー項目の上に重ねて表示します。",
                hideActivityInFullscreen: "フルスクリーン時にライブアクティビティを非表示",
                hideActivityInFullscreenHint: "アプリがフルスクリーン表示中はライブアクティビティを非表示にします。",
                showActivityOnLockScreen: "ロック画面にライブアクティビティを表示")
        case .ko:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "단축키로 Dynamic Island 열기",
                openIn: "Dynamic Island 표시 위치",
                useScrollGestures: "스크롤 제스처 사용",
                turnOnHapticFeedback: "햅틱 피드백 켜기",
                showInScreenshots: "스크린샷에 Dynamic Island 표시",
                onlyShowActivityWhenRoom: "공간이 있을 때만 실시간 활동 표시",
                onlyShowActivityWhenRoomHint: "끄면 메뉴 항목을 가릴 수 있습니다.",
                hideActivityInFullscreen: "전체 화면에서 실시간 활동 가리기",
                hideActivityInFullscreenHint: "앱이 전체 화면일 때 실시간 활동이 가려집니다.",
                showActivityOnLockScreen: "잠금 화면에 실시간 활동 표시")
        case .zhHans:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "通过快捷键打开 Dynamic Island",
                openIn: "打开 Dynamic Island 于",
                useScrollGestures: "使用滚动手势",
                turnOnHapticFeedback: "开启触感反馈",
                showInScreenshots: "在屏幕截图中显示 Dynamic Island",
                onlyShowActivityWhenRoom: "仅在有空间时显示实时活动",
                onlyShowActivityWhenRoomHint: "关闭以允许其遮挡菜单项。",
                hideActivityInFullscreen: "全屏时隐藏实时活动",
                hideActivityInFullscreenHint: "App处于全屏状态时，实时活动保持隐藏。",
                showActivityOnLockScreen: "在锁定屏幕上显示实时活动")
        case .zhTW:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "使用快捷鍵開啟 Dynamic Island",
                openIn: "開啟 Dynamic Island 於",
                useScrollGestures: "使用捲動手勢",
                turnOnHapticFeedback: "開啟觸覺回饋",
                showInScreenshots: "在螢幕截圖中顯示 Dynamic Island",
                onlyShowActivityWhenRoom: "僅在有空間時顯示即時動態",
                onlyShowActivityWhenRoomHint: "關閉以允許其遮住選單項目。",
                hideActivityInFullscreen: "全螢幕時隱藏即時動態",
                hideActivityInFullscreenHint: "App處於全螢幕狀態時，即時動態保持隱藏。",
                showActivityOnLockScreen: "在鎖定畫面上顯示即時動態")
        case .zhHK:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "使用快捷鍵開啟 Dynamic Island",
                openIn: "開啟 Dynamic Island 於",
                useScrollGestures: "使用捲動手勢",
                turnOnHapticFeedback: "開啟觸覺回饋",
                showInScreenshots: "在螢幕截圖中顯示 Dynamic Island",
                onlyShowActivityWhenRoom: "僅在有空間時顯示即時動態",
                onlyShowActivityWhenRoomHint: "關閉以允許其遮住選單項目。",
                hideActivityInFullscreen: "全螢幕時隱藏即時動態",
                hideActivityInFullscreenHint: "App處於全螢幕狀態時，即時動態保持隱藏。",
                showActivityOnLockScreen: "在鎖定畫面上顯示即時動態")
        case .uk:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "Відкрити Dynamic Island комбінацією клавіш",
                openIn: "Відкривати Dynamic Island на",
                useScrollGestures: "Використовувати жести прокручування",
                turnOnHapticFeedback: "Увімкнути тактильний відгук",
                showInScreenshots: "Показувати Dynamic Island на знімках екрана",
                onlyShowActivityWhenRoom: "Показувати інтерактивні трансляції лише за наявності місця",
                onlyShowActivityWhenRoomHint: "Вимкніть, щоб дозволити перекривати елементи меню.",
                hideActivityInFullscreen: "Ховати інтерактивні трансляції на весь екран",
                hideActivityInFullscreenHint: "Інтерактивні трансляції залишаються прихованими, доки програма на весь екран.",
                showActivityOnLockScreen: "Показувати інтерактивні трансляції на замкненому екрані")
        }
    }
}
