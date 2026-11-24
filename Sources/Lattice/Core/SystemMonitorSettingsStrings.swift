// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Copy for the System Monitor page. Same contract as the other FeatureStrings
/// structs: memberwise init in declaration order, one static per language.
struct SystemMonitorSettingsStrings {
    let emptyDescription: String
    let menuBarCaption: String
    let refreshTitle: String
    let refreshFast: String
    let refreshBalanced: String
    let refreshSaver: String
    let refreshFastCaption: String
    let refreshBalancedCaption: String
    let refreshSaverCaption: String
    let menuBarTitle: String
    let readingsTitle: String
    let readingsCaption: String
    let styleTitle: String
    let memberUsage: String
    let memberTemperature: String
    let memberActivity: String
    let memberCharge: String
    let memberTimeLeft: String
    let combineTitle: String
    let offOption: String
    let onOption: String
    let showInMenuBar: String
    let openAt: String
}

extension FeatureStrings {
    static func systemMonitorSettings(_ language: AppLanguage) -> SystemMonitorSettingsStrings {
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

extension SystemMonitorSettingsStrings {
    static let enUS = SystemMonitorSettingsStrings(
        emptyDescription: "Keep an eye on CPU, memory, network and more from the menu bar.",
        menuBarCaption: "Choose which readings appear and how they look.",
        refreshTitle: "Refresh rate",
        refreshFast: "Fast",
        refreshBalanced: "Balanced",
        refreshSaver: "Energy saver",
        refreshFastCaption: "Smoothest readings. Uses more energy.",
        refreshBalancedCaption: "Recommended for most Macs.",
        refreshSaverCaption: "Fewer updates for longer battery life.",
        menuBarTitle: "Menu Bar Readings",
        readingsTitle: "Readings",
        readingsCaption: "Drag to change their order in the menu bar.",
        styleTitle: "Appearance",
        memberUsage: "Usage",
        memberTemperature: "Temperature",
        memberActivity: "Activity",
        memberCharge: "Charge",
        memberTimeLeft: "Time remaining",
        combineTitle: "Show as one item",
        offOption: "Off",
        onOption: "On",
        showInMenuBar: "Show in menu bar",
        openAt: "Open System Monitor at"
    )

    static let ptBR = SystemMonitorSettingsStrings(
        emptyDescription: "Acompanhe CPU, memória, rede e mais na barra de menus.",
        menuBarCaption: "Escolha quais leituras aparecem e como elas ficam.",
        refreshTitle: "Taxa de atualização",
        refreshFast: "Rápida",
        refreshBalanced: "Equilibrada",
        refreshSaver: "Economia de energia",
        refreshFastCaption: "Leituras mais fluidas. Usa mais energia.",
        refreshBalancedCaption: "Recomendada para a maioria dos Macs.",
        refreshSaverCaption: "Menos atualizações para a bateria durar mais.",
        menuBarTitle: "Leituras na barra de menus",
        readingsTitle: "Leituras",
        readingsCaption: "Arraste para mudar a ordem na barra de menus.",
        styleTitle: "Aparência",
        memberUsage: "Uso",
        memberTemperature: "Temperatura",
        memberActivity: "Atividade",
        memberCharge: "Carga",
        memberTimeLeft: "Tempo restante",
        combineTitle: "Mostrar como um item",
        offOption: "Desativado",
        onOption: "Ativado",
        showInMenuBar: "Mostrar na barra de menus",
        openAt: "Abrir o Monitor do Sistema em"
    )

    static let tr = SystemMonitorSettingsStrings(
        emptyDescription: "CPU, bellek, ağ ve daha fazlasını menü çubuğundan takip edin.",
        menuBarCaption: "Hangi değerlerin görüneceğini ve nasıl görüneceklerini seçin.",
        refreshTitle: "Yenileme hızı",
        refreshFast: "Hızlı",
        refreshBalanced: "Dengeli",
        refreshSaver: "Enerji tasarrufu",
        refreshFastCaption: "En akıcı değerler. Daha fazla enerji kullanır.",
        refreshBalancedCaption: "Çoğu Mac için önerilir.",
        refreshSaverCaption: "Daha uzun pil ömrü için daha az güncelleme.",
        menuBarTitle: "Menü çubuğu değerleri",
        readingsTitle: "Değerler",
        readingsCaption: "Menü çubuğundaki sırayı değiştirmek için sürükleyin.",
        styleTitle: "Görünüm",
        memberUsage: "Kullanım",
        memberTemperature: "Sıcaklık",
        memberActivity: "Etkinlik",
        memberCharge: "Şarj",
        memberTimeLeft: "Kalan süre",
        combineTitle: "Tek öğe olarak göster",
        offOption: "Kapalı",
        onOption: "Açık",
        showInMenuBar: "Menü çubuğunda göster",
        openAt: "Sistem Monitörünü şurada aç"
    )

    static let ru = SystemMonitorSettingsStrings(
        emptyDescription: "Следите за процессором, памятью, сетью и другим в строке меню.",
        menuBarCaption: "Выберите, какие показатели видны и как они выглядят.",
        refreshTitle: "Частота обновления",
        refreshFast: "Быстро",
        refreshBalanced: "Сбалансированно",
        refreshSaver: "Экономия энергии",
        refreshFastCaption: "Самые плавные показатели. Расходует больше энергии.",
        refreshBalancedCaption: "Подходит большинству Mac.",
        refreshSaverCaption: "Реже обновляет, чтобы аккумулятор работал дольше.",
        menuBarTitle: "Показатели в строке меню",
        readingsTitle: "Показатели",
        readingsCaption: "Перетащите, чтобы изменить порядок в строке меню.",
        styleTitle: "Оформление",
        memberUsage: "Загрузка",
        memberTemperature: "Температура",
        memberActivity: "Активность",
        memberCharge: "Заряд",
        memberTimeLeft: "Осталось",
        combineTitle: "Показывать одним элементом",
        offOption: "Выкл.",
        onOption: "Вкл.",
        showInMenuBar: "Показывать в строке меню",
        openAt: "Открывать мониторинг системы в"
    )

    static let es = SystemMonitorSettingsStrings(
        emptyDescription: "Vigila la CPU, la memoria, la red y más desde la barra de menús.",
        menuBarCaption: "Elige qué lecturas aparecen y cómo se ven.",
        refreshTitle: "Frecuencia de actualización",
        refreshFast: "Rápida",
        refreshBalanced: "Equilibrada",
        refreshSaver: "Ahorro de energía",
        refreshFastCaption: "Lecturas más fluidas. Usa más energía.",
        refreshBalancedCaption: "Recomendada para la mayoría de los Mac.",
        refreshSaverCaption: "Menos actualizaciones para que la batería dure más.",
        menuBarTitle: "Lecturas en la barra de menús",
        readingsTitle: "Lecturas",
        readingsCaption: "Arrastra para cambiar el orden en la barra de menús.",
        styleTitle: "Apariencia",
        memberUsage: "Uso",
        memberTemperature: "Temperatura",
        memberActivity: "Actividad",
        memberCharge: "Carga",
        memberTimeLeft: "Tiempo restante",
        combineTitle: "Mostrar como un elemento",
        offOption: "Desactivado",
        onOption: "Activado",
        showInMenuBar: "Mostrar en la barra de menús",
        openAt: "Abrir el Monitor del sistema en"
    )

    static let sk = SystemMonitorSettingsStrings(
        emptyDescription: "Sledujte procesor, pamäť, sieť a ďalšie na lište.",
        menuBarCaption: "Vyberte, ktoré hodnoty sa zobrazia a ako budú vyzerať.",
        refreshTitle: "Frekvencia obnovovania",
        refreshFast: "Rýchla",
        refreshBalanced: "Vyvážená",
        refreshSaver: "Úspora energie",
        refreshFastCaption: "Najplynulejšie hodnoty. Spotrebuje viac energie.",
        refreshBalancedCaption: "Odporúčaná pre väčšinu Macov.",
        refreshSaverCaption: "Menej aktualizácií pre dlhšiu výdrž batérie.",
        menuBarTitle: "Hodnoty na lište",
        readingsTitle: "Hodnoty",
        readingsCaption: "Potiahnutím zmeníte poradie na lište.",
        styleTitle: "Vzhľad",
        memberUsage: "Využitie",
        memberTemperature: "Teplota",
        memberActivity: "Aktivita",
        memberCharge: "Nabitie",
        memberTimeLeft: "Zostávajúci čas",
        combineTitle: "Zobraziť ako jednu položku",
        offOption: "Vypnuté",
        onOption: "Zapnuté",
        showInMenuBar: "Zobraziť na lište",
        openAt: "Otvoriť Monitor systému v"
    )

    static let de = SystemMonitorSettingsStrings(
        emptyDescription: "Behalte CPU, Speicher, Netzwerk und mehr in der Menüleiste im Blick.",
        menuBarCaption: "Wähle, welche Werte erscheinen und wie sie aussehen.",
        refreshTitle: "Aktualisierungsrate",
        refreshFast: "Schnell",
        refreshBalanced: "Ausgewogen",
        refreshSaver: "Energiesparen",
        refreshFastCaption: "Flüssigste Werte. Braucht mehr Energie.",
        refreshBalancedCaption: "Für die meisten Macs empfohlen.",
        refreshSaverCaption: "Weniger Aktualisierungen für längere Batterielaufzeit.",
        menuBarTitle: "Werte in der Menüleiste",
        readingsTitle: "Werte",
        readingsCaption: "Ziehen, um die Reihenfolge in der Menüleiste zu ändern.",
        styleTitle: "Darstellung",
        memberUsage: "Auslastung",
        memberTemperature: "Temperatur",
        memberActivity: "Aktivität",
        memberCharge: "Ladung",
        memberTimeLeft: "Restzeit",
        combineTitle: "Als ein Objekt anzeigen",
        offOption: "Aus",
        onOption: "Ein",
        showInMenuBar: "In der Menüleiste anzeigen",
        openAt: "Systemmonitor öffnen in"
    )

    static let fr = SystemMonitorSettingsStrings(
        emptyDescription: "Surveillez le processeur, la mémoire, le réseau et plus depuis la barre des menus.",
        menuBarCaption: "Choisissez les mesures affichées et leur apparence.",
        refreshTitle: "Fréquence d’actualisation",
        refreshFast: "Rapide",
        refreshBalanced: "Équilibrée",
        refreshSaver: "Économie d’énergie",
        refreshFastCaption: "Mesures les plus fluides. Consomme plus d’énergie.",
        refreshBalancedCaption: "Recommandée pour la plupart des Mac.",
        refreshSaverCaption: "Moins de mises à jour pour une meilleure autonomie.",
        menuBarTitle: "Mesures dans la barre des menus",
        readingsTitle: "Mesures",
        readingsCaption: "Faites glisser pour changer l’ordre dans la barre des menus.",
        styleTitle: "Apparence",
        memberUsage: "Utilisation",
        memberTemperature: "Température",
        memberActivity: "Activité",
        memberCharge: "Charge",
        memberTimeLeft: "Temps restant",
        combineTitle: "Afficher en un seul élément",
        offOption: "Désactivé",
        onOption: "Activé",
        showInMenuBar: "Afficher dans la barre des menus",
        openAt: "Ouvrir le moniteur système dans"
    )

    static let it = SystemMonitorSettingsStrings(
        emptyDescription: "Tieni d’occhio CPU, memoria, rete e altro dalla barra dei menu.",
        menuBarCaption: "Scegli quali valori mostrare e come appaiono.",
        refreshTitle: "Frequenza di aggiornamento",
        refreshFast: "Veloce",
        refreshBalanced: "Bilanciata",
        refreshSaver: "Risparmio energetico",
        refreshFastCaption: "Valori più fluidi. Usa più energia.",
        refreshBalancedCaption: "Consigliata per la maggior parte dei Mac.",
        refreshSaverCaption: "Meno aggiornamenti per una batteria più duratura.",
        menuBarTitle: "Valori nella barra dei menu",
        readingsTitle: "Valori",
        readingsCaption: "Trascina per cambiare l’ordine nella barra dei menu.",
        styleTitle: "Aspetto",
        memberUsage: "Utilizzo",
        memberTemperature: "Temperatura",
        memberActivity: "Attività",
        memberCharge: "Carica",
        memberTimeLeft: "Tempo rimanente",
        combineTitle: "Mostra come un elemento",
        offOption: "Disattivato",
        onOption: "Attivo",
        showInMenuBar: "Mostra nella barra dei menu",
        openAt: "Apri Monitoraggio sistema in"
    )

    static let ja = SystemMonitorSettingsStrings(
        emptyDescription: "CPU、メモリ、ネットワークなどをメニューバーで確認できます。",
        menuBarCaption: "表示する項目と見た目を選びます。",
        refreshTitle: "更新頻度",
        refreshFast: "高速",
        refreshBalanced: "バランス",
        refreshSaver: "省エネルギー",
        refreshFastCaption: "最もなめらかに更新。電力を多く使います。",
        refreshBalancedCaption: "ほとんどのMacにおすすめです。",
        refreshSaverCaption: "更新を減らしてバッテリーを長持ちさせます。",
        menuBarTitle: "メニューバーの表示項目",
        readingsTitle: "項目",
        readingsCaption: "ドラッグしてメニューバーでの順序を変更します。",
        styleTitle: "外観",
        memberUsage: "使用率",
        memberTemperature: "温度",
        memberActivity: "アクティビティ",
        memberCharge: "充電",
        memberTimeLeft: "残り時間",
        combineTitle: "1つの項目として表示",
        offOption: "オフ",
        onOption: "オン",
        showInMenuBar: "メニューバーに表示",
        openAt: "システムモニタを開く場所"
    )

    static let ko = SystemMonitorSettingsStrings(
        emptyDescription: "메뉴 막대에서 CPU, 메모리, 네트워크 등을 확인하세요.",
        menuBarCaption: "표시할 항목과 모양을 선택합니다.",
        refreshTitle: "새로 고침 빈도",
        refreshFast: "빠르게",
        refreshBalanced: "균형",
        refreshSaver: "에너지 절약",
        refreshFastCaption: "가장 부드러운 표시. 에너지를 더 사용합니다.",
        refreshBalancedCaption: "대부분의 Mac에 권장됩니다.",
        refreshSaverCaption: "업데이트를 줄여 배터리를 오래 사용합니다.",
        menuBarTitle: "메뉴 막대 항목",
        readingsTitle: "항목",
        readingsCaption: "드래그하여 메뉴 막대의 순서를 바꿉니다.",
        styleTitle: "모양",
        memberUsage: "사용률",
        memberTemperature: "온도",
        memberActivity: "활동",
        memberCharge: "충전량",
        memberTimeLeft: "남은 시간",
        combineTitle: "하나의 항목으로 표시",
        offOption: "끔",
        onOption: "켬",
        showInMenuBar: "메뉴 막대에 표시",
        openAt: "시스템 모니터 열기 위치"
    )

    static let zhHans = SystemMonitorSettingsStrings(
        emptyDescription: "在菜单栏中查看 CPU、内存、网络等信息。",
        menuBarCaption: "选择显示哪些读数以及它们的样式。",
        refreshTitle: "刷新频率",
        refreshFast: "快速",
        refreshBalanced: "均衡",
        refreshSaver: "节能",
        refreshFastCaption: "读数最流畅，耗电更多。",
        refreshBalancedCaption: "推荐大多数 Mac 使用。",
        refreshSaverCaption: "减少更新，延长电池续航。",
        menuBarTitle: "菜单栏读数",
        readingsTitle: "读数",
        readingsCaption: "拖移以更改在菜单栏中的顺序。",
        styleTitle: "外观",
        memberUsage: "使用率",
        memberTemperature: "温度",
        memberActivity: "活动",
        memberCharge: "电量",
        memberTimeLeft: "剩余时间",
        combineTitle: "显示为一个项目",
        offOption: "关闭",
        onOption: "打开",
        showInMenuBar: "在菜单栏中显示",
        openAt: "打开系统监视器的位置"
    )

    static let zhTW = SystemMonitorSettingsStrings(
        emptyDescription: "在選單列中查看 CPU、記憶體、網路等資訊。",
        menuBarCaption: "選擇要顯示的讀數及其樣式。",
        refreshTitle: "重新整理頻率",
        refreshFast: "快速",
        refreshBalanced: "平衡",
        refreshSaver: "節能",
        refreshFastCaption: "讀數最流暢，耗電較多。",
        refreshBalancedCaption: "建議大多數 Mac 使用。",
        refreshSaverCaption: "減少更新，延長電池續航力。",
        menuBarTitle: "選單列讀數",
        readingsTitle: "讀數",
        readingsCaption: "拖移以更改在選單列中的順序。",
        styleTitle: "外觀",
        memberUsage: "使用率",
        memberTemperature: "溫度",
        memberActivity: "活動",
        memberCharge: "電量",
        memberTimeLeft: "剩餘時間",
        combineTitle: "顯示為一個項目",
        offOption: "關閉",
        onOption: "開啟",
        showInMenuBar: "在選單列中顯示",
        openAt: "打開系統監視器的位置"
    )

    static let zhHK = SystemMonitorSettingsStrings(
        emptyDescription: "在選單列中查看 CPU、記憶體、網絡等資訊。",
        menuBarCaption: "選擇要顯示的讀數及其樣式。",
        refreshTitle: "重新整理頻率",
        refreshFast: "快速",
        refreshBalanced: "平衡",
        refreshSaver: "節能",
        refreshFastCaption: "讀數最流暢，耗電較多。",
        refreshBalancedCaption: "建議大部分 Mac 使用。",
        refreshSaverCaption: "減少更新，延長電池續航力。",
        menuBarTitle: "選單列讀數",
        readingsTitle: "讀數",
        readingsCaption: "拖移以更改在選單列中的順序。",
        styleTitle: "外觀",
        memberUsage: "使用率",
        memberTemperature: "溫度",
        memberActivity: "活動",
        memberCharge: "電量",
        memberTimeLeft: "剩餘時間",
        combineTitle: "顯示為一個項目",
        offOption: "關閉",
        onOption: "開啟",
        showInMenuBar: "在選單列中顯示",
        openAt: "打開系統監視器的位置"
    )

    static let uk = SystemMonitorSettingsStrings(
        emptyDescription: "Стежте за процесором, пам’яттю, мережею та іншим у рядку меню.",
        menuBarCaption: "Виберіть, які показники видно і як вони виглядають.",
        refreshTitle: "Частота оновлення",
        refreshFast: "Швидко",
        refreshBalanced: "Збалансовано",
        refreshSaver: "Економія енергії",
        refreshFastCaption: "Найплавніші показники. Витрачає більше енергії.",
        refreshBalancedCaption: "Рекомендовано для більшості Mac.",
        refreshSaverCaption: "Рідше оновлює, щоб акумулятор працював довше.",
        menuBarTitle: "Показники в рядку меню",
        readingsTitle: "Показники",
        readingsCaption: "Перетягніть, щоб змінити порядок у рядку меню.",
        styleTitle: "Вигляд",
        memberUsage: "Навантаження",
        memberTemperature: "Температура",
        memberActivity: "Активність",
        memberCharge: "Заряд",
        memberTimeLeft: "Залишилось часу",
        combineTitle: "Показувати одним елементом",
        offOption: "Вимк.",
        onOption: "Увімк.",
        showInMenuBar: "Показувати в рядку меню",
        openAt: "Відкривати монітор системи в"
    )
}
