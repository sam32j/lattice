// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum FeatureStrings {
    static func settingsCategories(_ language: AppLanguage) -> SettingsCategoryStrings {
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

    static func clipboard(_ language: AppLanguage) -> ClipboardFeatureStrings {
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

    static func windowLayout(_ language: AppLanguage) -> WindowLayoutFeatureStrings {
        var result: WindowLayoutFeatureStrings = switch language {
        case .enUS: .enUS
        case .ptBR: .ptBR
        case .tr: .tr
        case .ru: .ru
        case .es: .es
        case .sk: .sk
        case .de: .de
        case .fr: .fr
        case .it: .it
        case .ja: .ja
        case .ko: .ko
        case .zhHans: .zhHans
        case .zhTW: .zhTW
        case .zhHK: .zhHK
        case .uk: .uk
        }
        result.quarters = switch language {
        case .enUS: "Quarters"
        case .ptBR: "Quartos"
        case .tr: "Çeyrekler"
        case .ru: "Четверти"
        case .es: "Cuartos"
        case .sk: "Štvrtiny"
        case .de: "Viertel"
        case .fr: "Quarts"
        case .it: "Quarti"
        case .ja: "4分割"
        case .ko: "4분할"
        case .zhHans, .zhTW, .zhHK: "四分"
        case .uk: "Чверті"
        }
        return result
    }

    static func monitorAlerts(_ language: AppLanguage) -> MonitorAlertFeatureStrings {
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

    static func mixer(_ language: AppLanguage) -> MixerFeatureStrings {
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

struct MixerFeatureStrings {
    let hideInactiveApps: String
    let pin: String
    let unpin: String
    let moveUp: String
    let moveDown: String
    /// The island runs the rows sideways, pinned ones first.
    let pinFirst: String
    let moveLeft: String
    let moveRight: String
    let arrange: String
    let actions: String

    static let enUS = MixerFeatureStrings(hideInactiveApps: "Hide inactive apps", pin: "Pin to Top", unpin: "Unpin", moveUp: "Move Up", moveDown: "Move Down", pinFirst: "Pin to Front", moveLeft: "Move Left", moveRight: "Move Right", arrange: "Hold Command and drag to reorder", actions: "Actions")
    static let ptBR = MixerFeatureStrings(hideInactiveApps: "Ocultar apps inativos", pin: "Fixar no topo", unpin: "Desafixar", moveUp: "Mover para cima", moveDown: "Mover para baixo", pinFirst: "Fixar no início", moveLeft: "Mover para a esquerda", moveRight: "Mover para a direita", arrange: "Segure Command e arraste para reorganizar", actions: "Ações")
    static let tr = MixerFeatureStrings(hideInactiveApps: "Etkin olmayan uygulamaları gizle", pin: "En üste sabitle", unpin: "Sabitlemeyi kaldır", moveUp: "Yukarı taşı", moveDown: "Aşağı taşı", pinFirst: "Başa sabitle", moveLeft: "Sola taşı", moveRight: "Sağa taşı", arrange: "Sıralamak için Command tuşunu basılı tutup sürükleyin", actions: "Eylemler")
    static let ru = MixerFeatureStrings(hideInactiveApps: "Скрывать неактивные приложения", pin: "Закрепить сверху", unpin: "Открепить", moveUp: "Переместить вверх", moveDown: "Переместить вниз", pinFirst: "Закрепить в начале", moveLeft: "Переместить влево", moveRight: "Переместить вправо", arrange: "Удерживайте Command и перетащите для изменения порядка", actions: "Действия")
    static let es = MixerFeatureStrings(hideInactiveApps: "Ocultar apps inactivas", pin: "Fijar arriba", unpin: "Desfijar", moveUp: "Mover hacia arriba", moveDown: "Mover hacia abajo", pinFirst: "Fijar al principio", moveLeft: "Mover a la izquierda", moveRight: "Mover a la derecha", arrange: "Mantén pulsado Command y arrastra para reordenar", actions: "Acciones")
    static let sk = MixerFeatureStrings(hideInactiveApps: "Skryť neaktívne aplikácie", pin: "Pripnúť navrch", unpin: "Odopnúť", moveUp: "Presunúť nahor", moveDown: "Presunúť nadol", pinFirst: "Pripnúť dopredu", moveLeft: "Presunúť doľava", moveRight: "Presunúť doprava", arrange: "Podržte Command a presuňte myšou pre zmenu poradia", actions: "Akcie")
    static let de = MixerFeatureStrings(hideInactiveApps: "Inaktive Apps ausblenden", pin: "Oben anheften", unpin: "Loslösen", moveUp: "Nach oben bewegen", moveDown: "Nach unten bewegen", pinFirst: "Vorne anheften", moveLeft: "Nach links bewegen", moveRight: "Nach rechts bewegen", arrange: "Zum Anordnen Command gedrückt halten und ziehen", actions: "Aktionen")
    static let fr = MixerFeatureStrings(hideInactiveApps: "Masquer les apps inactives", pin: "Épingler en haut", unpin: "Désépingler", moveUp: "Déplacer vers le haut", moveDown: "Déplacer vers le bas", pinFirst: "Épingler au début", moveLeft: "Déplacer vers la gauche", moveRight: "Déplacer vers la droite", arrange: "Maintenez Command et faites glisser pour réorganiser", actions: "Actions")
    static let it = MixerFeatureStrings(hideInactiveApps: "Nascondi le app inattive", pin: "Fissa in alto", unpin: "Rimuovi fissaggio", moveUp: "Sposta su", moveDown: "Sposta giù", pinFirst: "Fissa all’inizio", moveLeft: "Sposta a sinistra", moveRight: "Sposta a destra", arrange: "Tieni premuto Command e trascina per riordinare", actions: "Azioni")
    static let ja = MixerFeatureStrings(hideInactiveApps: "非アクティブなアプリを隠す", pin: "一番上に固定", unpin: "固定を解除", moveUp: "上に移動", moveDown: "下に移動", pinFirst: "先頭に固定", moveLeft: "左に移動", moveRight: "右に移動", arrange: "Commandキーを押しながらドラッグして並べ替え", actions: "アクション")
    static let ko = MixerFeatureStrings(hideInactiveApps: "비활성 앱 숨기기", pin: "맨 위에 고정", unpin: "고정 해제", moveUp: "위로 이동", moveDown: "아래로 이동", pinFirst: "맨 앞에 고정", moveLeft: "왼쪽으로 이동", moveRight: "오른쪽으로 이동", arrange: "Command 키를 누른 채 드래그하여 순서 변경", actions: "동작")
    static let zhHans = MixerFeatureStrings(hideInactiveApps: "隐藏不活跃的 App", pin: "置顶", unpin: "取消置顶", moveUp: "上移", moveDown: "下移", pinFirst: "置于最前", moveLeft: "左移", moveRight: "右移", arrange: "按住 Command 并拖移以重新排列", actions: "操作")
    static let zhTW = MixerFeatureStrings(hideInactiveApps: "隱藏非活躍的 App", pin: "置頂", unpin: "取消置頂", moveUp: "上移", moveDown: "下移", pinFirst: "置於最前", moveLeft: "左移", moveRight: "右移", arrange: "按住 Command 並拖移以重新排列", actions: "動作")
    static let zhHK = MixerFeatureStrings(hideInactiveApps: "隱藏非活躍的 App", pin: "置頂", unpin: "取消置頂", moveUp: "上移", moveDown: "下移", pinFirst: "置於最前", moveLeft: "左移", moveRight: "右移", arrange: "按住 Command 並拖移以重新排列", actions: "動作")
}

extension SettingsCategoryStrings {
    static let ko = SettingsCategoryStrings(
        interface: "인터페이스",
        windowsDock: "데스크탑 & 화면",
        audio: "오디오",
        energyDisplay: "기기 제어",
        screenCaptures: "화면 캡처",
        mouseKeyboard: "마우스 & 키보드",
        clipboardFiles: "클립보드 & 파일",
        system: "시스템",
        lattice: "Lattice",
        utilities: "유틸리티"
    )
}

extension ClipboardFeatureStrings {
    static let ko = ClipboardFeatureStrings(
        title: "클립보드",
        enable: "클립보드 기록 저장",
        caption: "복사한 텍스트를 저장하여 나중에 다시 사용할 수 있습니다. 모든 항목은 로컬에 보관되며 언제든 지울 수 있습니다.",
        localNote: "모든 항목은 이 Mac에만 저장됩니다. 너무 큰 항목은 무시됩니다.",
        skipSensitive: "민감해 보이는 텍스트 건너뛰기",
        skipSensitiveCaption: "암호나 토큰처럼 보이는 일반 텍스트도 건너뛸 수 있습니다. 원본 앱이 기밀로 표시한 콘텐츠는 항상 제외됩니다.",
        limit: "제한",
        limitUnlimited: "무제한",
        showInPanel: "패널에 표시",
        shortcut: "기록 단축키",
        shortcutCaption: "검색, 고정 항목 및 이전 앱에 붙여넣기 위한 ⌘1~⌘9 단축키가 있는 빠른 윈도우를 엽니다.",
        clickRowShortcut: "행 클릭",
        pinned: "고정됨",
        recent: "최근 항목",
        pin: "고정",
        unpin: "고정 해제",
        clearRecent: "고정되지 않은 항목 지우기",
        clearRecentKeywords: "최근 항목 지우기",
        empty: "저장한 텍스트가 없습니다",
        disabled: "복사한 텍스트를 저장하려면 기록을 켜세요.",
        search: "복사한 텍스트 검색",
        copy: "복사",
        copied: "복사됨",
        delete: "항목 삭제",
        selectMultiple: "묶음에 추가",
        unselectMultiple: "묶음에서 제거",
        pasteSelectedFormat: "%d개 붙여넣기",
        copySelectedFormat: "%d개 복사",
        clearSelection: "선택 해제",
        moveUp: "위로 이동",
        moveDown: "아래로 이동",
        noResults: "결과 없음",
        active: "새 텍스트 저장 중",
        includeImagesFiles: "복사한 이미지와 파일도 저장",
        includeImagesFilesCaption: "이미지는 기록에 추가되고 파일은 위치 링크로 저장됩니다. 텍스트 항목처럼 고정하고 붙여넣을 수 있습니다.",
        imageEntryLabel: "이미지",
        fileCountFormat: "파일 %d개",
        previewLabel: "미리보기",
        edit: "편집",
        cancel: "취소",
        save: "저장",
        autoClearEnable: "클립보드 자동 지우기 대기 시간",
        autoClearSecondsSuffix: "초",
        autoClearOnSleep: "Mac이 잠자기에 들어갈 때 클립보드 지우기",
        autoClearOnDisplaySleep: "디스플레이가 꺼질 때 클립보드 지우기",
        autoClearOnScreenLock: "화면이 잠길 때 클립보드 지우기",
        autoClearCaption: "시스템 클립보드만 지웁니다. 이미 저장된 항목은 기록에 남습니다.",
        deleteSelectedFormat: "%d개 삭제",
        menuBarPreview: "메뉴 막대에 최근 복사 항목 표시",
        menuBarPreviewCaption: "아이콘 옆에 최근 복사한 내용의 축약된 미리보기를 표시합니다. 클릭하면 기록이 열립니다.",
        menuBarPreviewLength: "미리보기 길이",
        menuBarPreviewLengthSuffix: "자",
        clearRecentConfirmFormat: "고정되지 않은 항목 %d개를 지울까요?",
        clearRecentConfirmMessage: "고정된 항목과 이후에 복사한 내용은 유지됩니다. 되돌릴 수 없습니다.",
        historyLayout: "기록 레이아웃",
        historyLayoutCards: "카드",
        historyLayoutList: "목록",
        showSourceAppIconsInList: "목록 보기에 원본 앱 아이콘 표시"
    )
}

extension WindowLayoutFeatureStrings {
    static let ko = WindowLayoutFeatureStrings(
        title: "윈도우 관리",
        enable: "윈도우 배치 활성화",
        caption: "윈도우를 화면 구역에 배치하거나 트랙패드 또는 마우스로 이동하고 크기를 조절합니다.",
        showInPanel: "유틸리티 메뉴에 표시",
        gestureSection: "윈도우 배치",
        gestureEnable: "드래그로 윈도우 이동 및 크기 조절",
        gestureCaption: "트랙패드 또는 마우스에서 표시된 보조 키를 누른 채 윈도우 안의 아무 곳이나 드래그합니다.",
        gestureModifiers: "이동 키",
        gestureMove: "드래그하여 이동",
        gestureResize: "Shift를 추가하고 드래그하여 크기 조절",
        gestureResizeHint: "시작 위치가 가장 가까운 가장자리나 모서리를 선택합니다. 마우스에서는 오른쪽 버튼 드래그도 크기를 조절합니다.",
        gestureRaiseWindow: "드래그한 윈도우를 앞으로 가져오기",
        shortcuts: "단축키",
        shortcutsCaption: "패널을 열지 않고 전역 단축키로 활성 윈도우를 정렬합니다.",
        permissionCaption: "손쉬운 사용 권한은 윈도우를 이동하고 크기를 조절하는 데만 사용합니다.",
        noWindow: "활성 윈도우를 찾을 수 없습니다.",
        missingPermission: "윈도우를 이동하려면 손쉬운 사용 권한을 허용하세요.",
        failed: "이 윈도우를 이동할 수 없습니다.",
        done: "윈도우를 정렬했습니다.",
        restored: "윈도우를 복원했습니다.",
        noRestore: "복원할 이전 정렬이 없습니다.",
        target: "활성 윈도우",
        halves: "화면 분할",
        thirds: "3등분",
        quarterRows: "가로 4등분",
        quarterColumns: "세로 4등분",
        sixths: "격자",
        corners: "모서리",
        other: "크기 조정 및 동작",
        moving: "다중 디스플레이",
        leftHalf: "왼쪽",
        rightHalf: "오른쪽",
        topHalf: "위쪽",
        bottomHalf: "아래쪽",
        centerHalf: "가운데 반",
        leftThird: "왼쪽 1/3",
        centerThird: "가운데 1/3",
        rightThird: "오른쪽 1/3",
        leftTwoThirds: "왼쪽 2/3",
        rightTwoThirds: "오른쪽 2/3",
        centerTwoThirds: "가운데 2/3",
        topThird: "위쪽 1/3",
        middleThird: "가운데 1/3",
        bottomThird: "아래쪽 1/3",
        topTwoThirds: "위쪽 2/3",
        bottomTwoThirds: "아래쪽 2/3",
        topQuarter: "상단 4등분",
        upperMiddleQuarter: "중앙 상단 4등분",
        lowerMiddleQuarter: "중앙 하단 4등분",
        bottomQuarter: "하단 4등분",
        leftQuarter: "왼쪽 4등분",
        leftMiddleQuarter: "왼쪽 중앙 4등분",
        rightMiddleQuarter: "오른쪽 중앙 4등분",
        rightQuarter: "오른쪽 4등분",
        topLeftSixth: "왼쪽 상단 격자",
        topCenterSixth: "중앙 상단 격자",
        topRightSixth: "오른쪽 상단 격자",
        bottomLeftSixth: "왼쪽 하단 격자",
        bottomCenterSixth: "중앙 하단 격자",
        bottomRightSixth: "오른쪽 하단 격자",
        topLeft: "왼쪽 상단 4등분",
        topRight: "오른쪽 상단 4등분",
        bottomLeft: "왼쪽 하단 4등분",
        bottomRight: "오른쪽 하단 4등분",
        maximize: "최대화",
        center: "가운데",
        nextDisplay: "창을 다음 디스플레이로 이동",
        restore: "복원",
        fullScreen: "전체 화면",
        previousDisplay: "창을 이전 디스플레이로 이동",
        edgeSnapEnable: "화면 가장자리에 윈도우 맞추기",
        edgeSnapSection: "윈도우를 드래그하여 맞춤",
        edgeSnapCaption: "윈도우를 화면 가장자리나 모서리로 드래그하여 제자리에 맞춥니다.",
        edgeSnapSystemConflict: "macOS가 같은 가장자리를 사용 중입니다. 데스크탑 및 Dock에서 윈도우 타일링을 끄면 Lattice가 사용할 수 있습니다.",
        edgeSnapOpenSystemSettings: "데스크탑 및 Dock 열기",
        edgeSnapWaitingForSystem: "Lattice에서 켜졌습니다. macOS 타일링을 끄면 바로 작동합니다.",
        edgeSnapUseCorner: "이 모서리 사용",
        edgeSnapUseEdge: "이 가장자리 사용",
        edgeSnapAreasOnEdge: "이 가장자리의 영역",
        gapsSection: "간격",
        gapsCaption: "스냅된 윈도우 사이, 그리고 윈도우와 화면 가장자리 사이의 간격입니다.",
        windowGap: "윈도우 사이 여백",
        screenGap: "화면 가장자리 여백",
        sideRepeatCycle: "왼쪽/오른쪽 반복 시 크기 순환",
        sideRepeatCycleCaption: "같은 디스플레이에서 절반, 2/3, 1/3 순으로 바뀝니다. 끄면 디스플레이가 여러 개일 때 그 방향의 다음 디스플레이로 이동합니다.",
        gapNone: "없음",
        gapTiny: "아주 작게",
        gapSmall: "작게",
        gapMedium: "중간",
        gapLarge: "크게",
        gapExtraLarge: "아주 크게"
    )
}

extension MonitorAlertFeatureStrings {
    static let ko = MonitorAlertFeatureStrings(
        section: "알림",
        caption: "값이 한도를 넘으면 알림을 받습니다. 12초 미만의 CPU 급증은 제외됩니다.",
        notificationsDenied: "시스템 설정에서 Lattice 알림이 꺼져 있어 경고를 표시할 수 없습니다.",
        cpu: "CPU 사용률",
        cpuTemperature: "CPU 온도",
        memory: "위험한 메모리 압력",
        disk: "디스크 여유 공간",
        battery: "배터리 잔량",
        cooldown: "다시 알림 간격",
        aboveFormat: "%@ 초과",
        belowFormat: "%@ 미만",
        cooldown2: "2분",
        cooldown5: "5분",
        cooldown15: "15분",
        cooldown30: "30분",
        cooldown60: "1시간",
        cpuTitle: "높은 CPU 사용량",
        cpuBodyFormat: "CPU 사용량이 몇 초 동안 %d%%를 넘었습니다.",
        cpuTemperatureTitle: "CPU 과열",
        cpuTemperatureBodyFormat: "CPU 온도가 %@에 도달했습니다.",
        memoryTitle: "위험한 메모리",
        memoryBody: "메모리 압력이 위험 수준에 도달했습니다.",
        diskTitle: "부족한 디스크 공간",
        diskBodyFormat: "%@의 여유 공간이 %d%% 미만입니다.",
        batteryTitle: "낮은 배터리",
        batteryBodyFormat: "배터리 잔량이 %d%%입니다.",
        batteryTemperature: "배터리 온도",
        batteryTemperatureTitle: "배터리 과열",
        batteryTemperatureBodyFormat: "배터리 온도가 %@에 도달했습니다."
    )
}

struct SettingsCategoryStrings {
    let interface: String
    let windowsDock: String
    let audio: String
    let energyDisplay: String
    let screenCaptures: String
    let mouseKeyboard: String
    let clipboardFiles: String
    let system: String
    let lattice: String
    let utilities: String

    var sound: String { audio }
    var files: String { clipboardFiles }
    var appManagement: String { system }

    static let enUS = SettingsCategoryStrings(
        interface: "Interface",
        windowsDock: "Desktop & Screen",
        audio: "Audio",
        energyDisplay: "Device Controls",
        screenCaptures: "Screen Captures",
        mouseKeyboard: "Mouse & Keyboard",
        clipboardFiles: "Clipboard & Files",
        system: "System",
        lattice: "Lattice",
        utilities: "Utilities"
    )

    static let ptBR = SettingsCategoryStrings(
        interface: "Interface",
        windowsDock: "Mesa & Tela",
        audio: "Áudio",
        energyDisplay: "Controles do Dispositivo",
        screenCaptures: "Capturas de Tela",
        mouseKeyboard: "Mouse & Teclado",
        clipboardFiles: "Área de Transferência & Arquivos",
        system: "Sistema",
        lattice: "Lattice",
        utilities: "Utilitários"
    )

    static let tr = SettingsCategoryStrings(
        interface: "Arayüz",
        windowsDock: "Masaüstü & Ekran",
        audio: "Ses",
        energyDisplay: "Aygıt Denetimleri",
        screenCaptures: "Ekran Yakalamaları",
        mouseKeyboard: "Fare & Klavye",
        clipboardFiles: "Pano & Dosyalar",
        system: "Sistem",
        lattice: "Lattice",
        utilities: "Araçlar"
    )

    static let ru = SettingsCategoryStrings(
        interface: "Интерфейс",
        windowsDock: "Рабочий стол & экран",
        audio: "Аудио",
        energyDisplay: "Управление устройствами",
        screenCaptures: "Записи Экрана",
        mouseKeyboard: "Мышь & клавиатура",
        clipboardFiles: "Буфер обмена & файлы",
        system: "Система",
        lattice: "Lattice",
        utilities: "Утилиты"
    )

    static let es = SettingsCategoryStrings(
        interface: "Interfaz",
        windowsDock: "Escritorio & pantalla",
        audio: "Audio",
        energyDisplay: "Controles del dispositivo",
        screenCaptures: "Capturas de Pantalla",
        mouseKeyboard: "Ratón & teclado",
        clipboardFiles: "Portapapeles & archivos",
        system: "Sistema",
        lattice: "Lattice",
        utilities: "Utilidades"
    )

    static let sk = SettingsCategoryStrings(
        interface: "Rozhranie",
        windowsDock: "Plocha & obrazovka",
        audio: "Audio",
        energyDisplay: "Ovládanie zariadení",
        screenCaptures: "Snímky Obrazovky",
        mouseKeyboard: "Myš & klávesnica",
        clipboardFiles: "Schránka & súbory",
        system: "Systém",
        lattice: "Lattice",
        utilities: "Pomôcky"
    )

    static let de = SettingsCategoryStrings(
        interface: "Bedienoberfläche",
        windowsDock: "Schreibtisch & Bildschirm",
        audio: "Audio",
        energyDisplay: "Gerätesteuerung",
        screenCaptures: "Bildschirmaufnahmen",
        mouseKeyboard: "Maus & Tastatur",
        clipboardFiles: "Zwischenablage & Dateien",
        system: "System",
        lattice: "Lattice",
        utilities: "Dienstprogramme"
    )

    static let fr = SettingsCategoryStrings(
        interface: "Interface",
        windowsDock: "Bureau & écran",
        audio: "Audio",
        energyDisplay: "Contrôles de l’appareil",
        screenCaptures: "Captures d’Écran",
        mouseKeyboard: "Souris & clavier",
        clipboardFiles: "Presse-papiers & fichiers",
        system: "Système",
        lattice: "Lattice",
        utilities: "Utilitaires"
    )

    static let it = SettingsCategoryStrings(
        interface: "Interfaccia",
        windowsDock: "Scrivania & schermo",
        audio: "Audio",
        energyDisplay: "Controlli del dispositivo",
        screenCaptures: "Registrazioni Schermo",
        mouseKeyboard: "Mouse & tastiera",
        clipboardFiles: "Appunti & file",
        system: "Sistema",
        lattice: "Lattice",
        utilities: "Utilità"
    )

    static let ja = SettingsCategoryStrings(
        interface: "インターフェイス",
        windowsDock: "デスクトップ & 画面",
        audio: "オーディオ",
        energyDisplay: "デバイスコントロール",
        screenCaptures: "画面キャプチャ",
        mouseKeyboard: "マウス & キーボード",
        clipboardFiles: "クリップボード & ファイル",
        system: "システム",
        lattice: "Lattice",
        utilities: "ユーティリティ"
    )

    static let zhHans = SettingsCategoryStrings(
        interface: "界面",
        windowsDock: "桌面 & 屏幕",
        audio: "音频",
        energyDisplay: "设备控制",
        screenCaptures: "屏幕截图与录制",
        mouseKeyboard: "鼠标 & 键盘",
        clipboardFiles: "剪贴板 & 文件",
        system: "系统",
        lattice: "Lattice",
        utilities: "实用工具"
    )

    static let zhTW = SettingsCategoryStrings(
        interface: "介面",
        windowsDock: "桌面 & 螢幕",
        audio: "音訊",
        energyDisplay: "裝置控制",
        screenCaptures: "螢幕擷取與錄製",
        mouseKeyboard: "滑鼠 & 鍵盤",
        clipboardFiles: "剪貼簿 & 檔案",
        system: "系統",
        lattice: "Lattice",
        utilities: "工具程式"
    )

    static let zhHK = SettingsCategoryStrings(
        interface: "介面",
        windowsDock: "桌面 & 螢幕",
        audio: "音訊",
        energyDisplay: "裝置控制",
        screenCaptures: "螢幕截圖與錄製",
        mouseKeyboard: "滑鼠 & 鍵盤",
        clipboardFiles: "剪貼簿 & 檔案",
        system: "系統",
        lattice: "Lattice",
        utilities: "工具"
    )
}

struct ClipboardFeatureStrings {
    let title: String
    let enable: String
    let caption: String
    let localNote: String
    let skipSensitive: String
    let skipSensitiveCaption: String
    let limit: String
    let limitUnlimited: String
    let showInPanel: String
    let shortcut: String
    let shortcutCaption: String
    let clickRowShortcut: String
    let pinned: String
    let recent: String
    let pin: String
    let unpin: String
    let clearRecent: String
    let clearRecentKeywords: String
    let empty: String
    let disabled: String
    let search: String
    let copy: String
    let copied: String
    let delete: String
    let selectMultiple: String
    let unselectMultiple: String
    let pasteSelectedFormat: String
    let copySelectedFormat: String
    let clearSelection: String
    let moveUp: String
    let moveDown: String
    let noResults: String
    let active: String
    let includeImagesFiles: String
    let includeImagesFilesCaption: String
    let imageEntryLabel: String
    let fileCountFormat: String
    let previewLabel: String
    let edit: String
    let cancel: String
    let save: String
    let autoClearEnable: String
    let autoClearSecondsSuffix: String
    let autoClearOnSleep: String
    let autoClearOnDisplaySleep: String
    let autoClearOnScreenLock: String
    let autoClearCaption: String
    let deleteSelectedFormat: String
    let menuBarPreview: String
    let menuBarPreviewCaption: String
    let menuBarPreviewLength: String
    let menuBarPreviewLengthSuffix: String
    let clearRecentConfirmFormat: String
    let clearRecentConfirmMessage: String
    let historyLayout: String
    let historyLayoutCards: String
    let historyLayoutList: String
    let showSourceAppIconsInList: String

    static let enUS = ClipboardFeatureStrings(
        title: "Clipboard History",
        enable: "Enable Clipboard History",
        caption: "Stores copied text so you can reuse it later. Everything stays local and can be cleared anytime.",
        localNote: "Everything stays on this Mac. Very large items are ignored.",
        skipSensitive: "Skip text that looks sensitive",
        skipSensitiveCaption: "May skip ordinary text that resembles passwords or tokens. Content marked as confidential by its source app is always excluded.",
        limit: "Limit",
        limitUnlimited: "Unlimited",
        showInPanel: "Show in panel",
        shortcut: "History shortcut",
        shortcutCaption: "Opens a quick window with search, pinned items and ⌘1 to ⌘9 shortcuts for pasting into the previous app.",
        clickRowShortcut: "Click row",
        pinned: "Pinned",
        recent: "Recent",
        pin: "Pin",
        unpin: "Unpin",
        clearRecent: "Clear unpinned",
        clearRecentKeywords: "Clear recent",
        empty: "No saved text",
        disabled: "Enable history to start saving copied text.",
        search: "Search copied text",
        copy: "Copy",
        copied: "Copied",
        delete: "Delete item",
        selectMultiple: "Add to pile",
        unselectMultiple: "Remove from pile",
        pasteSelectedFormat: "Paste %d",
        copySelectedFormat: "Copy %d",
        clearSelection: "Clear selection",
        moveUp: "Move up",
        moveDown: "Move down",
        noResults: "No results",
        active: "Saving new text",
        includeImagesFiles: "Also save copied images and files",
        includeImagesFilesCaption: "Images join the history and files are remembered as links to their location. Pin and paste them like any text item.",
        imageEntryLabel: "Image",
        fileCountFormat: "%d files",
        previewLabel: "Preview",
        edit: "Edit",
        cancel: "Cancel",
        save: "Save",
        autoClearEnable: "Auto clear clipboard with a delay of",
        autoClearSecondsSuffix: "seconds",
        autoClearOnSleep: "Clear clipboard on computer sleep",
        autoClearOnDisplaySleep: "Clear clipboard on display sleep",
        autoClearOnScreenLock: "Clear clipboard on screen lock",
        autoClearCaption: "Clears the system clipboard only. Items already saved stay in the history.",
        deleteSelectedFormat: "Delete %d",
        menuBarPreview: "Show latest copy in the menu bar",
        menuBarPreviewCaption: "Shows a shortened preview of your last copy next to the icon. Click it to open the history.",
        menuBarPreviewLength: "Preview length",
        menuBarPreviewLengthSuffix: "characters",
        clearRecentConfirmFormat: "Clear unpinned (%d)?",
        clearRecentConfirmMessage: "Pinned items stay, and so does anything copied after this. This can’t be undone.",
        historyLayout: "History layout",
        historyLayoutCards: "Cards",
        historyLayoutList: "List",
        showSourceAppIconsInList: "Show source app icons in list view"
    )

    static let ptBR = ClipboardFeatureStrings(
        title: "Clipboard",
        enable: "Guardar histórico de clipboard",
        caption: "Guarda textos copiados para reutilizar depois. Tudo fica local e pode ser apagado a qualquer momento.",
        localNote: "Tudo fica neste Mac. Itens muito grandes são ignorados.",
        skipSensitive: "Ignorar textos com aparência sensível",
        skipSensitiveCaption: "Pode ignorar textos comuns que pareçam senhas ou tokens. Conteúdo marcado como confidencial pelo aplicativo de origem nunca é salvo.",
        limit: "Limite",
        limitUnlimited: "Ilimitado",
        showInPanel: "Mostrar no painel",
        shortcut: "Atalho do histórico",
        shortcutCaption: "Abre uma janela rápida com busca, favoritos e atalhos ⌘1 a ⌘9 para colar no app anterior.",
        clickRowShortcut: "Clique na linha",
        pinned: "Fixados",
        recent: "Recentes",
        pin: "Fixar",
        unpin: "Desfixar",
        clearRecent: "Limpar não fixados",
        clearRecentKeywords: "Limpar recentes",
        empty: "Nenhum texto salvo",
        disabled: "Ative o histórico para começar a guardar textos copiados.",
        search: "Buscar textos copiados",
        copy: "Copiar",
        copied: "Copiado",
        delete: "Apagar item",
        selectMultiple: "Marcar para pilha",
        unselectMultiple: "Remover da pilha",
        pasteSelectedFormat: "Colar %d",
        copySelectedFormat: "Copiar %d",
        clearSelection: "Limpar seleção",
        moveUp: "Mover para cima",
        moveDown: "Mover para baixo",
        noResults: "Nenhum resultado",
        active: "Guardando novos textos",
        includeImagesFiles: "Guardar também imagens e arquivos copiados",
        includeImagesFilesCaption: "Imagens entram no histórico e arquivos são lembrados como links para o local deles. Fixe e cole como qualquer texto.",
        imageEntryLabel: "Imagem",
        fileCountFormat: "%d arquivos",
        previewLabel: "Prévia",
        edit: "Editar",
        cancel: "Cancelar",
        save: "Salvar",
        autoClearEnable: "Limpar o clipboard automaticamente após",
        autoClearSecondsSuffix: "segundos",
        autoClearOnSleep: "Limpar o clipboard quando o Mac dormir",
        autoClearOnDisplaySleep: "Limpar o clipboard quando a tela apagar",
        autoClearOnScreenLock: "Limpar o clipboard ao bloquear a tela",
        autoClearCaption: "Limpa apenas o clipboard do sistema. Os itens já guardados continuam no histórico.",
        deleteSelectedFormat: "Apagar %d",
        menuBarPreview: "Mostrar a última cópia na barra de menus",
        menuBarPreviewCaption: "Mostra uma prévia resumida da sua última cópia ao lado do ícone. Clique nela para abrir o histórico.",
        menuBarPreviewLength: "Tamanho da prévia",
        menuBarPreviewLengthSuffix: "caracteres",
        clearRecentConfirmFormat: "Limpar não fixados (%d)?",
        clearRecentConfirmMessage: "Os itens fixados ficam, e o que for copiado depois disso também. Não dá para desfazer.",
        historyLayout: "Layout do histórico",
        historyLayoutCards: "Cartões",
        historyLayoutList: "Lista",
        showSourceAppIconsInList: "Mostrar ícones dos apps de origem na lista"
    )

    static let tr = ClipboardFeatureStrings(
        title: "Pano",
        enable: "Pano geçmişini kaydet",
        caption: "Kopyalanan metinleri daha sonra yeniden kullanabilmen için saklar. Her şey yerel kalır ve istediğin zaman temizlenebilir.",
        localNote: "Her şey bu Mac’te kalır. Çok büyük öğeler yok sayılır.",
        skipSensitive: "Hassas görünen metinleri atla",
        skipSensitiveCaption: "Parola veya token gibi görünen normal metinleri de atlayabilir. Kaynak uygulamanın gizli olarak işaretlediği içerik her zaman hariç tutulur.",
        limit: "Sınır",
        limitUnlimited: "Sınırsız",
        showInPanel: "Panelde göster",
        shortcut: "Geçmiş kısayolu",
        shortcutCaption: "Arama, sabitlenmiş öğeler ve önceki uygulamaya yapıştırmak için ⌘1 - ⌘9 kısayolları olan hızlı bir pencere açar.",
        clickRowShortcut: "Satıra tıkla",
        pinned: "Sabitlenenler",
        recent: "Son",
        pin: "Sabitle",
        unpin: "Sabitlemeyi kaldır",
        clearRecent: "Sabitlenmeyenleri temizle",
        clearRecentKeywords: "Sonları temizle",
        empty: "Kayıtlı metin yok",
        disabled: "Kopyalanan metinleri kaydetmeye başlamak için geçmişi etkinleştir.",
        search: "Kopyalanan metinlerde ara",
        copy: "Kopyala",
        copied: "Kopyalandı",
        delete: "Öğeyi sil",
        selectMultiple: "Yığına ekle",
        unselectMultiple: "Yığından çıkar",
        pasteSelectedFormat: "%d öğeyi yapıştır",
        copySelectedFormat: "%d öğeyi kopyala",
        clearSelection: "Seçimi temizle",
        moveUp: "Yukarı taşı",
        moveDown: "Aşağı taşı",
        noResults: "Sonuç yok",
        active: "Yeni metinler kaydediliyor",
        includeImagesFiles: "Kopyalanan görselleri ve dosyaları da kaydet",
        includeImagesFilesCaption: "Görseller geçmişe eklenir, dosyalar konumlarına bağlantı olarak hatırlanır. Metin gibi sabitle ve yapıştır.",
        imageEntryLabel: "Görsel",
        fileCountFormat: "%d dosya",
        previewLabel: "Önizleme",
        edit: "Düzenle",
        cancel: "İptal",
        save: "Kaydet",
        autoClearEnable: "Panoyu otomatik temizle, gecikme",
        autoClearSecondsSuffix: "saniye",
        autoClearOnSleep: "Mac uykuya geçince panoyu temizle",
        autoClearOnDisplaySleep: "Ekran uykuya geçince panoyu temizle",
        autoClearOnScreenLock: "Ekran kilitlenince panoyu temizle",
        autoClearCaption: "Yalnızca sistem panosunu temizler. Kaydedilmiş ögeler geçmişte kalır.",
        deleteSelectedFormat: "%d öğeyi sil",
        menuBarPreview: "Menü çubuğunda son kopyalananı göster",
        menuBarPreviewCaption: "Simgenin yanında son kopyalananın kısaltılmış bir önizlemesini gösterir. Geçmişi açmak için üzerine tıkla.",
        menuBarPreviewLength: "Önizleme uzunluğu",
        menuBarPreviewLengthSuffix: "karakter",
        clearRecentConfirmFormat: "%d sabitlenmemiş öğe temizlensin mi?",
        clearRecentConfirmMessage: "Sabitlenen öğeler ve bundan sonra kopyalananlar kalır. Bu işlem geri alınamaz.",
        historyLayout: "Geçmiş yerleşimi",
        historyLayoutCards: "Kartlar",
        historyLayoutList: "Liste",
        showSourceAppIconsInList: "Liste görünümünde kaynak uygulama simgelerini göster"
    )

    static let ru = ClipboardFeatureStrings(
        title: "Буфер обмена",
        enable: "Сохранять историю буфера обмена",
        caption: "Сохраняет скопированный текст, чтобы вы могли использовать его позже. Всё остаётся локально и может быть очищено в любой момент.",
        localNote: "Всё остаётся на этом Mac. Слишком большие элементы игнорируются.",
        skipSensitive: "Пропускать текст, похожий на конфиденциальный",
        skipSensitiveCaption: "Может пропускать обычный текст, похожий на пароли или токены. Содержимое, отмеченное исходным приложением как конфиденциальное, всегда исключается.",
        limit: "Лимит",
        limitUnlimited: "Без ограничений",
        showInPanel: "Показывать в панели",
        shortcut: "Горячая клавиша истории",
        shortcutCaption: "Открывает быстрое окно с поиском, закреплёнными элементами и сочетаниями ⌘1–⌘9 для вставки в предыдущее приложение.",
        clickRowShortcut: "Щелчок по строке",
        pinned: "Закреплённые",
        recent: "Недавние",
        pin: "Закрепить",
        unpin: "Открепить",
        clearRecent: "Очистить незакреплённые",
        clearRecentKeywords: "Очистить недавнее",
        empty: "Нет сохранённого текста",
        disabled: "Включите историю, чтобы начать сохранять скопированный текст.",
        search: "Поиск по скопированному тексту",
        copy: "Скопировать",
        copied: "Скопировано",
        delete: "Удалить элемент",
        selectMultiple: "Добавить в стопку",
        unselectMultiple: "Убрать из стопки",
        pasteSelectedFormat: "Вставить: %d",
        copySelectedFormat: "Копировать: %d",
        clearSelection: "Снять выделение",
        moveUp: "Вверх",
        moveDown: "Вниз",
        noResults: "Ничего не найдено",
        active: "Сохраняет новые элементы",
        includeImagesFiles: "Сохранять также изображения и файлы",
        includeImagesFilesCaption: "Изображения попадают в историю, а файлы запоминаются как ссылки на их расположение. Закрепляйте и вставляйте их как текст.",
        imageEntryLabel: "Изображение",
        fileCountFormat: "Файлов: %d",
        previewLabel: "Просмотр",
        edit: "Редактировать",
        cancel: "Отмена",
        save: "Сохранить",
        autoClearEnable: "Очищать буфер обмена через",
        autoClearSecondsSuffix: "секунд",
        autoClearOnSleep: "Очищать буфер обмена при переходе в режим сна",
        autoClearOnDisplaySleep: "Очищать буфер обмена при выключении экрана",
        autoClearOnScreenLock: "Очищать буфер обмена при блокировке экрана",
        autoClearCaption: "Очищается только системный буфер обмена. Сохранённые элементы остаются в истории.",
        deleteSelectedFormat: "Удалить: %d",
        menuBarPreview: "Показывать последнюю скопированную запись в строке меню",
        menuBarPreviewCaption: "Показывает сокращённый предпросмотр последней скопированной записи рядом со значком. Нажмите на него, чтобы открыть историю.",
        menuBarPreviewLength: "Длина предпросмотра",
        menuBarPreviewLengthSuffix: "символов",
        clearRecentConfirmFormat: "Очистить незакреплённые (%d)?",
        clearRecentConfirmMessage: "Закреплённые останутся, как и всё, что скопировано после этого. Отменить нельзя.",
        historyLayout: "Макет истории",
        historyLayoutCards: "Карточки",
        historyLayoutList: "Список",
        showSourceAppIconsInList: "Показывать значки исходных приложений в списке"
    )

    static let es = ClipboardFeatureStrings(
        title: "Portapapeles",
        enable: "Guardar historial del portapapeles",
        caption: "Guarda el texto copiado para reutilizarlo después. Todo queda local y se puede borrar cuando quieras.",
        localNote: "Todo se queda en este Mac. Los elementos muy grandes se ignoran.",
        skipSensitive: "Omitir texto que parezca sensible",
        skipSensitiveCaption: "Puede omitir texto normal que parezca una contraseña o un token. El contenido marcado como confidencial por la app de origen siempre se excluye.",
        limit: "Límite",
        limitUnlimited: "Ilimitado",
        showInPanel: "Mostrar en el panel",
        shortcut: "Atajo del historial",
        shortcutCaption: "Abre una ventana rápida con búsqueda, elementos fijados y atajos ⌘1 a ⌘9 para pegar en la app anterior.",
        clickRowShortcut: "Clic en fila",
        pinned: "Fijados",
        recent: "Recientes",
        pin: "Fijar",
        unpin: "Desfijar",
        clearRecent: "Limpiar no fijados",
        clearRecentKeywords: "Limpiar recientes",
        empty: "No hay texto guardado",
        disabled: "Activa el historial para empezar a guardar texto copiado.",
        search: "Buscar texto copiado",
        copy: "Copiar",
        copied: "Copiado",
        delete: "Eliminar elemento",
        selectMultiple: "Añadir a la pila",
        unselectMultiple: "Quitar de la pila",
        pasteSelectedFormat: "Pegar %d",
        copySelectedFormat: "Copiar %d",
        clearSelection: "Limpiar selección",
        moveUp: "Subir",
        moveDown: "Bajar",
        noResults: "Sin resultados",
        active: "Guardando nuevo texto",
        includeImagesFiles: "Guardar también imágenes y archivos copiados",
        includeImagesFilesCaption: "Las imágenes entran en el historial y los archivos se recuerdan como enlaces a su ubicación. Fíjalos y pégalos como cualquier texto.",
        imageEntryLabel: "Imagen",
        fileCountFormat: "%d archivos",
        previewLabel: "Vista previa",
        edit: "Editar",
        cancel: "Cancelar",
        save: "Guardar",
        autoClearEnable: "Vaciar el portapapeles automáticamente tras",
        autoClearSecondsSuffix: "segundos",
        autoClearOnSleep: "Vaciar el portapapeles al suspender el Mac",
        autoClearOnDisplaySleep: "Vaciar el portapapeles al apagarse la pantalla",
        autoClearOnScreenLock: "Vaciar el portapapeles al bloquear la pantalla",
        autoClearCaption: "Solo se vacía el portapapeles del sistema. Los elementos guardados siguen en el historial.",
        deleteSelectedFormat: "Eliminar %d",
        menuBarPreview: "Mostrar la última copia en la barra de menús",
        menuBarPreviewCaption: "Muestra una vista previa abreviada de tu última copia junto al icono. Haz clic para abrir el historial.",
        menuBarPreviewLength: "Longitud de la vista previa",
        menuBarPreviewLengthSuffix: "caracteres",
        clearRecentConfirmFormat: "¿Limpiar no fijados (%d)?",
        clearRecentConfirmMessage: "Los fijados se conservan, y también lo que copies después. No se puede deshacer.",
        historyLayout: "Diseño del historial",
        historyLayoutCards: "Tarjetas",
        historyLayoutList: "Lista",
        showSourceAppIconsInList: "Mostrar iconos de las apps de origen en la lista"
    )

    static let sk = ClipboardFeatureStrings(
        title: "Schránka",
        enable: "Ukladať históriu schránky",
        caption: "Ukladá skopírovaný text, aby ste ho mohli neskôr znova použiť. Všetko zostáva lokálne a môžete to kedykoľvek vymazať.",
        localNote: "Všetko zostáva len na tomto Macu. Príliš veľké položky sa ignorujú.",
        skipSensitive: "Preskočiť text, ktorý vyzerá citlivo",
        skipSensitiveCaption: "Môže preskočiť aj bežný text, ktorý pripomína heslá alebo tokeny. Obsah označený zdrojovou aplikáciou ako dôverný sa vždy vylúči.",
        limit: "Limit",
        limitUnlimited: "Bez obmedzenia",
        showInPanel: "Zobraziť v paneli",
        shortcut: "Skratka histórie",
        shortcutCaption: "Otvorí rýchle okno s vyhľadávaním, pripnutými položkami a skratkami ⌘1 až ⌘9 na prilepenie do predchádzajúcej aplikácie.",
        clickRowShortcut: "Kliknutie na riadok",
        pinned: "Pripnuté",
        recent: "Nedávne",
        pin: "Pripnúť",
        unpin: "Odopnúť",
        clearRecent: "Vymazať nepripnuté",
        clearRecentKeywords: "Vymazať nedávne",
        empty: "Žiadny uložený text",
        disabled: "Históriu zapnite, aby sa začal ukladať skopírovaný text.",
        search: "Hľadať v skopírovanom texte",
        copy: "Kopírovať",
        copied: "Skopírované",
        delete: "Vymazať položku",
        selectMultiple: "Pridať do kôpky",
        unselectMultiple: "Odobrať z kôpky",
        pasteSelectedFormat: "Prilepiť %d",
        copySelectedFormat: "Kopírovať %d",
        clearSelection: "Zrušiť výber",
        moveUp: "Presunúť nahor",
        moveDown: "Presunúť nadol",
        noResults: "Žiadne výsledky",
        active: "Ukladá sa nový text",
        includeImagesFiles: "Ukladať aj skopírované obrázky a súbory",
        includeImagesFilesCaption: "Obrázky sa pridajú do histórie a súbory sa zapamätajú ako odkazy na ich umiestnenie. Pripínajte a prilepujte ich ako hocijaký text.",
        imageEntryLabel: "Obrázok",
        fileCountFormat: "Súbory: %d",
        previewLabel: "Náhľad",
        edit: "Upraviť",
        cancel: "Zrušiť",
        save: "Uložiť",
        autoClearEnable: "Automaticky vymazať schránku s oneskorením",
        autoClearSecondsSuffix: "sekúnd",
        autoClearOnSleep: "Vymazať schránku pri uspaní Macu",
        autoClearOnDisplaySleep: "Vymazať schránku pri vypnutí displeja",
        autoClearOnScreenLock: "Vymazať schránku pri uzamknutí obrazovky",
        autoClearCaption: "Vymaže iba systémovú schránku. Už uložené položky zostanú v histórii.",
        deleteSelectedFormat: "Vymazať %d",
        menuBarPreview: "Zobraziť poslednú kópiu v lište",
        menuBarPreviewCaption: "Zobrazí skrátený náhľad poslednej kópie vedľa ikony. Kliknutím naň otvoríte históriu.",
        menuBarPreviewLength: "Dĺžka náhľadu",
        menuBarPreviewLengthSuffix: "znakov",
        clearRecentConfirmFormat: "Vymazať nepripnuté (%d)?",
        clearRecentConfirmMessage: "Pripnuté položky zostanú, rovnako ako všetko, čo skopírujete potom. Nedá sa to vrátiť späť.",
        historyLayout: "Rozloženie histórie",
        historyLayoutCards: "Karty",
        historyLayoutList: "Zoznam",
        showSourceAppIconsInList: "Zobraziť ikony zdrojových aplikácií v zozname"
    )

    static let de = ClipboardFeatureStrings(
        title: "Zwischenablage",
        enable: "Zwischenablageverlauf speichern",
        caption: "Speichert kopierten Text, damit du ihn später wiederverwenden kannst. Alles bleibt lokal und kann jederzeit gelöscht werden.",
        localNote: "Alles bleibt auf diesem Mac. Sehr große Inhalte werden ignoriert.",
        skipSensitive: "Text überspringen, der sensibel wirkt",
        skipSensitiveCaption: "Kann auch normalen Text überspringen, der wie Passwörter oder Tokens aussieht. Von der Quell-App als vertraulich markierte Inhalte werden immer ausgeschlossen.",
        limit: "Limit",
        limitUnlimited: "Unbegrenzt",
        showInPanel: "Im Panel anzeigen",
        shortcut: "Verlaufskürzel",
        shortcutCaption: "Öffnet ein Schnellfenster mit Suche, angehefteten Einträgen und ⌘1 bis ⌘9 zum Einfügen in die vorherige App.",
        clickRowShortcut: "Zeile klicken",
        pinned: "Angeheftet",
        recent: "Zuletzt",
        pin: "Anheften",
        unpin: "Lösen",
        clearRecent: "Nicht angeheftete löschen",
        clearRecentKeywords: "Zuletzt löschen",
        empty: "Kein gespeicherter Text",
        disabled: "Aktiviere den Verlauf, um kopierten Text zu speichern.",
        search: "Kopierten Text suchen",
        copy: "Kopieren",
        copied: "Kopiert",
        delete: "Eintrag löschen",
        selectMultiple: "Zum Stapel hinzufügen",
        unselectMultiple: "Aus dem Stapel entfernen",
        pasteSelectedFormat: "%d einfügen",
        copySelectedFormat: "%d kopieren",
        clearSelection: "Auswahl löschen",
        moveUp: "Nach oben",
        moveDown: "Nach unten",
        noResults: "Keine Ergebnisse",
        active: "Speichert neuen Text",
        includeImagesFiles: "Auch kopierte Bilder und Dateien speichern",
        includeImagesFilesCaption: "Bilder wandern in den Verlauf, Dateien werden als Verweise auf ihren Ort gemerkt. Anheften und Einsetzen wie bei Text.",
        imageEntryLabel: "Bild",
        fileCountFormat: "%d Dateien",
        previewLabel: "Vorschau",
        edit: "Bearbeiten",
        cancel: "Abbrechen",
        save: "Sichern",
        autoClearEnable: "Zwischenablage automatisch leeren nach",
        autoClearSecondsSuffix: "Sekunden",
        autoClearOnSleep: "Zwischenablage beim Ruhezustand leeren",
        autoClearOnDisplaySleep: "Zwischenablage beim Ausschalten des Bildschirms leeren",
        autoClearOnScreenLock: "Zwischenablage beim Sperren des Bildschirms leeren",
        autoClearCaption: "Leert nur die Zwischenablage des Systems. Bereits gesicherte Einträge bleiben im Verlauf.",
        deleteSelectedFormat: "%d löschen",
        menuBarPreview: "Letzte Kopie in der Menüleiste anzeigen",
        menuBarPreviewCaption: "Zeigt eine gekürzte Vorschau deiner letzten Kopie neben dem Symbol. Klicke darauf, um den Verlauf zu öffnen.",
        menuBarPreviewLength: "Vorschaulänge",
        menuBarPreviewLengthSuffix: "Zeichen",
        clearRecentConfirmFormat: "Nicht angeheftete löschen (%d)?",
        clearRecentConfirmMessage: "Angeheftete bleiben, ebenso alles, was du danach kopierst. Das lässt sich nicht widerrufen.",
        historyLayout: "Verlaufslayout",
        historyLayoutCards: "Karten",
        historyLayoutList: "Liste",
        showSourceAppIconsInList: "Symbole der Quell-Apps in der Liste anzeigen"
    )

    static let fr = ClipboardFeatureStrings(
        title: "Presse-papiers",
        enable: "Enregistrer l’historique du presse-papiers",
        caption: "Enregistre le texte copié pour le réutiliser plus tard. Tout reste local et peut être effacé à tout moment.",
        localNote: "Tout reste sur ce Mac. Les éléments très volumineux sont ignorés.",
        skipSensitive: "Ignorer le texte qui semble sensible",
        skipSensitiveCaption: "Peut ignorer du texte ordinaire ressemblant à des mots de passe ou à des jetons. Le contenu marqué comme confidentiel par l’app source est toujours exclu.",
        limit: "Limite",
        limitUnlimited: "Illimité",
        showInPanel: "Afficher dans le panneau",
        shortcut: "Raccourci de l’historique",
        shortcutCaption: "Ouvre une fenêtre rapide avec recherche, éléments épinglés et raccourcis ⌘1 à ⌘9 pour coller dans l’app précédente.",
        clickRowShortcut: "Cliquer la ligne",
        pinned: "Épinglés",
        recent: "Récents",
        pin: "Épingler",
        unpin: "Désépingler",
        clearRecent: "Effacer non épinglés",
        clearRecentKeywords: "Effacer les récents",
        empty: "Aucun texte enregistré",
        disabled: "Activez l’historique pour commencer à enregistrer le texte copié.",
        search: "Rechercher le texte copié",
        copy: "Copier",
        copied: "Copié",
        delete: "Supprimer l’élément",
        selectMultiple: "Ajouter à la pile",
        unselectMultiple: "Retirer de la pile",
        pasteSelectedFormat: "Coller %d",
        copySelectedFormat: "Copier %d",
        clearSelection: "Effacer la sélection",
        moveUp: "Monter",
        moveDown: "Descendre",
        noResults: "Aucun résultat",
        active: "Enregistre le nouveau texte",
        includeImagesFiles: "Enregistrer aussi les images et fichiers copiés",
        includeImagesFilesCaption: "Les images rejoignent l’historique et les fichiers sont mémorisés comme des liens vers leur emplacement. Épinglez-les et collez-les comme du texte.",
        imageEntryLabel: "Image",
        fileCountFormat: "%d fichiers",
        previewLabel: "Aperçu",
        edit: "Modifier",
        cancel: "Annuler",
        save: "Enregistrer",
        autoClearEnable: "Vider le presse-papiers automatiquement après",
        autoClearSecondsSuffix: "secondes",
        autoClearOnSleep: "Vider le presse-papiers à la mise en veille du Mac",
        autoClearOnDisplaySleep: "Vider le presse-papiers à l’extinction de l’écran",
        autoClearOnScreenLock: "Vider le presse-papiers au verrouillage de l’écran",
        autoClearCaption: "Seul le presse-papiers du système est vidé. Les éléments enregistrés restent dans l’historique.",
        deleteSelectedFormat: "Supprimer %d",
        menuBarPreview: "Afficher la dernière copie dans la barre des menus",
        menuBarPreviewCaption: "Affiche un aperçu raccourci de votre dernière copie à côté de l’icône. Cliquez dessus pour ouvrir l’historique.",
        menuBarPreviewLength: "Longueur de l’aperçu",
        menuBarPreviewLengthSuffix: "caractères",
        clearRecentConfirmFormat: "Effacer non épinglés (%d)\u{00A0}?",
        clearRecentConfirmMessage: "Les éléments épinglés restent, comme tout ce qui sera copié ensuite. Action irréversible.",
        historyLayout: "Disposition de l’historique",
        historyLayoutCards: "Cartes",
        historyLayoutList: "Liste",
        showSourceAppIconsInList: "Afficher les icônes des apps sources dans la liste"
    )

    static let it = ClipboardFeatureStrings(
        title: "Appunti",
        enable: "Salva cronologia degli appunti",
        caption: "Salva il testo copiato per riutilizzarlo in seguito. Tutto resta locale e può essere cancellato in qualsiasi momento.",
        localNote: "Tutto resta su questo Mac. Gli elementi molto grandi vengono ignorati.",
        skipSensitive: "Ignora testo che sembra sensibile",
        skipSensitiveCaption: "Può ignorare anche testo normale che sembra una password o un token. I contenuti contrassegnati come riservati dall’app di origine vengono sempre esclusi.",
        limit: "Limite",
        limitUnlimited: "Illimitato",
        showInPanel: "Mostra nel pannello",
        shortcut: "Scorciatoia cronologia",
        shortcutCaption: "Apre una finestra rapida con ricerca, elementi fissati e scorciatoie ⌘1 a ⌘9 per incollare nell’app precedente.",
        clickRowShortcut: "Clic sulla riga",
        pinned: "Fissati",
        recent: "Recenti",
        pin: "Fissa",
        unpin: "Sblocca",
        clearRecent: "Cancella non fissati",
        clearRecentKeywords: "Cancella recenti",
        empty: "Nessun testo salvato",
        disabled: "Attiva la cronologia per iniziare a salvare il testo copiato.",
        search: "Cerca testo copiato",
        copy: "Copia",
        copied: "Copiato",
        delete: "Elimina elemento",
        selectMultiple: "Aggiungi alla pila",
        unselectMultiple: "Rimuovi dalla pila",
        pasteSelectedFormat: "Incolla %d",
        copySelectedFormat: "Copia %d",
        clearSelection: "Cancella selezione",
        moveUp: "Sposta su",
        moveDown: "Sposta giù",
        noResults: "Nessun risultato",
        active: "Salvataggio nuovo testo",
        includeImagesFiles: "Salva anche immagini e file copiati",
        includeImagesFilesCaption: "Le immagini entrano nella cronologia e i file vengono ricordati come collegamenti alla loro posizione. Fissali e incollali come qualsiasi testo.",
        imageEntryLabel: "Immagine",
        fileCountFormat: "%d file",
        previewLabel: "Anteprima",
        edit: "Modifica",
        cancel: "Annulla",
        save: "Salva",
        autoClearEnable: "Svuota gli appunti automaticamente dopo",
        autoClearSecondsSuffix: "secondi",
        autoClearOnSleep: "Svuota gli appunti quando il Mac va in stop",
        autoClearOnDisplaySleep: "Svuota gli appunti quando lo schermo si spegne",
        autoClearOnScreenLock: "Svuota gli appunti al blocco dello schermo",
        autoClearCaption: "Svuota solo gli appunti di sistema. Gli elementi salvati restano nella cronologia.",
        deleteSelectedFormat: "Elimina %d",
        menuBarPreview: "Mostra l’ultima copia nella barra dei menu",
        menuBarPreviewCaption: "Mostra un’anteprima abbreviata dell’ultima copia accanto all’icona. Fai clic per aprire la cronologia.",
        menuBarPreviewLength: "Lunghezza dell’anteprima",
        menuBarPreviewLengthSuffix: "caratteri",
        clearRecentConfirmFormat: "Cancellare non fissati (%d)?",
        clearRecentConfirmMessage: "Gli elementi fissati restano, come tutto ciò che copi dopo. Non si può annullare.",
        historyLayout: "Layout cronologia",
        historyLayoutCards: "Schede",
        historyLayoutList: "Elenco",
        showSourceAppIconsInList: "Mostra le icone delle app di origine nell’elenco"
    )

    static let ja = ClipboardFeatureStrings(
        title: "クリップボード",
        enable: "クリップボード履歴を保存",
        caption: "コピーしたテキストを保存して、あとで再利用できます。すべてローカルに保存され、いつでも削除できます。",
        localNote: "すべてこのMacに残ります。大きすぎる項目は無視されます。",
        skipSensitive: "機密らしいテキストを無視",
        skipSensitiveCaption: "パスワードやトークンに似た通常のテキストも除外される場合があります。コピー元のアプリが機密として指定した内容は常に除外されます。",
        limit: "上限",
        limitUnlimited: "無制限",
        showInPanel: "パネルに表示",
        shortcut: "履歴ショートカット",
        shortcutCaption: "検索、固定項目、前のアプリへ貼り付ける ⌘1 から ⌘9 のショートカットを備えたクイックウインドウを開きます。",
        clickRowShortcut: "行をクリック",
        pinned: "固定済み",
        recent: "最近",
        pin: "固定",
        unpin: "固定解除",
        clearRecent: "未固定を消去",
        clearRecentKeywords: "最近を消去",
        empty: "保存済みテキストなし",
        disabled: "履歴を有効にすると、コピーしたテキストを保存できます。",
        search: "コピーしたテキストを検索",
        copy: "コピー",
        copied: "コピー済み",
        delete: "項目を削除",
        selectMultiple: "束に追加",
        unselectMultiple: "束から削除",
        pasteSelectedFormat: "%d件を貼り付け",
        copySelectedFormat: "%d件をコピー",
        clearSelection: "選択を解除",
        moveUp: "上へ移動",
        moveDown: "下へ移動",
        noResults: "結果なし",
        active: "新しいテキストを保存中",
        includeImagesFiles: "コピーした画像やファイルも保存",
        includeImagesFilesCaption: "画像は履歴に入り、ファイルは場所へのリンクとして記憶されます。テキストと同じようにピン留めやペーストができます。",
        imageEntryLabel: "画像",
        fileCountFormat: "%d個のファイル",
        previewLabel: "プレビュー",
        edit: "編集",
        cancel: "キャンセル",
        save: "保存",
        autoClearEnable: "クリップボードを自動消去するまでの時間",
        autoClearSecondsSuffix: "秒",
        autoClearOnSleep: "システムスリープ時にクリップボードを消去",
        autoClearOnDisplaySleep: "ディスプレイスリープ時にクリップボードを消去",
        autoClearOnScreenLock: "画面ロック時にクリップボードを消去",
        autoClearCaption: "システムのクリップボードのみを消去します。保存済みの項目は履歴に残ります。",
        deleteSelectedFormat: "%d件を削除",
        menuBarPreview: "メニューバーに直前のコピーを表示",
        menuBarPreviewCaption: "アイコンの横に直前のコピーの短縮プレビューを表示します。クリックすると履歴が開きます。",
        menuBarPreviewLength: "プレビューの長さ",
        menuBarPreviewLengthSuffix: "文字",
        clearRecentConfirmFormat: "未固定の%d件を消去しますか？",
        clearRecentConfirmMessage: "固定済みの項目と、このあとにコピーした内容は残ります。元に戻せません。",
        historyLayout: "履歴のレイアウト",
        historyLayoutCards: "カード",
        historyLayoutList: "リスト",
        showSourceAppIconsInList: "リストにコピー元のアプリのアイコンを表示"
    )

    static let zhHans = ClipboardFeatureStrings(
        title: "剪贴板",
        enable: "保存剪贴板历史",
        caption: "保存拷贝过的文本，方便之后再次使用。所有内容都保存在本机，可随时清除。",
        localNote: "一切都保留在这台 Mac 上。特别大的内容会被忽略。",
        skipSensitive: "跳过疑似敏感文本",
        skipSensitiveCaption: "可能会跳过看起来像密码或令牌的普通文本。来源应用标记为机密的内容始终不会保存。",
        limit: "数量上限",
        limitUnlimited: "无限制",
        showInPanel: "在面板中显示",
        shortcut: "历史快捷键",
        shortcutCaption: "打开快速窗口，支持搜索、固定项目，以及用 ⌘1 到 ⌘9 粘贴到上一个 App。",
        clickRowShortcut: "点击整行",
        pinned: "已固定",
        recent: "最近",
        pin: "固定",
        unpin: "取消固定",
        clearRecent: "清除未固定项目",
        clearRecentKeywords: "清除最近项目",
        empty: "没有保存的文本",
        disabled: "启用历史记录后即可开始保存拷贝的文本。",
        search: "搜索拷贝的文本",
        copy: "拷贝",
        copied: "已拷贝",
        delete: "删除项目",
        selectMultiple: "加入堆叠",
        unselectMultiple: "从堆叠移除",
        pasteSelectedFormat: "粘贴 %d 项",
        copySelectedFormat: "拷贝 %d 项",
        clearSelection: "取消选择",
        moveUp: "上移",
        moveDown: "下移",
        noResults: "没有结果",
        active: "正在保存新文本",
        includeImagesFiles: "同时保存拷贝的图片和文件",
        includeImagesFilesCaption: "图片会进入历史记录，文件会以其位置链接的形式被记住。可以像文本一样固定和粘贴。",
        imageEntryLabel: "图片",
        fileCountFormat: "%d 个文件",
        previewLabel: "预览",
        edit: "编辑",
        cancel: "取消",
        save: "保存",
        autoClearEnable: "自动清空剪贴板，延迟",
        autoClearSecondsSuffix: "秒",
        autoClearOnSleep: "睡眠时清空剪贴板",
        autoClearOnDisplaySleep: "显示器睡眠时清空剪贴板",
        autoClearOnScreenLock: "锁定屏幕时清空剪贴板",
        autoClearCaption: "仅清空系统剪贴板，已保存的条目仍保留在历史记录中。",
        deleteSelectedFormat: "删除 %d 项",
        menuBarPreview: "在菜单栏显示最近拷贝的内容",
        menuBarPreviewCaption: "在图标旁显示最近拷贝内容的简短预览，点击即可打开历史记录。",
        menuBarPreviewLength: "预览长度",
        menuBarPreviewLengthSuffix: "个字符",
        clearRecentConfirmFormat: "清除 %d 个未固定项目？",
        clearRecentConfirmMessage: "已固定的项目和此后拷贝的内容会保留。此操作无法撤销。",
        historyLayout: "历史布局",
        historyLayoutCards: "卡片",
        historyLayoutList: "列表",
        showSourceAppIconsInList: "在列表中显示来源应用图标"
    )

    static let zhTW = ClipboardFeatureStrings(
        title: "剪貼簿",
        enable: "儲存剪貼簿紀錄",
        caption: "儲存複製過的文字，方便之後再次使用。所有內容都會儲存在這台裝置上，並可隨時清除。",
        localNote: "一切都保留在這台 Mac 上。過大的內容會被略過。",
        skipSensitive: "略過可能含有敏感資料的文字",
        skipSensitiveCaption: "可能會略過看起來像密碼或權杖的一般文字。來源 App 標記為機密的內容一律不會儲存。",
        limit: "數量上限",
        limitUnlimited: "無限制",
        showInPanel: "在面板中顯示",
        shortcut: "剪貼簿紀錄快速鍵",
        shortcutCaption: "開啟快速視窗，可搜尋、釘選項目，並使用 ⌘1 到 ⌘9 貼到上一個 App。",
        clickRowShortcut: "點選整列",
        pinned: "已釘選",
        recent: "最近",
        pin: "釘選",
        unpin: "取消釘選",
        clearRecent: "清除未釘選項目",
        clearRecentKeywords: "清除最近項目",
        empty: "沒有儲存的文字",
        disabled: "開啟紀錄後，即可開始儲存複製的文字。",
        search: "搜尋複製的文字",
        copy: "複製",
        copied: "已複製",
        delete: "刪除項目",
        selectMultiple: "加入堆疊",
        unselectMultiple: "從堆疊移除",
        pasteSelectedFormat: "貼上 %d 個",
        copySelectedFormat: "拷貝 %d 個",
        clearSelection: "取消選取",
        moveUp: "上移",
        moveDown: "下移",
        noResults: "沒有結果",
        active: "正在儲存新文字",
        includeImagesFiles: "同時保存拷貝的圖片和檔案",
        includeImagesFilesCaption: "圖片會進入歷史記錄，檔案會以其位置連結的形式被記住。可以像文字一樣固定和貼上。",
        imageEntryLabel: "圖片",
        fileCountFormat: "%d 個檔案",
        previewLabel: "預覽",
        edit: "編輯",
        cancel: "取消",
        save: "儲存",
        autoClearEnable: "自動清除剪貼簿，延遲",
        autoClearSecondsSuffix: "秒",
        autoClearOnSleep: "睡眠時清除剪貼簿",
        autoClearOnDisplaySleep: "顯示器睡眠時清除剪貼簿",
        autoClearOnScreenLock: "鎖定螢幕時清除剪貼簿",
        autoClearCaption: "僅清除系統剪貼簿，已儲存的項目仍保留在記錄中。",
        deleteSelectedFormat: "刪除 %d 個",
        menuBarPreview: "在選單列顯示最近複製的內容",
        menuBarPreviewCaption: "在圖示旁顯示最近複製內容的簡短預覽，點選即可開啟紀錄。",
        menuBarPreviewLength: "預覽長度",
        menuBarPreviewLengthSuffix: "個字元",
        clearRecentConfirmFormat: "清除 %d 個未釘選項目？",
        clearRecentConfirmMessage: "已釘選的項目和之後複製的內容會保留。此動作無法還原。",
        historyLayout: "剪貼簿紀錄佈局",
        historyLayoutCards: "卡片",
        historyLayoutList: "列表",
        showSourceAppIconsInList: "在列表中顯示來源 App 圖示"
    )

    static let zhHK = ClipboardFeatureStrings(
        title: "剪貼簿",
        enable: "儲存剪貼簿記錄",
        caption: "儲存複製過的文字，方便之後再次使用。所有內容都會儲存在此裝置上，並可隨時清除。",
        localNote: "一切都保留在這部 Mac 上。過大的內容會被略過。",
        skipSensitive: "略過可能含有敏感資料的文字",
        skipSensitiveCaption: "可能會略過看起來像密碼或權杖的一般文字。來源 App 標記為機密的內容一律不會儲存。",
        limit: "數量上限",
        limitUnlimited: "無限制",
        showInPanel: "在面板中顯示",
        shortcut: "剪貼簿記錄快捷鍵",
        shortcutCaption: "開啟快速視窗，可搜尋、釘選項目，並使用 ⌘1 至 ⌘9 貼到上一個 App。",
        clickRowShortcut: "按一下整列",
        pinned: "已釘選",
        recent: "最近",
        pin: "釘選",
        unpin: "取消釘選",
        clearRecent: "清除未釘選項目",
        clearRecentKeywords: "清除最近項目",
        empty: "沒有已儲存的文字",
        disabled: "開啟記錄後，即可開始儲存複製的文字。",
        search: "搜尋複製的文字",
        copy: "複製",
        copied: "已複製",
        delete: "刪除項目",
        selectMultiple: "加入堆疊",
        unselectMultiple: "從堆疊移除",
        pasteSelectedFormat: "貼上 %d 個",
        copySelectedFormat: "複製 %d 個",
        clearSelection: "取消選取",
        moveUp: "上移",
        moveDown: "下移",
        noResults: "沒有結果",
        active: "正在儲存新文字",
        includeImagesFiles: "同時儲存拷貝的圖片和檔案",
        includeImagesFilesCaption: "圖片會加入歷史記錄，檔案會以其位置連結的形式被記住。可以像文字一樣固定和貼上。",
        imageEntryLabel: "圖片",
        fileCountFormat: "%d 個檔案",
        previewLabel: "預覽",
        edit: "編輯",
        cancel: "取消",
        save: "儲存",
        autoClearEnable: "自動清除剪貼簿，延遲",
        autoClearSecondsSuffix: "秒",
        autoClearOnSleep: "睡眠時清除剪貼簿",
        autoClearOnDisplaySleep: "顯示器睡眠時清除剪貼簿",
        autoClearOnScreenLock: "鎖定螢幕時清除剪貼簿",
        autoClearCaption: "只會清除系統剪貼簿，已儲存的項目仍會保留在記錄中。",
        deleteSelectedFormat: "刪除 %d 個",
        menuBarPreview: "在選單列顯示最近複製的內容",
        menuBarPreviewCaption: "在圖示旁顯示最近複製內容的簡短預覽，按一下即可開啟記錄。",
        menuBarPreviewLength: "預覽長度",
        menuBarPreviewLengthSuffix: "個字元",
        clearRecentConfirmFormat: "清除 %d 個未釘選項目？",
        clearRecentConfirmMessage: "已釘選的項目和之後複製的內容會保留。此動作無法還原。",
        historyLayout: "剪貼簿記錄佈局",
        historyLayoutCards: "卡片",
        historyLayoutList: "列表",
        showSourceAppIconsInList: "在列表中顯示來源 App 圖示"
    )
}

struct WindowLayoutFeatureStrings {
    let title: String
    let enable: String
    let caption: String
    let showInPanel: String
    let gestureSection: String
    let gestureEnable: String
    let gestureCaption: String
    let gestureModifiers: String
    let gestureMove: String
    let gestureResize: String
    let gestureResizeHint: String
    let gestureRaiseWindow: String
    let shortcuts: String
    let shortcutsCaption: String
    let permissionCaption: String
    let noWindow: String
    let missingPermission: String
    let failed: String
    let done: String
    let restored: String
    let noRestore: String
    let target: String
    let halves: String
    let thirds: String
    let quarterRows: String
    let quarterColumns: String
    let sixths: String
    let corners: String
    let other: String
    let moving: String
    let leftHalf: String
    let rightHalf: String
    let topHalf: String
    let bottomHalf: String
    let centerHalf: String
    let leftThird: String
    let centerThird: String
    let rightThird: String
    let leftTwoThirds: String
    let rightTwoThirds: String
    let centerTwoThirds: String
    let topThird: String
    let middleThird: String
    let bottomThird: String
    let topTwoThirds: String
    let bottomTwoThirds: String
    let topQuarter: String
    let upperMiddleQuarter: String
    let lowerMiddleQuarter: String
    let bottomQuarter: String
    let leftQuarter: String
    let leftMiddleQuarter: String
    let rightMiddleQuarter: String
    let rightQuarter: String
    let topLeftSixth: String
    let topCenterSixth: String
    let topRightSixth: String
    let bottomLeftSixth: String
    let bottomCenterSixth: String
    let bottomRightSixth: String
    let topLeft: String
    let topRight: String
    let bottomLeft: String
    let bottomRight: String
    let maximize: String
    let center: String
    let nextDisplay: String
    let restore: String
    let fullScreen: String
    let previousDisplay: String
    let edgeSnapEnable: String
    let edgeSnapSection: String
    let edgeSnapCaption: String
    let edgeSnapSystemConflict: String
    let edgeSnapOpenSystemSettings: String
    let edgeSnapWaitingForSystem: String
    let edgeSnapUseCorner: String
    let edgeSnapUseEdge: String
    let edgeSnapAreasOnEdge: String
    let gapsSection: String
    let gapsCaption: String
    let windowGap: String
    let screenGap: String
    let sideRepeatCycle: String
    let sideRepeatCycleCaption: String
    let gapNone: String
    let gapTiny: String
    let gapSmall: String
    let gapMedium: String
    let gapLarge: String
    let gapExtraLarge: String
    var quarters: String = "Quarters"
    var centerColumn: String = "Center column"
    var centerRow: String = "Center row"
    var repeatCycleTooltip: String = "Repeat shortcuts to cycle through different sizes."
    var holdToCycleDisplay: String = "Hold resizing control to cycle display"
    var holdDelay: String = "Hold delay"
    var holdDelayDefault: String = "Default"
    var holdDelayLonger: String = "Longer"

    static func manageShortcuts(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: "Manage shortcuts"
        case .ptBR: "Gerenciar atalhos"
        case .tr: "Kısayolları yönet"
        case .ru: "Настроить сочетания клавиш"
        case .es: "Gestionar atajos"
        case .sk: "Spravovať skratky"
        case .de: "Kurzbefehle verwalten"
        case .fr: "Gérer les raccourcis"
        case .it: "Gestisci scorciatoie"
        case .ja: "ショートカットを管理"
        case .ko: "단축키 관리"
        case .zhHans: "管理快捷键"
        case .zhTW: "管理快速鍵"
        case .zhHK: "管理快捷鍵"
        case .uk: "Керувати скороченнями"
        }
    }

    static func edgeSnapCustomizeHint(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: "Click any zone to customize its layout."
        case .ptBR: "Clique em uma zona para personalizar seu layout."
        case .tr: "Düzenini özelleştirmek için bir bölgeye tıklayın."
        case .ru: "Нажмите на зону, чтобы настроить её расположение."
        case .es: "Haz clic en cualquier zona para personalizar su disposición."
        case .sk: "Kliknutím na oblasť prispôsobíte jej rozloženie."
        case .de: "Klicke auf einen Bereich, um sein Layout anzupassen."
        case .fr: "Cliquez sur une zone pour personnaliser sa disposition."
        case .it: "Fai clic su una zona per personalizzarne la disposizione."
        case .ja: "ゾーンをクリックして配置をカスタマイズできます。"
        case .ko: "영역을 클릭하여 배치를 사용자화할 수 있습니다."
        case .zhHans: "点按任意区域以自定义布局。"
        case .zhTW: "按一下任一區域以自訂版面。"
        case .zhHK: "按一下任何區域以自訂版面。"
        case .uk: "Натисніть будь-яку зону, щоб налаштувати її розташування."
        }
    }

    static func edgeSnapEnableZone(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: "Enable snap zone"
        case .ptBR: "Ativar zona de ajuste"
        case .tr: "Tutturma bölgesini etkinleştir"
        case .ru: "Включить зону привязки"
        case .es: "Activar zona de ajuste"
        case .sk: "Zapnúť oblasť prichytenia"
        case .de: "Einrastbereich aktivieren"
        case .fr: "Activer la zone d’ancrage"
        case .it: "Attiva zona di aggancio"
        case .ja: "スナップゾーンを有効にする"
        case .ko: "맞춤 영역 활성화"
        case .zhHans: "启用贴靠区域"
        case .zhTW: "啟用貼齊區域"
        case .zhHK: "啟用貼齊區域"
        case .uk: "Увімкнути зону прилипання"
        }
    }

    static func edgeSnapSplitInto(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: "Split into"
        case .ptBR: "Dividir em"
        case .tr: "Bölge sayısı"
        case .ru: "Разделить на"
        case .es: "Dividir en"
        case .sk: "Rozdeliť na"
        case .de: "Aufteilen in"
        case .fr: "Diviser en"
        case .it: "Dividi in"
        case .ja: "ゾーンの分割"
        case .ko: "영역 분할"
        case .zhHans: "拆分为"
        case .zhTW: "分割為"
        case .zhHK: "分割為"
        case .uk: "Розділити на"
        }
    }

    static func edgeSnapZoneCount(_ count: Int, _ language: AppLanguage) -> String {
        switch language {
        case .enUS: count == 1 ? "1 zone" : "\(count) zones"
        case .ptBR: count == 1 ? "1 zona" : "\(count) zonas"
        case .tr: "\(count) bölge"
        case .ru: count == 1 ? "1 зону" : "\(count) зоны"
        case .es: count == 1 ? "1 zona" : "\(count) zonas"
        case .sk: count == 1 ? "1 oblasť" : "\(count) oblasti"
        case .de: count == 1 ? "1 Bereich" : "\(count) Bereiche"
        case .fr: count == 1 ? "1 zone" : "\(count) zones"
        case .it: count == 1 ? "1 zona" : "\(count) zone"
        case .ja: "\(count)つのゾーン"
        case .ko: "\(count)개 영역"
        case .zhHans: "\(count) 个区域"
        case .zhTW: "\(count) 個區域"
        case .zhHK: "\(count) 個區域"
        case .uk: count == 1 ? "1 зону" : "\(count) зони"
        }
    }

    static func shortcutsPageTitle(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: "Window Arrangement Shortcuts"
        case .ptBR: "Atalhos de Organização de Janelas"
        case .tr: "Pencere Düzenleme Kısayolları"
        case .ru: "Сочетания клавиш расположения окон"
        case .es: "Atajos de disposición de ventanas"
        case .sk: "Skratky usporiadania okien"
        case .de: "Kurzbefehle für Fensteranordnung"
        case .fr: "Raccourcis de disposition des fenêtres"
        case .it: "Scorciatoie disposizione finestre"
        case .ja: "ウインドウ配置のショートカット"
        case .ko: "윈도우 배치 단축키"
        case .zhHans: "窗口排列快捷键"
        case .zhTW: "視窗排列快速鍵"
        case .zhHK: "視窗排列快捷鍵"
        case .uk: "Скорочення розташування вікон"
        }
    }

    static let enUS = WindowLayoutFeatureStrings(
        title: "Window Management",
        enable: "Enable Window Arrangement",
        caption: "Arrange windows into screen sections or move and resize them with a trackpad or mouse.",
        showInPanel: "Show control in utilities menu",
        gestureSection: "Window Arrangement",
        gestureEnable: "Drag Windows to Move and Resize",
        gestureCaption: "On a trackpad or mouse, hold the shown modifier keys and drag anywhere inside a window.",
        gestureModifiers: "Modifier keys to move",
        gestureMove: "Drag to move",
        gestureResize: "Add Shift and drag to resize",
        gestureResizeHint: "The starting point chooses the nearest edge or corner. On a mouse, right-button drag also resizes.",
        gestureRaiseWindow: "Bring the dragged window to front",
        shortcuts: "Shortcuts",
        shortcutsCaption: "Set shortcuts to move and resize the active window.",
        permissionCaption: "Uses Accessibility only to move and resize windows.",
        noWindow: "No active window found.",
        missingPermission: "Grant Accessibility to move windows.",
        failed: "Could not move this window.",
        done: "Window arranged.",
        restored: "Window restored.",
        noRestore: "No previous layout to restore.",
        target: "Active window",
        halves: "Splits",
        thirds: "Thirds",
        quarterRows: "Quarter rows",
        quarterColumns: "Quarter columns",
        sixths: "Grids",
        corners: "Corners",
        other: "Sizing & Action",
        moving: "Multi Display",
        leftHalf: "Left",
        rightHalf: "Right",
        topHalf: "Top",
        bottomHalf: "Bottom",
        centerHalf: "Center half",
        leftThird: "Left 1/3",
        centerThird: "Center 1/3",
        rightThird: "Right 1/3",
        leftTwoThirds: "Left 2/3",
        rightTwoThirds: "Right 2/3",
        centerTwoThirds: "Center 2/3",
        topThird: "Top 1/3",
        middleThird: "Middle 1/3",
        bottomThird: "Bottom 1/3",
        topTwoThirds: "Top 2/3",
        bottomTwoThirds: "Bottom 2/3",
        topQuarter: "Top quarter",
        upperMiddleQuarter: "Upper middle quarter",
        lowerMiddleQuarter: "Lower middle quarter",
        bottomQuarter: "Bottom quarter",
        leftQuarter: "Left quarter",
        leftMiddleQuarter: "Left middle quarter",
        rightMiddleQuarter: "Right middle quarter",
        rightQuarter: "Right quarter",
        topLeftSixth: "Top left grid",
        topCenterSixth: "Top center grid",
        topRightSixth: "Top right grid",
        bottomLeftSixth: "Bottom left grid",
        bottomCenterSixth: "Bottom center grid",
        bottomRightSixth: "Bottom right grid",
        topLeft: "Top left quarter",
        topRight: "Top right quarter",
        bottomLeft: "Bottom left quarter",
        bottomRight: "Bottom right quarter",
        maximize: "Maximize",
        center: "Center",
        nextDisplay: "Move window to next display",
        restore: "Restore",
        fullScreen: "Full Screen",
        previousDisplay: "Move window to previous display",
        edgeSnapEnable: "Snap windows at screen edges",
        edgeSnapSection: "Drag windows to snap",
        edgeSnapCaption: "Drag a window to a screen edge or corner to snap it into place.",
        edgeSnapSystemConflict: "macOS is using the same edges. Turn off window tiling in Desktop & Dock so Lattice can take over.",
        edgeSnapOpenSystemSettings: "Open Desktop & Dock",
        edgeSnapWaitingForSystem: "Enabled in Lattice. It starts working as soon as macOS tiling is off.",
        edgeSnapUseCorner: "Use this corner",
        edgeSnapUseEdge: "Use this edge",
        edgeSnapAreasOnEdge: "Areas on this edge",
        gapsSection: "Gaps",
        gapsCaption: "Space between snapped windows, and between windows and the screen edge.",
        windowGap: "Margin between windows",
        screenGap: "Screen edge margin",
        sideRepeatCycle: "Cycle Left or Right sizes",
        sideRepeatCycleCaption: "Cycles half, two-thirds, then one-third.",
        gapNone: "None",
        gapTiny: "Tiny",
        gapSmall: "Small",
        gapMedium: "Medium",
        gapLarge: "Large",
        gapExtraLarge: "Extra large"
    )

    static let ptBR = WindowLayoutFeatureStrings(
        title: "Gerenciamento de Janelas",
        enable: "Ativar Organização de Janelas",
        caption: "Organize janelas em áreas da tela ou mova e redimensione com o trackpad ou mouse.",
        showInPanel: "Mostrar no menu de utilitários",
        gestureSection: "Organização de janelas",
        gestureEnable: "Mover e redimensionar por arraste",
        gestureCaption: "No trackpad ou mouse, segure as teclas indicadas e arraste em qualquer ponto da janela.",
        gestureModifiers: "Teclas para mover",
        gestureMove: "Arraste para mover",
        gestureResize: "Adicione Shift e arraste para redimensionar",
        gestureResizeHint: "O ponto inicial escolhe a borda ou o canto. No mouse, o botão direito também redimensiona.",
        gestureRaiseWindow: "Trazer a janela arrastada para a frente",
        shortcuts: "Atalhos",
        shortcutsCaption: "Use atalhos globais para organizar a janela ativa sem abrir o painel.",
        permissionCaption: "Usa Acessibilidade apenas para mover e redimensionar janelas.",
        noWindow: "Nenhuma janela ativa encontrada.",
        missingPermission: "Conceda Acessibilidade para mover janelas.",
        failed: "Não foi possível mover esta janela.",
        done: "Janela organizada.",
        restored: "Janela restaurada.",
        noRestore: "Nenhum layout anterior para restaurar.",
        target: "Janela ativa",
        halves: "Divisões",
        thirds: "Terços",
        quarterRows: "Linhas de 1/4",
        quarterColumns: "Colunas de 1/4",
        sixths: "Grades",
        corners: "Cantos",
        other: "Redimensionamento e ações",
        moving: "Múltiplos monitores",
        leftHalf: "Esquerda",
        rightHalf: "Direita",
        topHalf: "Topo",
        bottomHalf: "Base",
        centerHalf: "Metade central",
        leftThird: "1/3 esquerda",
        centerThird: "1/3 centro",
        rightThird: "1/3 direita",
        leftTwoThirds: "2/3 esquerda",
        rightTwoThirds: "2/3 direita",
        centerTwoThirds: "2/3 centro",
        topThird: "1/3 topo",
        middleThird: "1/3 meio",
        bottomThird: "1/3 base",
        topTwoThirds: "2/3 topo",
        bottomTwoThirds: "2/3 base",
        topQuarter: "Quarto topo",
        upperMiddleQuarter: "Quarto meio superior",
        lowerMiddleQuarter: "Quarto meio inferior",
        bottomQuarter: "Quarto base",
        leftQuarter: "Quarto esquerda",
        leftMiddleQuarter: "Quarto meio esquerdo",
        rightMiddleQuarter: "Quarto meio direito",
        rightQuarter: "Quarto direita",
        topLeftSixth: "Grade topo esquerdo",
        topCenterSixth: "Grade topo central",
        topRightSixth: "Grade topo direito",
        bottomLeftSixth: "Grade base esquerda",
        bottomCenterSixth: "Grade base central",
        bottomRightSixth: "Grade base direita",
        topLeft: "Quarto topo esquerdo",
        topRight: "Quarto topo direito",
        bottomLeft: "Quarto base esquerda",
        bottomRight: "Quarto base direita",
        maximize: "Maximizar",
        center: "Centralizar",
        nextDisplay: "Mover janela para o próximo display",
        restore: "Restaurar",
        fullScreen: "Tela cheia",
        previousDisplay: "Mover janela para o display anterior",
        edgeSnapEnable: "Encaixar janelas nas bordas da tela",
        edgeSnapSection: "Arrastar janelas para ajustar",
        edgeSnapCaption: "Arraste uma janela até uma borda ou canto da tela para ajustá-la no lugar.",
        edgeSnapSystemConflict: "O macOS está usando as mesmas bordas. Desligue o encaixe em Mesa e Dock para o Lattice assumir.",
        edgeSnapOpenSystemSettings: "Abrir Mesa e Dock",
        edgeSnapWaitingForSystem: "Ativado no Lattice. Começa a funcionar assim que o encaixe do macOS for desligado.",
        edgeSnapUseCorner: "Usar este canto",
        edgeSnapUseEdge: "Usar esta borda",
        edgeSnapAreasOnEdge: "Áreas nesta borda",
        gapsSection: "Espaçamento",
        gapsCaption: "Espaço entre janelas ajustadas e entre as janelas e a borda da tela.",
        windowGap: "Margem entre janelas",
        screenGap: "Margem da borda da tela",
        sideRepeatCycle: "Repetir Esquerda ou Direita alterna os tamanhos",
        sideRepeatCycleCaption: "Metade, depois dois terços e um terço na mesma tela. Desligado e com mais de uma tela, a repetição move a janela para a próxima tela daquele lado.",
        gapNone: "Nenhum",
        gapTiny: "Minúsculo",
        gapSmall: "Pequeno",
        gapMedium: "Médio",
        gapLarge: "Grande",
        gapExtraLarge: "Extragrande"
    )

    static let tr = WindowLayoutFeatureStrings(
        title: "Pencere Yönetimi",
        enable: "Pencere Düzenlemeyi Etkinleştir",
        caption: "Pencereleri ekran bölümlerine yerleştirin veya izleme dörtgeni ya da fareyle taşıyıp yeniden boyutlandırın.",
        showInPanel: "İzlenceler menüsünde göster",
        gestureSection: "Pencere Düzenleme",
        gestureEnable: "Sürükleyerek taşı ve boyutlandır",
        gestureCaption: "İzleme dörtgeni veya farede gösterilen değiştirici tuşları basılı tutup pencerenin herhangi bir yerinden sürükleyin.",
        gestureModifiers: "Taşıma tuşları",
        gestureMove: "Taşımak için sürükleyin",
        gestureResize: "Shift ekleyip boyutlandırmak için sürükleyin",
        gestureResizeHint: "Başlangıç noktası en yakın kenarı veya köşeyi seçer. Farede sağ düğmeyle sürüklemek de boyutlandırır.",
        gestureRaiseWindow: "Sürüklenen pencereyi öne getir",
        shortcuts: "Kısayollar",
        shortcutsCaption: "Paneli açmadan etkin pencereyi düzenlemek için genel kısayollar kullan.",
        permissionCaption: "Erişilebilirliği yalnızca pencereleri taşımak ve yeniden boyutlandırmak için kullanır.",
        noWindow: "Etkin pencere bulunamadı.",
        missingPermission: "Pencereleri taşımak için Erişilebilirlik izni ver.",
        failed: "Bu pencere taşınamadı.",
        done: "Pencere yerleştirildi.",
        restored: "Pencere geri yüklendi.",
        noRestore: "Geri yüklenecek önceki yerleşim yok.",
        target: "Etkin pencere",
        halves: "Bölmeler",
        thirds: "Üçlüler",
        quarterRows: "Çeyrek satırlar",
        quarterColumns: "Çeyrek sütunlar",
        sixths: "Izgaralar",
        corners: "Köşeler",
        other: "Boyutlandırma ve Eylemler",
        moving: "Çoklu Ekran",
        leftHalf: "Sol",
        rightHalf: "Sağ",
        topHalf: "Üst",
        bottomHalf: "Alt",
        centerHalf: "Orta yarım",
        leftThird: "Sol 1/3",
        centerThird: "Orta 1/3",
        rightThird: "Sağ 1/3",
        leftTwoThirds: "Sol 2/3",
        rightTwoThirds: "Sağ 2/3",
        centerTwoThirds: "Orta 2/3",
        topThird: "Üst 1/3",
        middleThird: "Orta 1/3",
        bottomThird: "Alt 1/3",
        topTwoThirds: "Üst 2/3",
        bottomTwoThirds: "Alt 2/3",
        topQuarter: "Üst çeyrek",
        upperMiddleQuarter: "Üst orta çeyrek",
        lowerMiddleQuarter: "Alt orta çeyrek",
        bottomQuarter: "Alt çeyrek",
        leftQuarter: "Sol çeyrek",
        leftMiddleQuarter: "Sol orta çeyrek",
        rightMiddleQuarter: "Sağ orta çeyrek",
        rightQuarter: "Sağ çeyrek",
        topLeftSixth: "Sol üst ızgara",
        topCenterSixth: "Üst orta ızgara",
        topRightSixth: "Sağ üst ızgara",
        bottomLeftSixth: "Sol alt ızgara",
        bottomCenterSixth: "Alt orta ızgara",
        bottomRightSixth: "Sağ alt ızgara",
        topLeft: "Sol üst çeyrek",
        topRight: "Sağ üst çeyrek",
        bottomLeft: "Sol alt çeyrek",
        bottomRight: "Sağ alt çeyrek",
        maximize: "Büyüt",
        center: "Ortala",
        nextDisplay: "Pencereyi sonraki ekrana taşı",
        restore: "Geri yükle",
        fullScreen: "Tam ekran",
        previousDisplay: "Pencereyi önceki ekrana taşı",
        edgeSnapEnable: "Pencereleri ekran kenarlarına yerleştir",
        edgeSnapSection: "Tutturmak için pencereleri sürükle",
        edgeSnapCaption: "Bir pencereyi yerine tutturmak için ekran kenarına veya köşesine sürükleyin.",
        edgeSnapSystemConflict: "macOS aynı kenarları kullanıyor. Lattice’ın devralması için Masaüstü ve Dock’taki pencere döşemeyi kapatın.",
        edgeSnapOpenSystemSettings: "Masaüstü ve Dock’u Aç",
        edgeSnapWaitingForSystem: "Lattice’ta açık. macOS döşemesi kapanınca çalışmaya başlar.",
        edgeSnapUseCorner: "Bu köşeyi kullan",
        edgeSnapUseEdge: "Bu kenarı kullan",
        edgeSnapAreasOnEdge: "Bu kenardaki alanlar",
        gapsSection: "Boşluklar",
        gapsCaption: "Yaslanan pencereler arasındaki ve pencerelerle ekran kenarı arasındaki boşluk.",
        windowGap: "Pencereler arası kenar boşluğu",
        screenGap: "Ekran kenarı boşluğu",
        sideRepeatCycle: "Sol veya Sağ tekrarında boyutları döndür",
        sideRepeatCycleCaption: "Aynı ekranda yarım, ardından üçte iki ve üçte bir. Kapalıyken ve birden fazla ekran varken tekrar, pencereyi o yöndeki sonraki ekrana taşır.",
        gapNone: "Yok",
        gapTiny: "Çok küçük",
        gapSmall: "Küçük",
        gapMedium: "Orta",
        gapLarge: "Büyük",
        gapExtraLarge: "Çok büyük"
    )

    static let ru = WindowLayoutFeatureStrings(
        title: "Управление окнами",
        enable: "Включить расположение окон",
        caption: "Размещайте окна по областям экрана или перемещайте и меняйте их размер трекпадом или мышью.",
        showInPanel: "Показывать в меню утилит",
        gestureSection: "Расположение окон",
        gestureEnable: "Перемещать и менять размер перетаскиванием",
        gestureCaption: "На трекпаде или мыши удерживайте показанные клавиши и тяните из любой точки окна.",
        gestureModifiers: "Клавиши для перемещения",
        gestureMove: "Перетащите для перемещения",
        gestureResize: "Добавьте Shift и тяните для изменения размера",
        gestureResizeHint: "Начальная точка выбирает ближайшую сторону или угол. На мыши размер также меняется перетаскиванием правой кнопкой.",
        gestureRaiseWindow: "Выводить перетаскиваемое окно вперёд",
        shortcuts: "Горячие клавиши",
        shortcutsCaption: "Используйте глобальные сочетания клавиш, чтобы раскладывать активное окно без открытия панели.",
        permissionCaption: "Использует Универсальный доступ только для перемещения и изменения размера окон.",
        noWindow: "Активное окно не найдено.",
        missingPermission: "Выдайте Универсальный доступ для управления окнами.",
        failed: "Не удалось переместить это окно.",
        done: "Окно размещено.",
        restored: "Окно восстановлено.",
        noRestore: "Нет предыдущей раскладки для восстановления.",
        target: "Активное окно",
        halves: "Разделение",
        thirds: "Трети",
        quarterRows: "Строки по 1/4",
        quarterColumns: "Столбцы по 1/4",
        sixths: "Сетки",
        corners: "Углы",
        other: "Размер и действия",
        moving: "Несколько экранов",
        leftHalf: "Левая половина",
        rightHalf: "Правая половина",
        topHalf: "Верхняя половина",
        bottomHalf: "Нижняя половина",
        centerHalf: "Центр 1/2",
        leftThird: "Левая 1/3",
        centerThird: "Центр 1/3",
        rightThird: "Правая 1/3",
        leftTwoThirds: "Левые 2/3",
        rightTwoThirds: "Правые 2/3",
        centerTwoThirds: "Центр 2/3",
        topThird: "Верхняя 1/3",
        middleThird: "Средняя 1/3",
        bottomThird: "Нижняя 1/3",
        topTwoThirds: "Верхние 2/3",
        bottomTwoThirds: "Нижние 2/3",
        topQuarter: "Верхняя четверть",
        upperMiddleQuarter: "Верхняя средняя четверть",
        lowerMiddleQuarter: "Нижняя средняя четверть",
        bottomQuarter: "Нижняя четверть",
        leftQuarter: "Левая четверть",
        leftMiddleQuarter: "Левая средняя четверть",
        rightMiddleQuarter: "Правая средняя четверть",
        rightQuarter: "Правая четверть",
        topLeftSixth: "Сетка слева сверху",
        topCenterSixth: "Сетка сверху по центру",
        topRightSixth: "Сетка справа сверху",
        bottomLeftSixth: "Сетка слева снизу",
        bottomCenterSixth: "Сетка снизу по центру",
        bottomRightSixth: "Сетка справа снизу",
        topLeft: "Верхняя левая четверть",
        topRight: "Верхняя правая четверть",
        bottomLeft: "Нижняя левая четверть",
        bottomRight: "Нижняя правая четверть",
        maximize: "Развернуть",
        center: "По центру",
        nextDisplay: "Переместить окно на следующий дисплей",
        restore: "Восстановить",
        fullScreen: "Во весь экран",
        previousDisplay: "Переместить окно на предыдущий дисплей",
        edgeSnapEnable: "Привязывать окна к краям экрана",
        edgeSnapSection: "Перетаскивать окна для привязки",
        edgeSnapCaption: "Перетащите окно к краю или углу экрана, чтобы закрепить его на месте.",
        edgeSnapSystemConflict: "macOS использует те же края. Отключите размещение окон в разделе «Рабочий стол и Dock», чтобы их использовал Lattice.",
        edgeSnapOpenSystemSettings: "Открыть «Рабочий стол и Dock»",
        edgeSnapWaitingForSystem: "Включено в Lattice. Заработает сразу после отключения размещения окон macOS.",
        edgeSnapUseCorner: "Использовать этот угол",
        edgeSnapUseEdge: "Использовать этот край",
        edgeSnapAreasOnEdge: "Области на этом краю",
        gapsSection: "Отступы",
        gapsCaption: "Расстояние между прикреплёнными окнами и между окнами и краем экрана.",
        windowGap: "Отступ между окнами",
        screenGap: "Отступ от края экрана",
        sideRepeatCycle: "Повтор «Влево» или «Вправо» меняет размер",
        sideRepeatCycleCaption: "Половина, затем две трети и треть на том же дисплее. Если выключено и дисплеев несколько, повтор переносит окно на следующий дисплей с той стороны.",
        gapNone: "Нет",
        gapTiny: "Крошечный",
        gapSmall: "Маленький",
        gapMedium: "Средний",
        gapLarge: "Большой",
        gapExtraLarge: "Очень большой"
    )

    static let es = WindowLayoutFeatureStrings(
        title: "Gestión de ventanas",
        enable: "Activar disposición de ventanas",
        caption: "Organiza ventanas en zonas de la pantalla o muévelas y cambia su tamaño con el trackpad o el ratón.",
        showInPanel: "Mostrar en el menú de utilidades",
        gestureSection: "Disposición de ventanas",
        gestureEnable: "Mover y cambiar tamaño al arrastrar",
        gestureCaption: "En el trackpad o el ratón, mantén las teclas indicadas y arrastra desde cualquier punto de una ventana.",
        gestureModifiers: "Teclas para mover",
        gestureMove: "Arrastra para mover",
        gestureResize: "Añade Shift y arrastra para cambiar el tamaño",
        gestureResizeHint: "El punto inicial elige el borde o la esquina. Con ratón, arrastrar con el botón derecho también cambia el tamaño.",
        gestureRaiseWindow: "Traer al frente la ventana arrastrada",
        shortcuts: "Atajos",
        shortcutsCaption: "Usa atajos globales para organizar la ventana activa sin abrir el panel.",
        permissionCaption: "Usa Accesibilidad solo para mover y cambiar el tamaño de las ventanas.",
        noWindow: "No se encontró una ventana activa.",
        missingPermission: "Concede Accesibilidad para mover ventanas.",
        failed: "No se pudo mover esta ventana.",
        done: "Ventana organizada.",
        restored: "Ventana restaurada.",
        noRestore: "No hay un diseño anterior para restaurar.",
        target: "Ventana activa",
        halves: "Divisiones",
        thirds: "Tercios",
        quarterRows: "Filas de 1/4",
        quarterColumns: "Columnas de 1/4",
        sixths: "Cuadrículas",
        corners: "Esquinas",
        other: "Tamaño y acciones",
        moving: "Pantallas múltiples",
        leftHalf: "Izquierda",
        rightHalf: "Derecha",
        topHalf: "Arriba",
        bottomHalf: "Abajo",
        centerHalf: "Mitad centrada",
        leftThird: "1/3 izquierda",
        centerThird: "1/3 centro",
        rightThird: "1/3 derecha",
        leftTwoThirds: "2/3 izquierda",
        rightTwoThirds: "2/3 derecha",
        centerTwoThirds: "2/3 centro",
        topThird: "1/3 arriba",
        middleThird: "1/3 medio",
        bottomThird: "1/3 abajo",
        topTwoThirds: "2/3 arriba",
        bottomTwoThirds: "2/3 abajo",
        topQuarter: "Cuarto arriba",
        upperMiddleQuarter: "Cuarto medio superior",
        lowerMiddleQuarter: "Cuarto medio inferior",
        bottomQuarter: "Cuarto abajo",
        leftQuarter: "Cuarto izquierda",
        leftMiddleQuarter: "Cuarto medio izquierdo",
        rightMiddleQuarter: "Cuarto medio derecho",
        rightQuarter: "Cuarto derecha",
        topLeftSixth: "Cuadrícula arriba izquierda",
        topCenterSixth: "Cuadrícula arriba centro",
        topRightSixth: "Cuadrícula arriba derecha",
        bottomLeftSixth: "Cuadrícula abajo izquierda",
        bottomCenterSixth: "Cuadrícula abajo centro",
        bottomRightSixth: "Cuadrícula abajo derecha",
        topLeft: "Cuarto arriba izquierda",
        topRight: "Cuarto arriba derecha",
        bottomLeft: "Cuarto abajo izquierda",
        bottomRight: "Cuarto abajo derecha",
        maximize: "Maximizar",
        center: "Centrar",
        nextDisplay: "Mover ventana a la siguiente pantalla",
        restore: "Restaurar",
        fullScreen: "Pantalla completa",
        previousDisplay: "Mover ventana a la pantalla anterior",
        edgeSnapEnable: "Ajustar ventanas a los bordes de la pantalla",
        edgeSnapSection: "Arrastrar ventanas para ajustar",
        edgeSnapCaption: "Arrastra una ventana a un borde o esquina de la pantalla para encajarla en su sitio.",
        edgeSnapSystemConflict: "macOS usa los mismos bordes. Desactiva el ajuste de ventanas en Escritorio y Dock para que Lattice tome el control.",
        edgeSnapOpenSystemSettings: "Abrir Escritorio y Dock",
        edgeSnapWaitingForSystem: "Activado en Lattice. Funcionará en cuanto se desactive el ajuste de ventanas de macOS.",
        edgeSnapUseCorner: "Usar esta esquina",
        edgeSnapUseEdge: "Usar este borde",
        edgeSnapAreasOnEdge: "Áreas en este borde",
        gapsSection: "Espaciado",
        gapsCaption: "Espacio entre ventanas ajustadas y entre las ventanas y el borde de la pantalla.",
        windowGap: "Margen entre ventanas",
        screenGap: "Margen del borde de la pantalla",
        sideRepeatCycle: "Repetir Izquierda o Derecha alterna los tamaños",
        sideRepeatCycleCaption: "Mitad, luego dos tercios y un tercio en la misma pantalla. Desactivado y con más de una pantalla, la repetición mueve la ventana a la siguiente pantalla de ese lado.",
        gapNone: "Ninguno",
        gapTiny: "Diminuto",
        gapSmall: "Pequeño",
        gapMedium: "Mediano",
        gapLarge: "Grande",
        gapExtraLarge: "Extragrande"
    )

    static let sk = WindowLayoutFeatureStrings(
        title: "Správa okien",
        enable: "Povoliť usporiadanie okien",
        caption: "Usporiadajte okná do oblastí obrazovky alebo ich presúvajte a meňte im veľkosť trackpadom či myšou.",
        showInPanel: "Zobraziť v menu utilít",
        gestureSection: "Usporiadanie okien",
        gestureEnable: "Presúvať a meniť veľkosť ťahaním",
        gestureCaption: "Na trackpade alebo myši podržte zobrazené klávesy a ťahajte kdekoľvek vnútri okna.",
        gestureModifiers: "Klávesy na presun",
        gestureMove: "Ťahaním presuniete",
        gestureResize: "Pridajte Shift a ťahaním zmeníte veľkosť",
        gestureResizeHint: "Počiatočný bod určí najbližší okraj alebo roh. Na myši veľkosť zmení aj ťahanie pravým tlačidlom.",
        gestureRaiseWindow: "Presunúť ťahané okno dopredu",
        shortcuts: "Skratky",
        shortcutsCaption: "Pomocou globálnych skratiek usporiadajte aktívne okno bez otvorenia panela.",
        permissionCaption: "Prístupnosť sa používa iba na presúvanie a zmenu veľkosti okien.",
        noWindow: "Nenašlo sa žiadne aktívne okno.",
        missingPermission: "Na presúvanie okien povoľte Prístupnosť.",
        failed: "Toto okno sa nepodarilo presunúť.",
        done: "Okno usporiadané.",
        restored: "Okno obnovené.",
        noRestore: "Žiadne predchádzajúce rozloženie na obnovenie.",
        target: "Aktívne okno",
        halves: "Rozdelenia",
        thirds: "Tretiny",
        quarterRows: "Štvrtinové riadky",
        quarterColumns: "Štvrtinové stĺpce",
        sixths: "Mriežky",
        corners: "Rohy",
        other: "Zmena veľkosti a akcie",
        moving: "Viacero displejov",
        leftHalf: "Vľavo",
        rightHalf: "Vpravo",
        topHalf: "Hore",
        bottomHalf: "Dole",
        centerHalf: "Stredná polovica",
        leftThird: "Ľavá 1/3",
        centerThird: "Stredná 1/3",
        rightThird: "Pravá 1/3",
        leftTwoThirds: "Ľavé 2/3",
        rightTwoThirds: "Pravé 2/3",
        centerTwoThirds: "Stredné 2/3",
        topThird: "Horná 1/3",
        middleThird: "Stredná 1/3",
        bottomThird: "Dolná 1/3",
        topTwoThirds: "Horné 2/3",
        bottomTwoThirds: "Dolné 2/3",
        topQuarter: "Horná štvrtina",
        upperMiddleQuarter: "Horná stredná štvrtina",
        lowerMiddleQuarter: "Dolná stredná štvrtina",
        bottomQuarter: "Dolná štvrtina",
        leftQuarter: "Ľavá štvrtina",
        leftMiddleQuarter: "Ľavá stredná štvrtina",
        rightMiddleQuarter: "Pravá stredná štvrtina",
        rightQuarter: "Pravá štvrtina",
        topLeftSixth: "Horná ľavá mriežka",
        topCenterSixth: "Horná stredná mriežka",
        topRightSixth: "Horná pravá mriežka",
        bottomLeftSixth: "Dolná ľavá mriežka",
        bottomCenterSixth: "Dolná stredná mriežka",
        bottomRightSixth: "Dolná pravá mriežka",
        topLeft: "Horná ľavá štvrtina",
        topRight: "Horná pravá štvrtina",
        bottomLeft: "Dolná ľavá štvrtina",
        bottomRight: "Dolná pravá štvrtina",
        maximize: "Maximalizovať",
        center: "Vycentrovať",
        nextDisplay: "Presunúť okno na ďalší displej",
        restore: "Obnoviť",
        fullScreen: "Celá obrazovka",
        previousDisplay: "Presunúť okno na predchádzajúci displej",
        edgeSnapEnable: "Priťahovať okná k okrajom obrazovky",
        edgeSnapSection: "Prichytiť okná potiahnutím",
        edgeSnapCaption: "Potiahnite okno k okraju alebo rohu obrazovky, aby zapadlo na miesto.",
        edgeSnapSystemConflict: "macOS používa rovnaké okraje. V Ploche a Docku vypnite dlaždicovanie okien, aby to mohol prevziať Lattice.",
        edgeSnapOpenSystemSettings: "Otvoriť Plochu a Dock",
        edgeSnapWaitingForSystem: "Zapnuté vo Lattice. Začne fungovať hneď po vypnutí dlaždicovania v macOS.",
        edgeSnapUseCorner: "Používať tento roh",
        edgeSnapUseEdge: "Používať tento okraj",
        edgeSnapAreasOnEdge: "Oblasti na tomto okraji",
        gapsSection: "Medzery",
        gapsCaption: "Priestor medzi priťahovanými oknami a medzi oknami a okrajom obrazovky.",
        windowGap: "Okraj medzi oknami",
        screenGap: "Okraj obrazovky",
        sideRepeatCycle: "Opakovaním „Vľavo“ alebo „Vpravo“ striedať veľkosti",
        sideRepeatCycleCaption: "Polovica, potom dve tretiny, potom jedna tretina na tom istom displeji. Keď je to vypnuté a máte viac ako jeden displej, opakovanie presunie okno na ďalší displej na tej strane.",
        gapNone: "Žiadna",
        gapTiny: "Drobná",
        gapSmall: "Malá",
        gapMedium: "Stredná",
        gapLarge: "Veľká",
        gapExtraLarge: "Extra veľká"
    )

    static let de = WindowLayoutFeatureStrings(
        title: "Fensterverwaltung",
        enable: "Fensteranordnung aktivieren",
        caption: "Ordne Fenster in Bildschirmbereiche ein oder verschiebe und skaliere sie mit Trackpad oder Maus.",
        showInPanel: "Im Dienstprogramme-Menü anzeigen",
        gestureSection: "Fensteranordnung",
        gestureEnable: "Durch Ziehen verschieben und skalieren",
        gestureCaption: "Halte auf Trackpad oder Maus die angezeigten Sondertasten und ziehe an einer beliebigen Stelle im Fenster.",
        gestureModifiers: "Tasten zum Verschieben",
        gestureMove: "Zum Verschieben ziehen",
        gestureResize: "Shift hinzufügen und zum Skalieren ziehen",
        gestureResizeHint: "Der Startpunkt wählt die nächste Kante oder Ecke. Mit der Maus skaliert auch Ziehen mit der rechten Taste.",
        gestureRaiseWindow: "Gezogenes Fenster nach vorne bringen",
        shortcuts: "Kurzbefehle",
        shortcutsCaption: "Nutze globale Kurzbefehle, um das aktive Fenster ohne Panel zu arrangieren.",
        permissionCaption: "Nutzt Bedienungshilfen nur zum Verschieben und Skalieren von Fenstern.",
        noWindow: "Kein aktives Fenster gefunden.",
        missingPermission: "Erlaube Bedienungshilfen, um Fenster zu bewegen.",
        failed: "Dieses Fenster konnte nicht bewegt werden.",
        done: "Fenster arrangiert.",
        restored: "Fenster wiederhergestellt.",
        noRestore: "Kein vorheriges Layout zum Wiederherstellen.",
        target: "Aktives Fenster",
        halves: "Splits",
        thirds: "Drittel",
        quarterRows: "Viertelzeilen",
        quarterColumns: "Viertelspalten",
        sixths: "Raster",
        corners: "Ecken",
        other: "Größe & Aktionen",
        moving: "Mehrere Monitore",
        leftHalf: "Links",
        rightHalf: "Rechts",
        topHalf: "Oben",
        bottomHalf: "Unten",
        centerHalf: "Mittlere Hälfte",
        leftThird: "Linkes 1/3",
        centerThird: "Mittleres 1/3",
        rightThird: "Rechtes 1/3",
        leftTwoThirds: "Linke 2/3",
        rightTwoThirds: "Rechte 2/3",
        centerTwoThirds: "Mittlere 2/3",
        topThird: "Oben 1/3",
        middleThird: "Mitte 1/3",
        bottomThird: "Unten 1/3",
        topTwoThirds: "Oben 2/3",
        bottomTwoThirds: "Unten 2/3",
        topQuarter: "Viertel oben",
        upperMiddleQuarter: "Viertel obere Mitte",
        lowerMiddleQuarter: "Viertel untere Mitte",
        bottomQuarter: "Viertel unten",
        leftQuarter: "Viertel links",
        leftMiddleQuarter: "Viertel linke Mitte",
        rightMiddleQuarter: "Viertel rechte Mitte",
        rightQuarter: "Viertel rechts",
        topLeftSixth: "Raster oben links",
        topCenterSixth: "Raster oben mittig",
        topRightSixth: "Raster oben rechts",
        bottomLeftSixth: "Raster unten links",
        bottomCenterSixth: "Raster unten mittig",
        bottomRightSixth: "Raster unten rechts",
        topLeft: "Viertel oben links",
        topRight: "Viertel oben rechts",
        bottomLeft: "Viertel unten links",
        bottomRight: "Viertel unten rechts",
        maximize: "Maximieren",
        center: "Zentrieren",
        nextDisplay: "Fenster auf nächstes Display bewegen",
        restore: "Wiederherstellen",
        fullScreen: "Vollbild",
        previousDisplay: "Fenster auf vorheriges Display bewegen",
        edgeSnapEnable: "Fenster an Bildschirmrändern einrasten",
        edgeSnapSection: "Fenster zum Einrasten ziehen",
        edgeSnapCaption: "Ziehe ein Fenster an einen Bildschirmrand oder in eine Ecke, um es einzurasten.",
        edgeSnapSystemConflict: "macOS verwendet dieselben Ränder. Deaktiviere die Fensteranordnung unter Schreibtisch & Dock, damit Lattice übernimmt.",
        edgeSnapOpenSystemSettings: "Schreibtisch & Dock öffnen",
        edgeSnapWaitingForSystem: "In Lattice aktiviert. Es funktioniert, sobald die Fensteranordnung von macOS aus ist.",
        edgeSnapUseCorner: "Diese Ecke verwenden",
        edgeSnapUseEdge: "Diesen Rand verwenden",
        edgeSnapAreasOnEdge: "Bereiche an diesem Rand",
        gapsSection: "Abstände",
        gapsCaption: "Abstand zwischen angedockten Fenstern sowie zwischen Fenstern und dem Bildschirmrand.",
        windowGap: "Rand zwischen Fenstern",
        screenGap: "Bildschirmrand-Abstand",
        sideRepeatCycle: "Links oder Rechts wiederholen wechselt die Größe",
        sideRepeatCycleCaption: "Hälfte, dann zwei Drittel und ein Drittel auf demselben Bildschirm. Ausgeschaltet und bei mehr als einem Bildschirm schiebt die Wiederholung das Fenster auf den nächsten Bildschirm auf dieser Seite.",
        gapNone: "Kein",
        gapTiny: "Winzig",
        gapSmall: "Klein",
        gapMedium: "Mittel",
        gapLarge: "Groß",
        gapExtraLarge: "Sehr groß"
    )

    static let fr = WindowLayoutFeatureStrings(
        title: "Gestion des fenêtres",
        enable: "Activer la disposition des fenêtres",
        caption: "Organisez les fenêtres dans des zones de l’écran ou déplacez-les et redimensionnez-les au trackpad ou à la souris.",
        showInPanel: "Afficher dans le menu des utilitaires",
        gestureSection: "Disposition des fenêtres",
        gestureEnable: "Déplacer et redimensionner par glissement",
        gestureCaption: "Au trackpad ou à la souris, maintenez les touches indiquées et faites glisser depuis n’importe quel point d’une fenêtre.",
        gestureModifiers: "Touches pour déplacer",
        gestureMove: "Faites glisser pour déplacer",
        gestureResize: "Ajoutez Maj et faites glisser pour redimensionner",
        gestureResizeHint: "Le point de départ choisit le bord ou le coin. À la souris, le glissement avec le bouton droit redimensionne aussi.",
        gestureRaiseWindow: "Placer la fenêtre déplacée au premier plan",
        shortcuts: "Raccourcis",
        shortcutsCaption: "Utilisez des raccourcis globaux pour organiser la fenêtre active sans ouvrir le panneau.",
        permissionCaption: "Utilise Accessibilité uniquement pour déplacer et redimensionner les fenêtres.",
        noWindow: "Aucune fenêtre active trouvée.",
        missingPermission: "Autorisez Accessibilité pour déplacer les fenêtres.",
        failed: "Impossible de déplacer cette fenêtre.",
        done: "Fenêtre organisée.",
        restored: "Fenêtre restaurée.",
        noRestore: "Aucune disposition précédente à restaurer.",
        target: "Fenêtre active",
        halves: "Partages",
        thirds: "Tiers",
        quarterRows: "Rangées de 1/4",
        quarterColumns: "Colonnes de 1/4",
        sixths: "Grilles",
        corners: "Coins",
        other: "Redimensionnement et actions",
        moving: "Multi-écrans",
        leftHalf: "Gauche",
        rightHalf: "Droite",
        topHalf: "Haut",
        bottomHalf: "Bas",
        centerHalf: "Moitié centrée",
        leftThird: "1/3 gauche",
        centerThird: "1/3 centre",
        rightThird: "1/3 droite",
        leftTwoThirds: "2/3 gauche",
        rightTwoThirds: "2/3 droite",
        centerTwoThirds: "2/3 centre",
        topThird: "1/3 haut",
        middleThird: "1/3 milieu",
        bottomThird: "1/3 bas",
        topTwoThirds: "2/3 haut",
        bottomTwoThirds: "2/3 bas",
        topQuarter: "Quart haut",
        upperMiddleQuarter: "Quart milieu haut",
        lowerMiddleQuarter: "Quart milieu bas",
        bottomQuarter: "Quart bas",
        leftQuarter: "Quart gauche",
        leftMiddleQuarter: "Quart milieu gauche",
        rightMiddleQuarter: "Quart milieu droite",
        rightQuarter: "Quart droite",
        topLeftSixth: "Grille en haut à gauche",
        topCenterSixth: "Grille en haut au centre",
        topRightSixth: "Grille en haut à droite",
        bottomLeftSixth: "Grille en bas à gauche",
        bottomCenterSixth: "Grille en bas au centre",
        bottomRightSixth: "Grille en bas à droite",
        topLeft: "Quart haut gauche",
        topRight: "Quart haut droite",
        bottomLeft: "Quart bas gauche",
        bottomRight: "Quart bas droite",
        maximize: "Agrandir",
        center: "Centrer",
        nextDisplay: "Déplacer la fenêtre vers l’écran suivant",
        restore: "Restaurer",
        fullScreen: "Plein écran",
        previousDisplay: "Déplacer la fenêtre vers l’écran précédent",
        edgeSnapEnable: "Ancrer les fenêtres aux bords de l’écran",
        edgeSnapSection: "Faire glisser les fenêtres pour les ancrer",
        edgeSnapCaption: "Faites glisser une fenêtre vers un bord ou un coin de l’écran pour la mettre en place.",
        edgeSnapSystemConflict: "macOS utilise les mêmes bords. Désactivez le placement des fenêtres dans Bureau et Dock pour laisser Lattice prendre le relais.",
        edgeSnapOpenSystemSettings: "Ouvrir Bureau et Dock",
        edgeSnapWaitingForSystem: "Activé dans Lattice. Il fonctionnera dès que le placement des fenêtres de macOS sera désactivé.",
        edgeSnapUseCorner: "Utiliser ce coin",
        edgeSnapUseEdge: "Utiliser ce bord",
        edgeSnapAreasOnEdge: "Zones sur ce bord",
        gapsSection: "Espacements",
        gapsCaption: "Espace entre les fenêtres ancrées et entre les fenêtres et le bord de l’écran.",
        windowGap: "Marge entre les fenêtres",
        screenGap: "Marge du bord de l’écran",
        sideRepeatCycle: "Répéter Gauche ou Droite alterne les tailles",
        sideRepeatCycleCaption: "Moitié, puis deux tiers et un tiers sur le même écran. Désactivé et avec plusieurs écrans, la répétition déplace la fenêtre vers l’écran suivant de ce côté.",
        gapNone: "Aucun",
        gapTiny: "Minuscule",
        gapSmall: "Petit",
        gapMedium: "Moyen",
        gapLarge: "Grand",
        gapExtraLarge: "Très grand"
    )

    static let it = WindowLayoutFeatureStrings(
        title: "Gestione finestre",
        enable: "Abilita disposizione finestre",
        caption: "Disponi le finestre nelle aree dello schermo oppure spostale e ridimensionale con trackpad o mouse.",
        showInPanel: "Mostra nel menu delle utility",
        gestureSection: "Disposizione finestre",
        gestureEnable: "Sposta e ridimensiona trascinando",
        gestureCaption: "Sul trackpad o con il mouse, tieni premuti i tasti indicati e trascina da qualsiasi punto della finestra.",
        gestureModifiers: "Tasti per spostare",
        gestureMove: "Trascina per spostare",
        gestureResize: "Aggiungi Maiusc e trascina per ridimensionare",
        gestureResizeHint: "Il punto iniziale sceglie il bordo o l’angolo. Con il mouse, anche il trascinamento destro ridimensiona.",
        gestureRaiseWindow: "Porta in primo piano la finestra trascinata",
        shortcuts: "Scorciatoie",
        shortcutsCaption: "Usa scorciatoie globali per organizzare la finestra attiva senza aprire il pannello.",
        permissionCaption: "Usa Accessibilità solo per spostare e ridimensionare le finestre.",
        noWindow: "Nessuna finestra attiva trovata.",
        missingPermission: "Concedi Accessibilità per spostare le finestre.",
        failed: "Impossibile spostare questa finestra.",
        done: "Finestra organizzata.",
        restored: "Finestra ripristinata.",
        noRestore: "Nessun layout precedente da ripristinare.",
        target: "Finestra attiva",
        halves: "Divisioni",
        thirds: "Terzi",
        quarterRows: "Righe da 1/4",
        quarterColumns: "Colonne da 1/4",
        sixths: "Griglie",
        corners: "Angoli",
        other: "Dimensionamento e azioni",
        moving: "Schermi multipli",
        leftHalf: "Sinistra",
        rightHalf: "Destra",
        topHalf: "Alto",
        bottomHalf: "Basso",
        centerHalf: "Metà centrale",
        leftThird: "1/3 sinistra",
        centerThird: "1/3 centro",
        rightThird: "1/3 destra",
        leftTwoThirds: "2/3 sinistra",
        rightTwoThirds: "2/3 destra",
        centerTwoThirds: "2/3 centro",
        topThird: "1/3 alto",
        middleThird: "1/3 mezzo",
        bottomThird: "1/3 basso",
        topTwoThirds: "2/3 alto",
        bottomTwoThirds: "2/3 basso",
        topQuarter: "Quarto in alto",
        upperMiddleQuarter: "Quarto mezzo alto",
        lowerMiddleQuarter: "Quarto mezzo basso",
        bottomQuarter: "Quarto in basso",
        leftQuarter: "Quarto a sinistra",
        leftMiddleQuarter: "Quarto mezzo sinistro",
        rightMiddleQuarter: "Quarto mezzo destro",
        rightQuarter: "Quarto a destra",
        topLeftSixth: "Griglia in alto a sinistra",
        topCenterSixth: "Griglia in alto al centro",
        topRightSixth: "Griglia in alto a destra",
        bottomLeftSixth: "Griglia in basso a sinistra",
        bottomCenterSixth: "Griglia in basso al centro",
        bottomRightSixth: "Griglia in basso a destra",
        topLeft: "Quarto in alto a sinistra",
        topRight: "Quarto in alto a destra",
        bottomLeft: "Quarto in basso a sinistra",
        bottomRight: "Quarto in basso a destra",
        maximize: "Massimizza",
        center: "Centra",
        nextDisplay: "Sposta finestra sul display successivo",
        restore: "Ripristina",
        fullScreen: "Schermo intero",
        previousDisplay: "Sposta finestra sul display precedente",
        edgeSnapEnable: "Allinea le finestre ai bordi dello schermo",
        edgeSnapSection: "Trascina le finestre per agganciarle",
        edgeSnapCaption: "Trascina una finestra verso un bordo o un angolo dello schermo per posizionarla.",
        edgeSnapSystemConflict: "macOS usa gli stessi bordi. Disattiva l’affiancamento in Scrivania e Dock per lasciare il controllo a Lattice.",
        edgeSnapOpenSystemSettings: "Apri Scrivania e Dock",
        edgeSnapWaitingForSystem: "Attivato in Lattice. Funzionerà appena l’affiancamento di macOS sarà disattivato.",
        edgeSnapUseCorner: "Usa questo angolo",
        edgeSnapUseEdge: "Usa questo bordo",
        edgeSnapAreasOnEdge: "Aree su questo bordo",
        gapsSection: "Spaziatura",
        gapsCaption: "Spazio tra le finestre agganciate e tra le finestre e il bordo dello schermo.",
        windowGap: "Margine tra le finestre",
        screenGap: "Margine del bordo dello schermo",
        sideRepeatCycle: "Ripetere Sinistra o Destra alterna le dimensioni",
        sideRepeatCycleCaption: "Metà, poi due terzi e un terzo sullo stesso schermo. Se disattivato e con più di uno schermo, la ripetizione sposta la finestra sullo schermo successivo da quel lato.",
        gapNone: "Nessuno",
        gapTiny: "Minuscolo",
        gapSmall: "Piccolo",
        gapMedium: "Medio",
        gapLarge: "Grande",
        gapExtraLarge: "Molto grande"
    )

    static let ja = WindowLayoutFeatureStrings(
        title: "ウインドウ管理",
        enable: "ウインドウ配置を有効にする",
        caption: "ウインドウを画面の領域に配置したり、トラックパッドやマウスで移動やサイズ変更ができます。",
        showInPanel: "ユーティリティメニューに表示",
        gestureSection: "ウインドウ配置",
        gestureEnable: "ドラッグで移動とサイズ変更",
        gestureCaption: "トラックパッドまたはマウスで表示された修飾キーを押し、ウインドウ内の任意の場所からドラッグします。",
        gestureModifiers: "移動用キー",
        gestureMove: "ドラッグして移動",
        gestureResize: "Shiftを加えてドラッグしサイズ変更",
        gestureResizeHint: "開始位置に最も近い辺または角が選ばれます。マウスでは右ボタンのドラッグでもサイズ変更できます。",
        gestureRaiseWindow: "ドラッグしたウインドウを手前に表示",
        shortcuts: "ショートカット",
        shortcutsCaption: "パネルを開かずにグローバルショートカットでアクティブなウインドウを配置します。",
        permissionCaption: "アクセシビリティはウインドウの移動とサイズ変更にのみ使用します。",
        noWindow: "アクティブなウインドウが見つかりません。",
        missingPermission: "ウインドウを移動するにはアクセシビリティを許可してください。",
        failed: "このウインドウを移動できませんでした。",
        done: "ウインドウを配置しました。",
        restored: "ウインドウを復元しました。",
        noRestore: "復元できる前回の配置はありません。",
        target: "アクティブなウインドウ",
        halves: "分割",
        thirds: "3分割",
        quarterRows: "横4分割",
        quarterColumns: "縦4分割",
        sixths: "グリッド",
        corners: "四隅",
        other: "サイズ変更とアクション",
        moving: "マルチディスプレイ",
        leftHalf: "左",
        rightHalf: "右",
        topHalf: "上",
        bottomHalf: "下",
        centerHalf: "中央ハーフ",
        leftThird: "左 1/3",
        centerThird: "中央 1/3",
        rightThird: "右 1/3",
        leftTwoThirds: "左 2/3",
        rightTwoThirds: "右 2/3",
        centerTwoThirds: "中央 2/3",
        topThird: "上 1/3",
        middleThird: "中央 1/3",
        bottomThird: "下 1/3",
        topTwoThirds: "上 2/3",
        bottomTwoThirds: "下 2/3",
        topQuarter: "上4分割",
        upperMiddleQuarter: "中央上4分割",
        lowerMiddleQuarter: "中央下4分割",
        bottomQuarter: "下4分割",
        leftQuarter: "左4分割",
        leftMiddleQuarter: "左中央4分割",
        rightMiddleQuarter: "右中央4分割",
        rightQuarter: "右4分割",
        topLeftSixth: "左上グリッド",
        topCenterSixth: "中央上グリッド",
        topRightSixth: "右上グリッド",
        bottomLeftSixth: "左下グリッド",
        bottomCenterSixth: "中央下グリッド",
        bottomRightSixth: "右下グリッド",
        topLeft: "左上4分割",
        topRight: "右上4分割",
        bottomLeft: "左下4分割",
        bottomRight: "右下4分割",
        maximize: "最大化",
        center: "中央",
        nextDisplay: "ウインドウを次のディスプレイに移動",
        restore: "復元",
        fullScreen: "フルスクリーン",
        previousDisplay: "ウインドウを前のディスプレイに移動",
        edgeSnapEnable: "画面の端にウインドウをスナップ",
        edgeSnapSection: "ウインドウをドラッグしてスナップ",
        edgeSnapCaption: "ウインドウを画面の端や角にドラッグして配置します。",
        edgeSnapSystemConflict: "macOSが同じ画面端を使用しています。Latticeで使うには「デスクトップとDock」でウインドウのタイル表示をオフにしてください。",
        edgeSnapOpenSystemSettings: "デスクトップとDockを開く",
        edgeSnapWaitingForSystem: "Latticeでオンになっています。macOSのタイル表示をオフにすると動作します。",
        edgeSnapUseCorner: "この隅を使用",
        edgeSnapUseEdge: "この端を使用",
        edgeSnapAreasOnEdge: "この端の領域",
        gapsSection: "間隔",
        gapsCaption: "スナップしたウインドウ同士、およびウインドウと画面端の間隔です。",
        windowGap: "ウインドウ間の余白",
        screenGap: "画面端の余白",
        sideRepeatCycle: "左/右の繰り返しでサイズを切り替える",
        sideRepeatCycleCaption: "同じディスプレイで半分、2/3、1/3の順に変わります。オフでディスプレイが複数ある場合、繰り返すとその方向の次のディスプレイへ移動します。",
        gapNone: "なし",
        gapTiny: "極小",
        gapSmall: "小",
        gapMedium: "中",
        gapLarge: "大",
        gapExtraLarge: "特大"
    )

    static let zhHans = WindowLayoutFeatureStrings(
        title: "窗口管理",
        enable: "启用窗口排列",
        caption: "将窗口排列到屏幕区域，或用触控板或鼠标移动和调整大小。",
        showInPanel: "在实用工具菜单中显示",
        gestureSection: "窗口排列",
        gestureEnable: "拖动窗口以移动和调整大小",
        gestureCaption: "在触控板或鼠标上按住显示的修饰键，从窗口内任意位置拖动。",
        gestureModifiers: "移动按键",
        gestureMove: "拖动以移动",
        gestureResize: "加按 Shift 并拖动以调整大小",
        gestureResizeHint: "起点决定最近的边缘或角落。使用鼠标时，按住右键拖动也可调整大小。",
        gestureRaiseWindow: "将拖动的窗口置于最前",
        shortcuts: "快捷键",
        shortcutsCaption: "使用全局快捷键整理当前窗口，无需打开面板。",
        permissionCaption: "辅助功能权限仅用于移动窗口和调整窗口大小。",
        noWindow: "未找到当前窗口。",
        missingPermission: "请授予辅助功能权限以移动窗口。",
        failed: "无法移动此窗口。",
        done: "窗口已整理。",
        restored: "窗口已恢复。",
        noRestore: "没有可恢复的上一个布局。",
        target: "当前窗口",
        halves: "分屏",
        thirds: "三分屏",
        quarterRows: "横向四分屏",
        quarterColumns: "纵向四分屏",
        sixths: "网格",
        corners: "角落",
        other: "大小调整与操作",
        moving: "多显示器",
        leftHalf: "左半屏",
        rightHalf: "右半屏",
        topHalf: "上半屏",
        bottomHalf: "下半屏",
        centerHalf: "居中半屏",
        leftThird: "左侧 1/3",
        centerThird: "中间 1/3",
        rightThird: "右侧 1/3",
        leftTwoThirds: "左侧 2/3",
        rightTwoThirds: "右侧 2/3",
        centerTwoThirds: "居中 2/3",
        topThird: "上 1/3",
        middleThird: "中 1/3",
        bottomThird: "下 1/3",
        topTwoThirds: "上 2/3",
        bottomTwoThirds: "下 2/3",
        topQuarter: "顶端四等分",
        upperMiddleQuarter: "中上四等分",
        lowerMiddleQuarter: "中下四等分",
        bottomQuarter: "底端四等分",
        leftQuarter: "左侧四等分",
        leftMiddleQuarter: "左中四等分",
        rightMiddleQuarter: "右中四等分",
        rightQuarter: "右侧四等分",
        topLeftSixth: "左上网格",
        topCenterSixth: "中上网格",
        topRightSixth: "右上网格",
        bottomLeftSixth: "左下网格",
        bottomCenterSixth: "中下网格",
        bottomRightSixth: "右下网格",
        topLeft: "左上四等分",
        topRight: "右上四等分",
        bottomLeft: "左下四等分",
        bottomRight: "右下四等分",
        maximize: "最大化",
        center: "居中",
        nextDisplay: "将窗口移到下一台显示器",
        restore: "恢复",
        fullScreen: "全屏幕",
        previousDisplay: "将窗口移到上一台显示器",
        edgeSnapEnable: "将窗口贴靠到屏幕边缘",
        edgeSnapSection: "拖移窗口以贴靠",
        edgeSnapCaption: "将窗口拖移到屏幕边缘或角落以贴靠就位。",
        edgeSnapSystemConflict: "macOS 正在使用相同的屏幕边缘。请在“桌面与程序坞”中关闭窗口平铺，让 Lattice 接管。",
        edgeSnapOpenSystemSettings: "打开桌面与程序坞",
        edgeSnapWaitingForSystem: "已在 Lattice 中开启。关闭 macOS 窗口平铺后即可使用。",
        edgeSnapUseCorner: "使用此角落",
        edgeSnapUseEdge: "使用此边缘",
        edgeSnapAreasOnEdge: "此边缘的区域",
        gapsSection: "间距",
        gapsCaption: "贴靠窗口之间以及窗口与屏幕边缘之间的间距。",
        windowGap: "窗口间距",
        screenGap: "屏幕边缘间距",
        sideRepeatCycle: "重复左/右时循环尺寸",
        sideRepeatCycleCaption: "在同一显示器上依次切换为一半、三分之二和三分之一。关闭且有多台显示器时，重复操作会把窗口移到该侧的下一台显示器。",
        gapNone: "无",
        gapTiny: "极小",
        gapSmall: "小",
        gapMedium: "中",
        gapLarge: "大",
        gapExtraLarge: "特大"
    )

    static let zhTW = WindowLayoutFeatureStrings(
        title: "視窗管理",
        enable: "啟用視窗排列",
        caption: "將視窗排列到螢幕區域，或用觸控板或滑鼠移動及調整大小。",
        showInPanel: "在工具程式選單中顯示",
        gestureSection: "視窗排列",
        gestureEnable: "拖移以移動及調整大小",
        gestureCaption: "在觸控板或滑鼠上按住顯示的輔助鍵，從視窗內任何位置拖移。",
        gestureModifiers: "移動按鍵",
        gestureMove: "拖移以移動",
        gestureResize: "加按 Shift 並拖移以調整大小",
        gestureResizeHint: "起點會選擇最近的邊緣或角落。使用滑鼠時，按住右鍵拖移也可調整大小。",
        gestureRaiseWindow: "將拖移的視窗帶到最前方",
        shortcuts: "快速鍵",
        shortcutsCaption: "使用全域快速鍵整理目前視窗，不需要打開面板。",
        permissionCaption: "輔助使用權限只用於移動視窗及調整大小。",
        noWindow: "找不到目前視窗。",
        missingPermission: "請允許輔助使用權限以移動視窗。",
        failed: "無法移動此視窗。",
        done: "視窗已整理。",
        restored: "視窗已還原。",
        noRestore: "沒有可還原的上一個排列方式。",
        target: "目前視窗",
        halves: "分屏",
        thirds: "三等分",
        quarterRows: "橫向四等分",
        quarterColumns: "縱向四等分",
        sixths: "網格",
        corners: "角落",
        other: "大小調整與操作",
        moving: "多顯示器",
        leftHalf: "左半邊",
        rightHalf: "右半邊",
        topHalf: "上半邊",
        bottomHalf: "下半邊",
        centerHalf: "置中半屏",
        leftThird: "左側 1/3",
        centerThird: "中間 1/3",
        rightThird: "右側 1/3",
        leftTwoThirds: "左側 2/3",
        rightTwoThirds: "右側 2/3",
        centerTwoThirds: "置中 2/3",
        topThird: "上 1/3",
        middleThird: "中 1/3",
        bottomThird: "下 1/3",
        topTwoThirds: "上 2/3",
        bottomTwoThirds: "下 2/3",
        topQuarter: "頂端四等分",
        upperMiddleQuarter: "中上四等分",
        lowerMiddleQuarter: "中下四等分",
        bottomQuarter: "底端四等分",
        leftQuarter: "左側四等分",
        leftMiddleQuarter: "左中四等分",
        rightMiddleQuarter: "右中四等分",
        rightQuarter: "右側四等分",
        topLeftSixth: "左上網格",
        topCenterSixth: "上方中央網格",
        topRightSixth: "右上網格",
        bottomLeftSixth: "左下網格",
        bottomCenterSixth: "下方中央網格",
        bottomRightSixth: "右下網格",
        topLeft: "左上四等分",
        topRight: "右上四等分",
        bottomLeft: "左下四等分",
        bottomRight: "右下四等分",
        maximize: "最大化",
        center: "置中",
        nextDisplay: "將視窗移至下一台顯示器",
        restore: "還原",
        fullScreen: "全螢幕",
        previousDisplay: "將視窗移至上一台顯示器",
        edgeSnapEnable: "將視窗貼齊螢幕邊緣",
        edgeSnapSection: "拖移視窗以貼齊",
        edgeSnapCaption: "將視窗拖移到螢幕邊緣或角落以貼齊定位。",
        edgeSnapSystemConflict: "macOS 正在使用相同的螢幕邊緣。請在「桌面與 Dock」關閉視窗並排，讓 Lattice 接管。",
        edgeSnapOpenSystemSettings: "開啟桌面與 Dock",
        edgeSnapWaitingForSystem: "已在 Lattice 中開啟。關閉 macOS 視窗並排後即可使用。",
        edgeSnapUseCorner: "使用此角落",
        edgeSnapUseEdge: "使用此邊緣",
        edgeSnapAreasOnEdge: "此邊緣的區域",
        gapsSection: "間距",
        gapsCaption: "貼齊視窗之間以及視窗與螢幕邊緣之間的間距。",
        windowGap: "視窗間距",
        screenGap: "螢幕邊緣間距",
        sideRepeatCycle: "重複左/右時循環尺寸",
        sideRepeatCycleCaption: "在同一顯示器上依序切換為一半、三分之二和三分之一。關閉且有多部顯示器時，重複操作會把視窗移到該側的下一部顯示器。",
        gapNone: "無",
        gapTiny: "極小",
        gapSmall: "小",
        gapMedium: "中",
        gapLarge: "大",
        gapExtraLarge: "特大"
    )

    static let zhHK = WindowLayoutFeatureStrings(
        title: "視窗管理",
        enable: "啟用視窗排列",
        caption: "將視窗排列到螢幕區域，或用觸控板或滑鼠移動及調整大小。",
        showInPanel: "在工具程式選單中顯示",
        gestureSection: "視窗排列",
        gestureEnable: "拖動以移動及調整大小",
        gestureCaption: "在觸控板或滑鼠上按住顯示的輔助鍵，從視窗內任何位置拖動。",
        gestureModifiers: "移動按鍵",
        gestureMove: "拖動以移動",
        gestureResize: "加按 Shift 並拖動以調整大小",
        gestureResizeHint: "起點會選擇最近的邊緣或角落。使用滑鼠時，按住右鍵拖動也可調整大小。",
        gestureRaiseWindow: "將拖動的視窗帶到最前方",
        shortcuts: "快捷鍵",
        shortcutsCaption: "使用全域快捷鍵整理目前視窗，毋須打開面板。",
        permissionCaption: "輔助使用權限只用於移動視窗及調整大小。",
        noWindow: "找不到目前視窗。",
        missingPermission: "請同意輔助使用權限以移動視窗。",
        failed: "無法移動此視窗。",
        done: "視窗已整理。",
        restored: "視窗已還原。",
        noRestore: "沒有可還原的上一個排列方式。",
        target: "目前視窗",
        halves: "分屏",
        thirds: "三等分",
        quarterRows: "橫向四等分",
        quarterColumns: "縱向四等分",
        sixths: "網格",
        corners: "角落",
        other: "大小調整與操作",
        moving: "多顯示器",
        leftHalf: "左半邊",
        rightHalf: "右半邊",
        topHalf: "上半邊",
        bottomHalf: "下半邊",
        centerHalf: "置中半屏",
        leftThird: "左側 1/3",
        centerThird: "中間 1/3",
        rightThird: "右側 1/3",
        leftTwoThirds: "左側 2/3",
        rightTwoThirds: "右側 2/3",
        centerTwoThirds: "置中 2/3",
        topThird: "上 1/3",
        middleThird: "中 1/3",
        bottomThird: "下 1/3",
        topTwoThirds: "上 2/3",
        bottomTwoThirds: "下 2/3",
        topQuarter: "頂端四等分",
        upperMiddleQuarter: "中上四等分",
        lowerMiddleQuarter: "中下四等分",
        bottomQuarter: "底端四等分",
        leftQuarter: "左側四等分",
        leftMiddleQuarter: "左中四等分",
        rightMiddleQuarter: "右中四等分",
        rightQuarter: "右側四等分",
        topLeftSixth: "左上網格",
        topCenterSixth: "上方中央網格",
        topRightSixth: "右上網格",
        bottomLeftSixth: "左下網格",
        bottomCenterSixth: "下方中央網格",
        bottomRightSixth: "右下網格",
        topLeft: "左上四等分",
        topRight: "右上四等分",
        bottomLeft: "左下四等分",
        bottomRight: "右下四等分",
        maximize: "最大化",
        center: "置中",
        nextDisplay: "將視窗移至下一部顯示器",
        restore: "還原",
        fullScreen: "全螢幕",
        previousDisplay: "將視窗移至上一部顯示器",
        edgeSnapEnable: "將視窗貼齊螢幕邊緣",
        edgeSnapSection: "拖移視窗以貼齊",
        edgeSnapCaption: "將視窗拖移到螢幕邊緣或角落以貼齊定位。",
        edgeSnapSystemConflict: "macOS 正在使用相同的螢幕邊緣。請在「桌面與 Dock」關閉視窗並排，讓 Lattice 接管。",
        edgeSnapOpenSystemSettings: "開啟桌面與 Dock",
        edgeSnapWaitingForSystem: "已在 Lattice 中開啟。關閉 macOS 視窗並排後即可使用。",
        edgeSnapUseCorner: "使用此角落",
        edgeSnapUseEdge: "使用此邊緣",
        edgeSnapAreasOnEdge: "此邊緣的區域",
        gapsSection: "間距",
        gapsCaption: "貼齊視窗之間以及視窗與螢幕邊緣之間的間距。",
        windowGap: "視窗間距",
        screenGap: "螢幕邊緣間距",
        sideRepeatCycle: "重複左/右時循環尺寸",
        sideRepeatCycleCaption: "在同一顯示器上依序切換為一半、三分之二和三分之一。關閉且有多部顯示器時，重複操作會把視窗移到該側的下一部顯示器。",
        gapNone: "無",
        gapTiny: "極小",
        gapSmall: "小",
        gapMedium: "中",
        gapLarge: "大",
        gapExtraLarge: "特大"
    )
}

