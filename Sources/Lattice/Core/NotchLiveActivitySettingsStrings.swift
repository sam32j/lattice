// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct NotchLiveActivitySettingsStrings {
    let openWithShortcut: String
    let showOn: String
    let dynamicIslandSize: String
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
                showOn: "Show Dynamic Island on",
                dynamicIslandSize: "Dynamic Island Size",
                useScrollGestures: "Use Scroll Gestures",
                turnOnHapticFeedback: "Turn on Haptic feedback",
                showInScreenshots: "Show Dynamic Island in screenshots",
                onlyShowActivityWhenRoom: "Only show live activity when space allows",
                onlyShowActivityWhenRoomHint: "If there isn’t enough space in the menu bar, live activity is hidden.",
                hideActivityInFullscreen: "Hide live activity in full screen",
                hideActivityInFullscreenHint: "Live activity stays hidden while an app is full screen.",
                showActivityOnLockScreen: "Show live activity on lock screen")
        case .ptBR:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "Abrir o Dynamic Island com atalho",
                showOn: "Mostrar o Dynamic Island em",
                dynamicIslandSize: "Tamanho do Dynamic Island",
                useScrollGestures: "Usar gestos de rolagem",
                turnOnHapticFeedback: "Ativar retorno tátil",
                showInScreenshots: "Mostrar o Dynamic Island em capturas de tela",
                onlyShowActivityWhenRoom: "Mostrar atividade ao vivo apenas quando o espaço permitir",
                onlyShowActivityWhenRoomHint: "Se não houver espaço suficiente na barra de menus, a atividade ao vivo será ocultada.",
                hideActivityInFullscreen: "Ocultar atividade ao vivo em tela cheia",
                hideActivityInFullscreenHint: "A atividade ao vivo permanece oculta enquanto um app estiver em tela cheia.",
                showActivityOnLockScreen: "Mostrar atividade ao vivo na tela bloqueada")
        case .es:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "Abrir Dynamic Island con atajo",
                showOn: "Mostrar Dynamic Island en",
                dynamicIslandSize: "Tamaño de Dynamic Island",
                useScrollGestures: "Usar gestos de desplazamiento",
                turnOnHapticFeedback: "Activar vibración táctil",
                showInScreenshots: "Mostrar Dynamic Island en capturas de pantalla",
                onlyShowActivityWhenRoom: "Mostrar actividad en vivo solo cuando el espacio lo permita",
                onlyShowActivityWhenRoomHint: "Si no hay suficiente espacio en la barra de menús, la actividad en vivo se ocultará.",
                hideActivityInFullscreen: "Ocultar actividad en vivo en pantalla completa",
                hideActivityInFullscreenHint: "La actividad en vivo permanece oculta mientras una app está en pantalla completa.",
                showActivityOnLockScreen: "Mostrar actividad en vivo en la pantalla de bloqueo")
        case .sk:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "Otvoriť Dynamic Island skratkou",
                showOn: "Zobraziť Dynamic Island na",
                dynamicIslandSize: "Veľkosť Dynamic Island",
                useScrollGestures: "Používať gestá posúvania",
                turnOnHapticFeedback: "Zapnúť haptickú odozvu",
                showInScreenshots: "Zobraziť Dynamic Island na snímkach obrazovky",
                onlyShowActivityWhenRoom: "Zobrazovať živú aktivitu, len ak to priestor dovoľuje",
                onlyShowActivityWhenRoomHint: "Ak v lište nie je dostatok miesta, živá aktivita sa skryje.",
                hideActivityInFullscreen: "Skryť živú aktivitu na celej obrazovke",
                hideActivityInFullscreenHint: "Živá aktivita zostáva skrytá, kým je aplikácia na celej obrazovke.",
                showActivityOnLockScreen: "Zobraziť živú aktivitu na zamknutej obrazovke")
        case .de:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "Dynamic Island mit Kurzbefehl öffnen",
                showOn: "Dynamic Island anzeigen auf",
                dynamicIslandSize: "Dynamic Island-Größe",
                useScrollGestures: "Scrollgesten verwenden",
                turnOnHapticFeedback: "Haptisches Feedback aktivieren",
                showInScreenshots: "Dynamic Island in Screenshots anzeigen",
                onlyShowActivityWhenRoom: "Live-Aktivitäten nur bei ausreichendem Platz anzeigen",
                onlyShowActivityWhenRoomHint: "Wenn in der Menüleiste nicht genügend Platz ist, wird die Live-Aktivität ausgeblendet.",
                hideActivityInFullscreen: "Live-Aktivität im Vollbildmodus ausblenden",
                hideActivityInFullscreenHint: "Live-Aktivitäten bleiben ausgeblendet, während eine App im Vollbildmodus ist.",
                showActivityOnLockScreen: "Live-Aktivität auf dem Sperrbildschirm anzeigen")
        case .fr:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "Ouvrir le Dynamic Island avec un raccourci",
                showOn: "Afficher le Dynamic Island sur",
                dynamicIslandSize: "Taille de Dynamic Island",
                useScrollGestures: "Utiliser les gestes de défilement",
                turnOnHapticFeedback: "Activer le retour haptique",
                showInScreenshots: "Afficher le Dynamic Island dans les captures d’écran",
                onlyShowActivityWhenRoom: "Afficher l’activité en direct uniquement si l’espace le permet",
                onlyShowActivityWhenRoomHint: "S’il n’y a pas assez d’espace dans la barre des menus, l’activité en direct est masquée.",
                hideActivityInFullscreen: "Masquer l’activité en direct en plein écran",
                hideActivityInFullscreenHint: "L’activité en direct reste masquée lorsqu’une app est en plein écran.",
                showActivityOnLockScreen: "Afficher l’activité en direct sur l’écran verrouillé")
        case .it:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "Apri Dynamic Island con abbreviazione",
                showOn: "Mostra Dynamic Island su",
                dynamicIslandSize: "Dimensioni Dynamic Island",
                useScrollGestures: "Usa gesti di scorrimento",
                turnOnHapticFeedback: "Attiva feedback aptico",
                showInScreenshots: "Mostra Dynamic Island nelle istantanee dello schermo",
                onlyShowActivityWhenRoom: "Mostra attività dal vivo solo se lo spazio lo consente",
                onlyShowActivityWhenRoomHint: "Se non c’è abbastanza spazio nella barra dei menu, l’attività dal vivo viene nascosta.",
                hideActivityInFullscreen: "Nascondi attività dal vivo a schermo intero",
                hideActivityInFullscreenHint: "L’attività dal vivo rimane nascosta quando un’app è a schermo intero.",
                showActivityOnLockScreen: "Mostra attività dal vivo sulla schermata di blocco")
        case .ru:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "Открыть Dynamic Island сочетанием клавиш",
                showOn: "Показывать Dynamic Island на",
                dynamicIslandSize: "Размер Dynamic Island",
                useScrollGestures: "Использовать жесты прокрутки",
                turnOnHapticFeedback: "Включить тактильный отклик",
                showInScreenshots: "Показывать Dynamic Island на снимках экрана",
                onlyShowActivityWhenRoom: "Показывать эфир активности, только если позволяет место",
                onlyShowActivityWhenRoomHint: "Если в строке меню недостаточно места, эфир активности будет скрыт.",
                hideActivityInFullscreen: "Скрывать эфир активности в полноэкранном режиме",
                hideActivityInFullscreenHint: "Эфир активности остаётся скрытым, пока приложение работает на весь экран.",
                showActivityOnLockScreen: "Показывать эфир активности на экране блокировки")
        case .tr:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "Dynamic Island’ı kestirmeyle aç",
                showOn: "Dynamic Island’ı şurada göster:",
                dynamicIslandSize: "Dynamic Island Boyutu",
                useScrollGestures: "Kaydırma hareketlerini kullan",
                turnOnHapticFeedback: "Dokunsal geri bildirimi aç",
                showInScreenshots: "Dynamic Island’ı ekran görüntülerinde göster",
                onlyShowActivityWhenRoom: "Canlı etkinliği yalnızca alan izin verdiğinde göster",
                onlyShowActivityWhenRoomHint: "Menü çubuğunda yeterli alan yoksa canlı etkinlik gizlenir.",
                hideActivityInFullscreen: "Tam ekranda canlı etkinliği gizle",
                hideActivityInFullscreenHint: "Bir uygulama tam ekrandayken canlı etkinlik gizli kalır.",
                showActivityOnLockScreen: "Canlı etkinliği kilit ekranında göster")
        case .ja:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "ショートカットでDynamic Islandを開く",
                showOn: "Dynamic Islandを表示する画面",
                dynamicIslandSize: "Dynamic Islandのサイズ",
                useScrollGestures: "スクロールジェスチャを使用",
                turnOnHapticFeedback: "触覚フィードバックを有効にする",
                showInScreenshots: "スクリーンショットにDynamic Islandを表示",
                onlyShowActivityWhenRoom: "スペースに余裕がある場合のみライブアクティビティを表示",
                onlyShowActivityWhenRoomHint: "メニューバーに十分なスペースがない場合、ライブアクティビティは非表示になります。",
                hideActivityInFullscreen: "フルスクリーン時にライブアクティビティを非表示",
                hideActivityInFullscreenHint: "アプリがフルスクリーン表示中はライブアクティビティを非表示にします。",
                showActivityOnLockScreen: "ロック画面にライブアクティビティを表示")
        case .ko:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "단축키로 Dynamic Island 열기",
                showOn: "Dynamic Island 표시 화면",
                dynamicIslandSize: "Dynamic Island 크기",
                useScrollGestures: "스크롤 제스처 사용",
                turnOnHapticFeedback: "햅틱 피드백 켜기",
                showInScreenshots: "스크린샷에 Dynamic Island 표시",
                onlyShowActivityWhenRoom: "공간이 허용될 때만 실시간 활동 표시",
                onlyShowActivityWhenRoomHint: "메뉴 막대에 공간이 충분하지 않으면 실시간 활동이 숨겨집니다.",
                hideActivityInFullscreen: "전체 화면에서 실시간 활동 가리기",
                hideActivityInFullscreenHint: "앱이 전체 화면일 때 실시간 활동이 가려집니다.",
                showActivityOnLockScreen: "잠금 화면에 실시간 활동 표시")
        case .zhHans:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "通过快捷键打开 Dynamic Island",
                showOn: "显示 Dynamic Island 于",
                dynamicIslandSize: "全景光斑大小",
                useScrollGestures: "使用滚动手势",
                turnOnHapticFeedback: "开启触感反馈",
                showInScreenshots: "在屏幕截图中显示 Dynamic Island",
                onlyShowActivityWhenRoom: "仅在空间允许时显示实时活动",
                onlyShowActivityWhenRoomHint: "如果菜单栏空间不足，实时活动将被隐藏。",
                hideActivityInFullscreen: "全屏时隐藏实时活动",
                hideActivityInFullscreenHint: "App处于全屏状态时，实时活动保持隐藏。",
                showActivityOnLockScreen: "在锁定屏幕上显示实时活动")
        case .zhTW:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "使用快捷鍵開啟 Dynamic Island",
                showOn: "顯示 Dynamic Island 於",
                dynamicIslandSize: "動態島大小",
                useScrollGestures: "使用捲動手勢",
                turnOnHapticFeedback: "開啟觸覺回饋",
                showInScreenshots: "在螢幕截圖中顯示 Dynamic Island",
                onlyShowActivityWhenRoom: "僅在空間允許時顯示即時動態",
                onlyShowActivityWhenRoomHint: "若選單列空間不足，即時動態將會隱藏。",
                hideActivityInFullscreen: "全螢幕時隱藏即時動態",
                hideActivityInFullscreenHint: "App處於全螢幕狀態時，即時動態保持隱藏。",
                showActivityOnLockScreen: "在鎖定畫面上顯示即時動態")
        case .zhHK:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "使用快捷鍵開啟 Dynamic Island",
                showOn: "顯示 Dynamic Island 於",
                dynamicIslandSize: "動態島大小",
                useScrollGestures: "使用捲動手勢",
                turnOnHapticFeedback: "開啟觸覺回饋",
                showInScreenshots: "在螢幕截圖中顯示 Dynamic Island",
                onlyShowActivityWhenRoom: "僅在空間允許時顯示即時動態",
                onlyShowActivityWhenRoomHint: "若選單列空間不足，即時動態將會隱藏。",
                hideActivityInFullscreen: "全螢幕時隱藏即時動態",
                hideActivityInFullscreenHint: "App處於全螢幕狀態時，即時動態保持隱藏。",
                showActivityOnLockScreen: "在鎖定畫面上顯示即時動態")
        case .uk:
            return NotchLiveActivitySettingsStrings(
                openWithShortcut: "Відкрити Dynamic Island комбінацією клавіш",
                showOn: "Показувати Dynamic Island на",
                dynamicIslandSize: "Розмір Dynamic Island",
                useScrollGestures: "Використовувати жести прокручування",
                turnOnHapticFeedback: "Увімкнути тактильний відгук",
                showInScreenshots: "Показувати Dynamic Island на знімках екрана",
                onlyShowActivityWhenRoom: "Показувати інтерактивні трансляції, лише якщо дозволяє місце",
                onlyShowActivityWhenRoomHint: "Якщо в рядку меню недостатньо місця, інтерактивні трансляції будуть приховані.",
                hideActivityInFullscreen: "Ховати інтерактивні трансляції на весь екран",
                hideActivityInFullscreenHint: "Інтерактивні трансляції залишаються прихованими, доки програма на весь екран.",
                showActivityOnLockScreen: "Показувати інтерактивні трансляції на замкненому екрані")
        }
    }
}
