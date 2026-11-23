import Foundation

enum InputSettingsStrings {
    /// The middle-click gesture's follow-up rows.
    struct MiddleClick {
        let clickWith: String
        let ignoredApps: String
        let configure: String
        /// Under a picker whose three-finger choice macOS is using.
        let tapTaken: String
        let clickTaken: String
        /// While the Radial Menu holds the four-finger gesture.
        var tapTakenByRadial = ""
        var clickTakenByRadial = ""
        var clickUnavailable = ""
        var clickUnavailableNote = ""
        var openRadialMenu = ""
        /// One, a few (Russian, Ukrainian and Slovak only) and many apps.
        let oneApp: String
        var fewApps: String? = nil
        let manyApps: String
        var agreement: CountAgreement = .oneAndMany

        func appCount(_ count: Int) -> String {
            let format: String
            switch agreement {
            case .oneAndMany:
                format = count == 1 ? oneApp : manyApps
            case .byWholeNumber:
                format = count == 1 ? oneApp : (2...4).contains(count) ? (fewApps ?? manyApps) : manyApps
            case .byLastDigits:
                if (11...14).contains(count % 100) { format = manyApps }
                else if count % 10 == 1 { format = oneApp }
                else if (2...4).contains(count % 10) { format = fewApps ?? manyApps }
                else { format = manyApps }
            }
            return String(format: format, count)
        }
    }

