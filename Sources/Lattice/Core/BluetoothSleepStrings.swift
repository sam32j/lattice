// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Strings for the Bluetooth on sleep feature. Same contract as the other
/// FeatureStrings structs: memberwise init with labeled arguments in
/// declaration order, one static per language, all in this file.
struct BluetoothSleepStrings {
    let pageTitle: String
    let hubDescription: String
    let enable: String
    let enableCaption: String
    let restoreToggle: String
    let restoreCaption: String
    let unsupported: String
}

extension FeatureStrings {
    static func bluetoothSleep(_ language: AppLanguage) -> BluetoothSleepStrings {
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

extension BluetoothSleepStrings {
    static let enUS = BluetoothSleepStrings(
        pageTitle: "Bluetooth Control",
        hubDescription: "Switches Bluetooth off while the Mac sleeps, so headphones in a bag stop connecting to it.",
        enable: "Turn Bluetooth off when the Mac sleeps",
        enableCaption: "Disconnects Bluetooth devices, including headphones, keyboards and mice, while your Mac sleeps.",
        restoreToggle: "Turn Bluetooth back on when the Mac wakes",
        restoreCaption: "Restores Bluetooth if Lattice turned it off during sleep. If Bluetooth was already off, it stays off.",
        unsupported: "This Mac has no Bluetooth controller."
    )

    static let ptBR = BluetoothSleepStrings(
        pageTitle: "Comportamento do Bluetooth",
        hubDescription: "Desliga o Bluetooth enquanto o Mac dorme, para que os fones na mochila parem de se conectar.",
        enable: "Desligar o Bluetooth quando o Mac dormir",
        enableCaption: "Desconecta dispositivos Bluetooth, incluindo fones, teclados e mouses, enquanto o Mac dorme.",
        restoreToggle: "Ligar o Bluetooth de volta quando o Mac acordar",
        restoreCaption: "Religa o Bluetooth se o Lattice o desligou durante o repouso. Se já estava desligado, continua assim.",
        unsupported: "Este Mac não tem controlador Bluetooth."
    )

    static let tr = BluetoothSleepStrings(
        pageTitle: "Bluetooth Davranışı",
        hubDescription: "Mac uyurken Bluetooth’u kapatır, böylece çantadaki kulaklıklar bağlanmayı bırakır.",
        enable: "Mac uyuduğunda Bluetooth’u kapat",
        enableCaption: "Mac uyurken kulaklık, klavye ve fare dahil Bluetooth aygıtlarının bağlantısını keser.",
        restoreToggle: "Mac uyandığında Bluetooth’u yeniden aç",
        restoreCaption: "Lattice uyku sırasında kapattıysa Bluetooth’u geri açar. Önceden kapalıysa kapalı kalır.",
        unsupported: "Bu Mac’te Bluetooth denetleyicisi yok."
    )

    static let ru = BluetoothSleepStrings(
        pageTitle: "Поведение Bluetooth",
        hubDescription: "Выключает Bluetooth на время сна Mac, чтобы наушники в сумке перестали к нему подключаться.",
        enable: "Выключать Bluetooth, когда Mac засыпает",
        enableCaption: "Отключает Bluetooth-устройства, включая наушники, клавиатуры и мыши, пока Mac спит.",
        restoreToggle: "Включать Bluetooth обратно при пробуждении Mac",
        restoreCaption: "Включает Bluetooth, если Lattice выключил его на время сна. Если он был выключен заранее, он останется выключенным.",
        unsupported: "На этом Mac нет контроллера Bluetooth."
    )

    static let es = BluetoothSleepStrings(
        pageTitle: "Comportamiento de Bluetooth",
        hubDescription: "Apaga el Bluetooth mientras el Mac duerme, para que los auriculares en la mochila dejen de conectarse.",
        enable: "Apagar el Bluetooth cuando el Mac entre en reposo",
        enableCaption: "Desconecta los dispositivos Bluetooth, incluidos auriculares, teclados y ratones, mientras el Mac está en reposo.",
        restoreToggle: "Volver a encender el Bluetooth cuando el Mac despierte",
        restoreCaption: "Reactiva el Bluetooth si Lattice lo apagó durante el reposo. Si ya estaba apagado, seguirá así.",
        unsupported: "Este Mac no tiene controlador Bluetooth."
    )

    static let sk = BluetoothSleepStrings(
        pageTitle: "Správanie Bluetooth",
        hubDescription: "Vypne Bluetooth, kým Mac spí, aby sa slúchadlá v taške prestali k nemu pripájať.",
        enable: "Vypnúť Bluetooth, keď Mac zaspí",
        enableCaption: "Počas spánku Macu odpojí zariadenia Bluetooth vrátane slúchadiel, klávesníc a myší.",
        restoreToggle: "Znova zapnúť Bluetooth pri prebudení Macu",
        restoreCaption: "Zapne Bluetooth, ak ho Lattice vypol počas spánku. Ak bol vypnutý už predtým, zostane vypnutý.",
        unsupported: "Tento Mac nemá Bluetooth radič."
    )

    static let de = BluetoothSleepStrings(
        pageTitle: "Bluetooth-Verhalten",
        hubDescription: "Schaltet Bluetooth aus, während der Mac schläft, damit Kopfhörer in der Tasche sich nicht mehr verbinden.",
        enable: "Bluetooth ausschalten, wenn der Mac in den Ruhezustand geht",
        enableCaption: "Trennt Bluetooth-Geräte wie Kopfhörer, Tastaturen und Mäuse, während dein Mac schläft.",
        restoreToggle: "Bluetooth wieder einschalten, wenn der Mac aufwacht",
        restoreCaption: "Schaltet Bluetooth wieder ein, wenn Lattice es im Ruhezustand ausgeschaltet hat. War es vorher aus, bleibt es aus.",
        unsupported: "Dieser Mac hat keinen Bluetooth-Controller."
    )

    static let fr = BluetoothSleepStrings(
        pageTitle: "Comportement du Bluetooth",
        hubDescription: "Coupe le Bluetooth pendant que le Mac dort, pour que les écouteurs rangés dans un sac cessent de s’y connecter.",
        enable: "Couper le Bluetooth quand le Mac se met en veille",
        enableCaption: "Déconnecte les appareils Bluetooth, notamment les écouteurs, claviers et souris, pendant la veille du Mac.",
        restoreToggle: "Rallumer le Bluetooth au réveil du Mac",
        restoreCaption: "Réactive le Bluetooth si Lattice l’a coupé pendant la veille. S’il était déjà désactivé, il le reste.",
        unsupported: "Ce Mac n’a pas de contrôleur Bluetooth."
    )

    static let it = BluetoothSleepStrings(
        pageTitle: "Comportamento Bluetooth",
        hubDescription: "Spegne il Bluetooth mentre il Mac dorme, così le cuffie nello zaino smettono di collegarsi.",
        enable: "Spegni il Bluetooth quando il Mac va in stop",
        enableCaption: "Disconnette i dispositivi Bluetooth, incluse cuffie, tastiere e mouse, mentre il Mac è in stop.",
        restoreToggle: "Riaccendi il Bluetooth quando il Mac si riattiva",
        restoreCaption: "Riattiva il Bluetooth se Lattice l’ha spento durante lo stop. Se era già spento, rimane spento.",
        unsupported: "Questo Mac non ha un controller Bluetooth."
    )

    static let ja = BluetoothSleepStrings(
        pageTitle: "Bluetoothの動作",
        hubDescription: "Macのスリープ中にBluetoothを切り、カバンの中のヘッドホンが勝手につながらないようにします。",
        enable: "Macがスリープしたら Bluetooth を切る",
        enableCaption: "Macのスリープ中は、ヘッドホン、キーボード、マウスなどのBluetooth機器を切断します。",
        restoreToggle: "Macの復帰時に Bluetooth を戻す",
        restoreCaption: "Latticeがスリープ時にオフにした場合のみ、Bluetoothをオンに戻します。もともとオフなら、そのままにします。",
        unsupported: "このMacにはBluetoothコントローラがありません。"
    )

    static let ko = BluetoothSleepStrings(
        pageTitle: "Bluetooth 동작",
        hubDescription: "Mac이 잠자는 동안 Bluetooth를 꺼서 가방 속 헤드폰이 계속 연결되지 않도록 합니다.",
        enable: "Mac이 잠자기에 들어가면 Bluetooth 끄기",
        enableCaption: "Mac이 잠자는 동안 헤드폰, 키보드, 마우스 등 Bluetooth 기기의 연결을 끊습니다.",
        restoreToggle: "Mac이 깨어나면 Bluetooth 다시 켜기",
        restoreCaption: "Lattice가 잠자기 중에 끈 경우에만 Bluetooth를 다시 켭니다. 원래 꺼져 있었다면 그대로 둡니다.",
        unsupported: "이 Mac에는 Bluetooth 컨트롤러가 없습니다."
    )

    static let zhHans = BluetoothSleepStrings(
        pageTitle: "蓝牙行为",
        hubDescription: "Mac 睡眠期间关闭蓝牙，包里的耳机不再自动连上来。",
        enable: "Mac 进入睡眠时关闭蓝牙",
        enableCaption: "Mac 睡眠时断开耳机、键盘、鼠标等蓝牙设备的连接。",
        restoreToggle: "Mac 唤醒时重新打开蓝牙",
        restoreCaption: "仅恢复由 Lattice 在睡眠时关闭的蓝牙。如果蓝牙原本就已关闭，则保持关闭。",
        unsupported: "这台 Mac 没有蓝牙控制器。"
    )

    static let zhTW = BluetoothSleepStrings(
        pageTitle: "藍牙行為",
        hubDescription: "Mac 睡眠期間關閉藍牙，包包裡的耳機不會再自動連上來。",
        enable: "Mac 進入睡眠時關閉藍牙",
        enableCaption: "Mac 睡眠時中斷耳機、鍵盤、滑鼠等藍牙裝置的連線。",
        restoreToggle: "Mac 喚醒時重新開啟藍牙",
        restoreCaption: "僅恢復由 Lattice 在睡眠時關閉的藍牙。如果藍牙原本就已關閉，則保持關閉。",
        unsupported: "這台 Mac 沒有藍牙控制器。"
    )

    static let zhHK = BluetoothSleepStrings(
        pageTitle: "藍牙行為",
        hubDescription: "Mac 睡眠期間關閉藍牙，袋裡的耳機不會再自動連上來。",
        enable: "Mac 進入睡眠時關閉藍牙",
        enableCaption: "Mac 睡眠時中斷耳機、鍵盤、滑鼠等藍牙裝置的連線。",
        restoreToggle: "Mac 喚醒時重新開啟藍牙",
        restoreCaption: "只恢復由 Lattice 在睡眠時關閉的藍牙。如果藍牙原本已關閉，就保持關閉。",
        unsupported: "這部 Mac 沒有藍牙控制器。"
    )
    static let uk = BluetoothSleepStrings(
        pageTitle: "Поведінка Bluetooth",
        hubDescription: "Вимикає Bluetooth, поки Mac спить, щоб навушники в сумці перестали з’єднуватися з ним.",
        enable: "Вимикати Bluetooth, коли Mac засинає",
        enableCaption: "Від’єднує пристрої Bluetooth, зокрема навушники, клавіатури й миші, поки Mac спить.",
        restoreToggle: "Ввімкнути Bluetooth назад, коли Mac прокидається",
        restoreCaption: "Вмикає Bluetooth, якщо Lattice вимкнув його під час сну. Якщо він був вимкнений заздалегідь, він залишиться вимкненим.",
        unsupported: "На цьому Mac немає Bluetooth-контролера."
    )
}
