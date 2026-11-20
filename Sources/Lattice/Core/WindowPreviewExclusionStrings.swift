// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct WindowPreviewExclusionStrings {
    let sectionTitle: String
    let listTitle: String
    let addButton: String
    let removeButton: String
}

extension FeatureStrings {
    static func windowPreviewExclusions(_ language: AppLanguage) -> WindowPreviewExclusionStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        case .uk: return .uk
        }
    }
}

extension WindowPreviewExclusionStrings {
    static let enUS = WindowPreviewExclusionStrings(
        sectionTitle: "Window thumbnails",
        listTitle: "Pause for these apps",
        addButton: "Add an app…",
        removeButton: "Remove"
    )

    static let ptBR = WindowPreviewExclusionStrings(
        sectionTitle: "Miniaturas das janelas",
        listTitle: "Pausar para estes apps",
        addButton: "Adicionar app…",
        removeButton: "Remover"
    )

    static let tr = WindowPreviewExclusionStrings(
        sectionTitle: "Pencere küçük resimleri",
        listTitle: "Bu uygulamalar için duraklat",
        addButton: "Uygulama ekle…",
        removeButton: "Kaldır"
    )

    static let ru = WindowPreviewExclusionStrings(
        sectionTitle: "Миниатюры окон",
        listTitle: "Приостанавливать для этих приложений",
        addButton: "Добавить приложение…",
        removeButton: "Удалить"
    )

    static let es = WindowPreviewExclusionStrings(
        sectionTitle: "Miniaturas de ventanas",
        listTitle: "Pausar para estas apps",
        addButton: "Añadir app…",
        removeButton: "Quitar"
    )

    static let sk = WindowPreviewExclusionStrings(
        sectionTitle: "Miniatúry okien",
        listTitle: "Pozastaviť pre tieto aplikácie",
        addButton: "Pridať aplikáciu…",
        removeButton: "Odstrániť"
    )

    static let de = WindowPreviewExclusionStrings(
        sectionTitle: "Fenstervorschauen",
        listTitle: "Für diese Apps pausieren",
        addButton: "App hinzufügen…",
        removeButton: "Entfernen"
    )

    static let fr = WindowPreviewExclusionStrings(
        sectionTitle: "Aperçus des fenêtres",
        listTitle: "Mettre en pause pour ces apps",
        addButton: "Ajouter une app…",
        removeButton: "Retirer"
    )

    static let it = WindowPreviewExclusionStrings(
        sectionTitle: "Anteprime delle finestre",
        listTitle: "Metti in pausa per queste app",
        addButton: "Aggiungi app…",
        removeButton: "Rimuovi"
    )

    static let ja = WindowPreviewExclusionStrings(
        sectionTitle: "ウインドウのサムネイル",
        listTitle: "これらのAppに対して一時停止",
        addButton: "Appを追加…",
        removeButton: "削除"
    )

    static let ko = WindowPreviewExclusionStrings(
        sectionTitle: "창 미리보기",
        listTitle: "다음 앱에 대해 일시 정지",
        addButton: "앱 추가…",
        removeButton: "제거"
    )

    static let zhHans = WindowPreviewExclusionStrings(
        sectionTitle: "窗口缩略图",
        listTitle: "对这些 App 暂停",
        addButton: "添加 App…",
        removeButton: "移除"
    )

    static let zhTW = WindowPreviewExclusionStrings(
        sectionTitle: "視窗縮圖",
        listTitle: "對這些 App 暫停",
        addButton: "加入 App…",
        removeButton: "移除"
    )

    static let zhHK = WindowPreviewExclusionStrings(
        sectionTitle: "視窗縮圖",
        listTitle: "對這些 App 暫停",
        addButton: "加入 App…",
        removeButton: "移除"
    )

    static let uk = WindowPreviewExclusionStrings(
        sectionTitle: "Мініатюри вікон",
        listTitle: "Пауза для цих програм",
        addButton: "Додати програму…",
        removeButton: "Видалити"
    )
}
