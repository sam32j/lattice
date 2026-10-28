import SwiftUI

enum UtilitySettingsCopy {
    static func open(_ name: String, _ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Open \(name)"
        case .ptBR: return "Abrir \(name)"
        case .es: return "Abrir \(name)"
        case .de: return "\(name) öffnen"
        case .fr: return "Ouvrir \(name)"
        case .it: return "Apri \(name)"
        case .ja: return "\(name)を開く"
        case .ko: return "\(name) 열기"
        case .zhHans: return "打开\(name)"
        case .zhTW, .zhHK: return "開啟\(name)"
        case .ru: return "Открыть \(name)"
        case .uk: return "Відкрити \(name)"
        case .tr: return "\(name) aç"
        case .sk: return "Otvoriť \(name)"
        }
    }

    static func openWithShortcut(_ name: String, _ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Open \(name) with Shortcut"
        case .ptBR: return "Abrir \(name) com atalho"
        case .es: return "Abrir \(name) con atajo"
        case .de: return "\(name) mit Kurzbefehl öffnen"
        case .fr: return "Ouvrir \(name) avec le raccourci"
        case .it: return "Apri \(name) con scorciatoia"
        case .ja: return "ショートカットで\(name)を開く"
        case .ko: return "단축키로 \(name) 열기"
        case .zhHans: return "通过快捷键打开\(name)"
        case .zhTW, .zhHK: return "透過快速鍵開啟\(name)"
        case .ru: return "Открыть \(name) сочетанием клавиш"
        case .uk: return "Відкрити \(name) комбінацією клавіш"
        case .tr: return "\(name) kısayol ile aç"
        case .sk: return "Otvoriť \(name) skratkou"
        }
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
