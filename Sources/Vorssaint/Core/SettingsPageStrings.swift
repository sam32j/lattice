// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The one-line description under a redesigned Settings page's title, for
/// pages whose own string catalog has no room for it.
struct SettingsPageStrings {
    let finderTitle: String
    let energyDescription: String
    let monitorDescription: String
    let mouseDescription: String
    let switcherDescription: String
    let dockTitle: String
    let dockDescription: String
    let switcherLayoutWindows: String
    let switcherLayoutWindowsCaption: String
    let switcherLayoutIcons: String
    let switcherLayoutSimple: String
    let keyboardTitle: String
    let keyboardDescription: String
    let audioInputTitle: String
    let audioInputDescription: String
    let audioOutputTitle: String
    let audioOutputDescription: String
}

extension FeatureStrings {
    static func settingsPages(_ language: AppLanguage) -> SettingsPageStrings {
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
        case .uk: return .uk
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        }
    }
}

extension SettingsPageStrings {
    static let uk = SettingsPageStrings(
        finderTitle: "Finder",
        energyDescription: "Не давайте Mac заснути, керуйте екранами та заощаджуйте заряд акумулятора.",
        monitorDescription: "Що смуга меню й панель показують про Mac та коли попереджати вас.",
        mouseDescription: "Дайте колесу, боковим кнопкам і трекпеду нові функції.",
        switcherDescription: "Перемикайте програми й вікна на свій лад.",
        dockTitle: "Dock",
        dockDescription: "Переглядайте вікна програми з її значка в Dock і вибирайте, що робить клацання по ньому.",
        switcherLayoutWindows: "Мініатюри вікон",
        switcherLayoutWindowsCaption: "По одній мініатюрі для кожного вікна, включно зі згорнутими.",
        switcherLayoutIcons: "Великі значки",
        switcherLayoutSimple: "Простий список",
        keyboardTitle: "Клавіатура",
        keyboardDescription: "Захист від випадкового закриття, усунення брязкоту клавіш та налаштування Super Key.",
        audioInputTitle: "Вхід аудіо",
        audioInputDescription: "Швидкі клавіші вимкнення мікрофона та пріоритет пристроїв входу аудіо.",
        audioOutputTitle: "Вихід аудіо",
        audioOutputDescription: "Мікшер гучності, перемикач виходу аудіо та блокувальник програми Музика."
    )

    static let enUS = SettingsPageStrings(
        finderTitle: "Finder",
        energyDescription: "Keep the Mac awake, control your displays and save battery.",
        monitorDescription: "What the menu bar and the panel show about your Mac, and when to warn you.",
        mouseDescription: "Give the wheel, the side buttons and the trackpad new jobs.",
        switcherDescription: "Switch between apps and windows your way.",
        dockTitle: "Dock",
        dockDescription: "See an app’s windows from its Dock icon, and choose what a click on it does.",
        switcherLayoutWindows: "Window previews",
        switcherLayoutWindowsCaption: "One preview per window, minimized ones included.",
        switcherLayoutIcons: "Large icons",
        switcherLayoutSimple: "Simple list",
        keyboardTitle: "Keyboard",
        keyboardDescription: "Protect against accidental quits, debounce chatter, and unlock the Super Key.",
        audioInputTitle: "Audio Input",
        audioInputDescription: "Microphone mute shortcuts and audio input device priority.",
        audioOutputTitle: "Audio Output",
        audioOutputDescription: "Volume mixer, audio output switcher, and Music app blocker."
    )

    static let ptBR = SettingsPageStrings(
        finderTitle: "Finder",
        energyDescription: "Mantenha o Mac acordado, controle suas telas e economize bateria.",
        monitorDescription: "O que a barra de menus e o painel mostram sobre o Mac, e quando avisar você.",
        mouseDescription: "Dê novas funções à rodinha, aos botões laterais e ao trackpad.",
        switcherDescription: "Troque de app e de janela do seu jeito.",
        dockTitle: "Dock",
        dockDescription: "Veja as janelas de um app pelo ícone no Dock e escolha o que um clique nele faz.",
        switcherLayoutWindows: "Previews das janelas",
        switcherLayoutWindowsCaption: "Um preview por janela, incluindo as minimizadas.",
        switcherLayoutIcons: "Ícones grandes",
        switcherLayoutSimple: "Lista simples",
        keyboardTitle: "Teclado",
        keyboardDescription: "Evite encerramentos acidentais, elimine repetições de teclas e use a tecla Super.",
        audioInputTitle: "Entrada de áudio",
        audioInputDescription: "Atalhos para silenciar microfone e prioridade de dispositivos de entrada.",
        audioOutputTitle: "Saída de áudio",
        audioOutputDescription: "Mixer de volume, alternador de saída e bloqueador do app Música."
    )

