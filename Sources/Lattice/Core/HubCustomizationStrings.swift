// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

struct HubCustomizationStrings {
    let tools: String
    let toolsMenu: String
    let manageTools: String
    let openSettings: String
    let availableTools: String
    let dropToHide: String
    let dragToHide: String
    let hideFromHub: String
    let dragHint: String
    let allHidden: String
    let noneAvailable: String
    let chooseTools: String
    let enableTools: String
}

extension FeatureStrings {
    static func hubCustomization(_ language: AppLanguage) -> HubCustomizationStrings {
        switch language {
        case .enUS: return HubCustomizationStrings(
            tools: "Tools", toolsMenu: "Tools menu", manageTools: "Manage Tools", openSettings: "Open Settings",
            availableTools: "Hidden", dropToHide: "Drop to hide from Hub", dragToHide: "Drag tools here to hide",
            hideFromHub: "Hide from Hub", dragHint: "Drag to reorder or hide",
            allHidden: "All tools are hidden", noneAvailable: "No tools are available",
            chooseTools: "Choose which tools to show here.", enableTools: "Enable tools in Settings to use them here.")
        case .ptBR: return HubCustomizationStrings(
            tools: "Ferramentas", toolsMenu: "Menu de ferramentas", manageTools: "Gerenciar ferramentas", openSettings: "Abrir Ajustes",
            availableTools: "Oculto", dropToHide: "Solte para ocultar do Hub", dragToHide: "Arraste ferramentas aqui para ocultar",
            hideFromHub: "Ocultar do Hub", dragHint: "Arraste para reordenar ou ocultar",
            allHidden: "Todas as ferramentas estão ocultas", noneAvailable: "Nenhuma ferramenta disponível",
            chooseTools: "Escolha quais ferramentas mostrar aqui.", enableTools: "Ative ferramentas nos Ajustes para usá-las aqui.")
        case .es: return HubCustomizationStrings(
            tools: "Herramientas", toolsMenu: "Menú de herramientas", manageTools: "Gestionar herramientas", openSettings: "Abrir Ajustes",
            availableTools: "Oculto", dropToHide: "Suelta para ocultar del Hub", dragToHide: "Arrastra herramientas aquí para ocultarlas",
            hideFromHub: "Ocultar del Hub", dragHint: "Arrastra para reordenar u ocultar",
            allHidden: "Todas las herramientas están ocultas", noneAvailable: "No hay herramientas disponibles",
            chooseTools: "Elige qué herramientas mostrar aquí.", enableTools: "Activa herramientas en Ajustes para usarlas aquí.")
        case .fr: return HubCustomizationStrings(
            tools: "Outils", toolsMenu: "Menu des outils", manageTools: "Gérer les outils", openSettings: "Ouvrir les réglages",
            availableTools: "Masqué", dropToHide: "Déposer pour masquer dans le Hub", dragToHide: "Glissez les outils ici pour les masquer",
            hideFromHub: "Masquer dans le Hub", dragHint: "Glissez pour réorganiser ou masquer",
            allHidden: "Tous les outils sont masqués", noneAvailable: "Aucun outil disponible",
            chooseTools: "Choisissez les outils à afficher ici.", enableTools: "Activez des outils dans les réglages pour les utiliser ici.")
        case .de: return HubCustomizationStrings(
            tools: "Werkzeuge", toolsMenu: "Werkzeugmenü", manageTools: "Werkzeuge verwalten", openSettings: "Einstellungen öffnen",
            availableTools: "Ausgeblendet", dropToHide: "Ablegen, um im Hub auszublenden", dragToHide: "Werkzeuge zum Ausblenden hierher ziehen",
            hideFromHub: "Im Hub ausblenden", dragHint: "Zum Anordnen oder Ausblenden ziehen",
            allHidden: "Alle Werkzeuge sind ausgeblendet", noneAvailable: "Keine Werkzeuge verfügbar",
            chooseTools: "Wähle die Werkzeuge aus, die hier erscheinen sollen.", enableTools: "Aktiviere Werkzeuge in den Einstellungen, um sie hier zu verwenden.")
        case .it: return HubCustomizationStrings(
            tools: "Strumenti", toolsMenu: "Menu degli strumenti", manageTools: "Gestisci strumenti", openSettings: "Apri Impostazioni",
            availableTools: "Nascosto", dropToHide: "Rilascia per nascondere dall’Hub", dragToHide: "Trascina qui gli strumenti per nasconderli",
            hideFromHub: "Nascondi dall’Hub", dragHint: "Trascina per riordinare o nascondere",
            allHidden: "Tutti gli strumenti sono nascosti", noneAvailable: "Nessuno strumento disponibile",
            chooseTools: "Scegli quali strumenti mostrare qui.", enableTools: "Attiva gli strumenti in Impostazioni per usarli qui.")
        case .ja: return HubCustomizationStrings(
            tools: "ツール", toolsMenu: "ツールメニュー", manageTools: "ツールを管理", openSettings: "設定を開く",
            availableTools: "非表示", dropToHide: "ドロップしてHubから非表示", dragToHide: "非表示にするツールをここにドラッグ",
            hideFromHub: "Hubから非表示", dragHint: "ドラッグして並べ替え・非表示",
            allHidden: "すべてのツールが非表示です", noneAvailable: "利用可能なツールがありません",
            chooseTools: "ここに表示するツールを選んでください。", enableTools: "設定でツールを有効にすると、ここで使えます。")
        case .ko: return HubCustomizationStrings(
            tools: "도구", toolsMenu: "도구 메뉴", manageTools: "도구 관리", openSettings: "설정 열기",
            availableTools: "숨김", dropToHide: "놓아서 Hub에서 숨기기", dragToHide: "숨길 도구를 여기로 드래그하세요",
            hideFromHub: "Hub에서 숨기기", dragHint: "드래그하여 순서를 바꾸거나 숨기기",
            allHidden: "모든 도구가 숨겨져 있습니다", noneAvailable: "사용 가능한 도구가 없습니다",
            chooseTools: "여기에 표시할 도구를 선택하세요.", enableTools: "설정에서 도구를 활성화하면 여기서 사용할 수 있습니다.")
        case .zhHans: return HubCustomizationStrings(
            tools: "工具", toolsMenu: "工具菜单", manageTools: "管理工具", openSettings: "打开设置",
            availableTools: "隐藏", dropToHide: "放开以从 Hub 隐藏", dragToHide: "将工具拖到此处以隐藏",
            hideFromHub: "从 Hub 隐藏", dragHint: "拖动以重新排序或隐藏",
            allHidden: "所有工具均已隐藏", noneAvailable: "没有可用工具",
            chooseTools: "选择要在此处显示的工具。", enableTools: "在设置中启用工具后，即可在此处使用。")
        case .zhTW: return HubCustomizationStrings(
            tools: "工具", toolsMenu: "工具選單", manageTools: "管理工具", openSettings: "開啟設定",
            availableTools: "隱藏", dropToHide: "放開以從 Hub 隱藏", dragToHide: "將工具拖曳至此處以隱藏",
            hideFromHub: "從 Hub 隱藏", dragHint: "拖曳以重新排序或隱藏",
            allHidden: "所有工具均已隱藏", noneAvailable: "沒有可用工具",
            chooseTools: "選擇要在此處顯示的工具。", enableTools: "在設定中啟用工具後，即可在此處使用。")
        case .zhHK: return HubCustomizationStrings(
            tools: "工具", toolsMenu: "工具選單", manageTools: "管理工具", openSettings: "開啟設定",
            availableTools: "隱藏", dropToHide: "放開以從 Hub 隱藏", dragToHide: "將工具拖到此處以隱藏",
            hideFromHub: "從 Hub 隱藏", dragHint: "拖動以重新排序或隱藏",
            allHidden: "所有工具均已隱藏", noneAvailable: "沒有可用工具",
            chooseTools: "選擇要在此處顯示的工具。", enableTools: "在設定中啟用工具後，即可在此處使用。")
        case .ru: return HubCustomizationStrings(
            tools: "Инструменты", toolsMenu: "Меню инструментов", manageTools: "Управление инструментами", openSettings: "Открыть настройки",
            availableTools: "Скрыто", dropToHide: "Отпустите, чтобы скрыть из Hub", dragToHide: "Перетащите инструменты сюда, чтобы скрыть",
            hideFromHub: "Скрыть из Hub", dragHint: "Перетащите для изменения порядка или скрытия",
            allHidden: "Все инструменты скрыты", noneAvailable: "Нет доступных инструментов",
            chooseTools: "Выберите инструменты для отображения здесь.", enableTools: "Включите инструменты в настройках, чтобы использовать их здесь.")
        case .sk: return HubCustomizationStrings(
            tools: "Nástroje", toolsMenu: "Ponuka nástrojov", manageTools: "Spravovať nástroje", openSettings: "Otvoriť nastavenia",
            availableTools: "Skryté", dropToHide: "Pustením skryjete z Hubu", dragToHide: "Nástroje skryjete potiahnutím sem",
            hideFromHub: "Skryť z Hubu", dragHint: "Potiahnutím zmeňte poradie alebo skryte",
            allHidden: "Všetky nástroje sú skryté", noneAvailable: "Nie sú dostupné žiadne nástroje",
            chooseTools: "Vyberte nástroje, ktoré sa tu zobrazia.", enableTools: "Ak chcete nástroje používať tu, zapnite ich v nastaveniach.")
        case .tr: return HubCustomizationStrings(
            tools: "Araçlar", toolsMenu: "Araçlar menüsü", manageTools: "Araçları yönet", openSettings: "Ayarları aç",
            availableTools: "Gizli", dropToHide: "Hub’dan gizlemek için bırakın", dragToHide: "Gizlemek için araçları buraya sürükleyin",
            hideFromHub: "Hub’dan gizle", dragHint: "Sıralamak veya gizlemek için sürükleyin",
            allHidden: "Tüm araçlar gizli", noneAvailable: "Kullanılabilir araç yok",
            chooseTools: "Burada gösterilecek araçları seçin.", enableTools: "Burada kullanmak için Ayarlar’dan araçları etkinleştirin.")
        case .uk: return HubCustomizationStrings(
            tools: "Інструменти", toolsMenu: "Меню інструментів", manageTools: "Керувати інструментами", openSettings: "Відкрити параметри",
            availableTools: "Приховано", dropToHide: "Відпустіть, щоб приховати з Hub", dragToHide: "Перетягніть інструменти сюди, щоб приховати",
            hideFromHub: "Приховати з Hub", dragHint: "Перетягніть, щоб змінити порядок або приховати",
            allHidden: "Усі інструменти приховано", noneAvailable: "Немає доступних інструментів",
            chooseTools: "Виберіть інструменти для показу тут.", enableTools: "Увімкніть інструменти в параметрах, щоб використовувати їх тут.")
        }
    }
}
