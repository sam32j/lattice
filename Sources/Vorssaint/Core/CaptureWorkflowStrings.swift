// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Labels shared by capture settings and the chooser. The counted guide uses a
/// heading ("Selected windows: N") so it remains grammatical for every count.
struct CaptureWorkflowStrings {
    let selection: String
    let magnifier: String
    let preview: String
    let destination: String
    let shutter: String
    let recording: String
    let audioEditor: String
    let export: String
    let immediate: String
    let recordSound: String
    let recentRecordings: String
    let unlimited: String
    let scroll: String
    let recordWindow: String
    let selectedWindowsFormat: String
    let shortcutUnavailable: String

    func selectedWindows(_ count: Int) -> String {
        String(format: selectedWindowsFormat, count)
    }

    static func localized(_ language: AppLanguage) -> Self {
        switch language {
        case .enUS:
            return .init(selection: "Selection & Capture", magnifier: "Magnifier", preview: "Preview & Pin",
                destination: "Save & Destination", shutter: "Play shutter sound", recording: "Recording",
                audioEditor: "Audio & Editor", export: "Save & Export", immediate: "Record immediately after selection",
                recordSound: "Play record sound", recentRecordings: "Recent recordings", unlimited: "Unlimited",
                scroll: "Scroll", recordWindow: "Click to record window",
                selectedWindowsFormat: "Selected windows: %d · Release Shift to capture",
                shortcutUnavailable: "Unavailable")
        case .ptBR:
            return .init(selection: "Seleção e captura", magnifier: "Lupa", preview: "Prévia e fixação",
                destination: "Salvar e destino", shutter: "Reproduzir som do obturador", recording: "Gravação",
                audioEditor: "Áudio e editor", export: "Salvar e exportar", immediate: "Gravar imediatamente após a seleção",
                recordSound: "Reproduzir som de gravação", recentRecordings: "Gravações recentes", unlimited: "Ilimitado",
                scroll: "Rolagem", recordWindow: "Clique para gravar a janela",
                selectedWindowsFormat: "Janelas selecionadas: %d · Solte Shift para capturar",
                shortcutUnavailable: "Atalho indisponível")
        case .tr:
            return .init(selection: "Seçim ve yakalama", magnifier: "Büyüteç", preview: "Önizleme ve sabitleme",
                destination: "Kaydetme ve hedef", shutter: "Deklanşör sesi çal", recording: "Kayıt",
                audioEditor: "Ses ve düzenleyici", export: "Kaydet ve dışa aktar", immediate: "Seçimden hemen sonra kaydet",
                recordSound: "Kayıt sesi çal", recentRecordings: "Son kayıtlar", unlimited: "Sınırsız",
                scroll: "Kaydır", recordWindow: "Pencereyi kaydetmek için tıklayın",
                selectedWindowsFormat: "Seçilen pencere sayısı: %d · Yakalamak için Shift tuşunu bırakın",
                shortcutUnavailable: "Kısayol kullanılamıyor")
        case .ru:
            return .init(selection: "Выбор и захват", magnifier: "Лупа", preview: "Просмотр и закрепление",
                destination: "Сохранение и папка", shutter: "Звук затвора", recording: "Запись",
                audioEditor: "Звук и редактор", export: "Сохранение и экспорт", immediate: "Записывать сразу после выбора",
                recordSound: "Звук записи", recentRecordings: "Последние записи", unlimited: "Без ограничений",
                scroll: "Прокрутка", recordWindow: "Нажмите для записи окна",
                selectedWindowsFormat: "Выбрано окон: %d · Отпустите Shift для захвата",
                shortcutUnavailable: "Сочетание недоступно")
        case .es:
            return .init(selection: "Selección y captura", magnifier: "Lupa", preview: "Vista previa y fijación",
                destination: "Guardar y destino", shutter: "Reproducir sonido del obturador", recording: "Grabación",
                audioEditor: "Audio y editor", export: "Guardar y exportar", immediate: "Grabar inmediatamente tras seleccionar",
                recordSound: "Reproducir sonido de grabación", recentRecordings: "Grabaciones recientes", unlimited: "Sin límite",
                scroll: "Desplazar", recordWindow: "Haz clic para grabar la ventana",
                selectedWindowsFormat: "Ventanas seleccionadas: %d · Suelta Mayús para capturar",
                shortcutUnavailable: "Atajo no disponible")
        case .sk:
            return .init(selection: "Výber a snímanie", magnifier: "Lupa", preview: "Náhľad a pripnutie",
                destination: "Uloženie a cieľ", shutter: "Prehrať zvuk uzávierky", recording: "Nahrávanie",
                audioEditor: "Zvuk a editor", export: "Uloženie a export", immediate: "Nahrávať ihneď po výbere",
                recordSound: "Prehrať zvuk nahrávania", recentRecordings: "Nedávne nahrávky", unlimited: "Bez obmedzenia",
                scroll: "Posúvanie", recordWindow: "Kliknutím nahrajte okno",
                selectedWindowsFormat: "Počet vybraných okien: %d · Uvoľnením Shift nasnímate",
                shortcutUnavailable: "Skratka nedostupná")
        case .de:
            return .init(selection: "Auswahl und Aufnahme", magnifier: "Lupe", preview: "Vorschau und Anheften",
                destination: "Speichern und Ziel", shutter: "Auslöseton abspielen", recording: "Aufnahme",
                audioEditor: "Audio und Editor", export: "Speichern und Exportieren", immediate: "Sofort nach der Auswahl aufnehmen",
                recordSound: "Aufnahmeton abspielen", recentRecordings: "Letzte Aufnahmen", unlimited: "Unbegrenzt",
                scroll: "Scrollen", recordWindow: "Zum Aufnehmen des Fensters klicken",
                selectedWindowsFormat: "Ausgewählte Fenster: %d · Umschalttaste zum Aufnehmen loslassen",
                shortcutUnavailable: "Kurzbefehl nicht verfügbar")
        case .fr:
            return .init(selection: "Sélection et capture", magnifier: "Loupe", preview: "Aperçu et épinglage",
                destination: "Enregistrement et destination", shutter: "Jouer le son de l’obturateur", recording: "Enregistrement",
                audioEditor: "Audio et éditeur", export: "Enregistrement et export", immediate: "Enregistrer dès la sélection",
                recordSound: "Jouer le son d’enregistrement", recentRecordings: "Enregistrements récents", unlimited: "Illimité",
                scroll: "Défiler", recordWindow: "Cliquez pour enregistrer la fenêtre",
                selectedWindowsFormat: "Fenêtres sélectionnées : %d · Relâchez Maj pour capturer",
                shortcutUnavailable: "Raccourci indisponible")
        case .it:
            return .init(selection: "Selezione e cattura", magnifier: "Lente", preview: "Anteprima e fissaggio",
                destination: "Salvataggio e destinazione", shutter: "Riproduci suono dell’otturatore", recording: "Registrazione",
                audioEditor: "Audio ed editor", export: "Salvataggio ed esportazione", immediate: "Registra subito dopo la selezione",
                recordSound: "Riproduci suono di registrazione", recentRecordings: "Registrazioni recenti", unlimited: "Illimitate",
                scroll: "Scorri", recordWindow: "Fai clic per registrare la finestra",
                selectedWindowsFormat: "Finestre selezionate: %d · Rilascia Maiusc per catturare",
                shortcutUnavailable: "Scorciatoia non disponibile")
        case .ja:
            return .init(selection: "選択とキャプチャ", magnifier: "拡大鏡", preview: "プレビューとピン留め",
                destination: "保存と保存先", shutter: "シャッター音を再生", recording: "録画",
                audioEditor: "音声とエディタ", export: "保存と書き出し", immediate: "選択後すぐに録画",
                recordSound: "録画音を再生", recentRecordings: "最近の録画", unlimited: "無制限",
                scroll: "スクロール", recordWindow: "クリックしてウインドウを録画",
                selectedWindowsFormat: "選択したウインドウ数：%d · Shiftを離して撮影",
                shortcutUnavailable: "ショートカット利用不可")
        case .ko:
            return .init(selection: "선택 및 캡처", magnifier: "확대경", preview: "미리보기 및 고정",
                destination: "저장 및 위치", shutter: "셔터 소리 재생", recording: "녹화",
                audioEditor: "오디오 및 편집기", export: "저장 및 내보내기", immediate: "선택 직후 녹화",
                recordSound: "녹화 소리 재생", recentRecordings: "최근 녹화", unlimited: "무제한",
                scroll: "스크롤", recordWindow: "클릭하여 창 녹화",
                selectedWindowsFormat: "선택한 창 수: %d · Shift를 놓아 캡처",
                shortcutUnavailable: "단축키 사용 불가")
        case .uk:
            return .init(selection: "Вибір і захоплення", magnifier: "Лупа", preview: "Перегляд і закріплення",
                destination: "Збереження й папка", shutter: "Звук затвора", recording: "Запис",
                audioEditor: "Звук і редактор", export: "Збереження й експорт", immediate: "Записувати відразу після вибору",
                recordSound: "Звук запису", recentRecordings: "Останні записи", unlimited: "Без обмежень",
                scroll: "Прокручування", recordWindow: "Натисніть для запису вікна",
                selectedWindowsFormat: "Вибрано вікон: %d · Відпустіть Shift для захоплення",
                shortcutUnavailable: "Скорочення недоступне")
        case .zhHans:
            return .init(selection: "选取与捕获", magnifier: "放大镜", preview: "预览与固定",
                destination: "存储与目的地", shutter: "播放快门声", recording: "录制",
                audioEditor: "音频与编辑", export: "存储与导出", immediate: "选取后立即录制",
                recordSound: "播放录制提示音", recentRecordings: "最近录制", unlimited: "不限",
                scroll: "滚动", recordWindow: "点击录制窗口",
                selectedWindowsFormat: "已选窗口：%d · 松开 Shift 捕获",
                shortcutUnavailable: "快捷键不可用")
        case .zhTW:
            return .init(selection: "選取與擷取", magnifier: "放大鏡", preview: "預覽與固定",
                destination: "儲存與目的地", shutter: "播放快門聲", recording: "錄製",
                audioEditor: "音訊與編輯", export: "儲存與匯出", immediate: "選取後立即錄製",
                recordSound: "播放錄製提示音", recentRecordings: "最近錄製", unlimited: "不限",
                scroll: "捲動", recordWindow: "點選錄製視窗",
                selectedWindowsFormat: "已選視窗：%d · 放開 Shift 擷取",
                shortcutUnavailable: "快速鍵無法使用")
        case .zhHK:
            return .init(selection: "選取與擷取", magnifier: "放大鏡", preview: "預覽與固定",
                destination: "儲存與目的地", shutter: "播放快門聲", recording: "錄製",
                audioEditor: "音訊與編輯", export: "儲存與匯出", immediate: "選取後立即錄製",
                recordSound: "播放錄製提示音", recentRecordings: "最近錄製", unlimited: "不限",
                scroll: "捲動", recordWindow: "按一下錄製視窗",
                selectedWindowsFormat: "已選視窗：%d · 放開 Shift 擷取",
                shortcutUnavailable: "快速鍵無法使用")
        }
    }
}
