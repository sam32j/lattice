// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Copy for the shared Save settings card; token spelling is never translated.
struct CaptureSaveStrings {
    let save: String
    let location: String
    let organize: String
    let fileName: String
    let optional: String
    let insert: String
    let savedAs: String
    let choose: String
    let date: String
    let time: String
    let year: String
    let twoDigitYear: String
    let month: String
    let monthName: String
    let day: String
    let hour: String
    let minute: String
    let second: String
    let media: String
    let counter: String
    let uuid: String
    let shortID: String
    let oneCounter: String
    let subfolderCounter: String
    let chooseFolder: String
    let insertToken: String
    let saveFailed: String

    static func localized(_ language: AppLanguage) -> Self {
        switch language {
        case .enUS:
            return .init(
                save: "Save & Destination",
                location: "Default save location",
                organize: "Subfolders",
                fileName: "Default file name",
                optional: "Optional",
                insert: "Insert",
                savedAs: "Saved as",
                choose: "Choose…",
                date: "Date",
                time: "Time",
                year: "Year",
                twoDigitYear: "Year, two digits",
                month: "Month",
                monthName: "Month name",
                day: "Day",
                hour: "Hour",
                minute: "Minute",
                second: "Second",
                media: "Media type",
                counter: "Counter",
                uuid: "UUID",
                shortID: "Short ID",
                oneCounter: "Use only one counter.",
                subfolderCounter: "The counter works in file names only.",
                chooseFolder: "Choose a folder",
                insertToken: "Insert token",
                saveFailed: "Could not save capture"
            )
        case .ptBR:
            return .init(
                save: "Salvar e destino",
                location: "Local padrão para salvar",
                organize: "Subpastas",
                fileName: "Nome de arquivo padrão",
                optional: "Opcional",
                insert: "Inserir",
                savedAs: "Salvo como",
                choose: "Escolher…",
                date: "Data",
                time: "Hora",
                year: "Ano",
                twoDigitYear: "Ano, dois dígitos",
                month: "Mês",
                monthName: "Nome do mês",
                day: "Dia",
                hour: "Hora",
                minute: "Minuto",
                second: "Segundo",
                media: "Tipo de mídia",
                counter: "Contador",
                uuid: "UUID",
                shortID: "ID curto",
                oneCounter: "Use apenas um contador.",
                subfolderCounter: "O contador funciona apenas no nome do arquivo.",
                chooseFolder: "Escolha uma pasta",
                insertToken: "Inserir token",
                saveFailed: "Não foi possível salvar a captura"
            )
        case .tr:
            return .init(
                save: "Kaydetme ve hedef",
                location: "Varsayılan kaydetme konumu",
                organize: "Alt klasörler",
                fileName: "Varsayılan dosya adı",
                optional: "İsteğe bağlı",
                insert: "Ekle",
                savedAs: "Şu adla kaydedilir",
                choose: "Seç…",
                date: "Tarih",
                time: "Saat",
                year: "Yıl",
                twoDigitYear: "Yıl, iki basamak",
                month: "Ay",
                monthName: "Ay adı",
                day: "Gün",
                hour: "Saat",
                minute: "Dakika",
                second: "Saniye",
                media: "Medya türü",
                counter: "Sayaç",
                uuid: "UUID",
                shortID: "Kısa kimlik",
                oneCounter: "Yalnızca bir sayaç kullanın.",
                subfolderCounter: "Sayaç yalnızca dosya adlarında kullanılabilir.",
                chooseFolder: "Klasör seçin",
                insertToken: "Belirteç ekle",
                saveFailed: "Yakalama kaydedilemedi"
            )
        case .ru:
            return .init(
                save: "Сохранение и расположение",
                location: "Папка сохранения по умолчанию",
                organize: "Подпапки",
                fileName: "Имя файла по умолчанию",
                optional: "Необязательно",
                insert: "Вставить",
                savedAs: "Сохранить как",
                choose: "Выбрать…",
                date: "Дата",
                time: "Время",
                year: "Год",
                twoDigitYear: "Год, две цифры",
                month: "Месяц",
                monthName: "Название месяца",
                day: "День",
                hour: "Час",
                minute: "Минута",
                second: "Секунда",
                media: "Тип файла",
                counter: "Счётчик",
                uuid: "UUID",
                shortID: "Короткий ID",
                oneCounter: "Используйте только один счётчик.",
                subfolderCounter: "Счётчик работает только в имени файла.",
                chooseFolder: "Выберите папку",
                insertToken: "Вставить шаблон",
                saveFailed: "Не удалось сохранить запись"
            )
        case .es:
            return .init(
                save: "Guardado y destino",
                location: "Ubicación de guardado predeterminada",
                organize: "Subcarpetas",
                fileName: "Nombre de archivo predeterminado",
                optional: "Opcional",
                insert: "Insertar",
                savedAs: "Guardado como",
                choose: "Elegir…",
                date: "Fecha",
                time: "Hora",
                year: "Año",
                twoDigitYear: "Año, dos dígitos",
                month: "Mes",
                monthName: "Nombre del mes",
                day: "Día",
                hour: "Hora",
                minute: "Minuto",
                second: "Segundo",
                media: "Tipo de medio",
                counter: "Contador",
                uuid: "UUID",
                shortID: "ID corto",
                oneCounter: "Usa un solo contador.",
                subfolderCounter: "El contador solo funciona en nombres de archivo.",
                chooseFolder: "Elige una carpeta",
                insertToken: "Insertar variable",
                saveFailed: "No se pudo guardar la captura"
            )
        case .sk:
            return .init(
                save: "Ukladanie a umiestnenie",
                location: "Predvolené umiestnenie uloženia",
                organize: "Podpriečinky",
                fileName: "Predvolený názov súboru",
                optional: "Voliteľné",
                insert: "Vložiť",
                savedAs: "Uložené ako",
                choose: "Vybrať…",
                date: "Dátum",
                time: "Čas",
                year: "Rok",
                twoDigitYear: "Rok, dve číslice",
                month: "Mesiac",
                monthName: "Názov mesiaca",
                day: "Deň",
                hour: "Hodina",
                minute: "Minúta",
                second: "Sekunda",
                media: "Typ média",
                counter: "Počítadlo",
                uuid: "UUID",
                shortID: "Krátke ID",
                oneCounter: "Použite len jedno počítadlo.",
                subfolderCounter: "Počítadlo funguje iba v názvoch súborov.",
                chooseFolder: "Vyberte priečinok",
                insertToken: "Vložiť token",
                saveFailed: "Snímku sa nepodarilo uložiť"
            )
        case .de:
            return .init(
                save: "Speichern & Speicherort",
                location: "Standard-Speicherort",
                organize: "Unterordner",
                fileName: "Standarddateiname",
                optional: "Optional",
                insert: "Einfügen",
                savedAs: "Gespeichert als",
                choose: "Auswählen…",
                date: "Datum",
                time: "Uhrzeit",
                year: "Jahr",
                twoDigitYear: "Jahr, zweistellig",
                month: "Monat",
                monthName: "Monatsname",
                day: "Tag",
                hour: "Stunde",
                minute: "Minute",
                second: "Sekunde",
                media: "Medientyp",
                counter: "Zähler",
                uuid: "UUID",
                shortID: "Kurz-ID",
                oneCounter: "Nur einen Zähler verwenden.",
                subfolderCounter: "Zähler sind nur in Dateinamen möglich.",
                chooseFolder: "Ordner auswählen",
                insertToken: "Platzhalter einfügen",
                saveFailed: "Aufnahme konnte nicht gespeichert werden"
            )
        case .fr:
            return .init(
                save: "Enregistrement et destination",
                location: "Emplacement d’enregistrement par défaut",
                organize: "Sous-dossiers",
                fileName: "Nom de fichier par défaut",
                optional: "Facultatif",
                insert: "Insérer",
                savedAs: "Enregistré sous",
                choose: "Choisir…",
                date: "Date",
                time: "Heure",
                year: "Année",
                twoDigitYear: "Année sur deux chiffres",
                month: "Mois",
                monthName: "Nom du mois",
                day: "Jour",
                hour: "Heure",
                minute: "Minute",
                second: "Seconde",
                media: "Type de média",
                counter: "Compteur",
                uuid: "UUID",
                shortID: "ID court",
                oneCounter: "Utilisez un seul compteur.",
                subfolderCounter: "Le compteur fonctionne uniquement dans les noms de fichiers.",
                chooseFolder: "Choisissez un dossier",
                insertToken: "Insérer une variable",
                saveFailed: "Impossible d’enregistrer la capture"
            )
        case .it:
            return .init(
                save: "Salvataggio e destinazione",
                location: "Posizione di salvataggio predefinita",
                organize: "Sottocartelle",
                fileName: "Nome file predefinito",
                optional: "Facoltativo",
                insert: "Inserisci",
                savedAs: "Salvato come",
                choose: "Scegli…",
                date: "Data",
                time: "Ora",
                year: "Anno",
                twoDigitYear: "Anno a due cifre",
                month: "Mese",
                monthName: "Nome del mese",
                day: "Giorno",
                hour: "Ora",
                minute: "Minuto",
                second: "Secondo",
                media: "Tipo di file",
                counter: "Contatore",
                uuid: "UUID",
                shortID: "ID breve",
                oneCounter: "Usa un solo contatore.",
                subfolderCounter: "Il contatore funziona solo nei nomi dei file.",
                chooseFolder: "Scegli una cartella",
                insertToken: "Inserisci variabile",
                saveFailed: "Impossibile salvare l’acquisizione"
            )
        case .ja:
            return .init(
                save: "保存と保存先",
                location: "デフォルトの保存先",
                organize: "サブフォルダ",
                fileName: "既定のファイル名",
                optional: "任意",
                insert: "挿入",
                savedAs: "保存先",
                choose: "選択…",
                date: "日付",
                time: "時刻",
                year: "年",
                twoDigitYear: "年（2桁）",
                month: "月",
                monthName: "月の名前",
                day: "日",
                hour: "時",
                minute: "分",
                second: "秒",
                media: "メディアの種類",
                counter: "連番",
                uuid: "UUID",
                shortID: "短いID",
                oneCounter: "連番は1つだけ使用してください。",
                subfolderCounter: "連番はファイル名のみ使用できます。",
                chooseFolder: "フォルダを選択",
                insertToken: "変数を挿入",
                saveFailed: "キャプチャを保存できませんでした"
            )
        case .ko:
            return .init(
                save: "저장 및 위치",
                location: "기본 저장 위치",
                organize: "하위 폴더",
                fileName: "기본 파일 이름",
                optional: "선택 사항",
                insert: "삽입",
                savedAs: "저장 경로",
                choose: "선택…",
                date: "날짜",
                time: "시간",
                year: "연도",
                twoDigitYear: "연도 두 자리",
                month: "월",
                monthName: "월 이름",
                day: "일",
                hour: "시",
                minute: "분",
                second: "초",
                media: "미디어 유형",
                counter: "번호",
                uuid: "UUID",
                shortID: "짧은 ID",
                oneCounter: "번호는 하나만 사용하세요.",
                subfolderCounter: "번호는 파일 이름에서만 사용할 수 있습니다.",
                chooseFolder: "폴더 선택",
                insertToken: "토큰 삽입",
                saveFailed: "캡처를 저장하지 못했습니다"
            )
        case .uk:
            return .init(
                save: "Збереження та розташування",
                location: "Стандартне місце збереження",
                organize: "Підпапки",
                fileName: "Типова назва файлу",
                optional: "Необов’язково",
                insert: "Вставити",
                savedAs: "Збережено як",
                choose: "Вибрати…",
                date: "Дата",
                time: "Час",
                year: "Рік",
                twoDigitYear: "Рік, дві цифри",
                month: "Місяць",
                monthName: "Назва місяця",
                day: "День",
                hour: "Година",
                minute: "Хвилина",
                second: "Секунда",
                media: "Тип медіа",
                counter: "Лічильник",
                uuid: "UUID",
                shortID: "Короткий ID",
                oneCounter: "Використовуйте лише один лічильник.",
                subfolderCounter: "Лічильник працює лише в назвах файлів.",
                chooseFolder: "Виберіть папку",
                insertToken: "Вставити змінну",
                saveFailed: "Не вдалося зберегти знімок"
            )
        case .zhHans:
            return .init(
                save: "保存与位置",
                location: "默认保存位置",
                organize: "子文件夹",
                fileName: "默认文件名",
                optional: "可选",
                insert: "插入",
                savedAs: "保存为",
                choose: "选择…",
                date: "日期",
                time: "时间",
                year: "年份",
                twoDigitYear: "两位年份",
                month: "月份",
                monthName: "月份名称",
                day: "日期",
                hour: "小时",
                minute: "分钟",
                second: "秒",
                media: "媒体类型",
                counter: "计数器",
                uuid: "UUID",
                shortID: "短 ID",
                oneCounter: "只能使用一个计数器。",
                subfolderCounter: "计数器只能用于文件名。",
                chooseFolder: "选择文件夹",
                insertToken: "插入变量",
                saveFailed: "无法保存屏幕捕获"
            )
        case .zhTW:
            return .init(
                save: "儲存與位置",
                location: "預設儲存位置",
                organize: "子資料夾",
                fileName: "預設檔案名稱",
                optional: "選填",
                insert: "插入",
                savedAs: "儲存為",
                choose: "選擇…",
                date: "日期",
                time: "時間",
                year: "年份",
                twoDigitYear: "兩位數年份",
                month: "月份",
                monthName: "月份名稱",
                day: "日期",
                hour: "小時",
                minute: "分鐘",
                second: "秒",
                media: "媒體類型",
                counter: "計數器",
                uuid: "UUID",
                shortID: "短 ID",
                oneCounter: "只能使用一個計數器。",
                subfolderCounter: "計數器只能用於檔案名稱。",
                chooseFolder: "選擇資料夾",
                insertToken: "插入變數",
                saveFailed: "無法儲存螢幕擷取"
            )
        case .zhHK:
            return .init(
                save: "儲存與位置",
                location: "預設儲存位置",
                organize: "子資料夾",
                fileName: "預設檔案名稱",
                optional: "選填",
                insert: "插入",
                savedAs: "儲存為",
                choose: "選擇…",
                date: "日期",
                time: "時間",
                year: "年份",
                twoDigitYear: "兩位數年份",
                month: "月份",
                monthName: "月份名稱",
                day: "日期",
                hour: "小時",
                minute: "分鐘",
                second: "秒",
                media: "媒體類型",
                counter: "計數器",
                uuid: "UUID",
                shortID: "短 ID",
                oneCounter: "只能使用一個計數器。",
                subfolderCounter: "計數器只能用於檔案名稱。",
                chooseFolder: "選擇資料夾",
                insertToken: "插入變數",
                saveFailed: "無法儲存螢幕擷取"
            )
        }
    }
}
