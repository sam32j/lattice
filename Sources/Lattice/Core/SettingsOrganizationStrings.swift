import Foundation

/// Labels shared by the settings pages reorganized around the task at hand.
enum SettingsOrganizationStrings {
    enum Key: Int {
        case appearance, displayControls, modules, readings, activateCleaning, darkMode, cleaningShortcut, keyboardCleaningMode, keyboardInput, quitBehavior, closeBehavior, quitCaption, closeCaption
    }

    static func text(_ key: Key, _ language: AppLanguage) -> String {
        let labels: [String]
        switch language {
        case .enUS:
            labels = ["Appearance", "Display Control", "Modules", "Readings", "Activate Cleaning Mode", "Dark Mode", "Activate cleaning mode with shortcut", "Keyboard Cleaning Mode", "Keyboard Input", "⌘Q key lock", "⌘W key lock", "Require confirmation before ⌘Q quitting an app", "Require confirmation before ⌘W closing a window"]
        case .ptBR:
            labels = ["Aparência", "Controles de tela", "Módulos", "Leituras", "Ativar modo de limpeza", "Modo escuro", "Ativar modo de limpeza com atalho", "Modo de limpeza do teclado", "Entrada do teclado", "Bloqueio da tecla ⌘Q", "Bloqueio da tecla ⌘W", "Exigir confirmação antes de encerrar um app com ⌘Q", "Exigir confirmação antes de fechar uma janela com ⌘W"]
        case .es:
            labels = ["Apariencia", "Controles de pantalla", "Módulos", "Lecturas", "Activar modo de limpieza", "Modo oscuro", "Activar modo de limpieza con atajo", "Modo de limpieza del teclado", "Entrada de teclado", "Bloqueo de tecla ⌘Q", "Bloqueo de tecla ⌘W", "Solicitar confirmación antes de salir de una app con ⌘Q", "Solicitar confirmación antes de cerrar una ventana con ⌘W"]
        case .de:
            labels = ["Erscheinungsbild", "Bildschirmsteuerung", "Module", "Messwerte", "Reinigungsmodus aktivieren", "Dunkelmodus", "Reinigungsmodus mit Tastenkombination aktivieren", "Tastatur-Reinigungsmodus", "Tastatureingabe", "⌘Q-Tastensperre", "⌘W-Tastensperre", "Bestätigung vor dem Beenden einer App mit ⌘Q verlangen", "Bestätigung vor dem Schließen eines Fensters mit ⌘W verlangen"]
        case .fr:
            labels = ["Apparence", "Commandes d’écran", "Modules", "Mesures", "Activer le mode nettoyage", "Mode sombre", "Activer le mode nettoyage avec un raccourci", "Mode nettoyage du clavier", "Entrée clavier", "Verrouillage de ⌘Q", "Verrouillage de ⌘W", "Demander une confirmation avant de quitter une app avec ⌘Q", "Demander une confirmation avant de fermer une fenêtre avec ⌘W"]
        case .it:
            labels = ["Aspetto", "Controlli schermo", "Moduli", "Misurazioni", "Attiva modalità pulizia", "Modalità scura", "Attiva modalità pulizia con abbreviazione", "Modalità pulizia tastiera", "Input da tastiera", "Blocco tasto ⌘Q", "Blocco tasto ⌘W", "Richiedi conferma prima di chiudere un’app con ⌘Q", "Richiedi conferma prima di chiudere una finestra con ⌘W"]
        case .sk:
            labels = ["Vzhľad", "Ovládanie displeja", "Moduly", "Hodnoty", "Aktivovať režim čistenia", "Tmavý režim", "Aktivovať režim čistenia skratkou", "Režim čistenia klávesnice", "Vstup z klávesnice", "Zámok klávesu ⌘Q", "Zámok klávesu ⌘W", "Vyžadovať potvrdenie pred ukončením aplikácie cez ⌘Q", "Vyžadovať potvrdenie pred zatvorením okna cez ⌘W"]
        case .tr:
            labels = ["Görünüm", "Ekran denetimleri", "Modüller", "Ölçümler", "Temizleme modunu etkinleştir", "Koyu mod", "Temizleme modunu kısayolla etkinleştir", "Klavye Temizleme Modu", "Klavye Girişi", "⌘Q tuş kilidi", "⌘W tuş kilidi", "⌘Q ile bir uygulamadan çıkmadan önce onay iste", "⌘W ile bir pencereyi kapatmadan önce onay iste"]
        case .ru:
            labels = ["Оформление", "Управление дисплеями", "Модули", "Показатели", "Включить режим очистки", "Тёмный режим", "Включать режим очистки сочетанием клавиш", "Режим очистки клавиатуры", "Ввод с клавиатуры", "Блокировка ⌘Q", "Блокировка ⌘W", "Требовать подтверждение перед выходом из приложения по ⌘Q", "Требовать подтверждение перед закрытием окна по ⌘W"]
        case .uk:
            labels = ["Вигляд", "Керування дисплеями", "Модулі", "Показники", "Увімкнути режим очищення", "Темний режим", "Умикати режим очищення комбінацією клавіш", "Режим очищення клавіатури", "Введення з клавіатури", "Блокування ⌘Q", "Блокування ⌘W", "Вимагати підтвердження перед виходом із програми за допомогою ⌘Q", "Вимагати підтвердження перед закриттям вікна за допомогою ⌘W"]
        case .ja:
            labels = ["外観", "ディスプレイの操作", "モジュール", "測定値", "クリーニングモードを開始", "ダークモード", "ショートカットでクリーニングモードを開始", "キーボードクリーニングモード", "キーボード入力", "⌘Q キーロック", "⌘W キーロック", "⌘Q でアプリを終了する前に確認を求める", "⌘W でウインドウを閉じる前に確認を求める"]
        case .ko:
            labels = ["모양", "디스플레이 제어", "모듈", "측정값", "청소 모드 활성화", "다크 모드", "단축키로 청소 모드 활성화", "키보드 청소 모드", "키보드 입력", "⌘Q 키 잠금", "⌘W 키 잠금", "⌘Q로 앱을 종료하기 전에 확인 요청", "⌘W로 윈도우를 닫기 전에 확인 요청"]
        case .zhHans:
            labels = ["外观", "显示器控制", "模块", "读数", "启用清洁模式", "深色模式", "使用快捷键启用清洁模式", "键盘清洁模式", "键盘输入", "⌘Q 按键锁定", "⌘W 按键锁定", "使用 ⌘Q 退出应用前需要确认", "使用 ⌘W 关闭窗口前需要确认"]
        case .zhTW:
            labels = ["外觀", "顯示器控制", "模組", "讀數", "啟用清潔模式", "深色模式", "使用快捷鍵啟用清潔模式", "鍵盤清潔模式", "鍵盤輸入", "⌘Q 按鍵鎖定", "⌘W 按鍵鎖定", "使用 ⌘Q 結束應用程式前需要確認", "使用 ⌘W 關閉視窗前需要確認"]
        case .zhHK:
            labels = ["外觀", "顯示器控制", "模組", "讀數", "啟用清潔模式", "深色模式", "使用快捷鍵啟用清潔模式", "鍵盤清潔模式", "鍵盤輸入", "⌘Q 按鍵鎖定", "⌘W 按鍵鎖定", "使用 ⌘Q 結束應用程式前需要確認", "使用 ⌘W 關閉視窗前需要確認"]
        }
        return labels[key.rawValue]
    }
}
