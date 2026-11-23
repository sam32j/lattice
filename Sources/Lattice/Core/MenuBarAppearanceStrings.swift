// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct MenuBarAppearanceStrings {
    let values: String
    let bars: String
    let normalColor: String
    let mediumColor: String
    let highColor: String
    let mediumFrom: String
    let highFrom: String
}

extension FeatureStrings {
    static func menuBarAppearance(_ language: AppLanguage) -> MenuBarAppearanceStrings {
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

extension MenuBarAppearanceStrings {
    static let enUS = MenuBarAppearanceStrings(
        values: "Values",
        bars: "Bars",
        normalColor: "Normal color",
        mediumColor: "Medium color",
        highColor: "High color",
        mediumFrom: "Medium from",
        highFrom: "High from"
    )

    static let ptBR = MenuBarAppearanceStrings(
        values: "Valores",
        bars: "Barras",
        normalColor: "Cor normal",
        mediumColor: "Cor média",
        highColor: "Cor alta",
        mediumFrom: "Médio a partir de",
        highFrom: "Alto a partir de"
    )

    static let tr = MenuBarAppearanceStrings(
        values: "Değerler",
        bars: "Çubuklar",
        normalColor: "Normal renk",
        mediumColor: "Orta renk",
        highColor: "Yüksek renk",
        mediumFrom: "Orta başlangıcı",
        highFrom: "Yüksek başlangıcı"
    )

    static let ru = MenuBarAppearanceStrings(
        values: "Значения",
        bars: "Шкалы",
        normalColor: "Обычный цвет",
        mediumColor: "Средний цвет",
        highColor: "Высокий цвет",
        mediumFrom: "Средний от",
        highFrom: "Высокий от"
    )

    static let es = MenuBarAppearanceStrings(
        values: "Valores",
        bars: "Barras",
        normalColor: "Color normal",
        mediumColor: "Color medio",
        highColor: "Color alto",
        mediumFrom: "Medio desde",
        highFrom: "Alto desde"
    )

    static let sk = MenuBarAppearanceStrings(
        values: "Hodnoty",
        bars: "Pruhy",
        normalColor: "Bežná farba",
        mediumColor: "Stredná farba",
        highColor: "Vysoká farba",
        mediumFrom: "Stredná od",
        highFrom: "Vysoká od"
    )

    static let de = MenuBarAppearanceStrings(
        values: "Werte",
        bars: "Balken",
        normalColor: "Normale Farbe",
        mediumColor: "Mittlere Farbe",
        highColor: "Hohe Farbe",
        mediumFrom: "Mittel ab",
        highFrom: "Hoch ab"
    )

    static let fr = MenuBarAppearanceStrings(
        values: "Valeurs",
        bars: "Barres",
        normalColor: "Couleur normale",
        mediumColor: "Couleur moyenne",
        highColor: "Couleur élevée",
        mediumFrom: "Moyen à partir de",
        highFrom: "Élevé à partir de"
    )

    static let it = MenuBarAppearanceStrings(
        values: "Valori",
        bars: "Barre",
        normalColor: "Colore normale",
        mediumColor: "Colore medio",
        highColor: "Colore alto",
        mediumFrom: "Medio da",
        highFrom: "Alto da"
    )

    static let ja = MenuBarAppearanceStrings(
        values: "数値",
        bars: "バー",
        normalColor: "通常の色",
        mediumColor: "中程度の色",
        highColor: "高負荷の色",
        mediumFrom: "中程度の開始",
        highFrom: "高負荷の開始"
    )

    static let ko = MenuBarAppearanceStrings(
        values: "값",
        bars: "막대",
        normalColor: "보통 색상",
        mediumColor: "중간 색상",
        highColor: "높음 색상",
        mediumFrom: "중간 시작",
        highFrom: "높음 시작"
    )

    static let zhHans = MenuBarAppearanceStrings(
        values: "数值",
        bars: "条形",
        normalColor: "正常颜色",
        mediumColor: "中等颜色",
        highColor: "高负载颜色",
        mediumFrom: "中等起点",
        highFrom: "高负载起点"
    )

    static let zhTW = MenuBarAppearanceStrings(
        values: "數值",
        bars: "長條",
        normalColor: "正常顏色",
        mediumColor: "中等顏色",
        highColor: "高負載顏色",
        mediumFrom: "中等起點",
        highFrom: "高負載起點"
    )

    static let zhHK = MenuBarAppearanceStrings(
        values: "數值",
        bars: "長條",
        normalColor: "正常顏色",
        mediumColor: "中等顏色",
        highColor: "高負載顏色",
        mediumFrom: "中等起點",
        highFrom: "高負載起點"
    )
    static let uk = MenuBarAppearanceStrings(
        values: "Значення",
        bars: "Смуги",
        normalColor: "Звичайний колір",
        mediumColor: "Середній колір",
        highColor: "Високий колір",
        mediumFrom: "Середній від",
        highFrom: "Високий від"
    )
}