    /// Focus follows mouse's exception list names what it does, not the
    /// generic "Disable in these apps".
    static func focusFollowsMouseExceptionsTitle(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Don’t focus on these apps"
        case .ptBR: return "Não focar nestes apps"
        case .tr: return "Bu uygulamalara odaklanma"
        case .ru: return "Не фокусировать эти приложения"
        case .es: return "No enfocar estas apps"
        case .sk: return "Nezameriavať tieto aplikácie"
        case .de: return "Diese Apps nicht fokussieren"
        case .fr: return "Ne pas activer ces apps"
        case .it: return "Non attivare queste app"
        case .ja: return "これらのAppにはフォーカスしない"
        case .ko: return "이 앱들에는 포커스하지 않기"
        case .zhHans: return "不聚焦这些 App"
        case .zhTW, .zhHK: return "不聚焦這些 App"
        case .uk: return "Не фокусувати ці програми"
        }
    }

    /// Focus follows mouse's hover delays, shortest first: Instant, Default,
    /// Longer, Longest.
    static func hoverDelayNames(_ language: AppLanguage) -> [String] {
        switch language {
        case .enUS: return ["Instant", "Default", "Longer", "Longest"]
        case .ptBR: return ["Instantâneo", "Padrão", "Mais longo", "O mais longo"]
        case .tr: return ["Anında", "Varsayılan", "Daha uzun", "En uzun"]
        case .ru: return ["Мгновенно", "По умолчанию", "Дольше", "Максимально"]
        case .es: return ["Instantáneo", "Predeterminado", "Más largo", "El más largo"]
        case .sk: return ["Okamžite", "Predvolené", "Dlhšie", "Najdlhšie"]
        case .de: return ["Sofort", "Standard", "Länger", "Am längsten"]
        case .fr: return ["Instantané", "Par défaut", "Plus long", "Le plus long"]
        case .it: return ["Immediato", "Predefinito", "Più lungo", "Il più lungo"]
        case .ja: return ["すぐに", "デフォルト", "長め", "最長"]
        case .ko: return ["즉시", "기본", "길게", "가장 길게"]
        case .zhHans: return ["立即", "默认", "较长", "最长"]
        case .zhTW, .zhHK: return ["立即", "預設", "較長", "最長"]
        case .uk: return ["Миттєво", "Типово", "Довше", "Найдовше"]
        }
    }

    static func middleClick(_ language: AppLanguage) -> MiddleClick {
        var strings = middleClickBase(language)
        let radial = middleClickRadial(language)
        strings.tapTakenByRadial = radial[0]
        strings.clickTakenByRadial = radial[1]
        strings.clickUnavailable = radial[2]
        strings.clickUnavailableNote = radial[3]
        strings.openRadialMenu = radial[4]
        return strings
    }

    /// Tap taken, click taken, click unavailable, its note, and the button
    /// that opens the Radial Menu page.
    private static func middleClickRadial(_ language: AppLanguage) -> [String] {
        switch language {
        case .enUS: return ["4-finger tap is used by the Radial Menu.", "4-finger click is used by the Radial Menu.", "Not available", "The Radial Menu uses four fingers and macOS three-finger drag uses three.", "Open Radial Menu"]
        case .ptBR: return ["O toque com 4 dedos está em uso pelo menu radial.", "O clique com 4 dedos está em uso pelo menu radial.", "Indisponível", "O menu radial usa quatro dedos e o arrastar com três dedos do macOS usa três.", "Abrir menu radial"]
        case .es: return ["El menú radial usa el toque con 4 dedos.", "El menú radial usa el clic con 4 dedos.", "No disponible", "El menú radial usa cuatro dedos y el arrastre con tres dedos de macOS usa tres.", "Abrir menú radial"]
        case .de: return ["Tippen mit 4 Fingern wird vom Radialmenü verwendet.", "Klicken mit 4 Fingern wird vom Radialmenü verwendet.", "Nicht verfügbar", "Das Radialmenü nutzt vier Finger und das Dreifingerziehen in macOS drei.", "Radialmenü öffnen"]
        case .fr: return ["Le toucher à 4 doigts est utilisé par le menu radial.", "Le clic à 4 doigts est utilisé par le menu radial.", "Indisponible", "Le menu radial utilise quatre doigts et le glissement à trois doigts de macOS en utilise trois.", "Ouvrir le menu radial"]
        case .it: return ["Il tocco con 4 dita è usato dal menu radiale.", "Il clic con 4 dita è usato dal menu radiale.", "Non disponibile", "Il menu radiale usa quattro dita e il trascinamento con tre dita di macOS ne usa tre.", "Apri menu radiale"]
        case .ja: return ["4本指のタップはラジアルメニューで使用されています。", "4本指のクリックはラジアルメニューで使用されています。", "使用不可", "ラジアルメニューが4本指を、macOSの3本指ドラッグが3本指を使用しています。", "ラジアルメニューを開く"]
        case .ko: return ["네 손가락 탭은 방사형 메뉴에서 사용 중입니다.", "네 손가락 클릭은 방사형 메뉴에서 사용 중입니다.", "사용할 수 없음", "방사형 메뉴가 네 손가락을, macOS 세 손가락 드래그가 세 손가락을 사용합니다.", "방사형 메뉴 열기"]
        case .zhHans: return ["四指轻点由径向菜单使用。", "四指点按由径向菜单使用。", "不可用", "径向菜单使用四指，macOS 三指拖移使用三指。", "打开径向菜单"]
        case .zhTW: return ["四指點一下由放射狀選單使用。", "四指按一下由放射狀選單使用。", "無法使用", "放射狀選單使用四指，macOS 三指拖移使用三指。", "打開放射狀選單"]
        case .zhHK: return ["四指輕點由放射狀選單使用。", "四指點按由放射狀選單使用。", "無法使用", "放射狀選單使用四指，macOS 三指拖移使用三指。", "打開放射狀選單"]
        case .ru: return ["Касание 4 пальцами использует радиальное меню.", "Нажатие 4 пальцами использует радиальное меню.", "Недоступно", "Радиальное меню использует четыре пальца, а перетягивание тремя пальцами в macOS использует три.", "Открыть радиальное меню"]
        case .uk: return ["Дотик 4 пальцями використовує радіальне меню.", "Натискання 4 пальцями використовує радіальне меню.", "Недоступно", "Радіальне меню використовує чотири пальці, а перетягування трьома пальцями в macOS використовує три.", "Відкрити радіальне меню"]
        case .tr: return ["4 parmakla dokunma Dairesel menü tarafından kullanılıyor.", "4 parmakla tıklama Dairesel menü tarafından kullanılıyor.", "Kullanılamaz", "Dairesel menü dört parmağı, macOS’in üç parmakla sürükleme özelliği üç parmağı kullanıyor.", "Dairesel menüyü aç"]
        case .sk: return ["Ťuknutie 4 prstami používa radiálne menu.", "Kliknutie 4 prstami používa radiálne menu.", "Nedostupné", "Radiálne menu používa štyri prsty a ťahanie tromi prstami v macOS tri.", "Otvoriť radiálne menu"]
        }
    }

    private static func middleClickBase(_ language: AppLanguage) -> MiddleClick {
        switch language {
        case .enUS:
            return MiddleClick(clickWith: "Click with", ignoredApps: "Ignored apps", configure: "Configure…",
                               tapTaken: "3-finger tap is currently used by macOS.",
                               clickTaken: "3-finger click is currently used by macOS three-finger drag.",
                               oneApp: "%d app", manyApps: "%d apps")
        case .ptBR:
            return MiddleClick(clickWith: "Clicar com", ignoredApps: "Apps ignorados", configure: "Configurar…",
                               tapTaken: "O toque com 3 dedos está em uso pelo macOS.",
                               clickTaken: "O clique com 3 dedos está em uso pelo arrasto do macOS.",
                               oneApp: "%d app", manyApps: "%d apps")
        case .es:
            return MiddleClick(clickWith: "Clic con", ignoredApps: "Apps ignoradas", configure: "Configurar…",
                               tapTaken: "macOS está usando el toque con 3 dedos.",
                               clickTaken: "El arrastre con tres dedos de macOS está usando el clic con 3 dedos.",
                               oneApp: "%d app", manyApps: "%d apps")
        case .de:
            return MiddleClick(clickWith: "Klicken mit", ignoredApps: "Ignorierte Apps", configure: "Konfigurieren …",
                               tapTaken: "Tippen mit 3 Fingern wird derzeit von macOS verwendet.",
                               clickTaken: "Klicken mit 3 Fingern wird derzeit vom Dreifingerziehen in macOS verwendet.",
                               oneApp: "%d App", manyApps: "%d Apps")
        case .fr:
            return MiddleClick(clickWith: "Cliquer avec", ignoredApps: "Apps ignorées", configure: "Configurer…",
                               tapTaken: "Le toucher à 3 doigts est actuellement utilisé par macOS.",
                               clickTaken: "Le clic à 3 doigts est actuellement utilisé par le glissement à trois doigts de macOS.",
                               oneApp: "%d app", manyApps: "%d apps")
        case .it:
            return MiddleClick(clickWith: "Clic con", ignoredApps: "App ignorate", configure: "Configura…",
                               tapTaken: "Il tocco con 3 dita è attualmente usato da macOS.",
                               clickTaken: "Il clic con 3 dita è attualmente usato dal trascinamento con tre dita di macOS.",
                               oneApp: "%d app", manyApps: "%d app")
        case .ja:
            return MiddleClick(clickWith: "クリックする指", ignoredApps: "無視するアプリ", configure: "設定…",
                               tapTaken: "3本指のタップは現在macOSで使用されています。",
                               clickTaken: "3本指のクリックは現在macOSの3本指ドラッグで使用されています。",
                               oneApp: "%d個のアプリ", manyApps: "%d個のアプリ")
        case .ko:
            return MiddleClick(clickWith: "클릭 손가락 수", ignoredApps: "무시할 앱", configure: "구성…",
                               tapTaken: "세 손가락 탭은 현재 macOS에서 사용 중입니다.",
                               clickTaken: "세 손가락 클릭은 현재 macOS 세 손가락 드래그에서 사용 중입니다.",
                               oneApp: "앱 %d개", manyApps: "앱 %d개")
        case .zhHans:
            return MiddleClick(clickWith: "点按手指数", ignoredApps: "忽略的 App", configure: "配置…",
                               tapTaken: "三指轻点目前由 macOS 使用。",
                               clickTaken: "三指点按目前由 macOS 三指拖移使用。",
                               oneApp: "%d 个 App", manyApps: "%d 个 App")
        case .zhTW:
            return MiddleClick(clickWith: "按一下手指數", ignoredApps: "忽略的 App", configure: "設定…",
                               tapTaken: "三指點一下目前由 macOS 使用。",
                               clickTaken: "三指按一下目前由 macOS 三指拖移使用。",
                               oneApp: "%d 個 App", manyApps: "%d 個 App")
        case .zhHK:
            return MiddleClick(clickWith: "點按手指數", ignoredApps: "忽略的 App", configure: "設定…",
                               tapTaken: "三指輕點目前由 macOS 使用。",
                               clickTaken: "三指點按目前由 macOS 三指拖移使用。",
                               oneApp: "%d 個 App", manyApps: "%d 個 App")
        case .ru:
            return MiddleClick(clickWith: "Нажатие", ignoredApps: "Игнорируемые приложения", configure: "Настроить…",
                               tapTaken: "Касание тремя пальцами сейчас использует macOS.",
                               clickTaken: "Нажатие тремя пальцами сейчас использует перетягивание тремя пальцами в macOS.",
                               oneApp: "%d приложение", fewApps: "%d приложения", manyApps: "%d приложений",
                               agreement: .byLastDigits)
        case .uk:
            return MiddleClick(clickWith: "Натискання", ignoredApps: "Ігноровані програми", configure: "Налаштувати…",
                               tapTaken: "Дотик трьома пальцями зараз використовує macOS.",
                               clickTaken: "Натискання трьома пальцями зараз використовує перетягування трьома пальцями в macOS.",
                               oneApp: "%d програма", fewApps: "%d програми", manyApps: "%d програм",
                               agreement: .byLastDigits)
        case .tr:
            return MiddleClick(clickWith: "Tıklama", ignoredApps: "Yok sayılan uygulamalar", configure: "Yapılandır…",
                               tapTaken: "3 parmakla dokunma şu anda macOS tarafından kullanılıyor.",
                               clickTaken: "3 parmakla tıklama şu anda macOS’in üç parmakla sürükleme özelliği tarafından kullanılıyor.",
                               oneApp: "%d uygulama", manyApps: "%d uygulama")
        case .sk:
            return MiddleClick(clickWith: "Kliknutie", ignoredApps: "Ignorované aplikácie", configure: "Konfigurovať…",
                               tapTaken: "Ťuknutie tromi prstami momentálne používa macOS.",
                               clickTaken: "Kliknutie tromi prstami momentálne používa ťahanie tromi prstami v macOS.",
                               oneApp: "%d aplikácia", fewApps: "%d aplikácie", manyApps: "%d aplikácií",
                               agreement: .byWholeNumber)
        }
    }

    /// Preset names and captions for the smooth-scrolling pickers. The names
    /// agree with each row's own label (speed, response, coast).
    struct ScrollPresets {
        let slow, normal, fast, faster: String
        let snappy, balanced, silky: String
        let none, short, medium, long: String
        let responseCaption, coastCaption: String
    }

    static func scrollPresets(_ language: AppLanguage) -> ScrollPresets {
        switch language {
        case .enUS:
            return ScrollPresets(slow: "Slow", normal: "Normal", fast: "Fast", faster: "Faster",
                                 snappy: "Snappy", balanced: "Balanced", silky: "Silky",
                                 none: "None", short: "Short", medium: "Medium", long: "Long",
                                 responseCaption: "How quickly scrolling catches up with the wheel.",
                                 coastCaption: "How far scrolling glides after the wheel stops.")
        case .ptBR:
            return ScrollPresets(slow: "Lenta", normal: "Normal", fast: "Rápida", faster: "Mais rápida",
                                 snappy: "Ágil", balanced: "Equilibrada", silky: "Suave",
                                 none: "Nenhuma", short: "Curta", medium: "Média", long: "Longa",
                                 responseCaption: "A rapidez com que a rolagem acompanha a roda.",
                                 coastCaption: "Quanto a rolagem desliza depois que a roda para.")
        case .es:
            return ScrollPresets(slow: "Lenta", normal: "Normal", fast: "Rápida", faster: "Muy rápida",
                                 snappy: "Ágil", balanced: "Equilibrada", silky: "Suave",
                                 none: "Ninguna", short: "Corta", medium: "Media", long: "Larga",
                                 responseCaption: "La rapidez con que el desplazamiento sigue a la rueda.",
                                 coastCaption: "Cuánto se desliza el contenido cuando la rueda se detiene.")
        case .de:
            return ScrollPresets(slow: "Langsam", normal: "Normal", fast: "Schnell", faster: "Sehr schnell",
                                 snappy: "Direkt", balanced: "Ausgewogen", silky: "Weich",
                                 none: "Keiner", short: "Kurz", medium: "Mittel", long: "Lang",
                                 responseCaption: "Wie schnell das Scrollen dem Mausrad folgt.",
                                 coastCaption: "Wie weit das Scrollen nachläuft, wenn das Mausrad stoppt.")
        case .fr:
            return ScrollPresets(slow: "Lente", normal: "Normale", fast: "Rapide", faster: "Très rapide",
                                 snappy: "Vive", balanced: "Équilibrée", silky: "Douce",
                                 none: "Aucune", short: "Courte", medium: "Moyenne", long: "Longue",
                                 responseCaption: "La rapidité avec laquelle le défilement suit la molette.",
                                 coastCaption: "La distance parcourue par le défilement après l’arrêt de la molette.")
        case .it:
            return ScrollPresets(slow: "Lenta", normal: "Normale", fast: "Veloce", faster: "Molto veloce",
                                 snappy: "Scattante", balanced: "Bilanciata", silky: "Morbida",
                                 none: "Nessuna", short: "Breve", medium: "Media", long: "Lunga",
                                 responseCaption: "Quanto rapidamente lo scorrimento segue la rotellina.",
                                 coastCaption: "Quanto continua lo scorrimento dopo che la rotellina si ferma.")
        case .ja:
            return ScrollPresets(slow: "遅い", normal: "標準", fast: "速い", faster: "より速い",
                                 snappy: "機敏", balanced: "バランス", silky: "なめらか",
                                 none: "なし", short: "短い", medium: "中", long: "長い",
                                 responseCaption: "ホイールの動きにスクロールが追従する速さです。",
                                 coastCaption: "ホイールを止めたあとにスクロールが続く距離です。")
        case .ko:
            return ScrollPresets(slow: "느리게", normal: "보통", fast: "빠르게", faster: "더 빠르게",
                                 snappy: "민첩하게", balanced: "균형", silky: "부드럽게",
                                 none: "없음", short: "짧게", medium: "중간", long: "길게",
                                 responseCaption: "스크롤이 휠을 따라가는 속도입니다.",
                                 coastCaption: "휠을 멈춘 뒤 스크롤이 이어지는 거리입니다.")
        case .zhHans:
            return ScrollPresets(slow: "慢", normal: "正常", fast: "快", faster: "更快",
                                 snappy: "灵敏", balanced: "均衡", silky: "顺滑",
                                 none: "无", short: "短", medium: "中", long: "长",
                                 responseCaption: "滚动跟上滚轮的速度。",
                                 coastCaption: "滚轮停止后滚动继续滑行的距离。")
        case .zhTW, .zhHK:
            return ScrollPresets(slow: "慢", normal: "正常", fast: "快", faster: "更快",
                                 snappy: "靈敏", balanced: "均衡", silky: "順滑",
                                 none: "無", short: "短", medium: "中", long: "長",
                                 responseCaption: "捲動跟上滾輪的速度。",
                                 coastCaption: "滾輪停止後捲動繼續滑行的距離。")
        case .ru:
            return ScrollPresets(slow: "Медленная", normal: "Обычная", fast: "Быстрая", faster: "Очень быстрая",
                                 snappy: "Быстрый", balanced: "Сбалансированный", silky: "Плавный",
                                 none: "Нет", short: "Короткая", medium: "Средняя", long: "Долгая",
                                 responseCaption: "Как быстро прокрутка следует за колесом.",
                                 coastCaption: "Как далеко прокрутка продолжается после остановки колеса.")
        case .uk:
            return ScrollPresets(slow: "Повільна", normal: "Звичайна", fast: "Швидка", faster: "Дуже швидка",
                                 snappy: "Швидкий", balanced: "Збалансований", silky: "Плавний",
                                 none: "Немає", short: "Коротка", medium: "Середня", long: "Довга",
                                 responseCaption: "Як швидко прокрутка встигає за коліщатком.",
                                 coastCaption: "Як далеко прокрутка триває після зупинки коліщатка.")
        case .tr:
            return ScrollPresets(slow: "Yavaş", normal: "Normal", fast: "Hızlı", faster: "Daha hızlı",
                                 snappy: "Çevik", balanced: "Dengeli", silky: "Yumuşak",
                                 none: "Yok", short: "Kısa", medium: "Orta", long: "Uzun",
                                 responseCaption: "Kaydırmanın tekerleğe ne kadar hızlı yetiştiği.",
                                 coastCaption: "Tekerlek durduktan sonra kaydırmanın ne kadar süzüldüğü.")
        case .sk:
            return ScrollPresets(slow: "Pomalá", normal: "Normálna", fast: "Rýchla", faster: "Veľmi rýchla",
                                 snappy: "Svižná", balanced: "Vyvážená", silky: "Jemná",
                                 none: "Žiadny", short: "Krátky", medium: "Stredný", long: "Dlhý",
                                 responseCaption: "Ako rýchlo rolovanie nasleduje koliesko.",
                                 coastCaption: "Ako ďaleko rolovanie pokračuje po zastavení kolieska.")
        }
    }

    static func trackpadDragConflict(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Three-finger drag is enabled in macOS. Use four fingers for middle-click."
        case .ptBR: return "O arrasto com três dedos está ativo no macOS. Use quatro dedos para o clique do meio."
        case .es: return "El arrastre con tres dedos está activado en macOS. Usa cuatro dedos para el clic central."
        case .de: return "Dreifingerziehen ist in macOS aktiviert. Verwende vier Finger für den Mittelklick."
        case .fr: return "Le glissement à trois doigts est activé dans macOS. Utilisez quatre doigts pour le clic central."
        case .it: return "Il trascinamento con tre dita è attivo in macOS. Usa quattro dita per il clic centrale."
        case .ja: return "macOSの3本指ドラッグが有効です。中クリックには4本指を使ってください。"
        case .ko: return "macOS에서 세 손가락 드래그가 켜져 있습니다. 가운데 클릭에는 네 손가락을 사용하세요."
        case .zhHans: return "macOS 已开启三指拖移。请使用四指进行中键点击。"
        case .zhTW, .zhHK: return "macOS 已開啟三指拖移。請使用四指進行中鍵點按。"
        case .ru: return "В macOS включено перетягивание тремя пальцами. Для среднего клика используйте четыре пальца."
        case .uk: return "У macOS увімкнено перетягування трьома пальцями. Для середнього клацання використовуйте чотири пальці."
        case .tr: return "macOS’te üç parmakla sürükleme açık. Orta tıklama için dört parmağınızı kullanın."
        case .sk: return "V macOS je zapnuté ťahanie tromi prstami. Na stredné kliknutie použite štyri prsty."
        }
    }

    enum Key: Int, CaseIterable {
        case mouseScrolling, mouseClicks, mouseButtons, enableSuperKey, superKey
        case superKeyActive, superKeyConflict, filterActive, off, permissionRequired, waiting, sideButtonsHelp
    }

    static func text(_ key: Key, _ language: AppLanguage) -> String {
        let labels: [String]
        switch language {
        case .enUS:
            labels = ["Mouse Scrolling & Movement", "Mouse Clicks", "Mouse Buttons", "Enable super key", "Super Key", "Super Key active", "Another app’s key mapping uses the same key. Please reset.", "Duplicate-key filter active", "Off", "Allow Accessibility access to activate this feature.", "Not active. Check permissions and try enabling it again.", "Enable back and forward navigation with mouse thumb buttons."]
        case .ptBR:
            labels = ["Rolagem e movimento do mouse", "Cliques do mouse", "Botões do mouse", "Ativar tecla super", "Tecla super", "Tecla super ativa", "Outro app usa a mesma tecla. Redefina o mapeamento nesse app.", "Filtro de teclas duplicadas ativo", "Desativado", "Permita o acesso de Acessibilidade para ativar este recurso.", "Inativo. Verifique as permissões e tente ativar novamente.", "Ative a navegação para voltar e avançar com os botões laterais do mouse."]
        case .es:
            labels = ["Desplazamiento y movimiento del ratón", "Clics del ratón", "Botones del ratón", "Activar supertecla", "Supertecla", "Supertecla activa", "Otra app usa la misma tecla. Restablece su asignación.", "Filtro de teclas duplicadas activo", "Desactivado", "Permite el acceso de Accesibilidad para activar esta función.", "Inactivo. Revisa los permisos y vuelve a activarlo.", "Activa la navegación hacia atrás y adelante con los botones laterales del ratón."]
        case .de:
            labels = ["Maus-Scrollen & Bewegung", "Mausklicks", "Maustasten", "Super-Taste aktivieren", "Super-Taste", "Super-Taste aktiv", "Eine andere App belegt dieselbe Taste. Setze dort die Belegung zurück.", "Filter für doppelte Tastendrücke aktiv", "Aus", "Erlaube den Bedienungshilfen-Zugriff, um diese Funktion zu aktivieren.", "Nicht aktiv. Prüfe die Berechtigungen und aktiviere die Funktion erneut.", "Aktiviert Zurück und Vor mit den Daumentasten der Maus."]
        case .fr:
            labels = ["Défilement et mouvement de la souris", "Clics de la souris", "Boutons de la souris", "Activer la super touche", "Super touche", "Super touche active", "Une autre app utilise la même touche. Réinitialisez son affectation.", "Filtre des frappes répétées actif", "Désactivé", "Autorisez l’accès Accessibilité pour activer cette fonction.", "Inactif. Vérifiez les autorisations et réactivez la fonction.", "Active la navigation précédent et suivant avec les boutons latéraux de la souris."]
        case .it:
            labels = ["Scorrimento e movimento del mouse", "Clic del mouse", "Pulsanti del mouse", "Attiva super tasto", "Super tasto", "Super tasto attivo", "Un’altra app usa lo stesso tasto. Ripristina la sua assegnazione.", "Filtro dei tasti duplicati attivo", "Disattivato", "Consenti l’accesso ad Accessibilità per attivare questa funzione.", "Non attivo. Controlla i permessi e riattiva la funzione.", "Attiva la navigazione indietro e avanti con i pulsanti laterali del mouse."]
        case .sk:
            labels = ["Posúvanie a pohyb myši", "Kliknutia myšou", "Tlačidlá myši", "Zapnúť super kláves", "Super kláves", "Super kláves je aktívny", "Iná aplikácia používa rovnaký kláves. Obnovte jeho priradenie.", "Filter duplicitných klávesov je aktívny", "Vypnuté", "Na aktiváciu povoľte prístup k Prístupnosti.", "Neaktívne. Skontrolujte oprávnenia a skúste funkciu zapnúť znova.", "Zapne navigáciu späť a dopredu bočnými tlačidlami myši."]
        case .tr:
            labels = ["Fare Kaydırma ve Hareket", "Fare tıklamaları", "Fare düğmeleri", "Süper tuşu etkinleştir", "Süper tuş", "Süper tuş etkin", "Başka bir uygulama aynı tuşu kullanıyor. Tuş eşlemesini sıfırlayın.", "Yinelenen tuş filtresi etkin", "Kapalı", "Bu özelliği etkinleştirmek için Erişilebilirlik izni verin.", "Etkin değil. İzinleri kontrol edip yeniden etkinleştirin.", "Fare başparmak düğmeleriyle geri ve ileri gezinmeyi etkinleştirin."]
        case .ru:
            labels = ["Прокрутка и движение мыши", "Щелчки мышью", "Кнопки мыши", "Включить суперклавишу", "Суперклавиша", "Суперклавиша активна", "Другое приложение использует ту же клавишу. Сбросьте её назначение.", "Фильтр повторных нажатий активен", "Выключено", "Разрешите доступ к Универсальному доступу, чтобы включить функцию.", "Неактивно. Проверьте разрешения и включите функцию снова.", "Включает переход назад и вперёд боковыми кнопками мыши."]
        case .uk:
            labels = ["Прокручування та рух миші", "Клацання миші", "Кнопки миші", "Увімкнути суперклавішу", "Суперклавіша", "Суперклавіша активна", "Інша програма використовує ту саму клавішу. Скиньте її призначення.", "Фільтр повторних натискань активний", "Вимкнено", "Надайте дозвіл Доступності, щоб увімкнути цю функцію.", "Неактивно. Перевірте дозволи та ввімкніть функцію знову.", "Вмикає перехід назад і вперед бічними кнопками миші."]
        case .ja:
            labels = ["マウスのスクロールと移動", "マウスのクリック", "マウスボタン", "スーパーキーを有効にする", "スーパーキー", "スーパーキーは有効です", "別のアプリが同じキーを使用しています。割り当てをリセットしてください。", "重複キー入力フィルターは有効です", "オフ", "この機能を有効にするにはアクセシビリティへのアクセスを許可してください。", "動作していません。権限を確認して再度有効にしてください。", "マウスの親指ボタンで戻る・進むを使えるようにします。"]
        case .ko:
            labels = ["마우스 스크롤 및 이동", "마우스 클릭", "마우스 버튼", "슈퍼 키 활성화", "슈퍼 키", "슈퍼 키 활성 상태", "다른 앱이 같은 키를 사용합니다. 해당 키 매핑을 재설정하세요.", "중복 키 필터 활성 상태", "꺼짐", "이 기능을 사용하려면 손쉬운 사용 접근을 허용하세요.", "비활성 상태입니다. 권한을 확인하고 다시 활성화하세요.", "마우스 엄지 버튼으로 뒤로 및 앞으로 이동합니다."]
        case .zhHans:
            labels = ["鼠标滚动与移动", "鼠标点击", "鼠标按钮", "启用超级键", "超级键", "超级键已生效", "其他 App 的按键映射正在使用同一个键，请重置该映射。", "重复按键过滤已生效", "已关闭", "请允许辅助功能访问以启用此功能。", "尚未生效，请检查权限后重新启用。", "使用鼠标拇指侧按钮进行后退和前进导航。"]
        case .zhTW:
            labels = ["滑鼠捲動與移動", "滑鼠點按", "滑鼠按鈕", "啟用超級鍵", "超級鍵", "超級鍵已生效", "其他 App 的按鍵對應正在使用同一個鍵，請重設該對應。", "重複按鍵過濾已生效", "已關閉", "請允許輔助使用取用權限以啟用此功能。", "尚未生效，請檢查權限後重新啟用。", "使用滑鼠拇指側按鈕進行返回和前進導覽。"]
        case .zhHK:
            labels = ["滑鼠捲動與移動", "滑鼠點按", "滑鼠按鈕", "啟用超級鍵", "超級鍵", "超級鍵已生效", "其他 App 的按鍵對應正在使用同一個鍵，請重設該對應。", "重複按鍵過濾已生效", "已關閉", "請允許輔助使用取用權限以啟用此功能。", "尚未生效，請檢查權限後重新啟用。", "使用滑鼠拇指側按鈕進行返回和前進導覽。"]
        }
        return labels[key.rawValue]
    }
}
