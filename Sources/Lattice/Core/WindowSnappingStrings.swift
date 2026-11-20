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

/// Everything else the snapping panel says: quick actions, hints, and the
/// words its tile and preset labels are built from. Labels are composed
/// ("Left 1/3", "Top Right 1/6") rather than listed, so a language supplies
/// the position words and how they combine (`half`, `corner`), not every
/// label.
struct WindowSnappingPanelStrings {
    let maximize: String
    let centerWindow: String
    let prevDisplay: String
    let nextDisplay: String
    let restore: String
    let quickActions: String
    let gridHint: String
    let presetsHint: String
    /// "%@ — Click to snap" and "%@ — Release to snap".
    let clickToSnapFormat: String
    let releaseToSnapFormat: String
    let left: String
    let right: String
    let center: String
    let top: String
    let bottom: String
    let middle: String
    let centerLeft: String
    let centerRight: String
    let upperCenter: String
    let lowerCenter: String
    /// Short row names for the narrow 2×3 tiles.
    let middleShort: String
    let bottomShort: String
    let col: String
    let row: String
    let zone: String
    /// "%@ Half"; most languages say "%@ 1/2".
    let halfFormat: String
    /// Row then column: "%1$@ %2$@" reads "Top Left"; Japanese, Korean and
    /// Chinese put the column first.
    let cornerFormat: String
    let primaryFormat: String
    let sideFormat: String
    let stackFormat: String
    let threeColumns: String
    let quarters: String
    let mainStack: String

    func part(_ position: String, _ fraction: String) -> String { "\(position) \(fraction)" }
    func half(_ position: String) -> String { String(format: halfFormat, position) }
    func corner(row: String, col: String) -> String { String(format: cornerFormat, row, col) }
    func primary(_ position: String) -> String { String(format: primaryFormat, position) }
    func side(_ position: String) -> String { String(format: sideFormat, position) }
    func stack(_ position: String) -> String { String(format: stackFormat, position) }
    func clickToSnap(_ label: String) -> String { String(format: clickToSnapFormat, label) }
    func releaseToSnap(_ label: String) -> String { String(format: releaseToSnapFormat, label) }
    func zone(_ width: String, _ height: String) -> String { "\(zone) \(width) × \(height)" }

    static var current: WindowSnappingPanelStrings { localized(L10n.shared.language) }

