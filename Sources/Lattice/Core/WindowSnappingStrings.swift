// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// The window snapping panel's mode selector, grid divisions and layout
/// toggle. Division and toggle labels share a narrow segmented control, so
/// they stay short in every language.
struct WindowSnappingStrings {
    let customGrid: String
    let layoutPresets: String
    /// Compact island band labels for the two modes.
    let gridShort: String
    let presetsShort: String
    let split: String
    let threeWay: String
    let quarters: String
    let grid: String
    /// Layout toggle segments.
    let cols: String
    let rows: String
    /// The same layouts spelled out in the toast.
    let columns: String
    let rowsLong: String
    let corners: String
    let modeLabel: String

    static func localized(_ language: AppLanguage) -> WindowSnappingStrings {
        switch language {
        case .enUS: return enUS
        case .ptBR:
            return .init(customGrid: "Grade personalizada", layoutPresets: "Layouts prontos", gridShort: "Grade",
                         presetsShort: "Layouts", split: "Dividir", threeWay: "3 partes", quarters: "Quartos",
                         grid: "Grade", cols: "Col.", rows: "Lin.", columns: "Colunas", rowsLong: "Linhas",
                         corners: "Cantos 2×2", modeLabel: "Modo de encaixe")
        case .tr:
            return .init(customGrid: "Özel ızgara", layoutPresets: "Hazır düzenler", gridShort: "Izgara",
                         presetsShort: "Düzenler", split: "Böl", threeWay: "3’lü", quarters: "Çeyrekler",
                         grid: "Izgara", cols: "Sütun", rows: "Satır", columns: "Sütunlar", rowsLong: "Satırlar",
                         corners: "2×2 köşeler", modeLabel: "Yerleştirme modu")
        case .ru:
            return .init(customGrid: "Своя сетка", layoutPresets: "Готовые макеты", gridShort: "Сетка",
                         presetsShort: "Макеты", split: "Пополам", threeWay: "На 3", quarters: "Четверти",
                         grid: "Сетка", cols: "Столб.", rows: "Строки", columns: "Столбцы", rowsLong: "Строки",
                         corners: "Углы 2×2", modeLabel: "Режим привязки")
        case .es:
            return .init(customGrid: "Cuadrícula propia", layoutPresets: "Diseños predefinidos", gridShort: "Cuadrícula",
                         presetsShort: "Diseños", split: "Dividir", threeWay: "En 3", quarters: "Cuartos",
                         grid: "Cuadrícula", cols: "Col.", rows: "Filas", columns: "Columnas", rowsLong: "Filas",
                         corners: "Esquinas 2×2", modeLabel: "Modo de ajuste")
        case .sk:
            return .init(customGrid: "Vlastná mriežka", layoutPresets: "Hotové rozloženia", gridShort: "Mriežka",
                         presetsShort: "Rozloženia", split: "Polovice", threeWay: "Na 3", quarters: "Štvrtiny",
                         grid: "Mriežka", cols: "Stĺp.", rows: "Riadky", columns: "Stĺpce", rowsLong: "Riadky",
                         corners: "Rohy 2×2", modeLabel: "Režim prichytenia")
        case .de:
            return .init(customGrid: "Eigenes Raster", layoutPresets: "Layout-Vorlagen", gridShort: "Raster",
                         presetsShort: "Vorlagen", split: "Teilen", threeWay: "3-fach", quarters: "Viertel",
                         grid: "Raster", cols: "Spalt.", rows: "Zeilen", columns: "Spalten", rowsLong: "Zeilen",
                         corners: "2×2-Ecken", modeLabel: "Anordnungsmodus")
        case .fr:
            return .init(customGrid: "Grille perso", layoutPresets: "Dispositions prédéfinies", gridShort: "Grille",
                         presetsShort: "Dispositions", split: "Moitiés", threeWay: "En 3", quarters: "Quarts",
                         grid: "Grille", cols: "Col.", rows: "Lignes", columns: "Colonnes", rowsLong: "Lignes",
                         corners: "Coins 2×2", modeLabel: "Mode d’ancrage")
        case .it:
            return .init(customGrid: "Griglia personalizzata", layoutPresets: "Layout predefiniti", gridShort: "Griglia",
                         presetsShort: "Layout", split: "Dividi", threeWay: "In 3", quarters: "Quarti",
                         grid: "Griglia", cols: "Col.", rows: "Righe", columns: "Colonne", rowsLong: "Righe",
                         corners: "Angoli 2×2", modeLabel: "Modalità aggancio")
        case .ja:
            return .init(customGrid: "カスタムグリッド", layoutPresets: "レイアウトプリセット", gridShort: "グリッド",
                         presetsShort: "プリセット", split: "2分割", threeWay: "3分割", quarters: "4分割",
                         grid: "グリッド", cols: "列", rows: "行", columns: "列", rowsLong: "行",
                         corners: "2×2の四隅", modeLabel: "スナップモード")
        case .ko:
            return .init(customGrid: "사용자 지정 격자", layoutPresets: "레이아웃 프리셋", gridShort: "격자",
                         presetsShort: "프리셋", split: "2분할", threeWay: "3분할", quarters: "4분할",
                         grid: "격자", cols: "열", rows: "행", columns: "열", rowsLong: "행",
                         corners: "2×2 모서리", modeLabel: "스냅 모드")
        case .zhHans:
            return .init(customGrid: "自定网格", layoutPresets: "布局预设", gridShort: "网格",
                         presetsShort: "预设", split: "二分", threeWay: "三分", quarters: "四分",
                         grid: "网格", cols: "列", rows: "行", columns: "列", rowsLong: "行",
                         corners: "2×2 四角", modeLabel: "吸附模式")
        case .zhTW, .zhHK:
            return .init(customGrid: "自訂格線", layoutPresets: "版面預設", gridShort: "格線",
                         presetsShort: "預設", split: "二分", threeWay: "三分", quarters: "四分",
                         grid: "格線", cols: "欄", rows: "列", columns: "欄", rowsLong: "列",
                         corners: "2×2 四角", modeLabel: "吸附模式")
        case .uk:
            return .init(customGrid: "Власна сітка", layoutPresets: "Готові макети", gridShort: "Сітка",
                         presetsShort: "Макети", split: "Навпіл", threeWay: "На 3", quarters: "Чверті",
                         grid: "Сітка", cols: "Стовп.", rows: "Рядки", columns: "Стовпці", rowsLong: "Рядки",
                         corners: "Кути 2×2", modeLabel: "Режим прив’язки")
        }
    }

    static let enUS = WindowSnappingStrings(
        customGrid: "Custom Grid", layoutPresets: "Layout Presets", gridShort: "Grid", presetsShort: "Presets",
        split: "Split", threeWay: "3-Way", quarters: "Quarters", grid: "Grid",
        cols: "Cols", rows: "Rows", columns: "Columns", rowsLong: "Rows",
        corners: "2×2 Corners", modeLabel: "Snapping mode")

    static var current: WindowSnappingStrings { localized(L10n.shared.language) }
}
