import SwiftUI

enum UtilitySettingsCopy {
    static func globalShortcut(_ l10n: L10n) -> String {
        l10n.language == .enUS ? "Global keyboard shortcut" : l10n.s.globalHotkeySection
    }

    static func fileCacheHint(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Open File Cache by shaking your pointer while dragging."
        case .ptBR: return "Abra o Cache de Arquivos agitando o ponteiro enquanto arrasta."
        case .es: return "Abre la caché de archivos agitando el puntero mientras arrastras."
        case .de: return "Öffne den Datei-Cache, indem du den Zeiger beim Ziehen schüttelst."
        case .fr: return "Ouvrez le cache de fichiers en secouant le pointeur pendant un glissement."
        case .it: return "Apri la cache dei file scuotendo il puntatore durante il trascinamento."
        case .ja: return "ドラッグ中にポインタを振ると、ファイルキャッシュが開きます。"
        case .ko: return "드래그하는 동안 포인터를 흔들어 파일 캐시를 여세요."
        case .zhHans: return "拖移时晃动指针，即可打开文件暂存。"
        case .zhTW, .zhHK: return "拖移時晃動指標，即可開啟檔案暫存。"
        case .ru: return "Чтобы открыть кэш файлов, встряхните указатель во время перетаскивания."
        case .uk: return "Щоб відкрити кеш файлів, струсіть вказівник під час перетягування."
        case .tr: return "Dosya Önbelleğini açmak için sürüklerken işaretçiyi sallayın."
        case .sk: return "Vyrovnávaciu pamäť súborov otvoríte zatrasením ukazovateľa počas ťahania."
        }
    }
}