    static let tr = SettingsPageStrings(
        finderTitle: "Finder",
        energyDescription: "Mac’i uyanık tutun, ekranlarınızı yönetin ve pil tasarrufu yapın.",
        monitorDescription: "Menü çubuğu ve panelin Mac hakkında neler gösterdiği ve sizi ne zaman uyaracağı.",
        mouseDescription: "Tekerleğe, yan tuşlara ve izleme dörtgenine yeni görevler verin.",
        switcherDescription: "Uygulamalar ve pencereler arasında kendi tarzınızda geçin.",
        dockTitle: "Dock",
        dockDescription: "Bir uygulamanın pencerelerini Dock simgesinden görün ve simgeye tıklamanın ne yapacağını seçin.",
        switcherLayoutWindows: "Pencere önizlemeleri",
        switcherLayoutWindowsCaption: "Her pencere için bir önizleme, simge durumundakiler dahil.",
        switcherLayoutIcons: "Büyük simgeler",
        switcherLayoutSimple: "Basit liste",
        keyboardTitle: "Klavye",
        keyboardDescription: "Yanlışlıkla kapatmayı önleyin, tuş sekmesini engelleyin ve Super Key’i kullanın.",
        audioInputTitle: "Ses Girişi",
        audioInputDescription: "Mikrofon ses kapatma kısayolları ve ses giriş aygıtı önceliği.",
        audioOutputTitle: "Ses Çıkışı",
        audioOutputDescription: "Ses karıştırıcı, ses çıkış anahtarlayıcı ve Müzik uygulaması engelleyici."
    )

    static let ru = SettingsPageStrings(
        finderTitle: "Finder",
        energyDescription: "Не давайте Mac уснуть, управляйте экранами и берегите батарею.",
        monitorDescription: "Что строка меню и панель показывают о Mac и когда вас предупреждать.",
        mouseDescription: "Дайте колёсику, боковым кнопкам и трекпаду новые задачи.",
        switcherDescription: "Переключайтесь между приложениями и окнами по-своему.",
        dockTitle: "Dock",
        dockDescription: "Смотрите окна приложения по его значку в Dock и выбирайте, что делает щелчок по нему.",
        switcherLayoutWindows: "Миниатюры окон",
        switcherLayoutWindowsCaption: "По миниатюре на каждое окно, включая свёрнутые.",
        switcherLayoutIcons: "Крупные значки",
        switcherLayoutSimple: "Простой список",
        keyboardTitle: "Клавиатура",
        keyboardDescription: "Защита от случайного закрытия, устранение дребезга и настройка клавиши Super.",
        audioInputTitle: "Вход аудио",
        audioInputDescription: "Сочетания клавиш для отключения микрофона и приоритет устройств ввода.",
        audioOutputTitle: "Выход аудио",
        audioOutputDescription: "Микшер громкости, переключатель выхода и блокировщик приложения Музыка."
    )

    static let es = SettingsPageStrings(
        finderTitle: "Finder",
        energyDescription: "Mantén el Mac despierto, controla tus pantallas y ahorra batería.",
        monitorDescription: "Qué muestran la barra de menús y el panel sobre el Mac, y cuándo avisarte.",
        mouseDescription: "Dale nuevas funciones a la rueda, a los botones laterales y al trackpad.",
        switcherDescription: "Cambia de app y de ventana a tu manera.",
        dockTitle: "Dock",
        dockDescription: "Mira las ventanas de una app desde su icono en el Dock y elige qué hace un clic en él.",
        switcherLayoutWindows: "Vistas previas de ventanas",
        switcherLayoutWindowsCaption: "Una vista previa por ventana, incluidas las minimizadas.",
        switcherLayoutIcons: "Iconos grandes",
        switcherLayoutSimple: "Lista simple",
        keyboardTitle: "Teclado",
        keyboardDescription: "Evita cierres accidentales, elimina rebotes de teclas y aprovecha la tecla Super.",
        audioInputTitle: "Entrada de audio",
        audioInputDescription: "Atajos para silenciar el micrófono y prioridad de dispositivos de entrada.",
        audioOutputTitle: "Salida de audio",
        audioOutputDescription: "Mezclador de volumen, selector de salida y bloqueador de la app Música."
    )