struct MonitorAlertFeatureStrings {
    let section: String
    let caption: String
    let notificationsDenied: String
    let cpu: String
    let cpuTemperature: String
    let memory: String
    let disk: String
    let battery: String
    let cooldown: String
    let aboveFormat: String           // + limit
    let belowFormat: String           // + limit
    let cooldown2: String
    let cooldown5: String
    let cooldown15: String
    let cooldown30: String
    let cooldown60: String
    let cpuTitle: String
    let cpuBodyFormat: String
    let cpuTemperatureTitle: String
    let cpuTemperatureBodyFormat: String
    let memoryTitle: String
    let memoryBody: String
    let diskTitle: String
    let diskBodyFormat: String
    let batteryTitle: String
    let batteryBodyFormat: String
    let batteryTemperature: String
    let batteryTemperatureTitle: String
    let batteryTemperatureBodyFormat: String

    static let enUS = MonitorAlertFeatureStrings(
        section: "Alerts",
        caption: "Get a notification when a reading passes its limit. CPU spikes under 12 seconds don’t count.",
        notificationsDenied: "Notifications for Lattice are off in System Settings, so alerts cannot appear.",
        cpu: "CPU usage",
        cpuTemperature: "CPU temperature",
        memory: "Critical memory pressure",
        disk: "Free disk space",
        battery: "Battery level",
        cooldown: "Repeat after",
        aboveFormat: "Above %@",
        belowFormat: "Below %@",
        cooldown2: "2 minutes",
        cooldown5: "5 minutes",
        cooldown15: "15 minutes",
        cooldown30: "30 minutes",
        cooldown60: "1 hour",
        cpuTitle: "High CPU",
        cpuBodyFormat: "CPU stayed above %d%% for a few seconds.",
        cpuTemperatureTitle: "Hot CPU",
        cpuTemperatureBodyFormat: "CPU reached %@.",
        memoryTitle: "Critical memory",
        memoryBody: "Memory pressure reached the critical level.",
        diskTitle: "Low disk space",
        diskBodyFormat: "%@ has less than %d%% free.",
        batteryTitle: "Low battery",
        batteryBodyFormat: "Battery is at %d%%.",
        batteryTemperature: "Battery temperature",
        batteryTemperatureTitle: "Hot battery",
        batteryTemperatureBodyFormat: "Battery reached %@."
    )

