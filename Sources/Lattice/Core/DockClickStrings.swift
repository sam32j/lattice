// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

struct DockClickStrings {
    let title: String
    let body: String
    let off: String
    let toggleWindows: String
    let hideApps: String
    let cycleWindows: String
}

enum DockClickCopy {
    static func strings(_ language: AppLanguage) -> DockClickStrings {
        switch language {
        case .enUS:
            return DockClickStrings(
                title: "Dock Tile",
                body: "Click Dock tile to perform an action.",
                off: "Off",
                toggleWindows: "Toggle Windows",
                hideApps: "Hide/Show Apps",
                cycleWindows: "Cycle Windows"
            )
        case .zhHans:
            return DockClickStrings(
                title: "程序坞图标",
                body: "点按程序坞图标以执行",
                off: "关闭",
                toggleWindows: "最小化/恢复窗口",
                hideApps: "隐藏/关闭应用",
                cycleWindows: "切换"
            )
        case .zhTW:
            return DockClickStrings(
                title: "Dock 圖示",
                body: "點按 Dock 圖示以執行",
                off: "關閉",
                toggleWindows: "最小化/回復視窗",
                hideApps: "隱藏/關閉 App",
                cycleWindows: "切換"
            )
        case .zhHK:
            return DockClickStrings(
                title: "Dock 圖示",
                body: "點按 Dock 圖示以執行",
                off: "關閉",
                toggleWindows: "最小化/回復視窗",
                hideApps: "隱藏/關閉 App",
                cycleWindows: "切換"
            )
        case .ja:
            return DockClickStrings(
                title: "Dockアイコン",
                body: "Dockアイコンをクリックしてアクションを実行",
                off: "オフ",
                toggleWindows: "ウインドウを最小化/復元",
                hideApps: "アプリを非表示/終了",
                cycleWindows: "切り替え"
            )
        case .ko:
            return DockClickStrings(
                title: "Dock 아이콘",
                body: "동작을 실행하려면 Dock 아이콘을 클릭하세요",
                off: "꺼짐",
                toggleWindows: "윈도우 최소화/복원",
                hideApps: "앱 숨기기/종료",
                cycleWindows: "전환"
            )
        case .de:
            return DockClickStrings(
                title: "Dock-Symbole",
                body: "Auf ein Dock-Symbol klicken, um eine Aktion auszuführen",
                off: "Aus",
                toggleWindows: "Fenster minimieren/wiederherstellen",
                hideApps: "Apps ausblenden/beenden",
                cycleWindows: "Wechseln"
            )
        case .fr:
            return DockClickStrings(
                title: "Icônes du Dock",
                body: "Cliquez sur une icône du Dock pour exécuter une action",
                off: "Désactivé",
                toggleWindows: "Réduire/restaurer les fenêtres",
                hideApps: "Masquer/quitter les apps",
                cycleWindows: "Basculer"
            )
        case .es:
            return DockClickStrings(
                title: "Iconos del Dock",
                body: "Haz clic en un icono del Dock para realizar una acción",
                off: "Desactivado",
                toggleWindows: "Minimizar/restaurar ventanas",
                hideApps: "Ocultar/cerrar apps",
                cycleWindows: "Alternar"
            )
        case .ptBR:
            return DockClickStrings(
                title: "Ícones do Dock",
                body: "Clique em um ícone do Dock para executar uma ação",
                off: "Desativado",
                toggleWindows: "Minimizar/restaurar janelas",
                hideApps: "Ocultar/encerrar apps",
                cycleWindows: "Alternar"
            )
        case .it:
            return DockClickStrings(
                title: "Icone del Dock",
                body: "Fai clic su un’icona del Dock per eseguire un’azione",
                off: "Disattivato",
                toggleWindows: "Riduci a icona/ripristina finestre",
                hideApps: "Nascondi/chiudi app",
                cycleWindows: "Alterna"
            )
        case .ru:
            return DockClickStrings(
                title: "Значки Dock",
                body: "Нажмите на значок Dock для выполнения действия",
                off: "Выключено",
                toggleWindows: "Свернуть/развернуть окна",
                hideApps: "Скрыть/закрыть приложения",
                cycleWindows: "Переключение"
            )
        case .uk:
            return DockClickStrings(
                title: "Значки Dock",
                body: "Натисніть на значок Dock для виконання дії",
                off: "Вимкнено",
                toggleWindows: "Згорнути/відновити вікна",
                hideApps: "Приховати/закрити програми",
                cycleWindows: "Перемикання"
            )
        case .tr:
            return DockClickStrings(
                title: "Dock Simgeleri",
                body: "Bir eylem gerçekleştirmek için Dock simgesine tıklayın",
                off: "Kapalı",
                toggleWindows: "Pencereleri küçült/geri yükle",
                hideApps: "Uygulamaları gizle/kapat",
                cycleWindows: "Geçiş yap"
            )
        case .sk:
            return DockClickStrings(
                title: "Ikony Docku",
                body: "Kliknutím na ikonu Docku vykonáte akciu",
                off: "Vypnuté",
                toggleWindows: "Minimalizovať/obnoviť okná",
                hideApps: "Skryť/ukončiť apky",
                cycleWindows: "Prepnúť"
            )
        }
    }
}
