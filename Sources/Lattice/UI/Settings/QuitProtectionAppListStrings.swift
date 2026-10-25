import Foundation

enum QuitProtectionAppListStrings {
    static func text(enabledOnly: Bool, shortcut: String, language: AppLanguage) -> (title: String, caption: String) {
        let copy: (String, String, String)
        switch language {
        case .enUS: copy = ("Enable in these apps", "Apply {key} protection only to these apps.", "Do not apply {key} protection to these apps. Other apps remain protected.")
        case .ptBR: copy = ("Ativar nestes apps", "Aplicar a proteção de {key} somente a estes apps.", "Não aplicar a proteção de {key} a estes apps. Os demais continuam protegidos.")
        case .de: copy = ("In diesen Apps aktivieren", "Den {key}-Schutz nur in diesen Apps anwenden.", "Den {key}-Schutz in diesen Apps nicht anwenden. Andere Apps bleiben geschützt.")
        case .fr: copy = ("Activer dans ces apps", "Appliquer la protection {key} uniquement dans ces apps.", "Ne pas appliquer la protection {key} dans ces apps. Les autres restent protégées.")
        case .es: copy = ("Activar en estas apps", "Aplicar la protección de {key} solo en estas apps.", "No aplicar la protección de {key} en estas apps. Las demás siguen protegidas.")
        case .it: copy = ("Attiva in queste app", "Applica la protezione {key} solo in queste app.", "Non applicare la protezione {key} in queste app. Le altre restano protette.")
        case .tr: copy = ("Bu uygulamalarda etkinleştir", "{key} korumasını yalnızca bu uygulamalarda uygula.", "{key} korumasını bu uygulamalarda uygulama. Diğer uygulamalar korunur.")
        case .ru: copy = ("Включить в этих приложениях", "Применять защиту {key} только в этих приложениях.", "Не применять защиту {key} в этих приложениях. Остальные остаются защищены.")
        case .uk: copy = ("Увімкнути в цих програмах", "Застосовувати захист {key} лише в цих програмах.", "Не застосовувати захист {key} в цих програмах. Решта залишається захищеною.")
        case .sk: copy = ("Zapnúť v týchto aplikáciách", "Použiť ochranu {key} iba v týchto aplikáciách.", "Nepoužiť ochranu {key} v týchto aplikáciách. Ostatné zostanú chránené.")
        case .ja: copy = ("これらのアプリで有効にする", "これらのアプリでのみ {key} の保護を適用します。", "これらのアプリでは {key} の保護を適用しません。他のアプリは保護されます。")
        case .ko: copy = ("다음 앱에서 활성화", "다음 앱에서만 {key} 보호를 적용합니다.", "다음 앱에는 {key} 보호를 적용하지 않습니다. 다른 앱은 계속 보호됩니다.")
        case .zhHans: copy = ("在这些 App 中启用", "仅在这些 App 中应用 {key} 保护。", "不在这些 App 中应用 {key} 保护。其他 App 仍受保护。")
        case .zhTW: copy = ("在這些 App 中啟用", "僅在這些 App 中套用 {key} 保護。", "不在這些 App 中套用 {key} 保護。其他 App 仍受保護。")
        case .zhHK: copy = ("在這些 App 啟用", "只在這些 App 套用 {key} 保護。", "不在這些 App 套用 {key} 保護。其他 App 仍受保護。")
        }
        return (enabledOnly ? copy.0 : SettingsAppListStrings.text(language).disabledApps,
                (enabledOnly ? copy.1 : copy.2).replacingOccurrences(of: "{key}", with: shortcut))
    }
}