    static let ptBR = MonitorAlertFeatureStrings(
        section: "Alertas",
        caption: "Receba uma notificação quando uma leitura passar do limite. Picos de CPU com menos de 12 segundos não contam.",
        notificationsDenied: "As notificações do Lattice estão desativadas nos Ajustes do Sistema, então os alertas não aparecem.",
        cpu: "Uso da CPU",
        cpuTemperature: "Temperatura da CPU",
        memory: "Pressão de memória crítica",
        disk: "Espaço livre em disco",
        battery: "Nível da bateria",
        cooldown: "Repetir após",
        aboveFormat: "Acima de %@",
        belowFormat: "Abaixo de %@",
        cooldown2: "2 minutos",
        cooldown5: "5 minutos",
        cooldown15: "15 minutos",
        cooldown30: "30 minutos",
        cooldown60: "1 hora",
        cpuTitle: "CPU alta",
        cpuBodyFormat: "A CPU ficou acima de %d%% por alguns segundos.",
        cpuTemperatureTitle: "CPU quente",
        cpuTemperatureBodyFormat: "A CPU chegou a %@.",
        memoryTitle: "Memória crítica",
        memoryBody: "A pressão de memória chegou ao nível crítico.",
        diskTitle: "Pouco espaço em disco",
        diskBodyFormat: "%@ está com menos de %d%% livre.",
        batteryTitle: "Bateria baixa",
        batteryBodyFormat: "A bateria está em %d%%.",
        batteryTemperature: "Temperatura da bateria",
        batteryTemperatureTitle: "Bateria quente",
        batteryTemperatureBodyFormat: "A bateria chegou a %@."
    )

