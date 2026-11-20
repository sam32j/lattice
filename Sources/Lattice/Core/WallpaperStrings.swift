// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Wallpaper panel strings.
struct WallpaperFeatureStrings {
    let pageTitle: String
    let enableManagement: String
    let hubDescription: String
    /// Sentence form for the panel layout list, whose descriptions end in a stop.
    let panelDescription: String
    let filterAll: String
    let filterOwn: String
    let filterApple: String
    let applyAllDisplays: String
    let addFolder: String
    let removeAdded: String
    let sourceMenu: String
    let manageWallpapers: String
    let importedFolders: String
    let noFolders: String
    let sourceUnavailable: String
    let addImagePrompt: String
    let addFolderPrompt: String
    let emptyAll: String
    let emptyOwn: String
    let emptyOwnHint: String
    let emptyApple: String
    let download: String
    let downloading: String
    let downloadFailed: String
    let applyFailed: String
    let previousPage: String
    let nextPage: String
}

extension FeatureStrings {
    static func wallpaper(_ language: AppLanguage) -> WallpaperFeatureStrings {
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
        case .uk: return .uk
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        }
    }
}

extension WallpaperFeatureStrings {
    static let enUS = WallpaperFeatureStrings(
        pageTitle: "Wallpaper",
        enableManagement: "Wallpaper Management",
        hubDescription: "Pick a still wallpaper without opening System Settings",
        panelDescription: "Pick a still wallpaper without opening System Settings.",
        filterAll: "All",
        filterOwn: "Imported",
        filterApple: "Apple",
        applyAllDisplays: "Show on all Spaces",
        addFolder: "Add Folder…",
        removeAdded: "Remove",
        sourceMenu: "Source",
        manageWallpapers: "Manage Wallpapers…",
        importedFolders: "Imported Folders",
        noFolders: "No Folders",
        sourceUnavailable: "Unavailable",
        addImagePrompt: "Choose images to keep in Lattice’s wallpaper list",
        addFolderPrompt: "Choose a folder of images to keep in Lattice’s wallpaper list",
        emptyAll: "No wallpapers found",
        emptyOwn: "No imported pictures",
        emptyOwnHint: "Pictures in folders you add appear here.",
        emptyApple: "No Apple stills found",
        download: "Download",
        downloading: "Downloading…",
        downloadFailed: "Could not download the wallpaper",
        applyFailed: "Could not set the wallpaper",
        previousPage: "Previous",
        nextPage: "Next"
    )

    static let ptBR = WallpaperFeatureStrings(
        pageTitle: "Papel de parede",
        enableManagement: "Gerenciamento de papel de parede",
        hubDescription: "Escolha um papel de parede sem abrir os Ajustes do Sistema",
        panelDescription: "Escolha um papel de parede sem abrir os Ajustes do Sistema.",
        filterAll: "Todos",
        filterOwn: "Importados",
        filterApple: "Somente da Apple",
        applyAllDisplays: "Mostrar em todos os Spaces",
        addFolder: "Adicionar Pasta…",
        removeAdded: "Remover",
        sourceMenu: "Origem",
        manageWallpapers: "Gerenciar Papéis de Parede…",
        importedFolders: "Pastas Importadas",
        noFolders: "Nenhuma Pasta",
        sourceUnavailable: "Indisponível",
        addImagePrompt: "Escolha imagens para manter na lista do Lattice",
        addFolderPrompt: "Escolha uma pasta de imagens para manter na lista do Lattice",
        emptyAll: "Nenhum papel de parede encontrado",
        emptyOwn: "Nenhuma imagem importada",
        emptyOwnHint: "As imagens das pastas que você adicionar aparecem aqui.",
        emptyApple: "Nenhum papel da Apple encontrado",
        download: "Baixar",
        downloading: "Baixando…",
        downloadFailed: "Não foi possível baixar o papel de parede",
        applyFailed: "Não foi possível definir o papel de parede",
        previousPage: "Anterior",
        nextPage: "Próximo"
    )

