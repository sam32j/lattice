import Foundation

enum AppMenuRestorationCopy {
    static func cancel(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Don’t restore"
        case .ptBR: return "Não restaurar"
        case .es: return "No restaurar"
        case .de: return "Nicht wiederherstellen"
        case .fr: return "Ne pas restaurer"
        case .it: return "Non ripristinare"
        case .ja: return "復元しない"
        case .ko: return "복원하지 않기"
        case .zhHans: return "不恢复"
        case .zhTW, .zhHK: return "不恢復"
        case .ru: return "Не восстанавливать"
        case .uk: return "Не відновлювати"
        case .tr: return "Geri yükleme"
        case .sk: return "Neobnovovať"
        }
    }

    static func hint(_ target: AppMenuDestination, language: AppLanguage) -> String {
        let island = target == .island
        switch language {
        case .enUS: return island ? "The app menu will return when Dynamic Island is enabled again."
            : "The app menu will return when the menu bar icon is shown again."
        case .ptBR: return island ? "O menu do app voltará quando a Dynamic Island for ativada novamente."
            : "O menu do app voltará quando o ícone da barra de menus aparecer novamente."
        case .es: return island ? "El menú de la app volverá al activar Dynamic Island de nuevo."
            : "El menú de la app volverá al mostrar de nuevo el icono de la barra de menús."
        case .de: return island ? "Das App-Menü kehrt zurück, sobald Dynamic Island wieder aktiviert ist."
            : "Das App-Menü kehrt zurück, sobald das Menüleistensymbol wieder sichtbar ist."
        case .fr: return island ? "Le menu de l’app reviendra lorsque Dynamic Island sera réactivée."
            : "Le menu de l’app reviendra lorsque l’icône de la barre des menus sera de nouveau affichée."
        case .it: return island ? "Il menu dell’app tornerà quando Dynamic Island sarà riattivata."
            : "Il menu dell’app tornerà quando l’icona nella barra dei menu sarà di nuovo visibile."
        case .ja: return island ? "Dynamic Islandを再び有効にすると、アプリメニューが戻ります。"
            : "メニューバーアイコンを再び表示すると、アプリメニューが戻ります。"
        case .ko: return island ? "Dynamic Island를 다시 켜면 앱 메뉴가 돌아옵니다."
            : "메뉴 막대 아이콘을 다시 표시하면 앱 메뉴가 돌아옵니다."
        case .zhHans: return island ? "重新启用动态岛后，应用菜单会恢复显示。" : "重新显示菜单栏图标后，应用菜单会恢复显示。"
        case .zhTW, .zhHK: return island ? "重新啟用動態島後，App 選單會恢復顯示。" : "重新顯示選單列圖示後，App 選單會恢復顯示。"
        case .ru: return island ? "Меню приложения вернётся после повторного включения Dynamic Island."
            : "Меню приложения вернётся, когда значок строки меню снова станет видимым."
        case .uk: return island ? "Меню програми повернеться після повторного ввімкнення Dynamic Island."
            : "Меню програми повернеться, коли значок у рядку меню знову стане видимим."
        case .tr: return island ? "Dynamic Island yeniden açıldığında uygulama menüsü geri döner."
            : "Menü çubuğu simgesi yeniden gösterildiğinde uygulama menüsü geri döner."
        case .sk: return island ? "Ponuka aplikácie sa vráti po opätovnom zapnutí Dynamic Island."
            : "Ponuka aplikácie sa vráti po opätovnom zobrazení ikony v lište."
        }
    }
}
