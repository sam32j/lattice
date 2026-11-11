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

/// Labels added by the consolidated screenshot/recording options pages.
/// Keep the key order and each language row in sync; none fall back to English.
enum CaptureOptionsStrings {
    enum Key: Int, CaseIterable {
        case recordingBehavior
        case playStartSound
        case keepRecordings
        case defaultRecordingBehavior
        case afterRecording
        case copyRecording
        case saveRecording
        case addToFileCache
        case openEditorWithRecording
        case videoExportFormat
        case exportQuality
        case low
        case medium
        case raw
        case exportFrameRate
        case gifExportFormat
        case gifQuality
        case standard
        case best
        case gifFrameRate
        case recordSystemSound
        case recordMicrophone
        case recordCamera
        case recordKeyboardEvents
        case addZoomAutomatically
        case screenshotExportFormat
        case keyboardShortcuts
        case screenshotFullScreen
    }

    static func text(_ key: Key, _ language: AppLanguage) -> String {
        let values: [String]
        switch language {
        case .enUS:
            values = [
                "Recording behavior", "Play start sound", "Keep recordings",
                "Default recording behavior", "After recording", "Copy recording to clipboard",
                "Save recording to default location", "Add recording to File Cache", "Open editor with recording",
                "Video export & format", "Export quality", "Low",
                "Medium", "Raw", "Export frame rate",
                "GIF export & format", "GIF quality", "Standard",
                "Best", "GIF frame rate", "Record system sound",
                "Record microphone", "Record camera", "Record keyboard events",
                "Add zoom effect automatically", "Export & Format", "Keyboard shortcuts",
                "Screenshot Full Screen"
            ]
        case .ptBR:
            values = [
                "Comportamento da gravação", "Reproduzir som de início", "Manter gravações",
                "Comportamento padrão da gravação", "Após a gravação", "Copiar gravação para a área de transferência",
                "Salvar gravação no local padrão", "Adicionar gravação ao Cache de Arquivos", "Abrir editor com a gravação",
                "Exportação e formato de vídeo", "Qualidade de exportação", "Baixa",
                "Média", "Original", "Taxa de quadros da exportação",
                "Exportação e formato de GIF", "Qualidade do GIF", "Padrão",
                "Melhor", "Taxa de quadros do GIF", "Gravar som do sistema",
                "Gravar microfone", "Gravar câmera", "Gravar eventos do teclado",
                "Adicionar zoom automaticamente", "Exportação e formato", "Atalhos de teclado",
                "Captura de tela inteira"
            ]
        case .tr:
            values = [
                "Kayıt davranışı", "Başlangıç sesi çal", "Kayıtları sakla",
                "Varsayılan kayıt davranışı", "Kayıttan sonra", "Kaydı panoya kopyala",
                "Kaydı varsayılan konuma kaydet", "Kaydı Dosya Önbelleğine ekle", "Kaydı düzenleyicide aç",
                "Video dışa aktarma ve biçim", "Dışa aktarma kalitesi", "Düşük",
                "Orta", "Ham", "Dışa aktarma kare hızı",
                "GIF dışa aktarma ve biçim", "GIF kalitesi", "Standart",
                "En iyi", "GIF kare hızı", "Sistem sesini kaydet",
                "Mikrofonu kaydet", "Kamerayı kaydet", "Klavye olaylarını kaydet",
                "Yakınlaştırma efektini otomatik ekle", "Dışa aktarma ve biçim", "Klavye kısayolları",
                "Tam ekran görüntüsü al"
            ]
        case .ru:
            values = [
                "Параметры записи", "Воспроизводить звук начала", "Хранить записи",
                "Поведение записи по умолчанию", "После записи", "Копировать запись в буфер обмена",
                "Сохранять запись в папку по умолчанию", "Добавлять запись в кэш файлов", "Открывать запись в редакторе",
                "Экспорт видео и формат", "Качество экспорта", "Низкое",
                "Среднее", "Исходное", "Частота кадров экспорта",
                "Экспорт GIF и формат", "Качество GIF", "Стандартное",
                "Лучшее", "Частота кадров GIF", "Записывать системный звук",
                "Записывать микрофон", "Записывать камеру", "Записывать события клавиатуры",
                "Автоматически добавлять эффект увеличения", "Экспорт и формат", "Сочетания клавиш",
                "Снимок всего экрана"
            ]
        case .es:
            values = [
                "Comportamiento de grabación", "Reproducir sonido de inicio", "Conservar grabaciones",
                "Comportamiento predeterminado de grabación", "Después de grabar", "Copiar grabación al portapapeles",
                "Guardar grabación en la ubicación predeterminada", "Añadir grabación a la caché de archivos", "Abrir grabación en el editor",
                "Exportación y formato de vídeo", "Calidad de exportación", "Baja",
                "Media", "Original", "Frecuencia de fotogramas de exportación",
                "Exportación y formato de GIF", "Calidad del GIF", "Estándar",
                "Óptima", "Frecuencia de fotogramas del GIF", "Grabar sonido del sistema",
                "Grabar micrófono", "Grabar cámara", "Grabar eventos del teclado",
                "Añadir efecto de zoom automáticamente", "Exportación y formato", "Atajos de teclado",
                "Captura de pantalla completa"
            ]
        case .sk:
            values = [
                "Správanie nahrávania", "Prehrať zvuk spustenia", "Uchovávať nahrávky",
                "Predvolené správanie nahrávania", "Po nahrávaní", "Kopírovať nahrávku do schránky",
                "Uložiť nahrávku do predvoleného umiestnenia", "Pridať nahrávku do vyrovnávacej pamäte súborov", "Otvoriť nahrávku v editore",
                "Export videa a formát", "Kvalita exportu", "Nízka",
                "Stredná", "Pôvodná", "Snímková frekvencia exportu",
                "Export GIF a formát", "Kvalita GIF", "Štandardná",
                "Najlepšia", "Snímková frekvencia GIF", "Nahrávať systémový zvuk",
                "Nahrávať mikrofón", "Nahrávať kameru", "Nahrávať udalosti klávesnice",
                "Automaticky pridávať priblíženie", "Export a formát", "Klávesové skratky",
                "Snímka celej obrazovky"
            ]
        case .de:
            values = [
                "Aufnahmeverhalten", "Startton abspielen", "Aufnahmen behalten",
                "Standard-Aufnahmeverhalten", "Nach der Aufnahme", "Aufnahme in die Zwischenablage kopieren",
                "Aufnahme am Standardspeicherort sichern", "Aufnahme zum Datei-Cache hinzufügen", "Aufnahme im Editor öffnen",
                "Videoexport und Format", "Exportqualität", "Niedrig",
                "Mittel", "Original", "Export-Bildrate",
                "GIF-Export und Format", "GIF-Qualität", "Standard",
                "Beste", "GIF-Bildrate", "Systemton aufnehmen",
                "Mikrofon aufnehmen", "Kamera aufnehmen", "Tastaturereignisse aufzeichnen",
                "Zoomeffekt automatisch hinzufügen", "Export und Format", "Tastaturkurzbefehle",
                "Vollbild-Screenshot"
            ]
        case .fr:
            values = [
                "Comportement de l’enregistrement", "Jouer le son de démarrage", "Conserver les enregistrements",
                "Comportement d’enregistrement par défaut", "Après l’enregistrement", "Copier l’enregistrement dans le presse-papiers",
                "Enregistrer dans le dossier par défaut", "Ajouter l’enregistrement au cache de fichiers", "Ouvrir l’enregistrement dans l’éditeur",
                "Export vidéo et format", "Qualité d’export", "Faible",
                "Moyenne", "Originale", "Fréquence d’images à l’export",
                "Export GIF et format", "Qualité du GIF", "Standard",
                "Optimale", "Fréquence d’images du GIF", "Enregistrer le son du système",
                "Enregistrer le microphone", "Enregistrer la caméra", "Enregistrer les événements du clavier",
                "Ajouter automatiquement un effet de zoom", "Export et format", "Raccourcis clavier",
                "Capture de tout l’écran"
            ]
        case .it:
            values = [
                "Comportamento registrazione", "Riproduci suono di avvio", "Conserva le registrazioni",
                "Comportamento predefinito di registrazione", "Dopo la registrazione", "Copia la registrazione negli appunti",
                "Salva la registrazione nella posizione predefinita", "Aggiungi la registrazione alla cache dei file", "Apri la registrazione nell’editor",
                "Esportazione video e formato", "Qualità di esportazione", "Bassa",
                "Media", "Originale", "Frequenza fotogrammi di esportazione",
                "Esportazione GIF e formato", "Qualità GIF", "Standard",
                "Ottima", "Frequenza fotogrammi GIF", "Registra audio di sistema",
                "Registra microfono", "Registra fotocamera", "Registra eventi della tastiera",
                "Aggiungi automaticamente effetto zoom", "Esportazione e formato", "Scorciatoie da tastiera",
                "Screenshot schermo intero"
            ]
        case .ja:
            values = [
                "録画の動作", "開始音を再生", "録画の保存件数",
                "デフォルトの録画動作", "録画後", "録画をクリップボードにコピー",
                "録画をデフォルトの場所に保存", "録画をファイルキャッシュに追加", "録画をエディタで開く",
                "動画の書き出しと形式", "書き出し品質", "低",
                "中", "オリジナル", "書き出しフレームレート",
                "GIFの書き出しと形式", "GIF品質", "標準",
                "最高", "GIFフレームレート", "システム音声を録音",
                "マイク音声を録音", "カメラを録画", "キー入力イベントを記録",
                "ズーム効果を自動追加", "書き出しと形式", "キーボードショートカット",
                "画面全体のスクリーンショット"
            ]
        case .ko:
            values = [
                "녹화 동작", "시작 소리 재생", "녹화 보관 개수",
                "기본 녹화 동작", "녹화 후", "녹화를 클립보드에 복사",
                "녹화를 기본 위치에 저장", "녹화를 파일 캐시에 추가", "편집기에서 녹화 열기",
                "동영상 내보내기 및 형식", "내보내기 품질", "낮음",
                "중간", "원본", "내보내기 프레임 속도",
                "GIF 내보내기 및 형식", "GIF 품질", "표준",
                "최고", "GIF 프레임 속도", "시스템 소리 녹음",
                "마이크 녹음", "카메라 녹화", "키보드 이벤트 기록",
                "확대 효과 자동 추가", "내보내기 및 형식", "키보드 단축키",
                "전체 화면 스크린샷"
            ]
        case .uk:
            values = [
                "Поведінка запису", "Відтворювати звук початку", "Зберігати записи",
                "Типова поведінка запису", "Після запису", "Копіювати запис до буфера обміну",
                "Зберігати запис до типової папки", "Додавати запис до кешу файлів", "Відкривати запис у редакторі",
                "Експорт відео та формат", "Якість експорту", "Низька",
                "Середня", "Оригінальна", "Частота кадрів експорту",
                "Експорт GIF та формат", "Якість GIF", "Стандартна",
                "Найкраща", "Частота кадрів GIF", "Записувати системний звук",
                "Записувати мікрофон", "Записувати камеру", "Записувати події клавіатури",
                "Автоматично додавати ефект масштабування", "Експорт і формат", "Клавіатурні скорочення",
                "Знімок усього екрана"
            ]
        case .zhHans:
            values = [
                "录制行为", "播放开始提示音", "保留录制",
                "默认录制行为", "录制后", "将录制复制到剪贴板",
                "将录制保存到默认位置", "将录制添加到文件缓存", "使用编辑器打开录制",
                "视频导出与格式", "导出质量", "低",
                "中", "原始", "导出帧率",
                "GIF 导出与格式", "GIF 质量", "标准",
                "最佳", "GIF 帧率", "录制系统声音",
                "录制麦克风", "录制摄像头", "记录键盘事件",
                "自动添加缩放效果", "导出与格式", "键盘快捷键",
                "全屏截图"
            ]
        case .zhTW:
            values = [
                "錄製行為", "播放開始提示音", "保留錄製內容",
                "預設錄製行為", "錄製後", "將錄製內容複製到剪貼簿",
                "將錄製內容儲存至預設位置", "將錄製內容加入檔案快取", "使用編輯器開啟錄製內容",
                "影片匯出與格式", "匯出品質", "低",
                "中", "原始", "匯出影格率",
                "GIF 匯出與格式", "GIF 品質", "標準",
                "最佳", "GIF 影格率", "錄製系統聲音",
                "錄製麥克風", "錄製攝影機", "記錄鍵盤事件",
                "自動加入縮放效果", "匯出與格式", "鍵盤快速鍵",
                "全螢幕截圖"
            ]
        case .zhHK:
            values = [
                "錄影行為", "播放開始提示音", "保留錄影",
                "預設錄影行為", "錄影後", "將錄影複製到剪貼簿",
                "將錄影儲存至預設位置", "將錄影加入檔案快取", "使用編輯器開啟錄影",
                "影片匯出與格式", "匯出品質", "低",
                "中", "原始", "匯出影格率",
                "GIF 匯出與格式", "GIF 品質", "標準",
                "最佳", "GIF 影格率", "錄製系統聲音",
                "錄製咪高峰", "錄製攝影機", "記錄鍵盤事件",
                "自動加入縮放效果", "匯出與格式", "鍵盤快捷鍵",
                "全螢幕截圖"
            ]
        }
        assert(values.count == Key.allCases.count, "Capture localization table mismatch")
        return values[key.rawValue]
    }

