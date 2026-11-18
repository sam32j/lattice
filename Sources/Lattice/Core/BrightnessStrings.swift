// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Strings for the display brightness feature. Same contract as the other
/// FeatureStrings structs: memberwise init in declaration order, one static
/// per language, all in this file.
struct BrightnessFeatureStrings {
    let pageTitle: String
    let hubDescription: String
    let enable: String
    let enableCaption: String
    let externalCaption: String
    let noDisplays: String
    let displayOff: String
    let turnOffDisplay: String
    let turnOnDisplay: String
    let lastDisplayCaption: String
    let switchUnavailable: String
    let switchFailed: String
    let openLidToEnable: String
    let keysToggle: String
    let keysCaption: String
    let keyStep: String
    let keyStepCaption: String
    let keyStepStandard: String
    let keyStepHalf: String
    let keyStepQuarter: String
    let displayBrightnessDecrease: String
    let displayBrightnessIncrease: String
    let keyboardLight: String
    let keyboardBrightnessShortcuts: String
    let keyboardBrightnessDecrease: String
    let keyboardBrightnessIncrease: String
    let softwareDimming: String
    let extendedDimming: String
    let islandPromptTitle: String
    let islandPromptMessage: String
    let islandPromptKeepOff: String
    let toggleSystemAppearanceShortcut: String
}

extension BrightnessFeatureStrings {
    var keyboardLightLevel: String {
        switch keyboardLight {
        case "Keyboard Backlight": return "Keyboard backlight level"
        case "Luz do teclado": return "Nível da luz do teclado"
        case "Klavye ışığı": return "Klavye ışığı seviyesi"
        case "Подсветка клавиатуры": return "Уровень подсветки клавиатуры"
        case "Luz del teclado": return "Nivel de luz del teclado"
        case "Podsvietenie klávesnice": return "Úroveň podsvietenia klávesnice"
        case "Tastaturbeleuchtung": return "Tastaturbeleuchtungsstufe"
        case "Éclairage du clavier": return "Niveau d’éclairage du clavier"
        case "Illuminazione tastiera": return "Livello illuminazione tastiera"
        case "キーボードのバックライト": return "キーボードのバックライトのレベル"
        case "키보드 백라이트": return "키보드 백라이트 밝기"
        case "键盘背光": return "键盘背光亮度"
        case "鍵盤背光": return "鍵盤背光亮度"
        case "Підсвічування клавіатури": return "Рівень підсвічування клавіатури"
        default: return "Keyboard backlight level"
        }
    }
}

