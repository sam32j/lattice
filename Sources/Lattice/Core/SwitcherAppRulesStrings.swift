// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct SwitcherSettingsCopy {
    let switchAppsShortcut: String
    let switchWindowsShortcut: String
    let delayInstant: String
    let layoutWindowsCaption: String
    let layoutIconsCaption: String
    let layoutSimpleCaption: String

    static func text(_ language: AppLanguage) -> Self {
        switch language {
        case .enUS:
            return Self(
                switchAppsShortcut: "Switch apps",
                switchWindowsShortcut: "Switch app windows",
                delayInstant: "Instant",
                layoutWindowsCaption: "Live thumbnails for every open window.",
                layoutIconsCaption: "App icons with window previews below.",
                layoutSimpleCaption: "App icons only, like ⌘Tab."
            )
        case .ptBR:
            return Self(
                switchAppsShortcut: "Alternar apps",
                switchWindowsShortcut: "Alternar janelas do app",
                delayInstant: "Instantâneo",
                layoutWindowsCaption: "Miniaturas ao vivo para cada janela aberta.",
                layoutIconsCaption: "Ícones dos apps com prévias das janelas abaixo.",
                layoutSimpleCaption: "Apenas ícones dos apps, como no ⌘Tab."
            )
        case .tr:
            return Self(
                switchAppsShortcut: "Uygulamalar arasında geçiş yap",
                switchWindowsShortcut: "Uygulama pencereleri arasında geçiş yap",
                delayInstant: "Anında",
                layoutWindowsCaption: "Açık her pencere için canlı önizleme.",
                layoutIconsCaption: "Altında pencere önizlemeleriyle uygulama simgeleri.",
                layoutSimpleCaption: "⌘Tab gibi yalnızca uygulama simgeleri."
            )
        case .ru:
            return Self(
                switchAppsShortcut: "Переключить приложения",
                switchWindowsShortcut: "Переключить окна приложения",
                delayInstant: "Мгновенно",
                layoutWindowsCaption: "Живые миниатюры для каждого открытого окна.",
                layoutIconsCaption: "Значки приложений с миниатюрами окон под ними.",
                layoutSimpleCaption: "Только значки приложений, как в ⌘Tab."
            )
        case .es:
            return Self(
                switchAppsShortcut: "Cambiar de app",
                switchWindowsShortcut: "Cambiar ventanas de la app",
                delayInstant: "Instantáneo",
                layoutWindowsCaption: "Miniaturas en vivo de cada ventana abierta.",
                layoutIconsCaption: "Iconos de apps con vistas previas debajo.",
                layoutSimpleCaption: "Solo iconos de apps, como ⌘Tab."
            )
        case .sk:
            return Self(
                switchAppsShortcut: "Prepnúť aplikácie",
                switchWindowsShortcut: "Prepnúť okná aplikácie",
                delayInstant: "Okamžite",
                layoutWindowsCaption: "Živé náhľady pre každé otvorené okno.",
                layoutIconsCaption: "Ikony aplikácií s náhľadmi okien pod nimi.",
                layoutSimpleCaption: "Iba ikony aplikácií, ako pri ⌘Tab."
            )
        case .de:
            return Self(
                switchAppsShortcut: "Apps wechseln",
                switchWindowsShortcut: "App-Fenster wechseln",
                delayInstant: "Sofort",
                layoutWindowsCaption: "Live-Vorschauen für jedes geöffnete Fenster.",
                layoutIconsCaption: "App-Symbole mit Fenstervorschauen darunter.",
                layoutSimpleCaption: "Nur App-Symbole, wie bei ⌘Tab."
            )
        case .fr:
            return Self(
                switchAppsShortcut: "Changer d’app",
                switchWindowsShortcut: "Changer de fenêtre d’app",
                delayInstant: "Instantané",
                layoutWindowsCaption: "Aperçus en direct pour chaque fenêtre ouverte.",
                layoutIconsCaption: "Icônes d’apps avec aperçus des fenêtres en dessous.",
                layoutSimpleCaption: "Icônes d’apps uniquement, comme ⌘Tab."
            )
        case .it:
            return Self(
                switchAppsShortcut: "Cambia app",
                switchWindowsShortcut: "Cambia finestre dell’app",
                delayInstant: "Istantaneo",
                layoutWindowsCaption: "Anteprime dal vivo per ogni finestra aperta.",
                layoutIconsCaption: "Icone delle app con anteprime delle finestre sotto.",
                layoutSimpleCaption: "Solo icone delle app, come ⌘Tab."
            )
        case .ja:
            return Self(
                switchAppsShortcut: "アプリを切り替え",
                switchWindowsShortcut: "アプリのウインドウを切り替え",
                delayInstant: "なし",
                layoutWindowsCaption: "開いているすべてのウインドウをプレビュー表示。",
                layoutIconsCaption: "アプリアイコンの下にウインドウプレビューを表示。",
                layoutSimpleCaption: "⌘Tabと同じく、アプリアイコンのみを表示。"
            )
        case .ko:
            return Self(
                switchAppsShortcut: "앱 전환",
                switchWindowsShortcut: "앱 윈도우 전환",
                delayInstant: "즉시",
                layoutWindowsCaption: "열려 있는 모든 윈도우의 실시간 미리보기.",
                layoutIconsCaption: "앱 아이콘 아래에 윈도우 미리보기 표시.",
                layoutSimpleCaption: "⌘Tab처럼 앱 아이콘만 표시."
            )
        case .zhHans:
            return Self(
                switchAppsShortcut: "切换 App",
                switchWindowsShortcut: "切换当前 App 窗口",
                delayInstant: "立即",
                layoutWindowsCaption: "显示每个打开窗口的实时缩略图。",
                layoutIconsCaption: "显示 App 图标，并在下方展示其窗口预览。",
                layoutSimpleCaption: "仅显示 App 图标，与 ⌘Tab 相同。"
            )
        case .zhTW:
            return Self(
                switchAppsShortcut: "切換 App",
                switchWindowsShortcut: "切換目前 App 視窗",
                delayInstant: "立即",
                layoutWindowsCaption: "顯示每個開啟視窗的即時縮圖。",
                layoutIconsCaption: "顯示 App 圖示，並在下方展示視窗預覽。",
                layoutSimpleCaption: "僅顯示 App 圖示，與 ⌘Tab 相同。"
            )
        case .zhHK:
            return Self(
                switchAppsShortcut: "切換 App",
                switchWindowsShortcut: "切換目前 App 視窗",
                delayInstant: "即時",
                layoutWindowsCaption: "顯示每個開啟視窗的即時縮圖。",
                layoutIconsCaption: "顯示 App 圖示，並在下方展示視窗預覽。",
                layoutSimpleCaption: "只顯示 App 圖示，與 ⌘Tab 一樣。"
            )
        case .uk:
            return Self(
                switchAppsShortcut: "Перемкнути програми",
                switchWindowsShortcut: "Перемкнути вікна програми",
                delayInstant: "Миттєво",
                layoutWindowsCaption: "Живі мініатюри для кожного відкритого вікна.",
                layoutIconsCaption: "Значки програм із мініатюрами вікон під ними.",
                layoutSimpleCaption: "Лише значки програм, як у ⌘Tab."
            )
        }
    }
}