    static let sk = SettingsPageStrings(
        finderTitle: "Finder",
        energyDescription: "Udržujte Mac v bdelom stave, ovládajte svoje displeje a šetrite batériu.",
        monitorDescription: "Čo lišta a panel zobrazujú o vašom Macu a kedy vás upozorniť.",
        mouseDescription: "Priraďte koliesku, bočným tlačidlám a trackpadu nové úlohy.",
        switcherDescription: "Prepínajte medzi aplikáciami a oknami po svojom.",
        dockTitle: "Dock",
        dockDescription: "Zobrazte okná aplikácie z jej ikony v Docku a vyberte, čo urobí kliknutie na ňu.",
        switcherLayoutWindows: "Náhľady okien",
        switcherLayoutWindowsCaption: "Jeden náhľad na okno, vrátane minimalizovaných.",
        switcherLayoutIcons: "Veľké ikony",
        switcherLayoutSimple: "Jednoduchý zoznam",
        keyboardTitle: "Klávesnica",
        keyboardDescription: "Chráňte sa pred náhodným ukončením, potlačte chvenie klávesov a využite Super Key.",
        audioInputTitle: "Zvukový vstup",
        audioInputDescription: "Skratky stlmenia mikrofónu a priorita vstupných zvukových zariadení.",
        audioOutputTitle: "Zvukový výstup",
        audioOutputDescription: "Zmiešavač hlasitosti, prepínač výstupu a blokovač aplikácie Hudba."
    )

    static let de = SettingsPageStrings(
        finderTitle: "Finder",
        energyDescription: "Halte den Mac wach, steuere deine Bildschirme und spare Batterie.",
        monitorDescription: "Was Menüleiste und Panel über den Mac zeigen und wann du gewarnt wirst.",
        mouseDescription: "Gib dem Scrollrad, den Seitentasten und dem Trackpad neue Aufgaben.",
        switcherDescription: "Wechsle auf deine Art zwischen Apps und Fenstern.",
        dockTitle: "Dock",
        dockDescription: "Sieh die Fenster einer App über ihr Dock-Symbol und lege fest, was ein Klick darauf bewirkt.",
        switcherLayoutWindows: "Fenstervorschauen",
        switcherLayoutWindowsCaption: "Eine Vorschau pro Fenster, auch für minimierte.",
        switcherLayoutIcons: "Große Symbole",
        switcherLayoutSimple: "Einfache Liste",
        keyboardTitle: "Tastatur",
        keyboardDescription: "Schütze vor versehentlichem Beenden, entprelle Tasten und nutze die Super-Taste.",
        audioInputTitle: "Audioeingang",
        audioInputDescription: "Tastenkürzel zum Stummschalten des Mikrofons und Priorität von Audioeingabegeräten.",
        audioOutputTitle: "Audioausgang",
        audioOutputDescription: "Lautstärkemixer, Audioausgabe-Umschalter und Musik-App-Blocker."
    )

    static let fr = SettingsPageStrings(
        finderTitle: "Finder",
        energyDescription: "Gardez le Mac éveillé, réglez vos écrans et économisez la batterie.",
        monitorDescription: "Ce que la barre des menus et le panneau montrent du Mac, et quand vous prévenir.",
        mouseDescription: "Donnez de nouveaux rôles à la molette, aux boutons latéraux et au trackpad.",
        switcherDescription: "Passez d’une app ou d’une fenêtre à l’autre à votre façon.",
        dockTitle: "Dock",
        dockDescription: "Voyez les fenêtres d’une app depuis son icône dans le Dock et choisissez l’effet d’un clic dessus.",
        switcherLayoutWindows: "Aperçus des fenêtres",
        switcherLayoutWindowsCaption: "Un aperçu par fenêtre, fenêtres réduites comprises.",
        switcherLayoutIcons: "Grandes icônes",
        switcherLayoutSimple: "Liste simple",
        keyboardTitle: "Clavier",
        keyboardDescription: "Évitez les fermetures accidentelles, éliminez les rebonds et profitez de la touche Super.",
        audioInputTitle: "Entrée audio",
        audioInputDescription: "Raccourcis de coupure du micro et priorité des périphériques d’entrée audio.",
        audioOutputTitle: "Sortie audio",
        audioOutputDescription: "Mélangeur de volume, sélecteur de sortie et bloqueur de l’application Musique."
    )

