// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

struct WindowEdgeSnapRestoreStrings {
    let title: String
    let caption: String

    static func localized(_ language: AppLanguage) -> WindowEdgeSnapRestoreStrings {
        switch language {
        case .enUS: return .init(title: "Restore size when unsnapping", caption: "Dragging a snapped window away returns it to its earlier size.")
        case .ptBR: return .init(title: "Restaurar tamanho ao desencaixar", caption: "Arrastar uma janela encaixada devolve o tamanho anterior.")
        case .tr: return .init(title: "Ayırınca boyutu geri yükle", caption: "Yerleştirilmiş pencereyi sürüklemek önceki boyutunu geri getirir.")
        case .ru: return .init(title: "Возвращать размер при отцеплении", caption: "Вытянутое привязанное окно возвращает прежний размер.")
        case .es: return .init(title: "Restaurar tamaño al desajustar", caption: "Arrastrar una ventana ajustada recupera su tamaño anterior.")
        case .sk: return .init(title: "Obnoviť veľkosť po odtiahnutí", caption: "Odtiahnuté pritiahnuté okno sa vráti na pôvodnú veľkosť.")
        case .de: return .init(title: "Größe beim Lösen wiederherstellen", caption: "Ein weggezogenes Fenster erhält seine vorherige Größe zurück.")
        case .fr: return .init(title: "Restaurer la taille en détachant", caption: "Une fenêtre ancrée éloignée retrouve sa taille d’avant.")
        case .it: return .init(title: "Ripristina dimensione allo sgancio", caption: "Una finestra allineata trascinata via torna alla dimensione di prima.")
        case .ja: return .init(title: "スナップ解除で元のサイズに戻す", caption: "スナップしたウインドウを引き離すと元のサイズに戻ります。")
        case .ko: return .init(title: "맞춤 해제 시 크기 복원", caption: "맞춘 윈도우를 끌어내면 이전 크기로 돌아갑니다.")
        case .zhHans: return .init(title: "取消贴靠时恢复大小", caption: "拖离贴靠的窗口会恢复原来的大小。")
        case .zhTW: return .init(title: "取消貼齊時還原大小", caption: "拖離貼齊的視窗會還原原本大小。")
        case .zhHK: return .init(title: "取消貼齊時還原大小", caption: "拖離貼齊嘅視窗會還原原本大小。")
        case .uk: return .init(title: "Повертати розмір після відкріплення", caption: "Витягнуте прикріплене вікно повертає попередній розмір.")
        }
    }
}