struct SwitcherAppRulesStrings {
    let listTitle: String
    let addButton: String
    let removeButton: String
    let caption: String
}

extension FeatureStrings {
    static func switcherAppRules(_ language: AppLanguage) -> SwitcherAppRulesStrings {
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

extension SwitcherAppRulesStrings {
    static let enUS = SwitcherAppRulesStrings(
        listTitle: "Hide in switcher",
        addButton: "Add an app…",
        removeButton: "Remove",
        caption: "Apps in this list never appear in the switcher."
    )

    static let ptBR = SwitcherAppRulesStrings(
        listTitle: "Ocultar no alternador",
        addButton: "Adicionar app…",
        removeButton: "Remover",
        caption: "Os apps desta lista nunca aparecem no alternador."
    )

    static let tr = SwitcherAppRulesStrings(
        listTitle: "Değiştiricide gizle",
        addButton: "Uygulama ekle…",
        removeButton: "Kaldır",
        caption: "Bu listedeki uygulamalar değiştiricide hiç görünmez."
    )

    static let ru = SwitcherAppRulesStrings(
        listTitle: "Скрывать в переключателе",
        addButton: "Добавить приложение…",
        removeButton: "Удалить",
        caption: "Приложения из этого списка никогда не появляются в переключателе."
    )

    static let es = SwitcherAppRulesStrings(
        listTitle: "Ocultar en el selector",
        addButton: "Añadir app…",
        removeButton: "Quitar",
        caption: "Las apps de esta lista nunca aparecen en el selector."
    )

    static let sk = SwitcherAppRulesStrings(
        listTitle: "Skryť v prepínači",
        addButton: "Pridať aplikáciu…",
        removeButton: "Odstrániť",
        caption: "Aplikácie z tohto zoznamu sa v prepínači nikdy nezobrazia."
    )

    static let de = SwitcherAppRulesStrings(
        listTitle: "Im Umschalter ausblenden",
        addButton: "App hinzufügen…",
        removeButton: "Entfernen",
        caption: "Apps in dieser Liste erscheinen nie im Umschalter."
    )

    static let fr = SwitcherAppRulesStrings(
        listTitle: "Masquer dans le sélecteur",
        addButton: "Ajouter une app…",
        removeButton: "Retirer",
        caption: "Les apps de cette liste n’apparaissent jamais dans le sélecteur."
    )

    static let it = SwitcherAppRulesStrings(
        listTitle: "Nascondi nel selettore",
        addButton: "Aggiungi app…",
        removeButton: "Rimuovi",
        caption: "Le app in questo elenco non compaiono mai nel selettore."
    )

    static let ja = SwitcherAppRulesStrings(
        listTitle: "スイッチャーで非表示",
        addButton: "Appを追加…",
        removeButton: "削除",
        caption: "このリストのAppはスイッチャーに表示されません。"
    )

    static let ko = SwitcherAppRulesStrings(
        listTitle: "전환기에서 가리기",
        addButton: "앱 추가…",
        removeButton: "제거",
        caption: "이 목록의 앱은 전환기에 표시되지 않습니다."
    )

    static let zhHans = SwitcherAppRulesStrings(
        listTitle: "在切换器中隐藏",
        addButton: "添加 App…",
        removeButton: "移除",
        caption: "此列表中的 App 不会出现在切换器中。"
    )

    static let zhTW = SwitcherAppRulesStrings(
        listTitle: "在切換器中隱藏",
        addButton: "加入 App…",
        removeButton: "移除",
        caption: "此列表中的 App 不會出現在切換器中。"
    )

    static let zhHK = SwitcherAppRulesStrings(
        listTitle: "在切換器中隱藏",
        addButton: "加入 App…",
        removeButton: "移除",
        caption: "此列表中的 App 不會在切換器中出現。"
    )

    static let uk = SwitcherAppRulesStrings(
        listTitle: "Приховувати в перемикачі",
        addButton: "Додати програму…",
        removeButton: "Видалити",
        caption: "Програми з цього списку ніколи не з’являються в перемикачі."
    )
}
