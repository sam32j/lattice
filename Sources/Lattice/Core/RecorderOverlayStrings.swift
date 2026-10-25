// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct RecorderOverlayStrings {
    let camera, keys, defaultInput, noCamera, noMicrophone, unavailable, starting, flip, overlay: String
    let size, small, medium, big, circle, square, rectangle, vertical: String

    func title(_ shape: RecorderCameraLayout.Shape) -> String {
        switch shape { case .circle: circle; case .square: square; case .rectangle: rectangle; case .vertical: vertical }
    }
    func title(_ size: RecorderCameraLayout.Size) -> String {
        switch size { case .small: small; case .medium: medium; case .big: big }
    }
}

extension FeatureStrings {
    static func recorderOverlay(_ language: AppLanguage) -> RecorderOverlayStrings {
        switch language {
        case .enUS:
            return .init(camera: "Camera", keys: "Show keystrokes", defaultInput: "System default",
                noCamera: "No camera available", noMicrophone: "No microphone available", unavailable: "Camera unavailable",
                starting: "Starting camera…", flip: "Flip camera", overlay: "Recording camera overlay",
                size: "Size", small: "Small", medium: "Medium", big: "Large",
                circle: "Circle", square: "Square", rectangle: "Rectangle", vertical: "Vertical")
        case .ptBR:
            return .init(camera: "Câmera", keys: "Mostrar teclas", defaultInput: "Padrão do sistema",
                noCamera: "Nenhuma câmera disponível", noMicrophone: "Nenhum microfone disponível", unavailable: "Câmera indisponível",
                starting: "Iniciando câmera…", flip: "Espelhar câmera", overlay: "Sobreposição da câmera na gravação",
                size: "Tamanho", small: "Pequeno", medium: "Médio", big: "Grande",
                circle: "Círculo", square: "Quadrado", rectangle: "Retângulo", vertical: "Vertical")
        case .tr:
            return .init(camera: "Kamera", keys: "Tuş vuruşlarını göster", defaultInput: "Sistem varsayılanı",
                noCamera: "Kullanılabilir kamera yok", noMicrophone: "Kullanılabilir mikrofon yok", unavailable: "Kamera kullanılamıyor",
                starting: "Kamera başlatılıyor…", flip: "Kamerayı yansıt", overlay: "Kayıt kamerası katmanı",
                size: "Boyut", small: "Küçük", medium: "Orta", big: "Büyük",
                circle: "Daire", square: "Kare", rectangle: "Dikdörtgen", vertical: "Dikey")
        case .ru:
            return .init(camera: "Камера", keys: "Показывать нажатия клавиш", defaultInput: "По умолчанию в системе",
                noCamera: "Нет доступной камеры", noMicrophone: "Нет доступного микрофона", unavailable: "Камера недоступна",
                starting: "Запуск камеры…", flip: "Отразить камеру", overlay: "Камера поверх записи",
                size: "Размер", small: "Маленький", medium: "Средний", big: "Большой",
                circle: "Круг", square: "Квадрат", rectangle: "Прямоугольник", vertical: "Вертикальный")
        case .es:
            return .init(camera: "Cámara", keys: "Mostrar pulsaciones", defaultInput: "Predeterminado del sistema",
                noCamera: "No hay cámaras disponibles", noMicrophone: "No hay micrófonos disponibles", unavailable: "Cámara no disponible",
                starting: "Iniciando cámara…", flip: "Voltear cámara", overlay: "Cámara superpuesta en la grabación",
                size: "Tamaño", small: "Pequeño", medium: "Mediano", big: "Grande",
                circle: "Círculo", square: "Cuadrado", rectangle: "Rectángulo", vertical: "Vertical")
        case .sk:
            return .init(camera: "Kamera", keys: "Zobraziť stlačené klávesy", defaultInput: "Predvolené v systéme",
                noCamera: "Žiadna dostupná kamera", noMicrophone: "Žiadny dostupný mikrofón", unavailable: "Kamera nie je dostupná",
                starting: "Spúšťa sa kamera…", flip: "Zrkadliť kameru", overlay: "Prekrytie kamery pri nahrávaní",
                size: "Veľkosť", small: "Malá", medium: "Stredná", big: "Veľká",
                circle: "Kruh", square: "Štvorec", rectangle: "Obdĺžnik", vertical: "Zvislý")
        case .de:
            return .init(camera: "Kamera", keys: "Tastenanschläge anzeigen", defaultInput: "Systemstandard",
                noCamera: "Keine Kamera verfügbar", noMicrophone: "Kein Mikrofon verfügbar", unavailable: "Kamera nicht verfügbar",
                starting: "Kamera wird gestartet…", flip: "Kamera spiegeln", overlay: "Kameraeinblendung der Aufnahme",
                size: "Größe", small: "Klein", medium: "Mittel", big: "Groß",
                circle: "Kreis", square: "Quadrat", rectangle: "Rechteck", vertical: "Hochformat")
        case .fr:
            return .init(camera: "Caméra", keys: "Afficher les frappes", defaultInput: "Valeur par défaut du système",
                noCamera: "Aucune caméra disponible", noMicrophone: "Aucun microphone disponible", unavailable: "Caméra indisponible",
                starting: "Démarrage de la caméra…", flip: "Inverser la caméra", overlay: "Caméra superposée à l’enregistrement",
                size: "Taille", small: "Petite", medium: "Moyenne", big: "Grande",
                circle: "Cercle", square: "Carré", rectangle: "Rectangle", vertical: "Portrait")
        case .it:
            return .init(camera: "Fotocamera", keys: "Mostra i tasti premuti", defaultInput: "Predefinito di sistema",
                noCamera: "Nessuna fotocamera disponibile", noMicrophone: "Nessun microfono disponibile", unavailable: "Fotocamera non disponibile",
                starting: "Avvio fotocamera…", flip: "Specchia fotocamera", overlay: "Fotocamera sovrapposta alla registrazione",
                size: "Dimensione", small: "Piccola", medium: "Media", big: "Grande",
                circle: "Cerchio", square: "Quadrato", rectangle: "Rettangolo", vertical: "Verticale")
        case .ja:
            return .init(camera: "カメラ", keys: "キー入力を表示", defaultInput: "システムのデフォルト",
                noCamera: "使用できるカメラがありません", noMicrophone: "使用できるマイクがありません", unavailable: "カメラを使用できません",
                starting: "カメラを起動中…", flip: "カメラを反転", overlay: "録画用カメラオーバーレイ",
                size: "サイズ", small: "小", medium: "中", big: "大",
                circle: "円", square: "正方形", rectangle: "長方形", vertical: "縦長")
        case .ko:
            return .init(camera: "카메라", keys: "키 입력 표시", defaultInput: "시스템 기본값",
                noCamera: "사용 가능한 카메라 없음", noMicrophone: "사용 가능한 마이크 없음", unavailable: "카메라를 사용할 수 없음",
                starting: "카메라 시작 중…", flip: "카메라 좌우 반전", overlay: "녹화 카메라 오버레이",
                size: "크기", small: "작게", medium: "중간", big: "크게",
                circle: "원", square: "정사각형", rectangle: "직사각형", vertical: "세로")
        case .uk:
            return .init(camera: "Камера", keys: "Показувати натискання клавіш", defaultInput: "Типовий системний",
                noCamera: "Немає доступної камери", noMicrophone: "Немає доступного мікрофона", unavailable: "Камера недоступна",
                starting: "Запуск камери…", flip: "Віддзеркалити камеру", overlay: "Камера поверх запису",
                size: "Розмір", small: "Малий", medium: "Середній", big: "Великий",
                circle: "Коло", square: "Квадрат", rectangle: "Прямокутник", vertical: "Вертикальний")
        case .zhHans:
            return .init(camera: "摄像头", keys: "显示按键", defaultInput: "系统默认",
                noCamera: "没有可用的摄像头", noMicrophone: "没有可用的麦克风", unavailable: "摄像头不可用",
                starting: "正在启动摄像头…", flip: "翻转摄像头", overlay: "录屏摄像头浮窗",
                size: "大小", small: "小", medium: "中", big: "大",
                circle: "圆形", square: "正方形", rectangle: "长方形", vertical: "竖向")
        case .zhTW:
            return .init(camera: "相機", keys: "顯示按鍵", defaultInput: "系統預設",
                noCamera: "沒有可用的相機", noMicrophone: "沒有可用的麥克風", unavailable: "相機無法使用",
                starting: "正在啟動相機…", flip: "翻轉相機", overlay: "錄影相機浮動視窗",
                size: "大小", small: "小", medium: "中", big: "大",
                circle: "圓形", square: "正方形", rectangle: "長方形", vertical: "直向")
        case .zhHK:
            return .init(camera: "鏡頭", keys: "顯示按鍵", defaultInput: "系統預設",
                noCamera: "沒有可用的鏡頭", noMicrophone: "沒有可用的咪高峰", unavailable: "鏡頭無法使用",
                starting: "正在啟動鏡頭…", flip: "翻轉鏡頭", overlay: "錄影鏡頭浮動視窗",
                size: "大小", small: "小", medium: "中", big: "大",
                circle: "圓形", square: "正方形", rectangle: "長方形", vertical: "直向")
        }
    }
}