    static let tr = MonitorAlertFeatureStrings(
        section: "Uyarılar",
        caption: "Bir değer sınırını aştığında bildirim alın. 12 saniyeden kısa CPU sıçramaları sayılmaz.",
        notificationsDenied: "Sistem Ayarları’nda Lattice bildirimleri kapalı, bu yüzden uyarılar görünemez.",
        cpu: "CPU kullanımı",
        cpuTemperature: "CPU sıcaklığı",
        memory: "Kritik bellek basıncı",
        disk: "Boş disk alanı",
        battery: "Pil düzeyi",
        cooldown: "Tekrarlama süresi",
        aboveFormat: "%@ üstü",
        belowFormat: "%@ altı",
        cooldown2: "2 dakika",
        cooldown5: "5 dakika",
        cooldown15: "15 dakika",
        cooldown30: "30 dakika",
        cooldown60: "1 saat",
        cpuTitle: "Yüksek CPU",
        cpuBodyFormat: "CPU birkaç saniye boyunca %d%% üzerinde kaldı.",
        cpuTemperatureTitle: "CPU sıcak",
        cpuTemperatureBodyFormat: "CPU %@ değerine ulaştı.",
        memoryTitle: "Kritik bellek",
        memoryBody: "Bellek basıncı kritik seviyeye ulaştı.",
        diskTitle: "Düşük disk alanı",
        diskBodyFormat: "%@ diskinde %d%% altında boş alan var.",
        batteryTitle: "Düşük pil",
        batteryBodyFormat: "Pil %d%% seviyesinde.",
        batteryTemperature: "Pil sıcaklığı",
        batteryTemperatureTitle: "Pil sıcak",
        batteryTemperatureBodyFormat: "Pil %@ değerine ulaştı."
    )