extension FeatureStrings {
    static func brightness(_ language: AppLanguage) -> BrightnessFeatureStrings {
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

extension BrightnessFeatureStrings {
    static let enUS = BrightnessFeatureStrings(
        pageTitle: "Displays",
        hubDescription: "Brightness and power controls for every display",
        enable: "Display Control",
        enableCaption: "Adjust display brightness and power here or from the menu bar.",
        externalCaption: "External displays are adjusted through the same protocol as their own buttons. When the connection cannot carry it, as with HDMI adapters, the slider dims the picture instead, so brightness control works either way.",
        noDisplays: "No display found.",
        displayOff: "Off",
        turnOffDisplay: "Turn off display",
        turnOnDisplay: "Turn on display",
        lastDisplayCaption: "At least one display must stay on.",
        switchUnavailable: "Display switching is unavailable on this Mac.",
        switchFailed: "Could not change this display.",
        openLidToEnable: "Open the lid to turn on the built-in display.",
        keysToggle: "Adjust brightness of display under pointer",
        keysCaption: "The brightness keys change the display your pointer is on.",
        keyStep: "Brightness key step",
        keyStepCaption: "Use smaller steps for brightness control",
        keyStepStandard: "Standard",
        keyStepHalf: "Half steps",
        keyStepQuarter: "Quarter steps",
        displayBrightnessDecrease: "Decrease brightness with shortcut",
        displayBrightnessIncrease: "Increase brightness with shortcut",
        keyboardLight: "Keyboard Backlight",
        keyboardBrightnessShortcuts: "Use keyboard brightness shortcuts",
        keyboardBrightnessDecrease: "Decrease backlight with shortcut",
        keyboardBrightnessIncrease: "Increase backlight with shortcut",
        softwareDimming: "Dim the picture",
        extendedDimming: "Extra dimming",
        islandPromptTitle: "Show brightness in the Dynamic Island?",
        islandPromptMessage: "The Dynamic Island shows brightness changes only while “Display Control” is on in Displays settings.",
        islandPromptKeepOff: "Keep Off",
        toggleSystemAppearanceShortcut: "Toggle System Appearance with shortcut"
    )

    static let ptBR = BrightnessFeatureStrings(
        pageTitle: "Telas",
        hubDescription: "Brilho e controles para ligar ou desligar cada tela",
        enable: "Controle de telas",
        enableCaption: "Controles de brilho e de ligar ou desligar para a tela do Mac e monitores externos, aqui e no painel da barra de menus.",
        externalCaption: "Monitores externos são ajustados pelo mesmo protocolo dos botões do próprio monitor. Quando a conexão não transmite esse protocolo, como em adaptadores HDMI, o controle escurece a imagem, então o ajuste funciona de qualquer forma.",
        noDisplays: "Nenhuma tela encontrada.",
        displayOff: "Desligada",
        turnOffDisplay: "Desligar tela",
        turnOnDisplay: "Ligar tela",
        lastDisplayCaption: "Pelo menos uma tela deve continuar ligada.",
        switchUnavailable: "Não é possível ligar ou desligar telas neste Mac.",
        switchFailed: "Não foi possível alterar esta tela.",
        openLidToEnable: "Abra a tampa para ligar a tela integrada.",
        keysToggle: "Ajustar o brilho da tela sob o ponteiro",
        keysCaption: "As teclas de brilho mudam a tela em que o ponteiro está.",
        keyStep: "Passo da tecla de brilho",
        keyStepCaption: "Usar passos menores para o controle de brilho",
        keyStepStandard: "Padrão",
        keyStepHalf: "Meio passo",
        keyStepQuarter: "Um quarto de passo",
        displayBrightnessDecrease: "Diminuir brilho com atalho",
        displayBrightnessIncrease: "Aumentar brilho com atalho",
        keyboardLight: "Luz do teclado",
        keyboardBrightnessShortcuts: "Usar atalhos para o brilho do teclado",
        keyboardBrightnessDecrease: "Diminuir luz de fundo com atalho",
        keyboardBrightnessIncrease: "Aumentar luz de fundo com atalho",
        softwareDimming: "Escurecer a imagem",
        extendedDimming: "Escurecimento extra",
        islandPromptTitle: "Mostrar o brilho na Dynamic Island?",
        islandPromptMessage: "A Dynamic Island só mostra mudanças de brilho quando “Controle de telas” está ativado nos ajustes de Telas.",
        islandPromptKeepOff: "Manter desativado",
        toggleSystemAppearanceShortcut: "Alternar aparência do sistema com atalho"
    )

    static let tr = BrightnessFeatureStrings(
        pageTitle: "Ekranlar",
        hubDescription: "Tüm ekranlar için parlaklık ve güç denetimleri",
        enable: "Ekran Denetimi",
        enableCaption: "Yerleşik ekran ve harici monitörler için parlaklık ve açma kapatma denetimleri, burada ve menü çubuğu panelinde.",
        externalCaption: "Harici monitörler, kendi düğmelerinin kullandığı protokolle ayarlanır. Bağlantı bu protokolü taşıyamadığında, örneğin HDMI adaptörlerinde, kaydırıcı bunun yerine görüntüyü karartır; parlaklık denetimi her durumda çalışır.",
        noDisplays: "Ekran bulunamadı.",
        displayOff: "Kapalı",
        turnOffDisplay: "Ekranı kapat",
        turnOnDisplay: "Ekranı aç",
        lastDisplayCaption: "En az bir ekran açık kalmalıdır.",
        switchUnavailable: "Bu Mac’te ekran açma ve kapatma kullanılamıyor.",
        switchFailed: "Bu ekran değiştirilemedi.",
        openLidToEnable: "Yerleşik ekranı açmak için kapağı açın.",
        keysToggle: "İmlecin altındaki ekranın parlaklığını ayarla",
        keysCaption: "Parlaklık tuşları imlecinizin üzerinde olduğu ekranı değiştirir.",
        keyStep: "Parlaklık tuşu adımı",
        keyStepCaption: "Parlaklık denetimi için daha küçük adımlar kullan",
        keyStepStandard: "Standart",
        keyStepHalf: "Yarım adım",
        keyStepQuarter: "Çeyrek adım",
        displayBrightnessDecrease: "Kestirmeyle parlaklığı azalt",
        displayBrightnessIncrease: "Kestirmeyle parlaklığı artır",
        keyboardLight: "Klavye ışığı",
        keyboardBrightnessShortcuts: "Klavye parlaklığı kısayollarını kullan",
        keyboardBrightnessDecrease: "Kestirmeyle arka ışığı azalt",
        keyboardBrightnessIncrease: "Kestirmeyle arka ışığı artır",
        softwareDimming: "Görüntüyü karart",
        extendedDimming: "Ek karartma",
        islandPromptTitle: "Parlaklık Dynamic Island’da gösterilsin mi?",
        islandPromptMessage: "Dynamic Island, parlaklık değişikliklerini yalnızca Ekranlar ayarlarında “Ekran Denetimi” açıkken gösterir.",
        islandPromptKeepOff: "Kapalı kalsın",
        toggleSystemAppearanceShortcut: "Sistem görünüşünü kestirmeyle değiştir"
    )

    static let ru = BrightnessFeatureStrings(
        pageTitle: "Экраны",
        hubDescription: "Яркость и включение всех экранов",
        enable: "Управление экранами",
        enableCaption: "Настройки яркости и включения встроенного экрана и внешних мониторов здесь и в панели строки меню.",
        externalCaption: "Внешние мониторы настраиваются тем же протоколом, что и их собственные кнопки. Если соединение не передаёт этот протокол, например через адаптеры HDMI, ползунок затемняет изображение, так что регулировка работает в любом случае.",
        noDisplays: "Экраны не найдены.",
        displayOff: "Выключен",
        turnOffDisplay: "Выключить экран",
        turnOnDisplay: "Включить экран",
        lastDisplayCaption: "Хотя бы один экран должен оставаться включённым.",
        switchUnavailable: "Управление включением экранов недоступно на этом Mac.",
        switchFailed: "Не удалось изменить состояние экрана.",
        openLidToEnable: "Откройте крышку, чтобы включить встроенный экран.",
        keysToggle: "Регулировать яркость экрана под указателем",
        keysCaption: "Клавиши яркости меняют экран, на котором находится указатель.",
        keyStep: "Шаг клавиши яркости",
        keyStepCaption: "Использовать меньший шаг для регулировки яркости",
        keyStepStandard: "Стандартный",
        keyStepHalf: "Половина шага",
        keyStepQuarter: "Четверть шага",
        displayBrightnessDecrease: "Уменьшить яркость сочетанием клавиш",
        displayBrightnessIncrease: "Увеличить яркость сочетанием клавиш",
        keyboardLight: "Подсветка клавиатуры",
        keyboardBrightnessShortcuts: "Использовать сочетания клавиш для подсветки клавиатуры",
        keyboardBrightnessDecrease: "Уменьшить подсветку сочетанием клавиш",
        keyboardBrightnessIncrease: "Увеличить подсветку сочетанием клавиш",
        softwareDimming: "Затемнять изображение",
        extendedDimming: "Дополнительное затемнение",
        islandPromptTitle: "Показывать яркость в Dynamic Island?",
        islandPromptMessage: "Dynamic Island показывает изменения яркости, только когда в настройках «Экраны» включено «Управление экранами».",
        islandPromptKeepOff: "Оставить выключенным",
        toggleSystemAppearanceShortcut: "Переключить оформление системы сочетанием клавиш"
    )

    static let es = BrightnessFeatureStrings(
        pageTitle: "Pantallas",
        hubDescription: "Brillo y encendido para todas las pantallas",
        enable: "Control de pantallas",
        enableCaption: "Controles de brillo y encendido para la pantalla integrada y los monitores externos, aquí y en el panel de la barra de menús.",
        externalCaption: "Los monitores externos se ajustan con el mismo protocolo que sus propios botones. Cuando la conexión no transmite ese protocolo, como con adaptadores HDMI, el control oscurece la imagen, así que el ajuste funciona igualmente.",
        noDisplays: "No se encontró ninguna pantalla.",
        displayOff: "Apagada",
        turnOffDisplay: "Apagar pantalla",
        turnOnDisplay: "Encender pantalla",
        lastDisplayCaption: "Al menos una pantalla debe permanecer encendida.",
        switchUnavailable: "El encendido de pantallas no está disponible en este Mac.",
        switchFailed: "No se pudo cambiar esta pantalla.",
        openLidToEnable: "Abre la tapa para encender la pantalla integrada.",
        keysToggle: "Ajustar el brillo de la pantalla bajo el puntero",
        keysCaption: "Las teclas de brillo cambian la pantalla en la que está el puntero.",
        keyStep: "Paso de tecla de brillo",
        keyStepCaption: "Usar pasos más pequeños para el control de brillo",
        keyStepStandard: "Estándar",
        keyStepHalf: "Medio paso",
        keyStepQuarter: "Un cuarto de paso",
        displayBrightnessDecrease: "Reducir el brillo con atajo",
        displayBrightnessIncrease: "Aumentar el brillo con atajo",
        keyboardLight: "Luz del teclado",
        keyboardBrightnessShortcuts: "Usar atajos para el brillo del teclado",
        keyboardBrightnessDecrease: "Reducir la retroiluminación con atajo",
        keyboardBrightnessIncrease: "Aumentar la retroiluminación con atajo",
        softwareDimming: "Oscurecer la imagen",
        extendedDimming: "Atenuación adicional",
        islandPromptTitle: "¿Mostrar el brillo en el Dynamic Island?",
        islandPromptMessage: "El Dynamic Island solo muestra los cambios de brillo cuando “Control de pantallas” está activado en los ajustes de Pantallas.",
        islandPromptKeepOff: "Mantener desactivado",
        toggleSystemAppearanceShortcut: "Alternar aspecto del sistema con atajo"
    )

    static let sk = BrightnessFeatureStrings(
        pageTitle: "Displeje",
        hubDescription: "Jas a zapínanie pre všetky displeje",
        enable: "Ovládanie displejov",
        enableCaption: "Ovládanie jasu a zapínania pre vstavaný displej a externé monitory, tu aj v paneli v lište.",
        externalCaption: "Externé monitory sa upravujú rovnakým protokolom ako ich vlastné tlačidlá. Keď ho pripojenie nedokáže preniesť, napríklad pri HDMI adaptéroch, posuvník namiesto toho stmaví obraz, takže ovládanie jasu funguje vždy.",
        noDisplays: "Nenašiel sa žiadny displej.",
        displayOff: "Vypnutý",
        turnOffDisplay: "Vypnúť displej",
        turnOnDisplay: "Zapnúť displej",
        lastDisplayCaption: "Aspoň jeden displej musí zostať zapnutý.",
        switchUnavailable: "Prepínanie displejov nie je na tomto Macu dostupné.",
        switchFailed: "Tento displej sa nepodarilo zmeniť.",
        openLidToEnable: "Otvorte veko, aby ste zapli vstavaný displej.",
        keysToggle: "Upravovať jas displeja pod kurzorom",
        keysCaption: "Klávesy jasu menia displej, na ktorom je kurzor.",
        keyStep: "Krok klávesu jasu",
        keyStepCaption: "Používať menšie kroky na ovládanie jasu",
        keyStepStandard: "Štandardný",
        keyStepHalf: "Polovičný krok",
        keyStepQuarter: "Štvrtinový krok",
        displayBrightnessDecrease: "Znížiť jas skratkou",
        displayBrightnessIncrease: "Zvýšiť jas skratkou",
        keyboardLight: "Podsvietenie klávesnice",
        keyboardBrightnessShortcuts: "Používať klávesové skratky pre jas klávesnice",
        keyboardBrightnessDecrease: "Znížiť podsvietenie skratkou",
        keyboardBrightnessIncrease: "Zvýšiť podsvietenie skratkou",
        softwareDimming: "Stmaviť obraz",
        extendedDimming: "Ďalšie stmievanie",
        islandPromptTitle: "Zobrazovať jas v Dynamic Island?",
        islandPromptMessage: "Dynamic Island zobrazuje zmeny jasu, len keď je v nastaveniach Displeje zapnuté „Ovládanie displejov“.",
        islandPromptKeepOff: "Nechať vypnuté",
        toggleSystemAppearanceShortcut: "Prepnúť vzhľad systému skratkou"
    )

    static let de = BrightnessFeatureStrings(
        pageTitle: "Displays",
        hubDescription: "Helligkeit und Ein oder Aus für alle Displays",
        enable: "Display-Steuerung",
        enableCaption: "Regler für Helligkeit und Ein oder Aus für das eingebaute Display und externe Monitore, hier und im Menüleistenpanel.",
        externalCaption: "Externe Monitore werden über dasselbe Protokoll wie ihre eigenen Tasten eingestellt. Trägt die Verbindung es nicht, etwa bei HDMI-Adaptern, dunkelt der Regler stattdessen das Bild ab, sodass die Helligkeit in jedem Fall steuerbar bleibt.",
        noDisplays: "Kein Display gefunden.",
        displayOff: "Aus",
        turnOffDisplay: "Display ausschalten",
        turnOnDisplay: "Display einschalten",
        lastDisplayCaption: "Mindestens ein Display muss eingeschaltet bleiben.",
        switchUnavailable: "Die Displaysteuerung ist auf diesem Mac nicht verfügbar.",
        switchFailed: "Dieses Display konnte nicht geändert werden.",
        openLidToEnable: "Öffne den Deckel, um das integrierte Display einzuschalten.",
        keysToggle: "Helligkeit des Displays unter dem Zeiger anpassen",
        keysCaption: "Die Helligkeitstasten ändern das Display, auf dem sich der Zeiger befindet.",
        keyStep: "Helligkeitstasten-Schritt",
        keyStepCaption: "Kleinere Schritte für die Helligkeitssteuerung verwenden",
        keyStepStandard: "Standard",
        keyStepHalf: "Halbe Schritte",
        keyStepQuarter: "Viertelschritte",
        displayBrightnessDecrease: "Helligkeit mit Kurzbefehl verringern",
        displayBrightnessIncrease: "Helligkeit mit Kurzbefehl erhöhen",
        keyboardLight: "Tastaturbeleuchtung",
        keyboardBrightnessShortcuts: "Kurzbefehle für die Tastaturhelligkeit verwenden",
        keyboardBrightnessDecrease: "Hintergrundbeleuchtung mit Kurzbefehl verringern",
        keyboardBrightnessIncrease: "Hintergrundbeleuchtung mit Kurzbefehl erhöhen",
        softwareDimming: "Bild abdunkeln",
        extendedDimming: "Zusätzliches Abdunkeln",
        islandPromptTitle: "Helligkeit in der Dynamic Island anzeigen?",
        islandPromptMessage: "Die Dynamic Island zeigt Helligkeitsänderungen nur, wenn „Display-Steuerung“ in den Displays-Einstellungen aktiviert ist.",
        islandPromptKeepOff: "Aus lassen",
        toggleSystemAppearanceShortcut: "Systemerscheinungsbild mit Kurzbefehl umschalten"
    )

    static let fr = BrightnessFeatureStrings(
        pageTitle: "Écrans",
        hubDescription: "Luminosité et alimentation de tous les écrans",
        enable: "Contrôle des écrans",
        enableCaption: "Contrôles de luminosité et d’alimentation pour l’écran intégré et les moniteurs externes, ici et dans le panneau de la barre des menus.",
        externalCaption: "Les moniteurs externes sont réglés par le même protocole que leurs propres boutons. Quand la connexion ne le transmet pas, comme avec les adaptateurs HDMI, le curseur assombrit l’image, le réglage fonctionne donc dans tous les cas.",
        noDisplays: "Aucun écran détecté.",
        displayOff: "Éteint",
        turnOffDisplay: "Éteindre l’écran",
        turnOnDisplay: "Allumer l’écran",
        lastDisplayCaption: "Au moins un écran doit rester allumé.",
        switchUnavailable: "Le contrôle d’alimentation des écrans n’est pas disponible sur ce Mac.",
        switchFailed: "Impossible de modifier cet écran.",
        openLidToEnable: "Ouvrez le couvercle pour allumer l’écran intégré.",
        keysToggle: "Régler la luminosité de l’écran sous le pointeur",
        keysCaption: "Les touches de luminosité modifient l’écran où se trouve le pointeur.",
        keyStep: "Pas de touche de luminosité",
        keyStepCaption: "Utiliser des pas plus petits pour le contrôle de la luminosité",
        keyStepStandard: "Standard",
        keyStepHalf: "Demi-pas",
        keyStepQuarter: "Quart de pas",
        displayBrightnessDecrease: "Réduire la luminosité avec un raccourci",
        displayBrightnessIncrease: "Augmenter la luminosité avec un raccourci",
        keyboardLight: "Éclairage du clavier",
        keyboardBrightnessShortcuts: "Utiliser les raccourcis de luminosité du clavier",
        keyboardBrightnessDecrease: "Réduire le rétroéclairage avec un raccourci",
        keyboardBrightnessIncrease: "Augmenter le rétroéclairage avec un raccourci",
        softwareDimming: "Assombrir l’image",
        extendedDimming: "Assombrissement supplémentaire",
        islandPromptTitle: "Afficher la luminosité dans la Dynamic Island ?",
        islandPromptMessage: "La Dynamic Island n’affiche les changements de luminosité que lorsque « Contrôle des écrans » est activé dans les réglages Écrans.",
        islandPromptKeepOff: "Laisser désactivé",
        toggleSystemAppearanceShortcut: "Basculer l’apparence du système avec un raccourci"
    )

    static let it = BrightnessFeatureStrings(
        pageTitle: "Schermi",
        hubDescription: "Luminosità e accensione per tutti gli schermi",
        enable: "Controllo schermi",
        enableCaption: "Controlli di luminosità e accensione per lo schermo integrato e i monitor esterni, qui e nel pannello della barra dei menu.",
        externalCaption: "I monitor esterni vengono regolati con lo stesso protocollo dei loro pulsanti. Quando il collegamento non lo trasmette, come con gli adattatori HDMI, il cursore scurisce l’immagine, quindi la regolazione funziona comunque.",
        noDisplays: "Nessuno schermo trovato.",
        displayOff: "Spento",
        turnOffDisplay: "Spegni schermo",
        turnOnDisplay: "Accendi schermo",
        lastDisplayCaption: "Almeno uno schermo deve rimanere acceso.",
        switchUnavailable: "Il controllo di accensione degli schermi non è disponibile su questo Mac.",
        switchFailed: "Non è stato possibile modificare questo schermo.",
        openLidToEnable: "Apri il coperchio per accendere lo schermo integrato.",
        keysToggle: "Regola la luminosità dello schermo sotto il puntatore",
        keysCaption: "I tasti di luminosità modificano lo schermo su cui si trova il puntatore.",
        keyStep: "Passo del tasto di luminosità",
        keyStepCaption: "Usa passi più piccoli per la regolazione della luminosità",
        keyStepStandard: "Standard",
        keyStepHalf: "Mezzo passo",
        keyStepQuarter: "Un quarto di passo",
        displayBrightnessDecrease: "Riduci luminosità con abbreviazione",
        displayBrightnessIncrease: "Aumenta luminosità con abbreviazione",
        keyboardLight: "Illuminazione tastiera",
        keyboardBrightnessShortcuts: "Usa le scorciatoie per la luminosità della tastiera",
        keyboardBrightnessDecrease: "Riduci retroilluminazione con abbreviazione",
        keyboardBrightnessIncrease: "Aumenta retroilluminazione con abbreviazione",
        softwareDimming: "Scurisci l’immagine",
        extendedDimming: "Oscuramento extra",
        islandPromptTitle: "Mostrare la luminosità nella Dynamic Island?",
        islandPromptMessage: "La Dynamic Island mostra le variazioni di luminosità solo quando “Controllo schermi” è attivo nelle impostazioni Schermi.",
        islandPromptKeepOff: "Lascia disattivato",
        toggleSystemAppearanceShortcut: "Attiva/disattiva aspetto del sistema con abbreviazione"
    )

    static let ja = BrightnessFeatureStrings(
        pageTitle: "ディスプレイ",
        hubDescription: "すべてのディスプレイの明るさと電源を操作",
        enable: "ディスプレイの操作",
        enableCaption: "内蔵ディスプレイと外部モニタの明るさと電源を、こことメニューバーパネルで操作します。",
        externalCaption: "外部モニタは本体のボタンと同じプロトコルで調整します。HDMI変換アダプタなどでこのプロトコルが通らない場合は、スライダが代わりに画面を暗くするため、どの接続でも輝度を調整できます。",
        noDisplays: "ディスプレイが見つかりません。",
        displayOff: "オフ",
        turnOffDisplay: "ディスプレイの電源を切る",
        turnOnDisplay: "ディスプレイの電源を入れる",
        lastDisplayCaption: "少なくとも1台のディスプレイをオンのままにしてください。",
        switchUnavailable: "このMacではディスプレイの切り替えを利用できません。",
        switchFailed: "このディスプレイを切り替えられませんでした。",
        openLidToEnable: "内蔵ディスプレイをオンにするには、蓋を開いてください。",
        keysToggle: "ポインタの下のディスプレイの明るさを調整",
        keysCaption: "輝度キーで、ポインタがあるディスプレイを変更します。",
        keyStep: "輝度キーのステップ",
        keyStepCaption: "輝度調整により細かいステップを使用",
        keyStepStandard: "標準",
        keyStepHalf: "半分",
        keyStepQuarter: "4分の1",
        displayBrightnessDecrease: "ショートカットで明るさを下げる",
        displayBrightnessIncrease: "ショートカットで明るさを上げる",
        keyboardLight: "キーボードのバックライト",
        keyboardBrightnessShortcuts: "キーボードの明るさのショートカットを使用",
        keyboardBrightnessDecrease: "ショートカットでバックライトを下げる",
        keyboardBrightnessIncrease: "ショートカットでバックライトを上げる",
        softwareDimming: "画面を暗くする",
        extendedDimming: "さらに暗くする",
        islandPromptTitle: "Dynamic Islandに明るさを表示しますか？",
        islandPromptMessage: "Dynamic Islandは、「ディスプレイ」設定で「ディスプレイの操作」がオンのときだけ明るさの変化を表示します。",
        islandPromptKeepOff: "オフのままにする",
        toggleSystemAppearanceShortcut: "ショートカットでシステムの配色の切り替え"
    )

    static let ko = BrightnessFeatureStrings(
        pageTitle: "디스플레이",
        hubDescription: "모든 디스플레이의 밝기와 전원 제어",
        enable: "디스플레이 제어",
        enableCaption: "내장 화면과 외부 모니터의 밝기와 전원을 여기와 메뉴 막대 패널에서 제어합니다.",
        externalCaption: "외부 모니터는 자체 버튼과 동일한 프로토콜로 조절됩니다. HDMI 어댑터처럼 연결이 이 프로토콜을 지원하지 않으면 슬라이더가 대신 화면을 어둡게 하므로 어느 경우든 밝기를 조절할 수 있습니다.",
        noDisplays: "디스플레이를 찾을 수 없습니다.",
        displayOff: "꺼짐",
        turnOffDisplay: "디스플레이 끄기",
        turnOnDisplay: "디스플레이 켜기",
        lastDisplayCaption: "최소 한 대의 디스플레이는 켜져 있어야 합니다.",
        switchUnavailable: "이 Mac에서는 디스플레이 전원 제어를 사용할 수 없습니다.",
        switchFailed: "이 디스플레이를 변경할 수 없습니다.",
        openLidToEnable: "내장 디스플레이를 켜려면 덮개를 여세요.",
        keysToggle: "포인터 아래 디스플레이의 밝기 조절",
        keysCaption: "밝기 키는 포인터가 있는 디스플레이를 변경합니다.",
        keyStep: "밝기 키 단계",
        keyStepCaption: "밝기 조절 시 더 작은 단계 사용",
        keyStepStandard: "표준",
        keyStepHalf: "1/2 단계",
        keyStepQuarter: "1/4 단계",
        displayBrightnessDecrease: "단축키로 밝기 낮추기",
        displayBrightnessIncrease: "단축키로 밝기 높이기",
        keyboardLight: "키보드 백라이트",
        keyboardBrightnessShortcuts: "키보드 밝기 단축키 사용",
        keyboardBrightnessDecrease: "단축키로 백라이트 낮추기",
        keyboardBrightnessIncrease: "단축키로 백라이트 높이기",
        softwareDimming: "화면을 어둡게",
        extendedDimming: "추가 어둡게",
        islandPromptTitle: "Dynamic Island에 밝기를 표시할까요?",
        islandPromptMessage: "Dynamic Island는 디스플레이 설정에서 “디스플레이 제어”가 켜져 있을 때만 밝기 변화를 표시합니다.",
        islandPromptKeepOff: "끈 상태로 유지",
        toggleSystemAppearanceShortcut: "단축키로 시스템 화면 모드 전환"
    )

    static let zhHans = BrightnessFeatureStrings(
        pageTitle: "显示器",
        hubDescription: "控制所有显示器的亮度和开关",
        enable: "显示器控制",
        enableCaption: "内建显示器和外接显示器的亮度与开关控制，显示在这里和菜单栏面板中。",
        externalCaption: "外接显示器通过与其自身按键相同的协议调节。当连接无法传输该协议时（例如 HDMI 转接器），滑块会改为调暗画面，因此亮度调节始终可用。",
        noDisplays: "未找到显示器。",
        displayOff: "已关闭",
        turnOffDisplay: "关闭显示器",
        turnOnDisplay: "打开显示器",
        lastDisplayCaption: "至少要保留一台显示器开启。",
        switchUnavailable: "此 Mac 不支持显示器开关。",
        switchFailed: "无法更改这台显示器。",
        openLidToEnable: "请打开 Mac 盖子后再启用内建显示器。",
        keysToggle: "调节指针下方显示器的亮度",
        keysCaption: "亮度键会更改指针所在的显示器。",
        keyStep: "亮度键步进",
        keyStepCaption: "使用更小的步长调节亮度",
        keyStepStandard: "标准",
        keyStepHalf: "半步",
        keyStepQuarter: "四分之一步",
        displayBrightnessDecrease: "使用快捷键降低亮度",
        displayBrightnessIncrease: "使用快捷键提高亮度",
        keyboardLight: "键盘背光",
        keyboardBrightnessShortcuts: "使用键盘亮度快捷键",
        keyboardBrightnessDecrease: "使用快捷键降低背光",
        keyboardBrightnessIncrease: "使用快捷键提高背光",
        softwareDimming: "调暗画面",
        extendedDimming: "进一步调暗",
        islandPromptTitle: "在Dynamic Island中显示亮度？",
        islandPromptMessage: "只有在“显示器”设置中打开“显示器控制”时，Dynamic Island才会显示亮度变化。",
        islandPromptKeepOff: "保持关闭",
        toggleSystemAppearanceShortcut: "使用快捷键切换系统外观"
    )

    static let zhTW = BrightnessFeatureStrings(
        pageTitle: "顯示器",
        hubDescription: "控制所有顯示器的亮度和開關",
        enable: "顯示器控制",
        enableCaption: "內建螢幕和外接顯示器的亮度與開關控制，顯示在這裡和選單列面板中。",
        externalCaption: "外接顯示器透過與其本身按鍵相同的協定調整。當連接無法傳輸該協定時（例如 HDMI 轉接器），滑桿會改為調暗畫面，因此亮度調整始終可用。",
        noDisplays: "找不到顯示器。",
        displayOff: "已關閉",
        turnOffDisplay: "關閉顯示器",
        turnOnDisplay: "開啟顯示器",
        lastDisplayCaption: "至少要保留一台顯示器開啟。",
        switchUnavailable: "此 Mac 不支援顯示器開關。",
        switchFailed: "無法更改這台顯示器。",
        openLidToEnable: "請打開 Mac 上蓋後再啟用內建螢幕。",
        keysToggle: "調整指標下方顯示器的亮度",
        keysCaption: "亮度鍵會更改指標所在的顯示器。",
        keyStep: "亮度鍵步進",
        keyStepCaption: "使用更小的步幅調整亮度",
        keyStepStandard: "標準",
        keyStepHalf: "半步",
        keyStepQuarter: "四分之一步",
        displayBrightnessDecrease: "使用快捷鍵降低亮度",
        displayBrightnessIncrease: "使用快捷鍵提高亮度",
        keyboardLight: "鍵盤背光",
        keyboardBrightnessShortcuts: "使用鍵盤亮度快捷鍵",
        keyboardBrightnessDecrease: "使用快捷鍵降低背光",
        keyboardBrightnessIncrease: "使用快捷鍵提高背光",
        softwareDimming: "調暗畫面",
        extendedDimming: "進一步調暗",
        islandPromptTitle: "要在Dynamic Island中顯示亮度嗎？",
        islandPromptMessage: "只有在「顯示器」設定中開啟「顯示器控制」時，Dynamic Island才會顯示亮度變化。",
        islandPromptKeepOff: "保持關閉",
        toggleSystemAppearanceShortcut: "使用快速鍵切換系統外觀"
    )

    static let zhHK = BrightnessFeatureStrings(
        pageTitle: "顯示器",
        hubDescription: "控制所有顯示器的亮度和開關",
        enable: "顯示器控制",
        enableCaption: "內置螢幕和外接顯示器的亮度與開關控制，顯示在這裏和選單列面板中。",
        externalCaption: "外接顯示器透過與其本身按鍵相同的協定調整。當連接無法傳輸該協定時（例如 HDMI 轉接器），滑桿會改為調暗畫面，因此亮度調整始終可用。",
        noDisplays: "找不到顯示器。",
        displayOff: "已關閉",
        turnOffDisplay: "關閉顯示器",
        turnOnDisplay: "開啟顯示器",
        lastDisplayCaption: "至少要保留一台顯示器開啟。",
        switchUnavailable: "此 Mac 不支援顯示器開關。",
        switchFailed: "無法更改這部顯示器。",
        openLidToEnable: "請打開 Mac 上蓋後再啟用內置顯示器。",
        keysToggle: "調整指標下方顯示器的亮度",
        keysCaption: "亮度鍵會更改指標所在的顯示器。",
        keyStep: "亮度鍵步進",
        keyStepCaption: "使用更小的步幅調整亮度",
        keyStepStandard: "標準",
        keyStepHalf: "半步",
        keyStepQuarter: "四分之一步",
        displayBrightnessDecrease: "使用快捷鍵降低亮度",
        displayBrightnessIncrease: "使用快捷鍵提高亮度",
        keyboardLight: "鍵盤背光",
        keyboardBrightnessShortcuts: "使用鍵盤亮度快捷鍵",
        keyboardBrightnessDecrease: "使用快捷鍵降低背光",
        keyboardBrightnessIncrease: "使用快捷鍵提高背光",
        softwareDimming: "調暗畫面",
        extendedDimming: "進一步調暗",
        islandPromptTitle: "要在Dynamic Island中顯示亮度嗎？",
        islandPromptMessage: "只有在「顯示器」設定中開啟「顯示器控制」時，Dynamic Island才會顯示亮度變化。",
        islandPromptKeepOff: "保持關閉",
        toggleSystemAppearanceShortcut: "使用快捷鍵切換系統外觀"
    )
    static let uk = BrightnessFeatureStrings(
        pageTitle: "Дисплеї",
        hubDescription: "Керування яскравістю та живленням для кожного дисплея",
        enable: "Керування дисплеями",
        enableCaption: "Керування яскравістю та вмиканням/вимиканням вбудованого екрана та зовнішніх моніторів тут та в панелі на смузі меню.",
        externalCaption: "Зовнішні монітори регулюються тим самим протоколом, що й їхні власні кнопки. Коли з’єднання не може його передати, як з HDMI-адаптерами, повзунок замість цього затемнює зображення, тож керування яскравістю працює в обох випадках.",
        noDisplays: "Дисплей не знайдено.",
        displayOff: "Вимкнено",
        turnOffDisplay: "Вимкнути дисплей",
        turnOnDisplay: "Увімкнути дисплей",
        lastDisplayCaption: "Принаймні один дисплей має залишатися ввімкненим.",
        switchUnavailable: "Перемикання дисплеїв недоступне на цьому Mac.",
        switchFailed: "Не вдалося змінити цей дисплей.",
        openLidToEnable: "Відкрийте кришку, щоб увімкнути вбудований дисплей.",
        keysToggle: "Регулювати яскравість дисплея під вказівником",
        keysCaption: "Клавіші яскравості змінюють дисплей, на якому знаходиться вказівник.",
        keyStep: "Крок клавіші яскравості",
        keyStepCaption: "Використовувати менші кроки для регулювання яскравості",
        keyStepStandard: "Стандартний",
        keyStepHalf: "Половина кроку",
        keyStepQuarter: "Чверть кроку",
        displayBrightnessDecrease: "Зменшити яскравість комбінацією клавіш",
        displayBrightnessIncrease: "Збільшити яскравість комбінацією клавіш",
        keyboardLight: "Підсвічування клавіатури",
        keyboardBrightnessShortcuts: "Клавіатурні скорочення яскравості клавіатури",
        keyboardBrightnessDecrease: "Зменшити підсвічування комбінацією клавіш",
        keyboardBrightnessIncrease: "Збільшити підсвічування комбінацією клавіш",
        softwareDimming: "Затемнити зображення",
        extendedDimming: "Додаткове затемнення",
        islandPromptTitle: "Показувати яскравість у Dynamic Island?",
        islandPromptMessage: "Dynamic Island показує зміни яскравості, лише коли в налаштуваннях «Дисплеї» увімкнено «Керування дисплеями».",
        islandPromptKeepOff: "Залишити вимкненим",
        toggleSystemAppearanceShortcut: "Змінити вигляд системи комбінацією клавіш"
    )
}
