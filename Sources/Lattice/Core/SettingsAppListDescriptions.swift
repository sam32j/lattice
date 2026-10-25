// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
import Foundation

struct SettingsAppListDescriptions {
    let maximizeWindows: String
    let autoQuit: String
    let dockPreview: String

    static func text(_ language: AppLanguage) -> Self {
        switch language {
        case .enUS: return Self(maximizeWindows: "Apps in this list will still open in a full-screen space.",
            autoQuit: "Apps in this list will not auto quit.",
            dockPreview: "Apps in this list will not show dock preview")
        case .ptBR: return Self(maximizeWindows: "Os apps desta lista ainda abrirão em um Espaço de tela cheia.",
            autoQuit: "Os apps desta lista não serão encerrados automaticamente.",
            dockPreview: "Os apps desta lista não mostrarão prévias no Dock.")
        case .tr: return Self(maximizeWindows: "Bu listedeki uygulamalar tam ekran bir Masaüstünde açılmaya devam eder.",
            autoQuit: "Bu listedeki uygulamalar otomatik olarak kapatılmaz.",
            dockPreview: "Bu listedeki uygulamalar için Dock önizlemesi gösterilmez.")
        case .ru: return Self(maximizeWindows: "Приложения из этого списка по-прежнему открываются на полноэкранном рабочем столе.",
            autoQuit: "Приложения из этого списка не завершаются автоматически.",
            dockPreview: "Для приложений из этого списка не отображается предпросмотр в Dock.")
        case .es: return Self(maximizeWindows: "Las apps de esta lista seguirán abriéndose en un espacio de pantalla completa.",
            autoQuit: "Las apps de esta lista no se cerrarán automáticamente.",
            dockPreview: "Las apps de esta lista no mostrarán vistas previas en el Dock.")
        case .sk: return Self(maximizeWindows: "Aplikácie v tomto zozname sa budú naďalej otvárať na ploche na celú obrazovku.",
            autoQuit: "Aplikácie v tomto zozname sa nebudú automaticky ukončovať.",
            dockPreview: "Aplikácie v tomto zozname nebudú zobrazovať náhľady v Docku.")
        case .de: return Self(maximizeWindows: "Apps in dieser Liste werden weiterhin in einem Vollbild-Space geöffnet.",
            autoQuit: "Apps in dieser Liste werden nicht automatisch beendet.",
            dockPreview: "Für Apps in dieser Liste werden keine Dock-Vorschauen angezeigt.")
        case .fr: return Self(maximizeWindows: "Les apps de cette liste continueront à s’ouvrir dans un espace plein écran.",
            autoQuit: "Les apps de cette liste ne quitteront pas automatiquement.",
            dockPreview: "Les apps de cette liste n’afficheront pas d’aperçu dans le Dock.")
        case .it: return Self(maximizeWindows: "Le app in questo elenco continueranno ad aprirsi in uno spazio a schermo intero.",
            autoQuit: "Le app in questo elenco non verranno chiuse automaticamente.",
            dockPreview: "Le app in questo elenco non mostreranno anteprime nel Dock.")
        case .ja: return Self(maximizeWindows: "このリストのアプリは引き続きフルスクリーンの操作スペースで開きます。",
            autoQuit: "このリストのアプリは自動終了しません。",
            dockPreview: "このリストのアプリのDockプレビューは表示されません。")
        case .ko: return Self(maximizeWindows: "이 목록의 앱은 계속 전체 화면 Spaces에서 열립니다.",
            autoQuit: "이 목록의 앱은 자동으로 종료되지 않습니다.",
            dockPreview: "이 목록의 앱은 Dock 미리보기를 표시하지 않습니다.")
        case .uk: return Self(maximizeWindows: "Програми з цього списку й надалі відкриватимуться в повноекранному просторі.",
            autoQuit: "Програми з цього списку не завершуватимуться автоматично.",
            dockPreview: "Для програм із цього списку не відображатиметься перегляд у Dock.")
        case .zhHans: return Self(maximizeWindows: "此列表中的 App 仍会在全屏空间中打开。",
            autoQuit: "此列表中的 App 不会自动退出。",
            dockPreview: "此列表中的 App 不会显示程序坞预览。")
        case .zhTW: return Self(maximizeWindows: "此列表中的 App 仍會在全螢幕空間中開啟。",
            autoQuit: "此列表中的 App 不會自動結束。",
            dockPreview: "此列表中的 App 不會顯示 Dock 預覽。")
        case .zhHK: return Self(maximizeWindows: "此列表中的 App 仍會在全螢幕空間中開啟。",
            autoQuit: "此列表中的 App 不會自動結束。",
            dockPreview: "此列表中的 App 不會顯示 Dock 預覽。")
        }
    }
}