    static let tr = WallpaperFeatureStrings(
        pageTitle: "Duvar kağıdı",
        enableManagement: "Duvar Kağıdı Yönetimi",
        hubDescription: "Sistem Ayarları’nı açmadan sabit bir duvar kağıdı seçin",
        panelDescription: "Sistem Ayarları’nı açmadan sabit bir duvar kağıdı seçin.",
        filterAll: "Tümü",
        filterOwn: "İçe aktarılanlar",
        filterApple: "Sadece Apple",
        applyAllDisplays: "Tüm Spaces’te göster",
        addFolder: "Klasör Ekle…",
        removeAdded: "Kaldır",
        sourceMenu: "Kaynak",
        manageWallpapers: "Duvar Kâğıtlarını Yönet…",
        importedFolders: "İçe Aktarılan Klasörler",
        noFolders: "Klasör Yok",
        sourceUnavailable: "Kullanılamıyor",
        addImagePrompt: "Lattice listesinde tutulacak görüntüleri seçin",
        addFolderPrompt: "Lattice listesinde tutulacak bir görüntü klasörü seçin",
        emptyAll: "Duvar kağıdı bulunamadı",
        emptyOwn: "İçe aktarılan görüntü yok",
        emptyOwnHint: "Eklediğiniz klasörlerdeki görüntüler burada görünür.",
        emptyApple: "Apple duvar kağıdı bulunamadı",
        download: "İndir",
        downloading: "İndiriliyor…",
        downloadFailed: "Duvar kağıdı indirilemedi",
        applyFailed: "Duvar kağıdı ayarlanamadı",
        previousPage: "Önceki",
        nextPage: "Sonraki"
    )

    static let ru = WallpaperFeatureStrings(
        pageTitle: "Обои",
        enableManagement: "Управление обоями",
        hubDescription: "Выберите статичные обои без открытия Системных настроек",
        panelDescription: "Выберите статичные обои без открытия Системных настроек.",
        filterAll: "Все",
        filterOwn: "Импортированные",
        filterApple: "Только Apple",
        applyAllDisplays: "Показывать на всех Space",
        addFolder: "Добавить папку…",
        removeAdded: "Удалить",
        sourceMenu: "Источник",
        manageWallpapers: "Управлять обоями…",
        importedFolders: "Импортированные папки",
        noFolders: "Нет папок",
        sourceUnavailable: "Недоступно",
        addImagePrompt: "Выберите изображения для списка Lattice",
        addFolderPrompt: "Выберите папку с изображениями для списка Lattice",
        emptyAll: "Обои не найдены",
        emptyOwn: "Нет импортированных изображений",
        emptyOwnHint: "Здесь появятся изображения из добавленных папок.",
        emptyApple: "Обои Apple не найдены",
        download: "Загрузить",
        downloading: "Загрузка…",
        downloadFailed: "Не удалось загрузить обои",
        applyFailed: "Не удалось установить обои",
        previousPage: "Назад",
        nextPage: "Далее"
    )

    static let es = WallpaperFeatureStrings(
        pageTitle: "Fondo de pantalla",
        enableManagement: "Gestión de fondos de pantalla",
        hubDescription: "Elige un fondo fijo sin abrir Ajustes del Sistema",
        panelDescription: "Elige un fondo fijo sin abrir Ajustes del Sistema.",
        filterAll: "Todos",
        filterOwn: "Importados",
        filterApple: "Solo de Apple",
        applyAllDisplays: "Mostrar en todos los Spaces",
        addFolder: "Añadir carpeta…",
        removeAdded: "Quitar",
        sourceMenu: "Origen",
        manageWallpapers: "Gestionar fondos de pantalla…",
        importedFolders: "Carpetas importadas",
        noFolders: "No hay carpetas",
        sourceUnavailable: "No disponible",
        addImagePrompt: "Elige imágenes para la lista de Lattice",
        addFolderPrompt: "Elige una carpeta de imágenes para la lista de Lattice",
        emptyAll: "No se encontraron fondos",
        emptyOwn: "No hay imágenes importadas",
        emptyOwnHint: "Las imágenes de las carpetas que añadas aparecen aquí.",
        emptyApple: "No se encontraron fondos de Apple",
        download: "Descargar",
        downloading: "Descargando…",
        downloadFailed: "No se pudo descargar el fondo",
        applyFailed: "No se pudo establecer el fondo",
        previousPage: "Anterior",
        nextPage: "Siguiente"
    )
    static let sk = WallpaperFeatureStrings(
        pageTitle: "Pozadie",
        enableManagement: "Správa tapiet",
        hubDescription: "Vyberte statické pozadie bez otvárania Systémových nastavení",
        panelDescription: "Vyberte statické pozadie bez otvárania Systémových nastavení.",
        filterAll: "Všetky",
        filterOwn: "Importované",
        filterApple: "Apple",
        applyAllDisplays: "Zobraziť na všetkých plochách",
        addFolder: "Pridať priečinok…",
        removeAdded: "Odstrániť",
        sourceMenu: "Zdroj",
        manageWallpapers: "Spravovať tapety…",
        importedFolders: "Importované priečinky",
        noFolders: "Žiadne priečinky",
        sourceUnavailable: "Nedostupné",
        addImagePrompt: "Vyberte obrázky, ktoré sa majú ponechať v zozname pozadí Latticeu",
        addFolderPrompt: "Vyberte priečinok s obrázkami, ktorý sa má ponechať v zozname pozadí Latticeu",
        emptyAll: "Nenašli sa žiadne pozadia",
        emptyOwn: "Žiadne importované obrázky",
        emptyOwnHint: "Tu sa zobrazia obrázky z pridaných priečinkov.",
        emptyApple: "Nenašli sa žiadne statické pozadia od Apple",
        download: "Stiahnuť",
        downloading: "Sťahuje sa…",
        downloadFailed: "Pozadie sa nepodarilo stiahnuť",
        applyFailed: "Pozadie sa nepodarilo nastaviť",
        previousPage: "Predchádzajúca",
        nextPage: "Ďalšia"
    )

