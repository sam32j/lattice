import Foundation

enum SettingsFollowupStrings {
    enum Key: Int {
        case showMenuIcon, accessoryBattery, bluetoothExplanation,
             preferOpensAt, openLatticeShortcut,
             latticeWillBeHiddenTitle, latticeWillBeHiddenMessage, hideLatticeButton,
             allTools
    }

    static func text(_ key: Key, _ language: AppLanguage) -> String {
        let values: [String]
        switch language {
        case .enUS: values = ["Show menu bar icon", "Accessory battery",
            "Read battery levels for Bluetooth accessories. Everything stays on your Mac.",
            "Prefer Lattice opens at", "Open Lattice with shortcut",
            "Lattice Will Be Hidden", "Lattice will keep running in the background. You can still access your tools using keyboard shortcuts.", "Hide Lattice", "All Tools"]
        case .ptBR: values = ["Mostrar o ícone na barra de menus", "Bateria dos acessórios",
            "Lê a bateria dos acessórios Bluetooth. Tudo fica no seu Mac.",
            "Preferência de abertura do Lattice em", "Abrir o Lattice com atalho",
            "O Lattice será ocultado", "O Lattice continuará sendo executado em segundo plano. Você ainda pode acessar suas ferramentas usando atalhos de teclado.", "Ocultar Lattice", "Todas as Ferramentas"]
        case .tr: values = ["Menü çubuğu simgesini göster", "Aksesuar pili",
            "Bluetooth aksesuarlarının pil düzeylerini okur. Her şey Mac’inizde kalır.",
            "Lattice’ı şurada açmayı tercih et", "Lattice’ı kısayolla aç",
            "Lattice Gizlenecek", "Lattice arka planda çalışmaya devam edecek. Araçlarınıza klavye kısayollarını kullanarak erişmeye devam edebilirsiniz.", "Lattice’ı Gizle", "Tüm Araçlar"]
        case .ru: values = ["Показывать значок в строке меню", "Батарея аксессуаров",
            "Читает уровень заряда Bluetooth-аксессуаров. Всё остаётся на вашем Mac.",
            "Открывать Lattice предпочтительно в", "Открывать Lattice сочетанием клавиш",
            "Lattice будет скрыт", "Lattice продолжит работать в фоновом режиме. Вы по-прежнему можете открывать инструменты с помощью горячих клавиш.", "Скрыть Lattice", "Все инструменты"]
        case .es: values = ["Mostrar el icono en la barra de menús", "Batería de accesorios",
            "Lee la batería de los accesorios Bluetooth. Todo permanece en tu Mac.",
            "Preferir abrir Lattice en", "Abrir Lattice con atajo",
            "Lattice se ocultará", "Lattice seguirá ejecutándose en segundo plano. Aún puedes acceder a tus herramientas mediante atajos de teclado.", "Ocultar Lattice", "Todas las herramientas"]
        case .sk: values = ["Zobraziť ikonu v lište", "Batéria príslušenstva",
            "Číta stav batérie Bluetooth príslušenstva. Všetko zostáva na vašom Macu.",
            "Prednostne otvárať Lattice v", "Otvoriť Lattice pomocou skratky",
            "Lattice bude skrytý", "Lattice bude naďalej bežať na pozadí. K svojim nástrojom máte naďalej prístup pomocou klávesových skratiek.", "Skryť Lattice", "Všetky nástroje"]
        case .de: values = ["Symbol in der Menüleiste anzeigen", "Zubehörbatterie",
            "Liest den Batteriestand von Bluetooth-Zubehör. Alles bleibt auf deinem Mac.",
            "Lattice bevorzugt öffnen in", "Lattice mit Kurzbefehl öffnen",
            "Lattice wird ausgeblendet", "Lattice läuft weiterhin im Hintergrund. Du kannst deine Werkzeuge weiterhin über Tastaturkurzbefehle aufrufen.", "Lattice ausblenden", "Alle Werkzeuge"]
        case .fr: values = ["Afficher l’icône dans la barre des menus", "Batterie des accessoires",
            "Lit le niveau de batterie des accessoires Bluetooth. Tout reste sur votre Mac.",
            "Ouvrir Lattice de préférence dans", "Ouvrir Lattice avec un raccourci",
            "Lattice sera masqué", "Lattice continuera de s’exécuter en arrière-plan. Vous pouvez toujours accéder à vos outils à l’aide de raccourcis clavier.", "Masquer Lattice", "Tous les outils"]
        case .it: values = ["Mostra l’icona nella barra dei menu", "Batteria degli accessori",
            "Legge la batteria degli accessori Bluetooth. Tutto rimane sul Mac.",
            "Apri preferibilmente Lattice in", "Apri Lattice con abbreviazione",
            "Lattice verrà nascosto", "Lattice continuerà a funzionare in background. Puoi comunque accedere ai tuoi strumenti tramite le abbreviazioni da tastiera.", "Nascondi Lattice", "Tutti gli strumenti"]
        case .ja: values = ["メニューバーにアイコンを表示", "アクセサリのバッテリー",
            "Bluetoothアクセサリのバッテリー残量を読み取ります。すべての情報はMac内に保存されます。",
            "Lattice の優先表示先", "ショートカットで Lattice を開く",
            "Lattice が非表示になります", "Lattice はバックグラウンドで実行され続けます。キーボードショートカットを使用してツールにアクセスできます。", "Lattice を非表示にする", "すべてのツール"]
        case .ko: values = ["메뉴 막대 아이콘 표시", "액세서리 배터리",
            "Bluetooth 액세서리의 배터리 잔량을 읽습니다. 모든 정보는 Mac에만 보관됩니다。",
            "Lattice 열기 우선 위치", "단축키로 Lattice 열기",
            "Lattice가 숨겨집니다", "Lattice는 백그라운드에서 계속 실행됩니다. 키보드 단축키를 사용하여 도구에 계속 접근할 수 있습니다。", "Lattice 숨기기", "모든 도구"]
        case .zhHans: values = ["显示菜单栏图标", "配件电池",
            "读取蓝牙配件的电量。所有信息仅保存在你的 Mac 上。",
            "偏好 Lattice 打开于", "使用快捷键打开 Lattice",
            "Lattice 将被隐藏", "Lattice 将继续在后台运行。你仍可以使用键盘快捷键访问工具。", "隐藏 Lattice", "所有工具"]
        case .zhTW: values = ["顯示選單列圖示", "配件電池",
            "讀取藍牙配件的電量。所有資訊僅保留在你的 Mac 上。",
            "偏好 Lattice 開啟於", "使用快速鍵開啟 Lattice",
            "Lattice 將被隱藏", "Lattice 將繼續在背景執行。你仍可使用鍵盤快速鍵存取工具。", "隱藏 Lattice", "所有工具"]
        case .zhHK: values = ["顯示選單列圖示", "配件電池",
            "讀取藍牙配件電量。所有資料只保留在你的 Mac。",
            "偏好 Lattice 開啟於", "使用快捷鍵開啟 Lattice",
            "Lattice 將被隱藏", "Lattice 會繼續在背景運行。你仍可使用鍵盤快速鍵存取工具。", "隱藏 Lattice", "所有工具"]
        case .uk: values = ["Показувати значок у смузі меню", "Батарея аксесуарів",
            "Читає заряд Bluetooth-аксесуарів. Усе залишається на вашому Mac.",
            "Бажане відкриття Lattice у", "Відкривати Lattice комбінацією клавіш",
            "Lattice буде сховано", "Lattice продовжуватиме працювати у фоновому режимі. Ви все ще можете отримувати доступ до інструментів за допомогою комбінацій клавіш.", "Сховати Lattice", "Усі інструменти"]
        }
        return values[key.rawValue]
    }
}