    static let ru = MonitorAlertFeatureStrings(
        section: "Оповещения",
        caption: "Получайте уведомление, когда показатель выходит за предел. Всплески загрузки процессора короче 12 секунд не учитываются.",
        notificationsDenied: "Уведомления Lattice выключены в Системных настройках, поэтому оповещения не появятся.",
        cpu: "Загрузка процессора",
        cpuTemperature: "Температура процессора",
        memory: "Критическое давление памяти",
        disk: "Свободное место на диске",
        battery: "Уровень заряда",
        cooldown: "Повторять через",
        aboveFormat: "Выше %@",
        belowFormat: "Ниже %@",
        cooldown2: "2 минуты",
        cooldown5: "5 минут",
        cooldown15: "15 минут",
        cooldown30: "30 минут",
        cooldown60: "1 час",
        cpuTitle: "Высокая нагрузка CPU",
        cpuBodyFormat: "CPU держался выше %d%% несколько секунд.",
        cpuTemperatureTitle: "CPU перегрет",
        cpuTemperatureBodyFormat: "CPU достиг %@.",
        memoryTitle: "Критическая память",
        memoryBody: "Давление памяти достигло критического уровня.",
        diskTitle: "Мало места на диске",
        diskBodyFormat: "На %@ осталось меньше %d%% свободного места.",
        batteryTitle: "Низкий заряд батареи",
        batteryBodyFormat: "Заряд батареи: %d%%.",
        batteryTemperature: "Температура аккумулятора",
        batteryTemperatureTitle: "Батарея перегрета",
        batteryTemperatureBodyFormat: "Батарея достигла %@."
    )