    static let de = WallpaperFeatureStrings(
        pageTitle: "Hintergrundbild",
        enableManagement: "Hintergrundbildverwaltung",
        hubDescription: "Wähle ein Standbild ohne die Systemeinstellungen zu öffnen",
        panelDescription: "Wähle ein Standbild ohne die Systemeinstellungen zu öffnen.",
        filterAll: "Alle",
        filterOwn: "Importiert",
        filterApple: "Nur Apple",
        applyAllDisplays: "Auf allen Spaces zeigen",
        addFolder: "Ordner hinzufügen …",
        removeAdded: "Entfernen",
        sourceMenu: "Quelle",
        manageWallpapers: "Hintergrundbilder verwalten …",
        importedFolders: "Importierte Ordner",
        noFolders: "Keine Ordner",
        sourceUnavailable: "Nicht verfügbar",
        addImagePrompt: "Bilder für die Lattice-Liste wählen",
        addFolderPrompt: "Ordner mit Bildern für die Lattice-Liste wählen",
        emptyAll: "Keine Hintergrundbilder gefunden",
        emptyOwn: "Keine importierten Bilder",
        emptyOwnHint: "Bilder aus hinzugefügten Ordnern erscheinen hier.",
        emptyApple: "Keine Apple-Bilder gefunden",
        download: "Laden",
        downloading: "Wird geladen…",
        downloadFailed: "Hintergrundbild konnte nicht geladen werden",
        applyFailed: "Hintergrundbild konnte nicht gesetzt werden",
        previousPage: "Zurück",
        nextPage: "Weiter"
    )

    static let fr = WallpaperFeatureStrings(
        pageTitle: "Fond d’écran",
        enableManagement: "Gestion des fonds d’écran",
        hubDescription: "Choisissez une image fixe sans ouvrir Réglages Système",
        panelDescription: "Choisissez une image fixe sans ouvrir Réglages Système.",
        filterAll: "Tous",
        filterOwn: "Importés",
        filterApple: "Seulement Apple",
        applyAllDisplays: "Afficher sur tous les Spaces",
        addFolder: "Ajouter un dossier…",
        removeAdded: "Retirer",
        sourceMenu: "Source",
        manageWallpapers: "Gérer les fonds d’écran…",
        importedFolders: "Dossiers importés",
        noFolders: "Aucun dossier",
        sourceUnavailable: "Indisponible",
        addImagePrompt: "Choisissez des images pour la liste Lattice",
        addFolderPrompt: "Choisissez un dossier d’images pour la liste Lattice",
        emptyAll: "Aucun fond d’écran trouvé",
        emptyOwn: "Aucune image importée",
        emptyOwnHint: "Les images des dossiers ajoutés apparaissent ici.",
        emptyApple: "Aucun fond Apple trouvé",
        download: "Télécharger",
        downloading: "Téléchargement…",
        downloadFailed: "Impossible de télécharger le fond d’écran",
        applyFailed: "Impossible de définir le fond d’écran",
        previousPage: "Précédent",
        nextPage: "Suivant"
    )

