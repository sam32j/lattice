import Foundation

enum SettingsFollowupStrings {
    enum Key: Int { case showMenuIcon, accessoryBattery, bluetoothExplanation }

    static func text(_ key: Key, _ language: AppLanguage) -> String {
        let values: [String]
        switch language {
        case .enUS: values = ["Show the menu bar icon", "Accessory battery",
            "Read battery levels for Bluetooth accessories. Everything stays on your Mac."]
        case .ptBR: values = ["Mostrar o ícone na barra de menus", "Bateria dos acessórios",
            "Lê a bateria dos acessórios Bluetooth. Tudo fica no seu Mac."]
        case .tr: values = ["Menü çubuğu simgesini göster", "Aksesuar pili",
            "Bluetooth aksesuarlarının pil düzeylerini okur. Her şey Mac’inizde kalır."]
        case .ru: values = ["Показывать значок в строке меню", "Батарея аксессуаров",
            "Читает уровень заряда Bluetooth-аксессуаров. Всё остаётся на вашем Mac."]
        case .es: values = ["Mostrar el icono en la barra de menús", "Batería de accesorios",
            "Lee la batería de los accesorios Bluetooth. Todo permanece en tu Mac."]
        case .sk: values = ["Zobraziť ikonu v lište", "Batéria príslušenstva",
            "Číta stav batérie Bluetooth príslušenstva. Všetko zostáva na vašom Macu."]
        case .de: values = ["Symbol in der Menüleiste anzeigen", "Zubehörbatterie",
            "Liest den Batteriestand von Bluetooth-Zubehör. Alles bleibt auf deinem Mac."]
        case .fr: values = ["Afficher l’icône dans la barre des menus", "Batterie des accessoires",
            "Lit le niveau de batterie des accessoires Bluetooth. Tout reste sur votre Mac."]
        case .it: values = ["Mostra l’icona nella barra dei menu", "Batteria degli accessori",
            "Legge la batteria degli accessori Bluetooth. Tutto rimane sul Mac."]
        case .ja: values = ["メニューバーにアイコンを表示", "アクセサリのバッテリー",
            "Bluetoothアクセサリのバッテリー残量を読み取ります。すべての情報はMac内に保存されます。"]
        case .ko: values = ["메뉴 막대 아이콘 표시", "액세서리 배터리",
            "Bluetooth 액세서리의 배터리 잔량을 읽습니다. 모든 정보는 Mac에만 보관됩니다."]
        case .zhHans: values = ["显示菜单栏图标", "配件电池",
            "读取蓝牙配件的电量。所有信息仅保存在你的 Mac 上。"]
        case .zhTW: values = ["顯示選單列圖示", "配件電池",
            "讀取藍牙配件的電量。所有資訊僅保留在你的 Mac 上。"]
        case .zhHK: values = ["顯示選單列圖示", "配件電池",
            "讀取藍牙配件電量。所有資料只保留在你的 Mac。"]
        case .uk: values = ["Показувати значок у смузі меню", "Батарея аксесуарів",
            "Читає заряд Bluetooth-аксесуарів. Усе залишається на вашому Mac."]
        }
        return values[key.rawValue]
    }
}