    static let es = MonitorAlertFeatureStrings(
        section: "Alertas",
        caption: "Recibe una notificación cuando una lectura supere su límite. Los picos de CPU de menos de 12 segundos no cuentan.",
        notificationsDenied: "Las notificaciones de Lattice están desactivadas en Ajustes del Sistema, así que las alertas no aparecen.",
        cpu: "Uso de CPU",
        cpuTemperature: "Temperatura de la CPU",
        memory: "Presión de memoria crítica",
        disk: "Espacio libre en disco",
        battery: "Nivel de batería",
        cooldown: "Repetir tras",
        aboveFormat: "Por encima de %@",
        belowFormat: "Por debajo de %@",
        cooldown2: "2 minutos",
        cooldown5: "5 minutos",
        cooldown15: "15 minutos",
        cooldown30: "30 minutos",
        cooldown60: "1 hora",
        cpuTitle: "CPU alta",
        cpuBodyFormat: "La CPU estuvo por encima de %d%% durante unos segundos.",
        cpuTemperatureTitle: "CPU caliente",
        cpuTemperatureBodyFormat: "La CPU llegó a %@.",
        memoryTitle: "Memoria crítica",
        memoryBody: "La presión de memoria llegó al nivel crítico.",
        diskTitle: "Poco espacio en disco",
        diskBodyFormat: "%@ tiene menos de %d%% libre.",
        batteryTitle: "Batería baja",
        batteryBodyFormat: "La batería está al %d%%.",
        batteryTemperature: "Temperatura de la batería",
        batteryTemperatureTitle: "Batería caliente",
        batteryTemperatureBodyFormat: "La batería llegó a %@."
    )

