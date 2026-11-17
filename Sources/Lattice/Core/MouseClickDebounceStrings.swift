// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct MouseClickDebounceStrings {
    let title: String
    let caption: String
    let moreOptions: String
    let windowLabel: String
    let windowCaption: String
}

extension FeatureStrings {
    static func mouseClickDebounce(_ language: AppLanguage) -> MouseClickDebounceStrings {
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

extension MouseClickDebounceStrings {
    static let enUS = MouseClickDebounceStrings(
        title: "Rapid click filter",
        caption: "Ignores rapid extra clicks.",
        moreOptions: "More options",
        windowLabel: "Filter window",
        windowCaption: "A repeated click inside this interval is treated as an accidental duplicate."
    )

    static let ptBR = MouseClickDebounceStrings(
        title: "Filtro de cliques rápidos",
        caption: "Ignora cliques extras rápidos.",
        moreOptions: "Mais opções",
        windowLabel: "Janela do filtro",
        windowCaption: "Um clique repetido dentro deste intervalo é tratado como duplicação acidental."
    )

    static let tr = MouseClickDebounceStrings(
        title: "Hızlı tıklama filtresi",
        caption: "Hızlı fazladan tıklamaları yok sayar.",
        moreOptions: "Daha fazla seçenek",
        windowLabel: "Filtre aralığı",
        windowCaption: "Bu aralıkta tekrarlanan tıklama yanlışlıkla yinelenmiş sayılır."
    )

    static let ru = MouseClickDebounceStrings(
        title: "Фильтр быстрых щелчков",
        caption: "Игнорирует быстрые лишние щелчки.",
        moreOptions: "Дополнительные параметры",
        windowLabel: "Интервал фильтра",
        windowCaption: "Повторный клик в этом интервале считается случайным повтором."
    )

    static let es = MouseClickDebounceStrings(
        title: "Filtro de clics rápidos",
        caption: "Ignora los clics extra rápidos.",
        moreOptions: "Más opciones",
        windowLabel: "Intervalo del filtro",
        windowCaption: "Un clic repetido dentro de este intervalo se considera una repetición accidental."
    )

    static let sk = MouseClickDebounceStrings(
        title: "Filter rýchlych kliknutí",
        caption: "Ignoruje rýchle nadbytočné kliknutia.",
        moreOptions: "Ďalšie možnosti",
        windowLabel: "Interval filtra",
        windowCaption: "Opakované kliknutie v tomto intervale sa považuje za náhodné zduplikovanie."
    )

    static let de = MouseClickDebounceStrings(
        title: "Filter für schnelle Klicks",
        caption: "Ignoriert schnelle zusätzliche Klicks.",
        moreOptions: "Weitere Optionen",
        windowLabel: "Filterzeitraum",
        windowCaption: "Ein wiederholter Klick in diesem Zeitraum gilt als versehentliche Wiederholung."
    )

    static let fr = MouseClickDebounceStrings(
        title: "Filtre des clics rapides",
        caption: "Ignore les clics supplémentaires rapides.",
        moreOptions: "Plus d’options",
        windowLabel: "Intervalle du filtre",
        windowCaption: "Un clic répété dans cet intervalle est considéré comme une répétition accidentelle."
    )

    static let it = MouseClickDebounceStrings(
        title: "Filtro clic rapidi",
        caption: "Ignora i clic extra rapidi.",
        moreOptions: "Altre opzioni",
        windowLabel: "Intervallo del filtro",
        windowCaption: "Un clic ripetuto in questo intervallo viene considerato una ripetizione accidentale."
    )

    static let ja = MouseClickDebounceStrings(
        title: "高速クリックフィルタ",
        caption: "素早い余分なクリックを無視します。",
        moreOptions: "その他のオプション",
        windowLabel: "フィルタ時間",
        windowCaption: "この時間内の繰り返しクリックは誤った重複として扱われます。"
    )

    static let ko = MouseClickDebounceStrings(
        title: "빠른 클릭 필터",
        caption: "빠르게 반복된 추가 클릭을 무시합니다.",
        moreOptions: "추가 옵션",
        windowLabel: "필터 시간",
        windowCaption: "이 시간 안에 반복된 클릭은 실수로 중복된 클릭으로 처리됩니다."
    )

    static let zhHans = MouseClickDebounceStrings(
        title: "快速点按过滤",
        caption: "忽略快速的多余点按。",
        moreOptions: "更多选项",
        windowLabel: "过滤时段",
        windowCaption: "此时段内的重复点击会被视为意外重复。"
    )

    static let zhTW = MouseClickDebounceStrings(
        title: "快速點按過濾",
        caption: "忽略快速的多餘點按。",
        moreOptions: "更多選項",
        windowLabel: "過濾時段",
        windowCaption: "此時段內的重複點按會視為意外重複。"
    )

    static let zhHK = MouseClickDebounceStrings(
        title: "快速點按過濾",
        caption: "忽略快速的多餘點按。",
        moreOptions: "更多選項",
        windowLabel: "過濾時段",
        windowCaption: "此時段內的重複點按會視為意外重複。"
    )
    static let uk = MouseClickDebounceStrings(
        title: "Фільтр швидких клацань",
        caption: "Ігнорує швидкі зайві клацання.",
        moreOptions: "Більше опцій",
        windowLabel: "Фільтрувати вікно",
        windowCaption: "Повторний клац усередині цього інтервалу вважається випадковим дублікатом."
    )
}
