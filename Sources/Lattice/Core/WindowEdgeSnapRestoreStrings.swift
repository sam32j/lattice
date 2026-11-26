// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

struct WindowEdgeSnapRestoreStrings {
    let title: String
    let caption: String

    static func localized(_ language: AppLanguage) -> WindowEdgeSnapRestoreStrings {
        switch language {
        case .enUS: return .init(title: "Restore size when dragging a snapped window away", caption: "Drag a snapped window out of its place and it returns to the size it had before snapping, with the pointer kept at the same spot on its title bar. Apps where window layout is paused are skipped.")
        case .ptBR: return .init(title: "Restaurar o tamanho ao arrastar uma janela encaixada", caption: "Ao arrastar uma janela encaixada para fora do lugar, ela volta ao tamanho que tinha antes de encaixar, com o ponteiro na mesma posição da barra de título. Apps em que o layout de janelas está pausado ficam de fora.")
        case .tr: return .init(title: "Yerleştirilmiş pencere sürüklenince boyutu geri yükle", caption: "Yerleştirilmiş bir pencereyi yerinden sürüklediğinizde, yerleştirilmeden önceki boyutuna döner ve imleç başlık çubuğundaki aynı noktada kalır. Pencere yerleşiminin duraklatıldığı uygulamalar atlanır.")
        case .ru: return .init(title: "Возвращать размер при вытягивании привязанного окна", caption: "Если вытянуть привязанное окно из его места, оно вернётся к размеру, который был до привязки, а указатель останется в той же точке заголовка. Приложения, в которых раскладка окон приостановлена, пропускаются.")
        case .es: return .init(title: "Restaurar el tamaño al arrastrar una ventana ajustada", caption: "Al arrastrar una ventana ajustada fuera de su sitio, vuelve al tamaño que tenía antes de ajustarse y el puntero se mantiene en el mismo punto de la barra de título. Se omiten las apps en las que el diseño de ventanas está en pausa.")
        case .sk: return .init(title: "Obnoviť veľkosť pri odtiahnutí pritiahnutého okna", caption: "Keď pritiahnuté okno odtiahnete z jeho miesta, vráti sa na veľkosť, akú malo pred pritiahnutím, a ukazovateľ zostane na rovnakom mieste záhlavia. Aplikácie, v ktorých je rozloženie okien pozastavené, sa preskakujú.")
        case .de: return .init(title: "Größe beim Wegziehen eines eingerasteten Fensters wiederherstellen", caption: "Ziehst du ein eingerastetes Fenster von seinem Platz weg, erhält es die Größe zurück, die es vor dem Einrasten hatte, und der Zeiger bleibt an derselben Stelle der Titelleiste. Apps, in denen das Fensterlayout pausiert, bleiben außen vor.")
        case .fr: return .init(title: "Restaurer la taille en éloignant une fenêtre ancrée", caption: "Quand vous faites glisser une fenêtre ancrée hors de sa place, elle retrouve la taille qu’elle avait avant l’ancrage, et le pointeur reste au même endroit de la barre de titre. Les apps où la disposition des fenêtres est en pause sont exclues.")
        case .it: return .init(title: "Ripristina la dimensione trascinando via una finestra allineata", caption: "Se trascini una finestra allineata fuori dal suo posto, torna alla dimensione che aveva prima dell’allineamento e il puntatore resta nello stesso punto della barra del titolo. Le app in cui il layout finestre è sospeso vengono saltate.")
        case .ja: return .init(title: "スナップしたウインドウを引き離すと元のサイズに戻す", caption: "スナップしたウインドウをその位置からドラッグして離すと、スナップ前のサイズに戻り、ポインタはタイトルバー上の同じ位置に保たれます。ウインドウ配置を一時停止しているAppは対象外です。")
        case .ko: return .init(title: "맞춘 윈도우를 끌어내면 원래 크기로 복원", caption: "맞춰진 윈도우를 제자리에서 끌어내면 맞추기 전의 크기로 돌아가고, 포인터는 제목 막대의 같은 위치에 유지됩니다. 윈도우 정렬을 일시 정지한 앱은 건너뜁니다.")
        case .zhHans: return .init(title: "拖离贴靠的窗口时恢复原来大小", caption: "将贴靠的窗口拖离原位时，窗口会恢复为贴靠前的大小，指针保持在标题栏的同一位置。已暂停窗口布局的 App 不受影响。")
        case .zhTW: return .init(title: "拖離貼齊的視窗時還原原本大小", caption: "將貼齊的視窗拖離原位時，視窗會還原為貼齊前的大小，指標保持在標題列的同一位置。已暫停視窗排列的 App 不受影響。")
        case .zhHK: return .init(title: "拖離貼齊的視窗時還原原本大小", caption: "將貼齊的視窗拖離原位時，視窗會還原為貼齊前的大小，指標保持在標題列的同一位置。已暫停視窗排列嘅 App 唔受影響。")
        case .uk: return .init(title: "Повертати розмір, коли витягуєте прикріплене вікно", caption: "Якщо витягти прикріплене вікно з його місця, воно повернеться до розміру, який мало до прикріплення, а вказівник залишиться в тій самій точці заголовка. Програми, у яких розкладку вікон призупинено, пропускаються.")
        }
    }
}