    static let it = SettingsPageStrings(
        finderTitle: "Finder",
        energyDescription: "Tieni il Mac sveglio, controlla i tuoi schermi e risparmia batteria.",
        monitorDescription: "Cosa mostrano la barra dei menu e il pannello sul Mac, e quando avvisarti.",
        mouseDescription: "Assegna nuovi compiti alla rotellina, ai tasti laterali e al trackpad.",
        switcherDescription: "Passa da un’app o una finestra all’altra a modo tuo.",
        dockTitle: "Dock",
        dockDescription: "Guarda le finestre di un’app dalla sua icona nel Dock e scegli cosa fa un clic su di essa.",
        switcherLayoutWindows: "Anteprime delle finestre",
        switcherLayoutWindowsCaption: "Un’anteprima per finestra, comprese quelle contratte.",
        switcherLayoutIcons: "Icone grandi",
        switcherLayoutSimple: "Elenco semplice",
        keyboardTitle: "Tastiera",
        keyboardDescription: "Evita chiusure accidentali, elimina i rimbalzi dei tasti e usa il tasto Super.",
        audioInputTitle: "Ingresso audio",
        audioInputDescription: "Scorciatoie per disattivare il microfono e priorità dei dispositivi di ingresso audio.",
        audioOutputTitle: "Uscita audio",
        audioOutputDescription: "Mixer del volume, selettore di uscita e blocco dell’app Musica."
    )

    static let ja = SettingsPageStrings(
        finderTitle: "Finder",
        energyDescription: "Mac をスリープさせず、ディスプレイを調整し、バッテリーを節約します。",
        monitorDescription: "メニューバーとパネルに Mac の何を表示するか、いつ知らせるか。",
        mouseDescription: "ホイール、サイドボタン、トラックパッドに新しい役割を。",
        switcherDescription: "アプリやウインドウを自分のやり方で切り替え。",
        dockTitle: "Dock",
        dockDescription: "Dock のアイコンからアプリのウインドウを確認し、クリックしたときの動作を選べます。",
        switcherLayoutWindows: "ウインドウのプレビュー",
        switcherLayoutWindowsCaption: "ウインドウごとにプレビューを表示。しまったウインドウも含みます。",
        switcherLayoutIcons: "大きなアイコン",
        switcherLayoutSimple: "シンプルなリスト",
        keyboardTitle: "キーボード",
        keyboardDescription: "誤終了を防ぎ、チャタリングを抑制し、Super Key を活用します。",
        audioInputTitle: "オーディオ入力",
        audioInputDescription: "マイク消音ショートカットおよびオーディオ入力デバイスの優先順位。",
        audioOutputTitle: "オーディオ出力",
        audioOutputDescription: "音量ミキサー、オーディオ出力スイッチャー、ミュージックアプリブロッカー。"
    )

    static let ko = SettingsPageStrings(
        finderTitle: "Finder",
        energyDescription: "Mac을 깨어 있게 하고, 화면을 조절하고, 배터리를 아끼세요.",
        monitorDescription: "메뉴 막대와 패널에 Mac의 무엇을 표시할지, 언제 알릴지.",
        mouseDescription: "휠, 사이드 버튼, 트랙패드에 새 역할을 맡기세요.",
        switcherDescription: "나만의 방식으로 앱과 윈도우를 전환하세요.",
        dockTitle: "Dock",
        dockDescription: "Dock 아이콘에서 앱의 윈도우를 확인하고, 아이콘을 클릭했을 때의 동작을 고르세요.",
        switcherLayoutWindows: "윈도우 미리보기",
        switcherLayoutWindowsCaption: "윈도우마다 미리보기 하나, 축소된 윈도우도 포함합니다.",
        switcherLayoutIcons: "큰 아이콘",
        switcherLayoutSimple: "간단한 목록",
        keyboardTitle: "키보드",
        keyboardDescription: "실수 방지 종료 보호, 키 바운스 방지 및 Super Key를 설정합니다.",
        audioInputTitle: "오디오 입력",
        audioInputDescription: "마이크 음소거 단축키 및 오디오 입력 기기 우선순위.",
        audioOutputTitle: "오디오 출력",
        audioOutputDescription: "볼륨 믹서, 오디오 출력 전환기 및 음악 앱 차단기."
    )