    static let it = WallpaperFeatureStrings(
        pageTitle: "Sfondo",
        enableManagement: "Gestione sfondo",
        hubDescription: "Scegli uno sfondo fisso senza aprire Impostazioni di Sistema",
        panelDescription: "Scegli uno sfondo fisso senza aprire Impostazioni di Sistema.",
        filterAll: "Tutti",
        filterOwn: "Importati",
        filterApple: "Solo Apple",
        applyAllDisplays: "Mostra su tutti gli Spaces",
        addFolder: "Aggiungi cartella…",
        removeAdded: "Rimuovi",
        sourceMenu: "Origine",
        manageWallpapers: "Gestisci sfondi…",
        importedFolders: "Cartelle importate",
        noFolders: "Nessuna cartella",
        sourceUnavailable: "Non disponibile",
        addImagePrompt: "Scegli immagini per l’elenco di Lattice",
        addFolderPrompt: "Scegli una cartella di immagini per l’elenco di Lattice",
        emptyAll: "Nessuno sfondo trovato",
        emptyOwn: "Nessuna immagine importata",
        emptyOwnHint: "Le immagini delle cartelle aggiunte appaiono qui.",
        emptyApple: "Nessuno sfondo Apple trovato",
        download: "Scarica",
        downloading: "Download in corso…",
        downloadFailed: "Impossibile scaricare lo sfondo",
        applyFailed: "Impossibile impostare lo sfondo",
        previousPage: "Precedente",
        nextPage: "Successiva"
    )

    static let ja = WallpaperFeatureStrings(
        pageTitle: "壁紙",
        enableManagement: "壁紙管理",
        hubDescription: "システム設定を開かずに静止壁紙を選べます",
        panelDescription: "システム設定を開かずに静止壁紙を選べます。",
        filterAll: "すべて",
        filterOwn: "読み込み済み",
        filterApple: "Appleのみ",
        applyAllDisplays: "すべてのスペースに表示",
        addFolder: "フォルダを追加…",
        removeAdded: "削除",
        sourceMenu: "ソース",
        manageWallpapers: "壁紙を管理…",
        importedFolders: "読み込んだフォルダ",
        noFolders: "フォルダなし",
        sourceUnavailable: "利用できません",
        addImagePrompt: "Latticeの一覧に残す画像を選んでください",
        addFolderPrompt: "Latticeの一覧に残す画像フォルダを選んでください",
        emptyAll: "壁紙が見つかりません",
        emptyOwn: "読み込んだ画像はありません",
        emptyOwnHint: "追加したフォルダの画像がここに表示されます。",
        emptyApple: "Appleの壁紙が見つかりません",
        download: "ダウンロード",
        downloading: "ダウンロード中…",
        downloadFailed: "壁紙をダウンロードできませんでした",
        applyFailed: "壁紙を設定できませんでした",
        previousPage: "前へ",
        nextPage: "次へ"
    )

    static let ko = WallpaperFeatureStrings(
        pageTitle: "배경화면",
        enableManagement: "배경화면 관리",
        hubDescription: "시스템 설정을 열지 않고 고정 배경을 고릅니다",
        panelDescription: "시스템 설정을 열지 않고 고정 배경을 고릅니다.",
        filterAll: "전체",
        filterOwn: "가져온 항목",
        filterApple: "Apple만",
        applyAllDisplays: "모든 Space에 표시",
        addFolder: "폴더 추가…",
        removeAdded: "제거",
        sourceMenu: "소스",
        manageWallpapers: "배경화면 관리…",
        importedFolders: "가져온 폴더",
        noFolders: "폴더 없음",
        sourceUnavailable: "사용할 수 없음",
        addImagePrompt: "Lattice 목록에 둘 이미지를 선택하세요",
        addFolderPrompt: "Lattice 목록에 둘 이미지 폴더를 선택하세요",
        emptyAll: "배경화면을 찾을 수 없습니다",
        emptyOwn: "가져온 이미지 없음",
        emptyOwnHint: "추가한 폴더의 이미지가 여기에 표시됩니다.",
        emptyApple: "Apple 배경을 찾을 수 없습니다",
        download: "다운로드",
        downloading: "다운로드 중…",
        downloadFailed: "배경화면을 다운로드할 수 없습니다",
        applyFailed: "배경화면을 설정할 수 없습니다",
        previousPage: "이전",
        nextPage: "다음"
    )
    static let uk = WallpaperFeatureStrings(
        pageTitle: "Шпалера",
        enableManagement: "Керування шпалерами",
        hubDescription: "Вибирайте статичну шпалеру, не відкриваючи Системні параметри",
        panelDescription: "Вибирайте статичну шпалеру, не відкриваючи Системні параметри.",
        filterAll: "Усі",
        filterOwn: "Імпортовані",
        filterApple: "Apple",
        applyAllDisplays: "Показувати всюди",
        addFolder: "Додати папку…",
        removeAdded: "Видалити",
        sourceMenu: "Джерело",
        manageWallpapers: "Керувати шпалерами…",
        importedFolders: "Імпортовані папки",
        noFolders: "Немає папок",
        sourceUnavailable: "Недоступно",
        addImagePrompt: "Виберіть зображення для списку шпалер Lattice",
        addFolderPrompt: "Виберіть папку із зображеннями для списку шпалер Lattice",
        emptyAll: "Шпалер не знайдено",
        emptyOwn: "Немає імпортованих зображень",
        emptyOwnHint: "Тут з’являться зображення з доданих папок.",
        emptyApple: "Статичних шпалер Apple не знайдено",
        download: "Завантажити",
        downloading: "Завантаження…",
        downloadFailed: "Не вдалося завантажити шпалеру",
        applyFailed: "Не вдалося встановити шпалеру",
        previousPage: "Назад",
        nextPage: "Далі"
    )