    static let sk = MonitorAlertFeatureStrings(
        section: "Hlásenia",
        caption: "Dostanete upozornenie, keď hodnota prekročí limit. Špičky procesora kratšie ako 12 sekúnd sa nerátajú.",
        notificationsDenied: "Hlásenia pre Lattice sú vypnuté v Systémových nastaveniach, takže sa nemôžu zobraziť.",
        cpu: "Využitie procesora",
        cpuTemperature: "Teplota procesora",
        memory: "Kritický tlak na pamäť",
        disk: "Voľné miesto na disku",
        battery: "Úroveň batérie",
        cooldown: "Opakovať po",
        aboveFormat: "Nad %@",
        belowFormat: "Pod %@",
        cooldown2: "2 minúty",
        cooldown5: "5 minút",
        cooldown15: "15 minút",
        cooldown30: "30 minút",
        cooldown60: "1 hodina",
        cpuTitle: "Vysoké vyťaženie CPU",
        cpuBodyFormat: "Využitie CPU bolo niekoľko sekúnd nad %d%%.",
        cpuTemperatureTitle: "Horúce CPU",
        cpuTemperatureBodyFormat: "CPU dosiahlo %@.",
        memoryTitle: "Kritická pamäť",
        memoryBody: "Tlak na pamäť dosiahol kritickú úroveň.",
        diskTitle: "Málo miesta na disku",
        diskBodyFormat: "%@ má menej ako %d%% voľného miesta.",
        batteryTitle: "Nízka batéria",
        batteryBodyFormat: "Batéria je na %d%%.",
        batteryTemperature: "Teplota batérie",
        batteryTemperatureTitle: "Horúca batéria",
        batteryTemperatureBodyFormat: "Batéria dosiahla %@."
    )

