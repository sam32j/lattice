import Foundation

/// Labels shared by the settings pages reorganized around the task at hand.
enum SettingsOrganizationStrings {
    enum Key: Int {
        case appearance, displayControls, modules, readings, activateCleaning, darkMode, cleaningShortcut
    }

    static func text(_ key: Key, _ language: AppLanguage) -> String {
        let labels: [String]
        switch language {
        case .enUS:
            labels = ["Appearance", "Display Controls", "Modules", "Readings", "Activate Cleaning Mode", "Dark Mode", "Activate cleaning mode with shortcut"]
        case .ptBR:
            labels = ["Aparência", "Controles de tela", "Módulos", "Leituras", "Ativar modo de limpeza", "Modo escuro", "Ativar modo de limpeza com atalho"]
        case .es:
            labels = ["Apariencia", "Controles de pantalla", "Módulos", "Lecturas", "Activar modo de limpieza", "Modo oscuro", "Activar modo de limpieza con atajo"]
        case .de:
            labels = ["Erscheinungsbild", "Bildschirmsteuerung", "Module", "Messwerte", "Reinigungsmodus aktivieren", "Dunkelmodus", "Reinigungsmodus mit Tastenkombination aktivieren"]
        case .fr:
            labels = ["Apparence", "Commandes d’écran", "Modules", "Mesures", "Activer le mode nettoyage", "Mode sombre", "Activer le mode nettoyage avec un raccourci"]
        case .it:
            labels = ["Aspetto", "Controlli schermo", "Moduli", "Misurazioni", "Attiva modalità pulizia", "Modalità scura", "Attiva modalità pulizia con abbreviazione"]
        case .sk:
            labels = ["Vzhľad", "Ovládanie displeja", "Moduly", "Hodnoty", "Aktivovať režim čistenia", "Tmavý režim", "Aktivovať režim čistenia skratkou"]
        case .tr:
            labels = ["Görünüm", "Ekran denetimleri", "Modüller", "Ölçümler", "Temizleme modunu etkinleştir", "Koyu mod", "Temizleme modunu kısayolla etkinleştir"]
        case .ru:
            labels = ["Оформление", "Управление дисплеями", "Модули", "Показатели", "Включить режим очистки", "Тёмный режим", "Включать режим очистки сочетанием клавиш"]
        case .uk:
            labels = ["Вигляд", "Керування дисплеями", "Модулі", "Показники", "Увімкнути режим очищення", "Темний режим", "Умикати режим очищення комбінацією клавіш"]
        case .ja:
            labels = ["外観", "ディスプレイの操作", "モジュール", "測定値", "クリーニングモードを開始", "ダークモード", "ショートカットでクリーニングモードを開始"]
        case .ko:
            labels = ["모양", "디스플레이 제어", "모듈", "측정값", "청소 모드 활성화", "다크 모드", "단축키로 청소 모드 활성화"]
        case .zhHans:
            labels = ["外观", "显示器控制", "模块", "读数", "启用清洁模式", "深色模式", "使用快捷键启用清洁模式"]
        case .zhTW:
            labels = ["外觀", "顯示器控制", "模組", "讀數", "啟用清潔模式", "深色模式", "使用快捷鍵啟用清潔模式"]
        case .zhHK:
            labels = ["外觀", "顯示器控制", "模組", "讀數", "啟用清潔模式", "深色模式", "使用快捷鍵啟用清潔模式"]
        }
        return labels[key.rawValue]
    }
}