    /// One label for both screenshot and recording Quick Links. Links remain
    /// active until their expiration even when creating new links is disabled.
    static func activeLinksLabel(_ count: Int, _ language: AppLanguage) -> String {
        let single = count == 1
        let form: String
        switch language {
        case .enUS: form = single ? "%d active link" : "%d active links"
        case .ptBR: form = single ? "%d link ativo" : "%d links ativos"
        case .tr: form = "%d etkin bağlantı"
        case .ru:
            let few = (2...4).contains(count % 10) && !(12...14).contains(count % 100)
            let one = count % 10 == 1 && count % 100 != 11
            form = one ? "%d активная ссылка" : (few ? "%d активные ссылки" : "%d активных ссылок")
        case .es: form = single ? "%d enlace activo" : "%d enlaces activos"
        case .sk:
            let few = (2...4).contains(count)
            form = single ? "%d aktívny odkaz" : (few ? "%d aktívne odkazy" : "%d aktívnych odkazov")
        case .de: form = single ? "%d aktiver Link" : "%d aktive Links"
        case .fr: form = single ? "%d lien actif" : "%d liens actifs"
        case .it: form = single ? "%d link attivo" : "%d link attivi"
        case .ja: form = "%d 件の有効なリンク"
        case .ko: form = "활성 링크 %d개"
        case .uk:
            let few = (2...4).contains(count % 10) && !(12...14).contains(count % 100)
            let one = count % 10 == 1 && count % 100 != 11
            form = one ? "%d активне посилання" : (few ? "%d активні посилання" : "%d активних посилань")
        case .zhHans: form = "%d 个有效链接"
        case .zhTW, .zhHK: form = "%d 個有效連結"
        }
        return String(format: form, count)
    }
}