    static let zhHans = SettingsPageStrings(
        finderTitle: "访达",
        energyDescription: "让 Mac 保持唤醒、调节显示器并节省电量。",
        monitorDescription: "菜单栏和面板显示 Mac 的哪些信息，以及何时提醒你。",
        mouseDescription: "让滚轮、侧键和触控板承担新的任务。",
        switcherDescription: "按你的方式切换 App 和窗口。",
        dockTitle: "程序坞",
        dockDescription: "从程序坞图标查看 App 的窗口，并选择点按图标时的操作。",
        switcherLayoutWindows: "窗口预览",
        switcherLayoutWindowsCaption: "每个窗口一张预览，包括已最小化的窗口。",
        switcherLayoutIcons: "大图标",
        switcherLayoutSimple: "简单列表",
        keyboardTitle: "键盘",
        keyboardDescription: "防误退防误关、按键消抖以及配置 Super Key。",
        audioInputTitle: "音频输入",
        audioInputDescription: "麦克风静音快捷键和音频输入设备优先级。",
        audioOutputTitle: "音频输出",
        audioOutputDescription: "音量混音器、音频输出切换器和音乐应用阻止程序。"
    )

    static let zhTW = SettingsPageStrings(
        finderTitle: "Finder",
        energyDescription: "讓 Mac 保持喚醒、調整顯示器並節省電量。",
        monitorDescription: "選單列和面板顯示 Mac 的哪些資訊，以及何時提醒你。",
        mouseDescription: "讓滾輪、側鍵和觸控板承擔新的任務。",
        switcherDescription: "用你的方式切換 App 和視窗。",
        dockTitle: "Dock",
        dockDescription: "從 Dock 圖示查看 App 的視窗，並選擇點按圖示時的動作。",
        switcherLayoutWindows: "視窗預覽",
        switcherLayoutWindowsCaption: "每個視窗一張預覽，包括已縮到最小的視窗。",
        switcherLayoutIcons: "大圖示",
        switcherLayoutSimple: "簡單列表",
        keyboardTitle: "鍵盤",
        keyboardDescription: "防誤退防誤關、按鍵消抖以及設定 Super Key。",
        audioInputTitle: "音訊輸入",
        audioInputDescription: "麥克風靜音快捷鍵與音訊輸入裝置優先權。",
        audioOutputTitle: "音訊輸出",
        audioOutputDescription: "音量混音器、音訊輸出切換器與音樂應用程式阻擋器。"
    )

    static let zhHK = SettingsPageStrings(
        finderTitle: "Finder",
        energyDescription: "讓 Mac 保持喚醒、調整顯示器並節省電量。",
        monitorDescription: "選單列和面板顯示 Mac 的哪些資訊，以及何時提醒你。",
        mouseDescription: "讓滾輪、側鍵和觸控板承擔新的任務。",
        switcherDescription: "用你的方式切換 App 和視窗。",
        dockTitle: "Dock",
        dockDescription: "從 Dock 圖示查看 App 的視窗，並選擇點按圖示時的動作。",
        switcherLayoutWindows: "視窗預覽",
        switcherLayoutWindowsCaption: "每個視窗一張預覽，包括已縮到最小的視窗。",
        switcherLayoutIcons: "大圖示",
        switcherLayoutSimple: "簡單列表",
        keyboardTitle: "鍵盤",
        keyboardDescription: "防誤退防誤關、按鍵消抖以及設定 Super Key。",
        audioInputTitle: "音訊輸入",
        audioInputDescription: "麥克風靜音快捷鍵與音訊輸入裝置優先權。",
        audioOutputTitle: "音訊輸出",
        audioOutputDescription: "音量混音器、音訊輸出切換器與音樂應用程式阻擋器。"
    )
}