    static let de = MonitorAlertFeatureStrings(
        section: "Warnungen",
        caption: "Erhalte eine Mitteilung, wenn ein Wert sein Limit überschreitet. CPU-Spitzen unter 12 Sekunden zählen nicht.",
        notificationsDenied: "Mitteilungen für Lattice sind in den Systemeinstellungen aus, daher können keine Warnungen erscheinen.",
        cpu: "CPU-Auslastung",
        cpuTemperature: "CPU-Temperatur",
        memory: "Kritischer Speicherdruck",
        disk: "Freier Speicherplatz",
        battery: "Batteriestand",
        cooldown: "Wiederholen nach",
        aboveFormat: "Über %@",
        belowFormat: "Unter %@",
        cooldown2: "2 Minuten",
        cooldown5: "5 Minuten",
        cooldown15: "15 Minuten",
        cooldown30: "30 Minuten",
        cooldown60: "1 Stunde",
        cpuTitle: "Hohe CPU",
        cpuBodyFormat: "Die CPU lag einige Sekunden über %d%%.",
        cpuTemperatureTitle: "Heiße CPU",
        cpuTemperatureBodyFormat: "Die CPU hat %@ erreicht.",
        memoryTitle: "Kritischer Speicher",
        memoryBody: "Der Speicherdruck hat den kritischen Wert erreicht.",
        diskTitle: "Wenig Speicherplatz",
        diskBodyFormat: "%@ hat weniger als %d%% frei.",
        batteryTitle: "Niedriger Akkustand",
        batteryBodyFormat: "Der Akku ist bei %d%%.",
        batteryTemperature: "Batterietemperatur",
        batteryTemperatureTitle: "Heißer Akku",
        batteryTemperatureBodyFormat: "Der Akku hat %@ erreicht."
    )

    static let fr = MonitorAlertFeatureStrings(
        section: "Alertes",
        caption: "Recevez une notification quand une mesure dépasse sa limite. Les pics de processeur de moins de 12 secondes ne comptent pas.",
        notificationsDenied: "Les notifications de Lattice sont désactivées dans Réglages Système, les alertes ne peuvent donc pas apparaître.",
        cpu: "Utilisation du processeur",
        cpuTemperature: "Température du processeur",
        memory: "Pression mémoire critique",
        disk: "Espace disque libre",
        battery: "Niveau de batterie",
        cooldown: "Répéter après",
        aboveFormat: "Au-dessus de %@",
        belowFormat: "En dessous de %@",
        cooldown2: "2 minutes",
        cooldown5: "5 minutes",
        cooldown15: "15 minutes",
        cooldown30: "30 minutes",
        cooldown60: "1 heure",
        cpuTitle: "CPU élevé",
        cpuBodyFormat: "Le CPU est resté au-dessus de %d%% pendant quelques secondes.",
        cpuTemperatureTitle: "CPU chaud",
        cpuTemperatureBodyFormat: "Le CPU a atteint %@.",
        memoryTitle: "Mémoire critique",
        memoryBody: "La pression mémoire a atteint le niveau critique.",
        diskTitle: "Espace disque faible",
        diskBodyFormat: "%@ a moins de %d%% libre.",
        batteryTitle: "Batterie faible",
        batteryBodyFormat: "La batterie est à %d%%.",
        batteryTemperature: "Température de la batterie",
        batteryTemperatureTitle: "Batterie chaude",
        batteryTemperatureBodyFormat: "La batterie a atteint %@."
    )

    static let it = MonitorAlertFeatureStrings(
        section: "Avvisi",
        caption: "Ricevi una notifica quando un valore supera il limite. I picchi di CPU sotto i 12 secondi non contano.",
        notificationsDenied: "Le notifiche di Lattice sono disattivate in Impostazioni di Sistema, quindi gli avvisi non compaiono.",
        cpu: "Uso CPU",
        cpuTemperature: "Temperatura CPU",
        memory: "Pressione memoria critica",
        disk: "Spazio libero su disco",
        battery: "Livello batteria",
        cooldown: "Ripeti dopo",
        aboveFormat: "Sopra %@",
        belowFormat: "Sotto %@",
        cooldown2: "2 minuti",
        cooldown5: "5 minuti",
        cooldown15: "15 minuti",
        cooldown30: "30 minuti",
        cooldown60: "1 ora",
        cpuTitle: "CPU alta",
        cpuBodyFormat: "La CPU è rimasta sopra %d%% per alcuni secondi.",
        cpuTemperatureTitle: "CPU calda",
        cpuTemperatureBodyFormat: "La CPU ha raggiunto %@.",
        memoryTitle: "Memoria critica",
        memoryBody: "La pressione della memoria ha raggiunto il livello critico.",
        diskTitle: "Poco spazio su disco",
        diskBodyFormat: "%@ ha meno del %d%% libero.",
        batteryTitle: "Batteria scarica",
        batteryBodyFormat: "La batteria è al %d%%.",
        batteryTemperature: "Temperatura batteria",
        batteryTemperatureTitle: "Batteria calda",
        batteryTemperatureBodyFormat: "La batteria ha raggiunto %@."
    )

    static let ja = MonitorAlertFeatureStrings(
        section: "アラート",
        caption: "値が上限を超えると通知します。12秒未満のCPUの急上昇は対象外です。",
        notificationsDenied: "システム設定でLatticeの通知がオフのため、アラートは表示されません。",
        cpu: "CPU使用率",
        cpuTemperature: "CPU温度",
        memory: "メモリ圧迫が深刻",
        disk: "ディスクの空き容量",
        battery: "バッテリー残量",
        cooldown: "再通知までの間隔",
        aboveFormat: "%@超",
        belowFormat: "%@未満",
        cooldown2: "2 分",
        cooldown5: "5 分",
        cooldown15: "15 分",
        cooldown30: "30 分",
        cooldown60: "1 時間",
        cpuTitle: "CPU 高負荷",
        cpuBodyFormat: "CPU が数秒間 %d%% を超えました。",
        cpuTemperatureTitle: "CPU が高温",
        cpuTemperatureBodyFormat: "CPU が %@ に達しました。",
        memoryTitle: "メモリが深刻",
        memoryBody: "メモリ圧迫が深刻レベルに達しました。",
        diskTitle: "ディスク空き容量不足",
        diskBodyFormat: "%@ の空き容量が %d%% 未満です。",
        batteryTitle: "バッテリー残量低下",
        batteryBodyFormat: "バッテリー残量は %d%% です。",
        batteryTemperature: "バッテリー温度",
        batteryTemperatureTitle: "バッテリーが高温",
        batteryTemperatureBodyFormat: "バッテリーが %@ に達しました。"
    )

    static let zhHans = MonitorAlertFeatureStrings(
        section: "提醒",
        caption: "读数超过限值时发送通知。短于 12 秒的 CPU 峰值不计入。",
        notificationsDenied: "Lattice 的通知已在系统设置中关闭，警报无法显示。",
        cpu: "CPU 使用率",
        cpuTemperature: "CPU 温度",
        memory: "内存压力严重",
        disk: "可用磁盘空间",
        battery: "电池电量",
        cooldown: "重复间隔",
        aboveFormat: "高于 %@",
        belowFormat: "低于 %@",
        cooldown2: "2 分钟",
        cooldown5: "5 分钟",
        cooldown15: "15 分钟",
        cooldown30: "30 分钟",
        cooldown60: "1 小时",
        cpuTitle: "CPU 过高",
        cpuBodyFormat: "CPU 已连续几秒高于 %d%%。",
        cpuTemperatureTitle: "CPU 过热",
        cpuTemperatureBodyFormat: "CPU 已达到 %@。",
        memoryTitle: "内存严重",
        memoryBody: "内存压力已达到严重级别。",
        diskTitle: "磁盘空间不足",
        diskBodyFormat: "%@ 的可用空间低于 %d%%。",
        batteryTitle: "电池电量低",
        batteryBodyFormat: "电池电量为 %d%%。",
        batteryTemperature: "电池温度",
        batteryTemperatureTitle: "电池过热",
        batteryTemperatureBodyFormat: "电池已达到 %@。"
    )

    static let zhTW = MonitorAlertFeatureStrings(
        section: "提醒",
        caption: "讀數超過限值時傳送通知。短於 12 秒的 CPU 峰值不計入。",
        notificationsDenied: "Lattice 的通知已在系統設定中關閉，警示無法顯示。",
        cpu: "CPU 使用率",
        cpuTemperature: "CPU 溫度",
        memory: "記憶體壓力過高",
        disk: "可用磁碟空間",
        battery: "電池電量",
        cooldown: "重複間隔",
        aboveFormat: "高於 %@",
        belowFormat: "低於 %@",
        cooldown2: "2 分鐘",
        cooldown5: "5 分鐘",
        cooldown15: "15 分鐘",
        cooldown30: "30 分鐘",
        cooldown60: "1 小時",
        cpuTitle: "CPU 使用率過高",
        cpuBodyFormat: "CPU 已連續數秒高於 %d%%。",
        cpuTemperatureTitle: "CPU 過熱",
        cpuTemperatureBodyFormat: "CPU 已達到 %@。",
        memoryTitle: "記憶體壓力過高",
        memoryBody: "記憶體壓力已達到嚴重等級。",
        diskTitle: "磁碟空間不足",
        diskBodyFormat: "%@ 的可用空間低於 %d%%。",
        batteryTitle: "電池電量偏低",
        batteryBodyFormat: "電池電量為 %d%%。",
        batteryTemperature: "電池溫度",
        batteryTemperatureTitle: "電池過熱",
        batteryTemperatureBodyFormat: "電池已達到 %@。"
    )

    static let zhHK = MonitorAlertFeatureStrings(
        section: "提示",
        caption: "讀數超過限值時傳送通知。短於 12 秒的 CPU 峰值不計入。",
        notificationsDenied: "Lattice 的通知已在系統設定中關閉，警示無法顯示。",
        cpu: "CPU 使用率",
        cpuTemperature: "CPU 溫度",
        memory: "記憶體壓力過高",
        disk: "可用磁碟空間",
        battery: "電池電量",
        cooldown: "重複間隔",
        aboveFormat: "高於 %@",
        belowFormat: "低於 %@",
        cooldown2: "2 分鐘",
        cooldown5: "5 分鐘",
        cooldown15: "15 分鐘",
        cooldown30: "30 分鐘",
        cooldown60: "1 小時",
        cpuTitle: "CPU 使用率過高",
        cpuBodyFormat: "CPU 已連續數秒高於 %d%%。",
        cpuTemperatureTitle: "CPU 過熱",
        cpuTemperatureBodyFormat: "CPU 已達到 %@。",
        memoryTitle: "記憶體壓力過高",
        memoryBody: "記憶體壓力已達至嚴重水平。",
        diskTitle: "磁碟空間不足",
        diskBodyFormat: "%@ 的可用空間低於 %d%%。",
        batteryTitle: "電池電量偏低",
        batteryBodyFormat: "電池電量為 %d%%。",
        batteryTemperature: "電池溫度",
        batteryTemperatureTitle: "電池過熱",
        batteryTemperatureBodyFormat: "電池已達到 %@。"
    )
}

extension SettingsCategoryStrings {
    static let uk = SettingsCategoryStrings(
        interface: "Інтерфейс",
        windowsDock: "Робочий стіл & екран",
        audio: "Аудіо",
        energyDisplay: "Керування пристроями",
        screenCaptures: "Знімки Екрана",
        mouseKeyboard: "Миша & клавіатура",
        clipboardFiles: "Буфер обміну & файли",
        system: "Система",
        lattice: "Lattice",
        utilities: "Утиліти"
    )
}

extension ClipboardFeatureStrings {
    static let uk = ClipboardFeatureStrings(
        title: "Буфер обміну",
        enable: "Зберігати історію буфера обміну",
        caption: "Зберігає скопійований текст, щоб ви могли використати його пізніше. Все залишається локальним і може бути очищене будь-коли.",
        localNote: "Все залишається на цьому Mac. Дуже великі елементи ігноруються.",
        skipSensitive: "Пропускати текст, схожий на конфіденційний",
        skipSensitiveCaption: "Може пропускати звичайний текст, схожий на паролі або токени. Вміст, позначений вихідною програмою як конфіденційний, завжди виключається.",
        limit: "Ліміт",
        limitUnlimited: "Без обмежень",
        showInPanel: "Показати в панелі",
        shortcut: "Клавіатурне скорочення історії",
        shortcutCaption: "Відкриває швидке вікно з пошуком, закріпленими елементами та клавіатурними скороченнями ⌘1–⌘9 для вставки в попередню програму.",
        clickRowShortcut: "Натисніть рядок",
        pinned: "Закріплено",
        recent: "Недавнє",
        pin: "Закріпити",
        unpin: "Відкріпити",
        clearRecent: "Очистити незакріплене",
        clearRecentKeywords: "Очистити недавні",
        empty: "Немає збереженого тексту",
        disabled: "Увімкніть історію, щоб почати зберігати скопійований текст.",
        search: "Шукати скопійований текст",
        copy: "Скопіювати",
        copied: "Скопійовано",
        delete: "Видалити елемент",
        selectMultiple: "Додати до стопки",
        unselectMultiple: "Видалити зі стопки",
        pasteSelectedFormat: "Вставити %d",
        copySelectedFormat: "Скопіювати %d",
        clearSelection: "Очистити вибір",
        moveUp: "Вгору",
        moveDown: "Вниз",
        noResults: "Немає результатів",
        active: "Збереження нового тексту",
        includeImagesFiles: "Також зберігати скопійовані зображення та файли",
        includeImagesFilesCaption: "Зображення потрапляють в історію, а файли запам’ятовуються як посилання на їхнє розташування. Закріплюйте та вставляйте їх як будь-який текстовий елемент.",
        imageEntryLabel: "Зображення",
        fileCountFormat: "Файлів: %d",
        previewLabel: "Попередній перегляд",
        edit: "Редагувати",
        cancel: "Скасувати",
        save: "Зберегти",
        autoClearEnable: "Автоочищення буфера з затримкою",
        autoClearSecondsSuffix: "с",
        autoClearOnSleep: "Очищати буфер при засинанні комп’ютера",
        autoClearOnDisplaySleep: "Очищати буфер при засинанні дисплея",
        autoClearOnScreenLock: "Очищати буфер при блокуванні екрана",
        autoClearCaption: "Очищає лише системний буфер обміну. Збережені елементи залишаються в історії.",
        deleteSelectedFormat: "Видалити %d",
        menuBarPreview: "Показувати останню копію на смузі меню",
        menuBarPreviewCaption: "Показує скорочений перегляд останнього скопійованого вмісту поруч зі значком. Натисніть, щоб відкрити історію.",
        menuBarPreviewLength: "Довжина перегляду",
        menuBarPreviewLengthSuffix: "симв.",
        clearRecentConfirmFormat: "Очистити незакріплене (%d)?",
        clearRecentConfirmMessage: "Закріплені залишаться, як і все, що скопійовано після цього. Скасувати не можна.",
        historyLayout: "Розкладка історії",
        historyLayoutCards: "Картки",
        historyLayoutList: "Список",
        showSourceAppIconsInList: "Показувати значки вихідних програм у списку"
    )
}

extension WindowLayoutFeatureStrings {
    static let uk = WindowLayoutFeatureStrings(
        title: "Керування вікнами",
        enable: "Увімкнути розташування вікон",
        caption: "Розставляйте вікна у розділи екрана або переміщуйте та змінюйте їхній розмір трекпедом або мишею.",
        showInPanel: "Показати в меню утиліт",
        gestureSection: "Розташування вікон",
        gestureEnable: "Переміщення та зміна розміру перетягуванням",
        gestureCaption: "На трекпеді або миші утримуйте показані клавіші-модифікатори та перетягуйте в будь-якому місці всередині вікна.",
        gestureModifiers: "Клавіші для переміщення",
        gestureMove: "Перетягніть для переміщення",
        gestureResize: "Додайте Shift та перетягуйте для зміни розміру",
        gestureResizeHint: "Стартова точка обирає найближчий край або кут. На миші перетягування правою кнопкою також змінює розмір.",
        gestureRaiseWindow: "Винести перетягуване вікно на передній план",
        shortcuts: "Клавіатурні скорочення",
        shortcutsCaption: "Використовуйте глобальні клавіатурні скорочення, щоб розташувати активне вікно без відкриття панелі.",
        permissionCaption: "Використовує дозвіл «Доступність» лише для переміщення та зміни розміру вікон.",
        noWindow: "Активне вікно не знайдено.",
        missingPermission: "Надайте дозвіл «Доступність», щоб переміщувати вікна.",
        failed: "Не вдалося перемістити це вікно.",
        done: "Вікно розташоване.",
        restored: "Вікно відновлено.",
        noRestore: "Немає попередньої розкладки для відновлення.",
        target: "Активне вікно",
        halves: "Розділення",
        thirds: "Третини",
        quarterRows: "Ряди по чверті",
        quarterColumns: "Стовпці по чверті",
        sixths: "Сітки",
        corners: "Кути",
        other: "Розмір та дії",
        moving: "Кілька екранів",
        leftHalf: "Ліворуч",
        rightHalf: "Праворуч",
        topHalf: "Вгорі",
        bottomHalf: "Внизу",
        centerHalf: "Центральна 1/2",
        leftThird: "Ліва 1/3",
        centerThird: "Центральна 1/3",
        rightThird: "Права 1/3",
        leftTwoThirds: "Ліва 2/3",
        rightTwoThirds: "Права 2/3",
        centerTwoThirds: "Центральні 2/3",
        topThird: "Верхня 1/3",
        middleThird: "Середня 1/3",
        bottomThird: "Нижня 1/3",
        topTwoThirds: "Верхні 2/3",
        bottomTwoThirds: "Нижні 2/3",
        topQuarter: "Верхня чверть",
        upperMiddleQuarter: "Верхня середня чверть",
        lowerMiddleQuarter: "Нижня середня чверть",
        bottomQuarter: "Нижня чверть",
        leftQuarter: "Ліва чверть",
        leftMiddleQuarter: "Ліва середня чверть",
        rightMiddleQuarter: "Права середня чверть",
        rightQuarter: "Права чверть",
        topLeftSixth: "Сітка вгорі ліворуч",
        topCenterSixth: "Сітка вгорі по центру",
        topRightSixth: "Сітка вгорі праворуч",
        bottomLeftSixth: "Сітка внизу ліворуч",
        bottomCenterSixth: "Сітка внизу по центру",
        bottomRightSixth: "Сітка внизу праворуч",
        topLeft: "Верхня ліва чверть",
        topRight: "Верхня права чверть",
        bottomLeft: "Нижня ліва чверть",
        bottomRight: "Нижня права чверть",
        maximize: "Розгорнути",
        center: "Центр",
        nextDisplay: "Перемістити вікно на наступний дисплей",
        restore: "Відновити",
        fullScreen: "На весь екран",
        previousDisplay: "Перемістити вікно на попередній дисплей",
        edgeSnapEnable: "Прилипати вікнами до країв екрана",
        edgeSnapSection: "Перетягувати вікна для прилипання",
        edgeSnapCaption: "Перетягніть вікно до краю або кута екрана, щоб закріпити його на місці.",
        edgeSnapSystemConflict: "macOS використовує ті самі краї. Вимкніть мозаїку вікон у розділі «Робочий стіл і Dock», щоб Lattice міг керувати ними.",
        edgeSnapOpenSystemSettings: "Відкрити «Робочий стіл і Dock»",
        edgeSnapWaitingForSystem: "Увімкнено в Lattice. Почне працювати, щойно мозаїку macOS буде вимкнено.",
        edgeSnapUseCorner: "Використовувати цей кут",
        edgeSnapUseEdge: "Використовувати цей край",
        edgeSnapAreasOnEdge: "Області на цьому краю",
        gapsSection: "Проміжки",
        gapsCaption: "Проміжок між прилиплими вікнами та між вікнами та краєм екрана.",
        windowGap: "Відступ між вікнами",
        screenGap: "Відступ від краю екрана",
        sideRepeatCycle: "Повтор «Ліворуч» або «Праворуч» змінює розмір",
        sideRepeatCycleCaption: "Половина, потім дві третини й третина на тому самому дисплеї. Якщо вимкнено й дисплеїв кілька, повтор переносить вікно на наступний дисплей із того боку.",
        gapNone: "Немає",
        gapTiny: "Крихітний",
        gapSmall: "Малий",
        gapMedium: "Середній",
        gapLarge: "Великий",
        gapExtraLarge: "Дуже великий"
    )
}

extension MonitorAlertFeatureStrings {
    static let uk = MonitorAlertFeatureStrings(
        section: "Сповіщення",
        caption: "Отримуйте сповіщення, коли показник виходить за межу. Сплески навантаження процесора коротші за 12 секунд не враховуються.",
        notificationsDenied: "Сповіщення Lattice вимкнено в Системних параметрах, тому вони не можуть з’являтися.",
        cpu: "Навантаження процесора",
        cpuTemperature: "Температура процесора",
        memory: "Критичний тиск пам’яті",
        disk: "Вільне місце на диску",
        battery: "Рівень заряду",
        cooldown: "Повторювати через",
        aboveFormat: "Вище %@",
        belowFormat: "Нижче %@",
        cooldown2: "2 хвилини",
        cooldown5: "5 хвилин",
        cooldown15: "15 хвилин",
        cooldown30: "30 хвилин",
        cooldown60: "1 годину",
        cpuTitle: "Високий CPU",
        cpuBodyFormat: "CPU тримався вище %d%% кілька секунд.",
        cpuTemperatureTitle: "Гарячий CPU",
        cpuTemperatureBodyFormat: "CPU досяг %@.",
        memoryTitle: "Критична пам’ять",
        memoryBody: "Тиск пам’яті досяг критичного рівня.",
        diskTitle: "Мало місця на диску",
        diskBodyFormat: "На %@ залишилося менше %d%%.",
        batteryTitle: "Низький заряд акумулятора",
        batteryBodyFormat: "Заряд акумулятора становить %d%%.",
        batteryTemperature: "Температура акумулятора",
        batteryTemperatureTitle: "Гарячий акумулятор",
        batteryTemperatureBodyFormat: "Акумулятор нагрівся до %@."
    )
}

extension MixerFeatureStrings {
    static let uk = MixerFeatureStrings(
        hideInactiveApps: "Приховувати неактивні програми",
        pin: "Закріпити вгорі",
        unpin: "Відкріпити",
        moveUp: "Вгору",
        moveDown: "Вниз",
        pinFirst: "Закріпити на початку",
        moveLeft: "Перемістити ліворуч",
        moveRight: "Перемістити праворуч",
        arrange: "Утримуйте Command і перетягуйте, щоб змінити порядок",
        actions: "Дії"
    )
}
