// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

enum SettingsOwnershipStrings {
    static func enable(_ name: String, _ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Enable \(name)"
        case .ptBR: return "Ativar \(name)"
        case .tr: return "\(name) özelliğini etkinleştir"
        case .ru: return "Включить \(name)"
        case .es: return "Activar \(name)"
        case .sk: return "Zapnúť \(name)"
        case .de: return "\(name) aktivieren"
        case .fr: return "Activer \(name)"
        case .it: return "Abilita \(name)"
        case .ja: return "\(name)を有効にする"
        case .ko: return "\(name) 활성화"
        case .zhHans: return "启用\(name)"
        case .zhTW, .zhHK: return "啟用\(name)"
        case .uk: return "Увімкнути \(name)"
        }
    }

    enum Key: Int { case utilities, fileCache, dmgInstaller, showIsland, clipboardCaption, cacheCaption,
                         compact, regular, appMenu, none, noMenuTarget, displayStyle,
                         shortcutTarget, shortcutTargetCaption, dynamicIsland, floatingWindow }

    static func text(_ key: Key, _ language: AppLanguage) -> String {
        let values: [String]
        switch language {
        case .enUS: values = ["Utilities", "File Cache", "DMG Installer", "Show on Dynamic Island",
            "Stores clipboard history. Everything stays local.", "Drag and drop files for quick access.",
            "Compact", "Regular", "Show App menu in…", "Don’t show",
            "Unhide menu bar or enable dynamic island to show app menu.", "Display style",
            "Shortcut opens Hub in", "Clicking Hub in the menu bar or Dynamic Island opens it right there. This setting applies only to the keyboard shortcut.", "Dynamic Island", "Floating Window"]
        case .ptBR: values = ["Utilitários", "Cache de arquivos", "Instalador de DMG", "Mostrar na Dynamic Island",
            "Salva o histórico da área de transferência. Tudo fica local.", "Arraste e solte arquivos para acesso rápido.",
            "Compacto", "Normal", "Mostrar menu do app em…", "Não mostrar", "Mostre o ícone na barra de menus ou ative a Dynamic Island para ver o menu do app.", "Estilo de exibição",
            "Atalho abre o Hub em", "Clicar no Hub na barra de menus ou na Dynamic Island o abre ali mesmo. Essa configuração se aplica apenas ao atalho de teclado.", "Dynamic Island", "Janela flutuante"]
        case .tr: values = ["Araçlar", "Dosya önbelleği", "DMG Yükleyici", "Dynamic Island’da göster",
            "Pano geçmişini saklar. Her şey yerel kalır.", "Hızlı erişim için dosyaları sürükleyip bırakın.",
            "Kompakt", "Normal", "Uygulama menüsünün konumu…", "Gösterme", "Uygulama menüsü için menü çubuğu simgesini gösterin veya Dynamic Island’ı açın.", "Görünüm stili",
            "Kısayol Hub’ı şurada açar", "Menü çubuğunda veya Dynamic Island’da Hub’a tıklamak onu orada açar. Bu ayar yalnızca klavye kısayolu için geçerlidir.", "Dynamic Island", "Kayan pencere"]
        case .ru: values = ["Утилиты", "Кэш файлов", "Установщик DMG", "Показывать в Dynamic Island",
            "Сохраняет историю буфера обмена. Всё остаётся на Mac.", "Перетаскивайте файлы для быстрого доступа.",
            "Компактный", "Обычный", "Показывать меню приложения в…", "Не показывать", "Покажите значок в строке меню или включите Dynamic Island, чтобы видеть меню приложения.", "Стиль отображения",
            "Сочетание клавиш открывает Hub в", "Нажатие на Hub в строке меню или в Dynamic Island открывает его там же. Эта настройка применяется только к сочетанию клавиш.", "Dynamic Island", "Плавающее окно"]
        case .es: values = ["Utilidades", "Caché de archivos", "Instalador de DMG", "Mostrar en Dynamic Island",
            "Guarda el historial del portapapeles. Todo permanece local.", "Arrastra y suelta archivos para acceder rápidamente.",
            "Compacto", "Normal", "Mostrar menú de la app en…", "No mostrar", "Muestra el icono en la barra de menús o activa Dynamic Island para ver el menú de la app.", "Estilo de visualización",
            "El atajo abre Hub en", "Hacer clic en Hub en la barra de menús o Dynamic Island lo abre en ese lugar. Este ajuste solo se aplica al atajo de teclado.", "Dynamic Island", "Ventana flotante"]
        case .sk: values = ["Nástroje", "Vyrovnávacia pamäť súborov", "Inštalátor DMG", "Zobraziť v Dynamic Island",
            "Ukladá históriu schránky. Všetko zostáva lokálne.", "Presuňte súbory pre rýchly prístup.",
            "Kompaktné", "Bežné", "Zobraziť menu aplikácie v…", "Nezobrazovať", "Zobrazte ikonu v lište alebo zapnite Dynamic Island pre menu aplikácie.", "Štýl zobrazenia",
            "Skratka otvorí Hub v", "Kliknutie na Hub v lište alebo Dynamic Island ho otvorí priamo tam. Toto nastavenie platí iba pre klávesovú skratku.", "Dynamic Island", "Plávajúce okno"]
        case .de: values = ["Dienstprogramme", "Dateicache", "DMG-Installer", "In Dynamic Island anzeigen",
            "Speichert den Zwischenablageverlauf. Alles bleibt lokal.", "Dateien für schnellen Zugriff hierher ziehen.",
            "Kompakt", "Normal", "App-Menü anzeigen in…", "Nicht anzeigen", "Blende das Menüleistensymbol ein oder aktiviere Dynamic Island, um das App-Menü anzuzeigen.", "Darstellungsstil",
            "Kurzbefehl öffnet Hub in", "Ein Klick auf Hub in der Menüleiste oder Dynamic Island öffnet es direkt dort. Diese Einstellung gilt nur für den Kurzbefehl.", "Dynamic Island", "Schwebendes Fenster"]
        case .fr: values = ["Utilitaires", "Cache de fichiers", "Installateur DMG", "Afficher dans Dynamic Island",
            "Conserve l’historique du presse-papiers. Tout reste local.", "Glissez-déposez des fichiers pour un accès rapide.",
            "Compact", "Normal", "Afficher le menu de l’app dans…", "Ne pas afficher", "Affichez l’icône de la barre des menus ou activez Dynamic Island pour voir le menu de l’app.", "Style d’affichage",
            "Le raccourci ouvre Hub dans", "Cliquer sur Hub dans la barre des menus ou Dynamic Island l’ouvre directement là. Ce réglage s’applique uniquement au raccourci clavier.", "Dynamic Island", "Fenêtre flottante"]
        case .it: values = ["Utilità", "Cache file", "Installer DMG", "Mostra in Dynamic Island",
            "Salva la cronologia degli appunti. Tutto rimane locale.", "Trascina i file per accedervi rapidamente.",
            "Compatto", "Normale", "Mostra il menu dell’app in…", "Non mostrare", "Mostra l’icona nella barra dei menu o attiva Dynamic Island per vedere il menu dell’app.", "Stile di visualizzazione",
            "La scorciatoia apre Hub in", "Facendo clic su Hub nella barra dei menu o in Dynamic Island lo apre direttamente lì. Questa impostazione si applica solo alla scorciatoia da tastiera.", "Dynamic Island", "Finestra mobile"]
        case .ja: values = ["ユーティリティ", "ファイルキャッシュ", "DMGインストーラ", "Dynamic Islandに表示",
            "クリップボードの履歴を保存します。すべてローカルに保存されます。", "ファイルをドラッグ＆ドロップしてすばやくアクセスできます。",
            "コンパクト", "標準", "アプリメニューの表示先…", "表示しない", "アプリメニューを表示するには、メニューバーのアイコンを表示するかDynamic Islandを有効にしてください。", "表示スタイル",
            "ショートカットのHub表示先", "メニューバーやDynamic IslandでHubをクリックするとその場で開きます。この設定はキーボードショートカットにのみ適用されます。", "Dynamic Island", "フローティングウインドウ"]
        case .ko: values = ["유틸리티", "파일 캐시", "DMG 설치 프로그램", "Dynamic Island에 표시",
            "클립보드 기록을 저장합니다. 모든 내용은 로컬에 보관됩니다.", "파일을 드래그 앤 드롭하여 빠르게 접근하세요.",
            "간결하게", "보통", "앱 메뉴 표시 위치…", "표시 안 함", "앱 메뉴를 보려면 메뉴 막대 아이콘을 표시하거나 Dynamic Island를 켜세요.", "표시 스타일",
            "단축키로 Hub 열기 위치", "메뉴 막대나 Dynamic Island에서 Hub를 클릭하면 그 위치에서 바로 열립니다. 이 설정은 키보드 단축키에만 적용됩니다.", "Dynamic Island", "플로팅 윈도우"]
        case .zhHans: values = ["实用工具", "文件缓存", "DMG 安装器", "在灵动岛上显示",
            "保存剪贴板历史记录。所有内容都保存在本地。", "拖放文件以便快速访问。", "紧凑", "常规", "应用菜单显示位置…", "不显示", "请显示菜单栏图标或启用灵动岛，以显示应用菜单。", "显示样式",
            "快捷键打开 Hub 于", "在菜单栏或灵动岛中点按 Hub 会直接在对应位置打开。此设置仅适用于键盘快捷键。", "灵动岛", "浮动窗口"]
        case .zhTW: values = ["工具程式", "檔案快取", "DMG 安裝程式", "在動態島上顯示",
            "儲存剪貼簿歷史記錄。所有內容皆保留於本機。", "拖放檔案以便快速存取。", "精簡", "一般", "應用程式選單顯示位置…", "不顯示", "請顯示選單列圖示或啟用動態島，以顯示應用程式選單。", "顯示樣式",
            "快速鍵開啟 Hub 於", "在選單列或動態島中點按 Hub 會直接在相應位置開啟。此設定僅適用於鍵盤快速鍵。", "動態島", "浮動視窗"]
        case .zhHK: values = ["工具程式", "檔案快取", "DMG 安裝程式", "在動態島顯示",
            "儲存剪貼簿記錄。所有內容都保留在本機。", "拖放檔案以便快速存取。", "精簡", "一般", "應用程式選單顯示位置…", "不顯示", "請顯示選單列圖示或啟用動態島，以顯示應用程式選單。", "顯示樣式",
            "快速鍵開啟 Hub 於", "在選單列或動態島點按 Hub 會直接在相應位置開啟。此設定僅適用於鍵盤快速鍵。", "動態島", "浮動視窗"]
        case .uk: values = ["Утиліти", "Кеш файлів", "Інсталятор DMG", "Показувати в Dynamic Island",
            "Зберігає історію буфера обміну. Усе залишається локально.", "Перетягуйте файли для швидкого доступу.",
            "Компактний", "Звичайний", "Показувати меню програми в…", "Не показувати", "Покажіть значок у смузі меню або ввімкніть Dynamic Island, щоб бачити меню програми.", "Стиль відображення",
            "Комбінація клавіш відкриває Hub у", "Натискання на Hub у смузі меню або Dynamic Island відкриває його прямо там. Цей параметр застосовується лише до комбінації клавіш.", "Dynamic Island", "Рухоме вікно"]
        }
        return values[key.rawValue]
    }
}
