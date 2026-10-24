import Foundation

enum InputSettingsStrings {
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
            labels = ["Mouse Scrolling", "Mouse Clicks", "Mouse Buttons", "Enable super key", "Super Key", "Super Key active", "Another app’s key mapping uses the same key. Please reset.", "Duplicate-key filter active", "Off", "Allow Accessibility access to activate this feature.", "Not active. Check permissions and try enabling it again.", "Use the extra thumb buttons usually assigned to Back and Forward. Your mouse software may remap them."]
        case .ptBR:
            labels = ["Rolagem do mouse", "Cliques do mouse", "Botões do mouse", "Ativar tecla super", "Tecla super", "Tecla super ativa", "Outro app usa a mesma tecla. Redefina o mapeamento nesse app.", "Filtro de teclas duplicadas ativo", "Desativado", "Permita o acesso de Acessibilidade para ativar este recurso.", "Inativo. Verifique as permissões e tente ativar novamente.", "Use os botões extras do polegar, normalmente usados para Voltar e Avançar. O software do mouse pode remapeá-los."]
        case .es:
            labels = ["Desplazamiento del ratón", "Clics del ratón", "Botones del ratón", "Activar supertecla", "Supertecla", "Supertecla activa", "Otra app usa la misma tecla. Restablece su asignación.", "Filtro de teclas duplicadas activo", "Desactivado", "Permite el acceso de Accesibilidad para activar esta función.", "Inactivo. Revisa los permisos y vuelve a activarlo.", "Usa los botones del pulgar, normalmente Atrás y Adelante. El software del ratón puede reasignarlos."]
        case .de:
            labels = ["Maus-Scrollen", "Mausklicks", "Maustasten", "Super-Taste aktivieren", "Super-Taste", "Super-Taste aktiv", "Eine andere App belegt dieselbe Taste. Setze dort die Belegung zurück.", "Filter für doppelte Tastendrücke aktiv", "Aus", "Erlaube den Bedienungshilfen-Zugriff, um diese Funktion zu aktivieren.", "Nicht aktiv. Prüfe die Berechtigungen und aktiviere die Funktion erneut.", "Verwende die zusätzlichen Daumentasten für Zurück und Vorwärts. Die Maussoftware kann sie anders belegen."]
        case .fr:
            labels = ["Défilement de la souris", "Clics de la souris", "Boutons de la souris", "Activer la super touche", "Super touche", "Super touche active", "Une autre app utilise la même touche. Réinitialisez son affectation.", "Filtre des frappes répétées actif", "Désactivé", "Autorisez l’accès Accessibilité pour activer cette fonction.", "Inactif. Vérifiez les autorisations et réactivez la fonction.", "Utilisez les boutons du pouce, généralement Précédent et Suivant. Le logiciel de la souris peut les réaffecter."]
        case .it:
            labels = ["Scorrimento del mouse", "Clic del mouse", "Pulsanti del mouse", "Attiva super tasto", "Super tasto", "Super tasto attivo", "Un’altra app usa lo stesso tasto. Ripristina la sua assegnazione.", "Filtro dei tasti duplicati attivo", "Disattivato", "Consenti l’accesso ad Accessibilità per attivare questa funzione.", "Non attivo. Controlla i permessi e riattiva la funzione.", "Usa i pulsanti del pollice, normalmente Indietro e Avanti. Il software del mouse può riassegnarli."]
        case .sk:
            labels = ["Posúvanie myšou", "Kliknutia myšou", "Tlačidlá myši", "Zapnúť super kláves", "Super kláves", "Super kláves je aktívny", "Iná aplikácia používa rovnaký kláves. Obnovte jeho priradenie.", "Filter duplicitných klávesov je aktívny", "Vypnuté", "Na aktiváciu povoľte prístup k Prístupnosti.", "Neaktívne. Skontrolujte oprávnenia a skúste funkciu zapnúť znova.", "Použite bočné tlačidlá pre palec, zvyčajne Späť a Dopredu. Softvér myši ich môže premapovať."]
        case .tr:
            labels = ["Fare kaydırma", "Fare tıklamaları", "Fare düğmeleri", "Süper tuşu etkinleştir", "Süper tuş", "Süper tuş etkin", "Başka bir uygulama aynı tuşu kullanıyor. Tuş eşlemesini sıfırlayın.", "Yinelenen tuş filtresi etkin", "Kapalı", "Bu özelliği etkinleştirmek için Erişilebilirlik izni verin.", "Etkin değil. İzinleri kontrol edip yeniden etkinleştirin.", "Genellikle Geri ve İleri için kullanılan başparmak düğmelerini kullanın. Fare yazılımı bunları yeniden eşleyebilir."]
        case .ru:
            labels = ["Прокрутка мышью", "Щелчки мышью", "Кнопки мыши", "Включить суперклавишу", "Суперклавиша", "Суперклавиша активна", "Другое приложение использует ту же клавишу. Сбросьте её назначение.", "Фильтр повторных нажатий активен", "Выключено", "Разрешите доступ к Универсальному доступу, чтобы включить функцию.", "Неактивно. Проверьте разрешения и включите функцию снова.", "Используйте кнопки под большим пальцем, обычно Назад и Вперёд. ПО мыши может менять их назначение."]
        case .uk:
            labels = ["Прокручування мишею", "Клацання миші", "Кнопки миші", "Увімкнути суперклавішу", "Суперклавіша", "Суперклавіша активна", "Інша програма використовує ту саму клавішу. Скиньте її призначення.", "Фільтр повторних натискань активний", "Вимкнено", "Надайте дозвіл Доступності, щоб увімкнути цю функцію.", "Неактивно. Перевірте дозволи та ввімкніть функцію знову.", "Використовуйте кнопки під великим пальцем, зазвичай Назад і Вперед. ПЗ миші може змінювати їх призначення."]
        case .ja:
            labels = ["マウスのスクロール", "マウスのクリック", "マウスボタン", "スーパーキーを有効にする", "スーパーキー", "スーパーキーは有効です", "別のアプリが同じキーを使用しています。割り当てをリセットしてください。", "重複キー入力フィルターは有効です", "オフ", "この機能を有効にするにはアクセシビリティへのアクセスを許可してください。", "動作していません。権限を確認して再度有効にしてください。", "通常「戻る」「進む」に使う親指側の追加ボタンです。マウスのソフトウェアで割り当てが変更されている場合があります。"]
        case .ko:
            labels = ["마우스 스크롤", "마우스 클릭", "마우스 버튼", "슈퍼 키 활성화", "슈퍼 키", "슈퍼 키 활성 상태", "다른 앱이 같은 키를 사용합니다. 해당 키 매핑을 재설정하세요.", "중복 키 필터 활성 상태", "꺼짐", "이 기능을 사용하려면 손쉬운 사용 접근을 허용하세요.", "비활성 상태입니다. 권한을 확인하고 다시 활성화하세요.", "주로 뒤로 및 앞으로 이동에 사용하는 엄지 쪽 추가 버튼입니다. 마우스 소프트웨어에서 매핑을 변경했을 수 있습니다."]
        case .zhHans:
            labels = ["鼠标滚动", "鼠标点击", "鼠标按钮", "启用超级键", "超级键", "超级键已生效", "其他 App 的按键映射正在使用同一个键，请重置该映射。", "重复按键过滤已生效", "已关闭", "请允许辅助功能访问以启用此功能。", "尚未生效，请检查权限后重新启用。", "使用拇指侧通常用于后退和前进的额外按钮。鼠标软件可能已重新映射这些按钮。"]
        case .zhTW:
            labels = ["滑鼠捲動", "滑鼠點按", "滑鼠按鈕", "啟用超級鍵", "超級鍵", "超級鍵已生效", "其他 App 的按鍵對應正在使用同一個鍵，請重設該對應。", "重複按鍵過濾已生效", "已關閉", "請允許輔助使用取用權限以啟用此功能。", "尚未生效，請檢查權限後重新啟用。", "使用拇指側通常用於返回和前進的額外按鈕。滑鼠軟體可能已重新對應這些按鈕。"]
        case .zhHK:
            labels = ["滑鼠捲動", "滑鼠點按", "滑鼠按鈕", "啟用超級鍵", "超級鍵", "超級鍵已生效", "其他 App 的按鍵對應正在使用同一個鍵，請重設該對應。", "重複按鍵過濾已生效", "已關閉", "請允許輔助使用取用權限以啟用此功能。", "尚未生效，請檢查權限後重新啟用。", "使用拇指側通常用於返回和前進的額外按鈕。滑鼠軟件可能已重新對應這些按鈕。"]
        }
        return labels[key.rawValue]
    }
}
