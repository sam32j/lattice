// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

enum MediaEditorFileStrings {
    static var openInEditor: String { values(L10n.shared.language).open }
    static var enableFeature: String { values(L10n.shared.language).enable }

    static func values(_ language: AppLanguage) -> (open: String, enable: String) {
        switch language {
        case .enUS: ("Open in editor", "Enable %@ in Features to edit this file.")
        case .ptBR: ("Abrir no editor", "Ative %@ em Recursos para editar este arquivo.")
        case .tr: ("Düzenleyicide aç", "Bu dosyayı düzenlemek için Özellikler’de %@ özelliğini etkinleştirin.")
        case .ru: ("Открыть в редакторе", "Включите %@ в разделе «Функции», чтобы редактировать этот файл.")
        case .es: ("Abrir en el editor", "Activa %@ en Funciones para editar este archivo.")
        case .sk: ("Otvoriť v editore", "Na úpravu tohto súboru zapnite %@ v časti Funkcie.")
        case .de: ("Im Editor öffnen", "Aktiviere %@ unter Funktionen, um diese Datei zu bearbeiten.")
        case .fr: ("Ouvrir dans l’éditeur", "Activez %@ dans Fonctionnalités pour modifier ce fichier.")
        case .it: ("Apri nell’editor", "Attiva %@ in Funzionalità per modificare questo file.")
        case .ja: ("エディタで開く", "このファイルを編集するには、「機能」で%@を有効にしてください。")
        case .ko: ("편집기에서 열기", "이 파일을 편집하려면 기능에서 %@을(를) 활성화하세요.")
        case .uk: ("Відкрити в редакторі", "Увімкніть %@ у розділі «Функції», щоб редагувати цей файл.")
        case .zhHans: ("在编辑器中打开", "请在“功能”中启用%@以编辑此文件。")
        case .zhTW: ("在編輯器中打開", "請在「功能」中啟用%@以編輯此檔案。")
        case .zhHK: ("在編輯器中開啟", "請在「功能」中啟用%@以編輯此檔案。")
        }
    }
}