    static func localized(_ language: AppLanguage) -> WindowSnappingPanelStrings {
        switch language {
        case .enUS: return enUS
        case .ptBR:
            return .init(maximize: "Maximizar",
                         centerWindow: "Centralizar", prevDisplay: "Tela anterior", nextDisplay: "Próxima tela",
                         restore: "Restaurar tamanho anterior", quickActions: "AÇÕES RÁPIDAS",
                         gridHint: "Clique para encaixar • Arraste para abranger • Role para alternar",
                         presetsHint: "Passe o ponteiro sobre uma área para ver • Clique para encaixar",
                         clickToSnapFormat: "%@ — Clique para encaixar", releaseToSnapFormat: "%@ — Solte para encaixar",
                         left: "Esquerda", right: "Direita", center: "Centro", top: "Topo", bottom: "Base",
                         middle: "Meio", centerLeft: "Centro-esquerda", centerRight: "Centro-direita",
                         upperCenter: "Centro superior", lowerCenter: "Centro inferior", middleShort: "Meio",
                         bottomShort: "Base", col: "Col.", row: "Lin.", zone: "Zona", halfFormat: "%@ 1/2",
                         cornerFormat: "%1$@ %2$@", primaryFormat: "%@ principal", sideFormat: "%@ lateral",
                         stackFormat: "%@ (pilha)", threeColumns: "3 colunas", quarters: "Quartos 2×2",
                         mainStack: "Principal + pilha")
        case .tr:
            return .init(maximize: "Büyüt",
                         centerWindow: "Ortala", prevDisplay: "Önceki ekran", nextDisplay: "Sonraki ekran",
                         restore: "Önceki boyuta dön", quickActions: "HIZLI EYLEMLER",
                         gridHint: "Yerleştirmek için tıklayın • Yaymak için sürükleyin • Değiştirmek için kaydırın",
                         presetsHint: "Önizlemek için bir bölmenin üzerine gelin • Yerleştirmek için tıklayın",
                         clickToSnapFormat: "%@ — Yerleştirmek için tıklayın", releaseToSnapFormat: "%@ — Yerleştirmek için bırakın",
                         left: "Sol", right: "Sağ", center: "Orta", top: "Üst", bottom: "Alt",
                         middle: "Orta", centerLeft: "Orta-sol", centerRight: "Orta-sağ",
                         upperCenter: "Üst orta", lowerCenter: "Alt orta", middleShort: "Orta",
                         bottomShort: "Alt", col: "Süt.", row: "Sat.", zone: "Bölge", halfFormat: "%@ 1/2",
                         cornerFormat: "%1$@ %2$@", primaryFormat: "Ana %@", sideFormat: "Yan %@",
                         stackFormat: "%@ yığın", threeColumns: "3 sütun", quarters: "2×2 çeyrek",
                         mainStack: "Ana + yığın")
        case .ru:
            return .init(maximize: "Развернуть",
                         centerWindow: "По центру", prevDisplay: "Пред. дисплей", nextDisplay: "След. дисплей",
                         restore: "Вернуть прежний размер", quickActions: "БЫСТРЫЕ ДЕЙСТВИЯ",
                         gridHint: "Щелчок — привязать • Перетаскивание — охватить • Прокрутка — переключить",
                         presetsHint: "Наведите на область для просмотра • Щелчок — привязать",
                         clickToSnapFormat: "%@ — щёлкните, чтобы привязать", releaseToSnapFormat: "%@ — отпустите, чтобы привязать",
                         left: "Слева", right: "Справа", center: "Центр", top: "Сверху", bottom: "Снизу",
                         middle: "Середина", centerLeft: "Центр-слева", centerRight: "Центр-справа",
                         upperCenter: "Верх-центр", lowerCenter: "Низ-центр", middleShort: "Сер.",
                         bottomShort: "Низ", col: "Ст.", row: "Стр.", zone: "Зона", halfFormat: "%@ 1/2",
                         cornerFormat: "%1$@ %2$@", primaryFormat: "Основное %@", sideFormat: "Боковое %@",
                         stackFormat: "Стопка %@", threeColumns: "3 столбца", quarters: "Четверти 2×2",
                         mainStack: "Основное + стопка")
        case .es:
            return .init(maximize: "Maximizar",
                         centerWindow: "Centrar", prevDisplay: "Pantalla anterior", nextDisplay: "Pantalla siguiente",
                         restore: "Restaurar tamaño anterior", quickActions: "ACCIONES RÁPIDAS",
                         gridHint: "Clic para ajustar • Arrastra para abarcar • Desplázate para cambiar",
                         presetsHint: "Pasa el puntero por un panel para previsualizar • Clic para ajustar",
                         clickToSnapFormat: "%@ — Clic para ajustar", releaseToSnapFormat: "%@ — Suelta para ajustar",
                         left: "Izquierda", right: "Derecha", center: "Centro", top: "Arriba", bottom: "Abajo",
                         middle: "Medio", centerLeft: "Centro-izquierda", centerRight: "Centro-derecha",
                         upperCenter: "Centro superior", lowerCenter: "Centro inferior", middleShort: "Medio",
                         bottomShort: "Abajo", col: "Col.", row: "Fila", zone: "Zona", halfFormat: "%@ 1/2",
                         cornerFormat: "%1$@ %2$@", primaryFormat: "%@ principal", sideFormat: "%@ lateral",
                         stackFormat: "Pila %@", threeColumns: "3 columnas", quarters: "Cuartos 2×2",
                         mainStack: "Principal + pila")
        case .sk:
            return .init(maximize: "Maximalizovať",
                         centerWindow: "Na stred", prevDisplay: "Predch. displej", nextDisplay: "Ďalší displej",
                         restore: "Obnoviť predošlú veľkosť", quickActions: "RÝCHLE AKCIE",
                         gridHint: "Kliknutím prichytíte • Potiahnutím roztiahnete • Posúvaním prepnete",
                         presetsHint: "Podržte ukazovateľ nad časťou pre náhľad • Kliknutím prichytíte",
                         clickToSnapFormat: "%@ — kliknutím prichytíte", releaseToSnapFormat: "%@ — uvoľnením prichytíte",
                         left: "Vľavo", right: "Vpravo", center: "Stred", top: "Hore", bottom: "Dole",
                         middle: "Stred", centerLeft: "Stred-vľavo", centerRight: "Stred-vpravo",
                         upperCenter: "Horný stred", lowerCenter: "Dolný stred", middleShort: "Stred",
                         bottomShort: "Dole", col: "Stĺp.", row: "Riad.", zone: "Zóna", halfFormat: "%@ 1/2",
                         cornerFormat: "%1$@ %2$@", primaryFormat: "Hlavné %@", sideFormat: "Bočné %@",
                         stackFormat: "Stoh %@", threeColumns: "3 stĺpce", quarters: "Štvrtiny 2×2",
                         mainStack: "Hlavné + stoh")
        case .de:
            return .init(maximize: "Maximieren",
                         centerWindow: "Zentrieren", prevDisplay: "Vorh. Display", nextDisplay: "Nächstes Display",
                         restore: "Vorherige Größe wiederherstellen", quickActions: "SCHNELLAKTIONEN",
                         gridHint: "Klicken zum Anordnen • Ziehen zum Aufspannen • Scrollen zum Wechseln",
                         presetsHint: "Bereich überfahren für Vorschau • Klicken zum Anordnen",
                         clickToSnapFormat: "%@ — Klicken zum Anordnen", releaseToSnapFormat: "%@ — Loslassen zum Anordnen",
                         left: "Links", right: "Rechts", center: "Mitte", top: "Oben", bottom: "Unten",
                         middle: "Mitte", centerLeft: "Mitte links", centerRight: "Mitte rechts",
                         upperCenter: "Oben Mitte", lowerCenter: "Unten Mitte", middleShort: "Mitte",
                         bottomShort: "Unten", col: "Sp.", row: "Z.", zone: "Bereich", halfFormat: "%@ 1/2",
                         cornerFormat: "%1$@ %2$@", primaryFormat: "Haupt %@", sideFormat: "Seite %@",
                         stackFormat: "Stapel %@", threeColumns: "3 Spalten", quarters: "2×2-Viertel",
                         mainStack: "Haupt + Stapel")
        case .fr:
            return .init(maximize: "Agrandir",
                         centerWindow: "Centrer", prevDisplay: "Écran préc.", nextDisplay: "Écran suiv.",
                         restore: "Rétablir la taille précédente", quickActions: "ACTIONS RAPIDES",
                         gridHint: "Cliquez pour ancrer • Glissez pour étendre • Faites défiler pour changer",
                         presetsHint: "Survolez une zone pour l’aperçu • Cliquez pour ancrer",
                         clickToSnapFormat: "%@ — Cliquez pour ancrer", releaseToSnapFormat: "%@ — Relâchez pour ancrer",
                         left: "Gauche", right: "Droite", center: "Centre", top: "Haut", bottom: "Bas",
                         middle: "Milieu", centerLeft: "Centre gauche", centerRight: "Centre droit",
                         upperCenter: "Centre haut", lowerCenter: "Centre bas", middleShort: "Milieu",
                         bottomShort: "Bas", col: "Col.", row: "Lig.", zone: "Zone", halfFormat: "%@ 1/2",
                         cornerFormat: "%1$@ %2$@", primaryFormat: "%@ principal", sideFormat: "%@ latéral",
                         stackFormat: "Pile %@", threeColumns: "3 colonnes", quarters: "Quarts 2×2",
                         mainStack: "Principal + pile")
        case .it:
            return .init(maximize: "Ingrandisci",
                         centerWindow: "Centra", prevDisplay: "Monitor prec.", nextDisplay: "Monitor succ.",
                         restore: "Ripristina dimensioni precedenti", quickActions: "AZIONI RAPIDE",
                         gridHint: "Clic per agganciare • Trascina per estendere • Scorri per cambiare",
                         presetsHint: "Passa sopra un riquadro per l’anteprima • Clic per agganciare",
                         clickToSnapFormat: "%@ — Clic per agganciare", releaseToSnapFormat: "%@ — Rilascia per agganciare",
                         left: "Sinistra", right: "Destra", center: "Centro", top: "Alto", bottom: "Basso",
                         middle: "Mezzo", centerLeft: "Centro-sinistra", centerRight: "Centro-destra",
                         upperCenter: "Centro alto", lowerCenter: "Centro basso", middleShort: "Mezzo",
                         bottomShort: "Basso", col: "Col.", row: "Riga", zone: "Zona", halfFormat: "%@ 1/2",
                         cornerFormat: "%1$@ %2$@", primaryFormat: "%@ principale", sideFormat: "%@ laterale",
                         stackFormat: "Pila %@", threeColumns: "3 colonne", quarters: "Quarti 2×2",
                         mainStack: "Principale + pila")
        case .ja:
            return .init(maximize: "最大化",
                         centerWindow: "中央に配置", prevDisplay: "前のディスプレイ", nextDisplay: "次のディスプレイ",
                         restore: "前のサイズに戻す", quickActions: "クイックアクション",
                         gridHint: "クリックでスナップ・ドラッグで範囲指定・スクロールで切り替え",
                         presetsHint: "ペインにポインタを合わせてプレビュー・クリックでスナップ",
                         clickToSnapFormat: "%@ — クリックでスナップ", releaseToSnapFormat: "%@ — 離してスナップ",
                         left: "左", right: "右", center: "中央", top: "上", bottom: "下",
                         middle: "中段", centerLeft: "中央左", centerRight: "中央右",
                         upperCenter: "上中央", lowerCenter: "下中央", middleShort: "中段",
                         bottomShort: "下", col: "列", row: "行", zone: "ゾーン", halfFormat: "%@ 1/2",
                         cornerFormat: "%2$@%1$@", primaryFormat: "メイン%@", sideFormat: "サイド%@",
                         stackFormat: "%@スタック", threeColumns: "3列", quarters: "2×2の4分割",
                         mainStack: "メイン + スタック")
        case .ko:
            return .init(maximize: "최대화",
                         centerWindow: "가운데", prevDisplay: "이전 디스플레이", nextDisplay: "다음 디스플레이",
                         restore: "이전 크기로 복원", quickActions: "빠른 동작",
                         gridHint: "클릭해 스냅 • 드래그해 범위 지정 • 스크롤해 전환",
                         presetsHint: "영역에 포인터를 올려 미리보기 • 클릭해 스냅",
                         clickToSnapFormat: "%@ — 클릭해 스냅", releaseToSnapFormat: "%@ — 놓아서 스냅",
                         left: "왼쪽", right: "오른쪽", center: "가운데", top: "위", bottom: "아래",
                         middle: "중간", centerLeft: "가운데 왼쪽", centerRight: "가운데 오른쪽",
                         upperCenter: "위 가운데", lowerCenter: "아래 가운데", middleShort: "중간",
                         bottomShort: "아래", col: "열", row: "행", zone: "영역", halfFormat: "%@ 1/2",
                         cornerFormat: "%2$@ %1$@", primaryFormat: "메인 %@", sideFormat: "보조 %@",
                         stackFormat: "%@ 스택", threeColumns: "3열", quarters: "2×2 4분할",
                         mainStack: "메인 + 스택")
        case .zhHans:
            return .init(maximize: "最大化",
                         centerWindow: "居中", prevDisplay: "上一个显示器", nextDisplay: "下一个显示器",
                         restore: "恢复之前的大小", quickActions: "快捷操作",
                         gridHint: "点按吸附 • 拖移跨越 • 滚动切换",
                         presetsHint: "悬停区域预览 • 点按吸附",
                         clickToSnapFormat: "%@ — 点按吸附", releaseToSnapFormat: "%@ — 松开吸附",
                         left: "左", right: "右", center: "中", top: "上", bottom: "下",
                         middle: "中间", centerLeft: "中左", centerRight: "中右",
                         upperCenter: "中上", lowerCenter: "中下", middleShort: "中",
                         bottomShort: "下", col: "列", row: "行", zone: "区域", halfFormat: "%@ 1/2",
                         cornerFormat: "%2$@%1$@", primaryFormat: "主%@", sideFormat: "侧%@",
                         stackFormat: "%@堆叠", threeColumns: "3 列", quarters: "2×2 四分",
                         mainStack: "主 + 堆叠")
        case .zhTW, .zhHK:
            return .init(maximize: "最大化",
                         centerWindow: "置中", prevDisplay: "上一個顯示器", nextDisplay: "下一個顯示器",
                         restore: "恢復之前的大小", quickActions: "快速動作",
                         gridHint: "點按吸附 • 拖移跨越 • 捲動切換",
                         presetsHint: "停留區域預覽 • 點按吸附",
                         clickToSnapFormat: "%@ — 點按吸附", releaseToSnapFormat: "%@ — 放開吸附",
                         left: "左", right: "右", center: "中", top: "上", bottom: "下",
                         middle: "中間", centerLeft: "中左", centerRight: "中右",
                         upperCenter: "中上", lowerCenter: "中下", middleShort: "中",
                         bottomShort: "下", col: "欄", row: "列", zone: "區域", halfFormat: "%@ 1/2",
                         cornerFormat: "%2$@%1$@", primaryFormat: "主%@", sideFormat: "側%@",
                         stackFormat: "%@堆疊", threeColumns: "3 欄", quarters: "2×2 四分",
                         mainStack: "主 + 堆疊")
        case .uk:
            return .init(maximize: "Розгорнути",
                         centerWindow: "По центру", prevDisplay: "Попер. дисплей", nextDisplay: "Наст. дисплей",
                         restore: "Повернути попередній розмір", quickActions: "ШВИДКІ ДІЇ",
                         gridHint: "Клацання — прив’язати • Перетягування — охопити • Прокручування — перемкнути",
                         presetsHint: "Наведіть на область для перегляду • Клацання — прив’язати",
                         clickToSnapFormat: "%@ — клацніть, щоб прив’язати", releaseToSnapFormat: "%@ — відпустіть, щоб прив’язати",
                         left: "Ліворуч", right: "Праворуч", center: "Центр", top: "Згори", bottom: "Знизу",
                         middle: "Середина", centerLeft: "Центр-ліворуч", centerRight: "Центр-праворуч",
                         upperCenter: "Верх-центр", lowerCenter: "Низ-центр", middleShort: "Сер.",
                         bottomShort: "Низ", col: "Ст.", row: "Ряд.", zone: "Зона", halfFormat: "%@ 1/2",
                         cornerFormat: "%1$@ %2$@", primaryFormat: "Основне %@", sideFormat: "Бічне %@",
                         stackFormat: "Стос %@", threeColumns: "3 стовпці", quarters: "Чверті 2×2",
                         mainStack: "Основне + стос")
        }
    }

    static let enUS = WindowSnappingPanelStrings(
        maximize: "Maximize",
        centerWindow: "Center", prevDisplay: "Prev Display", nextDisplay: "Next Display",
        restore: "Restore Previous Size", quickActions: "QUICK ACTIONS",
        gridHint: "Click to snap • Drag to span • Scroll to cycle",
        presetsHint: "Hover any pane to preview • Click to snap",
        clickToSnapFormat: "%@ — Click to snap", releaseToSnapFormat: "%@ — Release to snap",
        left: "Left", right: "Right", center: "Center", top: "Top", bottom: "Bottom",
        middle: "Middle", centerLeft: "Center-Left", centerRight: "Center-Right",
        upperCenter: "Upper-Center", lowerCenter: "Lower-Center", middleShort: "Mid",
        bottomShort: "Btm", col: "Col", row: "Row", zone: "Zone", halfFormat: "%@ Half",
        cornerFormat: "%1$@ %2$@", primaryFormat: "Primary %@", sideFormat: "Side %@",
        stackFormat: "%@ Stack", threeColumns: "3 Columns", quarters: "2×2 Quarters",
        mainStack: "Main + Stack")
}