    static let zhHans = WallpaperFeatureStrings(
        pageTitle: "壁纸",
        enableManagement: "壁纸管理",
        hubDescription: "无需打开系统设置即可选择静态壁纸",
        panelDescription: "无需打开系统设置即可选择静态壁纸。",
        filterAll: "全部",
        filterOwn: "已导入",
        filterApple: "仅 Apple",
        applyAllDisplays: "在所有空间显示",
        addFolder: "添加文件夹…",
        removeAdded: "移除",
        sourceMenu: "来源",
        manageWallpapers: "管理墙纸…",
        importedFolders: "已导入的文件夹",
        noFolders: "无文件夹",
        sourceUnavailable: "不可用",
        addImagePrompt: "选择要保留在 Lattice 列表中的图片",
        addFolderPrompt: "选择要保留在 Lattice 列表中的图片文件夹",
        emptyAll: "未找到壁纸",
        emptyOwn: "没有已导入的图片",
        emptyOwnHint: "你添加的文件夹中的图片会显示在这里。",
        emptyApple: "未找到 Apple 壁纸",
        download: "下载",
        downloading: "正在下载…",
        downloadFailed: "无法下载壁纸",
        applyFailed: "无法设置壁纸",
        previousPage: "上一页",
        nextPage: "下一页"
    )

    static let zhTW = WallpaperFeatureStrings(
        pageTitle: "桌布",
        enableManagement: "桌布管理",
        hubDescription: "不必打開系統設定即可選擇靜態桌布",
        panelDescription: "不必打開系統設定即可選擇靜態桌布。",
        filterAll: "全部",
        filterOwn: "已匯入",
        filterApple: "僅 Apple",
        applyAllDisplays: "在所有空間顯示",
        addFolder: "新增資料夾…",
        removeAdded: "移除",
        sourceMenu: "來源",
        manageWallpapers: "管理背景圖片…",
        importedFolders: "已匯入的資料夾",
        noFolders: "沒有資料夾",
        sourceUnavailable: "無法使用",
        addImagePrompt: "選擇要保留在 Lattice 清單中的圖片",
        addFolderPrompt: "選擇要保留在 Lattice 清單中的圖片資料夾",
        emptyAll: "找不到桌布",
        emptyOwn: "沒有已匯入的圖片",
        emptyOwnHint: "你加入的資料夾中的圖片會顯示在這裡。",
        emptyApple: "找不到 Apple 桌布",
        download: "下載",
        downloading: "下載中…",
        downloadFailed: "無法下載桌布",
        applyFailed: "無法設定桌布",
        previousPage: "上一頁",
        nextPage: "下一頁"
    )

    static let zhHK = WallpaperFeatureStrings(
        pageTitle: "桌布",
        enableManagement: "桌布管理",
        hubDescription: "唔使開系統設定都可以揀靜態桌布",
        panelDescription: "唔使開系統設定都可以揀靜態桌布。",
        filterAll: "全部",
        filterOwn: "已匯入",
        filterApple: "淨係 Apple",
        applyAllDisplays: "喺所有空間顯示",
        addFolder: "新增資料夾…",
        removeAdded: "移除",
        sourceMenu: "來源",
        manageWallpapers: "管理背景圖片…",
        importedFolders: "已匯入的資料夾",
        noFolders: "沒有資料夾",
        sourceUnavailable: "無法使用",
        addImagePrompt: "選擇要保留喺 Lattice 清單嘅圖片",
        addFolderPrompt: "選擇要保留喺 Lattice 清單嘅圖片資料夾",
        emptyAll: "搵唔到桌布",
        emptyOwn: "沒有已匯入的圖片",
        emptyOwnHint: "你加入嘅資料夾入面嘅圖片會喺呢度顯示。",
        emptyApple: "搵唔到 Apple 桌布",
        download: "下載",
        downloading: "下載中…",
        downloadFailed: "無法下載桌布",
        applyFailed: "無法設定桌布",
        previousPage: "上一頁",
        nextPage: "下一頁"
    )
}
