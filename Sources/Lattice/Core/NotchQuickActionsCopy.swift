// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum NotchQuickActionsCopy {
    static func editingTools(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Editing Tools..."
        case .ptBR: return "Editando ferramentas..."
        case .es: return "Editando herramientas..."
        case .sk: return "Úprava nástrojov..."
        case .de: return "Tools bearbeiten..."
        case .fr: return "Modification des outils..."
        case .it: return "Modifica strumenti..."
        case .ru: return "Редактирование инструментов..."
        case .tr: return "Araçları düzenleme..."
        case .ja: return "ツールを編集中..."
        case .ko: return "도구 편집 중..."
        case .zhHans: return "正在编辑工具..."
        case .zhTW: return "正在編輯工具..."
        case .zhHK: return "正在編輯工具..."
        case .uk: return "Редагування інструментів..."
        }
    }

    /// The gear menu action starts the same live editing mode as the Done button.
    /// Keep it separate from `manageTools`, which is also used by non-menu UI.
    static func editToolsMenu(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Edit Tools..."
        case .ptBR: return "Editar ferramentas..."
        case .es: return "Editar herramientas..."
        case .sk: return "Upraviť nástroje..."
        case .de: return "Werkzeuge bearbeiten..."
        case .fr: return "Modifier les outils..."
        case .it: return "Modifica strumenti..."
        case .ru: return "Редактировать инструменты..."
        case .tr: return "Araçları düzenle..."
        case .ja: return "ツールを編集..."
        case .ko: return "도구 편집..."
        case .zhHans: return "编辑工具..."
        case .zhTW: return "編輯工具..."
        case .zhHK: return "編輯工具..."
        case .uk: return "Редагувати інструменти..."
        }
    }

    static func instructions(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Drag to rearrange. Use − and + to edit."
        case .ptBR: return "Arraste para reorganizar. Use − e + para editar."
        case .es: return "Arrastra para reordenar. Usa − y + para editar."
        case .sk: return "Presunutím zmeňte poradie. Na úpravu použite − a +."
        case .de: return "Zum Anordnen ziehen. Mit − und + bearbeiten."
        case .fr: return "Faites glisser pour réorganiser. Utilisez − et + pour modifier."
        case .it: return "Trascina per riordinare. Usa − e + per modificare."
        case .ru: return "Перетаскивайте для изменения порядка. Используйте − и + для редактирования."
        case .tr: return "Yeniden sıralamak için sürükleyin. Düzenlemek için − ve + kullanın."
        case .ja: return "ドラッグして並べ替えます。− と + で編集します。"
        case .ko: return "드래그하여 순서를 바꾸세요. − 및 +로 편집하세요."
        case .uk: return "Перетягуйте для зміни порядку. Використовуйте − і + для редагування."
        case .zhHans: return "拖动以重新排列。使用 − 和 + 编辑。"
        case .zhTW: return "拖移以重新排列。使用 − 和 + 編輯。"
        case .zhHK: return "拖移以重新排列。使用 − 和 + 編輯。"
        }
    }

    static func caption(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Quick action buttons around your Dynamic Island."
        case .ptBR: return "Botões de ações rápidas ao redor do Dynamic Island."
        case .es: return "Botones de acciones rápidas alrededor de Dynamic Island."
        case .sk: return "Tlačidlá rýchlych akcií okolo Dynamic Island."
        case .de: return "Schnellaktionstasten rund um Dynamic Island."
        case .fr: return "Boutons d’actions rapides autour de Dynamic Island."
        case .it: return "Pulsanti per azioni rapide intorno a Dynamic Island."
        case .ru: return "Кнопки быстрых действий вокруг Dynamic Island."
        case .tr: return "Dynamic Island çevresindeki hızlı işlem düğmeleri."
        case .ja: return "Dynamic Island の周囲に表示するクイックアクションボタン。"
        case .ko: return "Dynamic Island 주변의 빠른 작업 버튼입니다."
        case .uk: return "Кнопки швидких дій навколо Dynamic Island."
        case .zhHans: return "灵动岛周围的快捷操作按钮。"
        case .zhTW: return "動態島周圍的快速操作按鈕。"
        case .zhHK: return "動態島周圍的快速操作按鈕。"
        }
    }
}
