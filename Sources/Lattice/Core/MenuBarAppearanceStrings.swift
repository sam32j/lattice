// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct MenuBarAppearanceStrings {
    let values: String
    let bars: String
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
        bars: "Bars"
    )

    static let ptBR = MenuBarAppearanceStrings(
        values: "Valores",
        bars: "Barras"
    )

    static let tr = MenuBarAppearanceStrings(
        values: "Değerler",
        bars: "Çubuklar"
    )

    static let ru = MenuBarAppearanceStrings(
        values: "Значения",
        bars: "Шкалы"
    )

    static let es = MenuBarAppearanceStrings(
        values: "Valores",
        bars: "Barras"
    )

    static let sk = MenuBarAppearanceStrings(
        values: "Hodnoty",
        bars: "Pruhy"
    )

    static let de = MenuBarAppearanceStrings(
        values: "Werte",
        bars: "Balken"
    )

    static let fr = MenuBarAppearanceStrings(
        values: "Valeurs",
        bars: "Barres"
    )

    static let it = MenuBarAppearanceStrings(
        values: "Valori",
        bars: "Barre"
    )

    static let ja = MenuBarAppearanceStrings(
        values: "数値",
        bars: "バー"
    )

    static let ko = MenuBarAppearanceStrings(
        values: "값",
        bars: "막대"
    )

    static let zhHans = MenuBarAppearanceStrings(
        values: "数值",
        bars: "条形"
    )

    static let zhTW = MenuBarAppearanceStrings(
        values: "數值",
        bars: "長條"
    )

    static let zhHK = MenuBarAppearanceStrings(
        values: "數值",
        bars: "長條"
    )
    static let uk = MenuBarAppearanceStrings(
        values: "Значення",
        bars: "Смуги"
    )
}
