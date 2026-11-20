// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct MouseButtonFeatureStrings {
    let pageTitle: String
    let hubDescription: String
    let enableLabel: String
    let enableCaption: String
    let addButton: String
    let captureWaiting: String
    let captureCancel: String
    let captureBlind: String
    let captureUnsupported: String
    let captureWheel: String
    let captureExists: String
    let captureHint: String
    let backButtonName: String
    let forwardButtonName: String
    let otherButtonFormat: String      // "Button %d"
    let setShortcutButton: String
    let removeButton: String
    let emptyCaption: String
    let rowWheelNote: String
    let manageButton: String
    let panelCaption: String
    let sideWheelLeftName: String
    let sideWheelRightName: String
    let spacesEnableLabel: String
    let spacesEnableCaption: String
    let spacesPickButton: String
    let spacesShortcutsOffNote: String
    // The drag capture cannot borrow the shortcut capture's strings: it
    // refuses the side wheel by design, and its refusals must not point at a
    // list that is off screen with the shortcut switch off. New fields, so the
    // memberwise initializer makes a missing language a compile error.
    let spacesCaptureWaiting: String
    let spacesCaptureUnsupported: String
    let spacesCaptureExists: String
    let spacesFollowsDragLabel: String
    let spacesFollowsDragCaption: String

    func configureButton(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Configure"
        case .zhHans: return "配置"
        case .zhTW, .zhHK: return "設定"
        case .ja: return "設定"
        case .ko: return "구성"
        case .de: return "Konfigurieren"
        case .fr: return "Configurer"
        case .es: return "Configurar"
        case .ptBR: return "Configurar"
        case .it: return "Configura"
        case .ru: return "Настроить"
        case .uk: return "Налаштувати"
        case .tr: return "Ayarla"
        case .sk: return "Nastaviť"
        }
    }
}

extension FeatureStrings {
    static func mouseButtons(_ language: AppLanguage) -> MouseButtonFeatureStrings {
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

extension MouseButtonFeatureStrings {
    static let enUS = MouseButtonFeatureStrings(
        pageTitle: "Mouse button shortcuts",
        hubDescription: "Extra buttons and side-wheel directions press a key combination you choose.",
        enableLabel: "Custom Mouse Shortcuts",
        enableCaption: "Assign keyboard shortcuts to mouse controls.",
        addButton: "Add a button or side wheel",
        captureWaiting: "Waiting for mouse input…",
        captureCancel: "Cancel",
        captureBlind: "Lattice cannot watch the mouse right now.",
        captureUnsupported: "Invalid mouse input, try another one.",
        captureWheel: "That button already opens the radial menu. Pick another one, or free it there first.",
        captureExists: "That button or direction is already on the list below.",
        captureHint: "Controls assigned elsewhere cannot be detected.",
        backButtonName: "Back side button",
        forwardButtonName: "Forward side button",
        otherButtonFormat: "Button %d",
        setShortcutButton: "Set shortcut",
        removeButton: "Remove",
        emptyCaption: "No shortcuts yet. Add a button or side-wheel direction.",
        rowWheelNote: "This button opens the radial menu now, so the shortcut waits.",
        manageButton: "Set up…",
        panelCaption: "Extra buttons and side-wheel directions press key combinations you choose.",
        sideWheelLeftName: "Side wheel left",
        sideWheelRightName: "Side wheel right",
        spacesEnableLabel: "Mouse navigation gesture",
        spacesEnableCaption: "Hold mouse button to navigate.",
        spacesPickButton: "Choose a button",
        spacesShortcutsOffNote: "This gesture can’t switch Spaces. The required keyboard shortcuts are off. Open System Settings > Keyboard > Keyboard Shortcuts > Mission Control and enable “Move left a space” and “Move right a space”.",
        spacesCaptureWaiting: "Now press an extra button.",
        spacesCaptureUnsupported: "That input cannot be held for a drag. Use an extra button.",
        spacesCaptureExists: "That button already has a shortcut. Pick another one.",
        spacesFollowsDragLabel: "Reverse horizontal drag direction",
        spacesFollowsDragCaption: "When on, dragging right switches to the Space on the left."
    )

    static let ptBR = MouseButtonFeatureStrings(
        pageTitle: "Atalhos nos botões do mouse",
        hubDescription: "Botões extras e os sentidos da roda lateral apertam uma combinação de teclas que você escolher.",
        enableLabel: "Atalhos personalizados do mouse",
        enableCaption: "Atribua atalhos de teclado aos controles do mouse.",
        addButton: "Adicionar botão ou roda lateral",
        captureWaiting: "Aguardando entrada do mouse…",
        captureCancel: "Cancelar",
        captureBlind: "O Lattice não consegue observar o mouse agora.",
        captureUnsupported: "Entrada do mouse inválida, tente outra.",
        captureWheel: "Esse botão já abre o menu radial. Escolha outro, ou libere ele lá primeiro.",
        captureExists: "Esse botão ou sentido já está na lista abaixo.",
        captureHint: "Controles atribuídos em outro lugar não podem ser detectados.",
        backButtonName: "Botão lateral de voltar",
        forwardButtonName: "Botão lateral de avançar",
        otherButtonFormat: "Botão %d",
        setShortcutButton: "Definir atalho",
        removeButton: "Remover",
        emptyCaption: "Nenhum atalho ainda. Adicione um botão ou sentido da roda lateral.",
        rowWheelNote: "Esse botão abre o menu radial agora, então o atalho fica esperando.",
        manageButton: "Configurar…",
        panelCaption: "Botões extras e os sentidos da roda lateral apertam combinações de teclas que você escolher.",
        sideWheelLeftName: "Roda lateral para a esquerda",
        sideWheelRightName: "Roda lateral para a direita",
        spacesEnableLabel: "Gesto de navegação com o mouse",
        spacesEnableCaption: "Segure um botão do mouse para navegar.",
        spacesPickButton: "Escolher um botão",
        spacesShortcutsOffNote: "Este gesto não pode alternar entre Spaces porque os atalhos necessários estão desativados. Abra Ajustes do Sistema > Teclado > Atalhos de Teclado > Mission Control e ative os atalhos para mover um Space à esquerda e à direita.",
        spacesCaptureWaiting: "Agora aperte um botão extra.",
        spacesCaptureUnsupported: "Esse controle não dá para segurar e arrastar. Use um botão extra.",
        spacesCaptureExists: "Esse botão já tem um atalho. Escolha outro.",
        spacesFollowsDragLabel: "Inverter a direção horizontal do arrasto",
        spacesFollowsDragCaption: "Quando ativado, arrastar para a direita muda para o Espaço à esquerda."
    )

    static let tr = MouseButtonFeatureStrings(
        pageTitle: "Fare düğmesi kısayolları",
        hubDescription: "Ekstra fare düğmeleri ve yan teker yönleri seçtiğiniz bir tuş birleşimine basar.",
        enableLabel: "Özel fare kısayolları",
        enableCaption: "Fare kontrollerine klavye kısayolları atayın.",
        addButton: "Düğme veya yan teker ekle",
        captureWaiting: "Fare girişi bekleniyor…",
        captureCancel: "Vazgeç",
        captureBlind: "Lattice şu anda fareyi izleyemiyor.",
        captureUnsupported: "Geçersiz fare girişi, başka birini deneyin.",
        captureWheel: "Bu düğme zaten dairesel menüyü açıyor. Başka bir düğme seçin veya önce orada serbest bırakın.",
        captureExists: "Bu düğme veya yön zaten aşağıdaki listede.",
        captureHint: "Başka yerde atanmış kontroller algılanamaz.",
        backButtonName: "Geri yan düğmesi",
        forwardButtonName: "İleri yan düğmesi",
        otherButtonFormat: "Düğme %d",
        setShortcutButton: "Kısayol belirle",
        removeButton: "Kaldır",
        emptyCaption: "Henüz kısayol yok. Bir düğme veya yan teker yönü ekleyin.",
        rowWheelNote: "Bu düğme şu anda dairesel menüyü açıyor, kısayol bekliyor.",
        manageButton: "Ayarla…",
        panelCaption: "Ekstra düğmeler ve yan teker yönleri seçtiğiniz tuş birleşimlerine basar.",
        sideWheelLeftName: "Yan teker sola",
        sideWheelRightName: "Yan teker sağa",
        spacesEnableLabel: "Fare gezinme hareketi",
        spacesEnableCaption: "Gezinmek için fare düğmesini basılı tutun.",
        spacesPickButton: "Bir düğme seç",
        spacesShortcutsOffNote: "Gerekli klavye kısayolları kapalı olduğundan bu hareket Spaces arasında geçiş yapamaz. Sistem Ayarları > Klavye > Klavye Kısayolları > Mission Control bölümünde bir alan sola ve sağa gitme kısayollarını açın.",
        spacesCaptureWaiting: "Şimdi ek bir düğmeye basın.",
        spacesCaptureUnsupported: "Bu giriş basılı tutulup sürüklenemez. Ek bir düğme kullanın.",
        spacesCaptureExists: "Bu düğmenin zaten bir kısayolu var. Başka bir düğme seçin.",
        spacesFollowsDragLabel: "Yatay sürükleme yönünü tersine çevir",
        spacesFollowsDragCaption: "Açıkken sağa sürüklemek soldaki Alana geçer."
    )

    static let ru = MouseButtonFeatureStrings(
        pageTitle: "Сочетания на кнопках мыши",
        hubDescription: "Дополнительные кнопки и направления бокового колёсика нажимают выбранное вами сочетание клавиш.",
        enableLabel: "Свои сочетания для мыши",
        enableCaption: "Назначайте сочетания клавиш элементам управления мыши.",
        addButton: "Добавить кнопку или боковое колёсико",
        captureWaiting: "Ожидание ввода с мыши…",
        captureCancel: "Отменить",
        captureBlind: "Lattice сейчас не может отслеживать мышь.",
        captureUnsupported: "Недопустимый ввод с мыши, попробуйте другой.",
        captureWheel: "Эта кнопка уже открывает радиальное меню. Выберите другую или сначала освободите её там.",
        captureExists: "Эта кнопка или направление уже есть в списке ниже.",
        captureHint: "Элементы, назначенные в другом месте, не распознаются.",
        backButtonName: "Боковая кнопка «Назад»",
        forwardButtonName: "Боковая кнопка «Вперёд»",
        otherButtonFormat: "Кнопка %d",
        setShortcutButton: "Задать сочетание",
        removeButton: "Удалить",
        emptyCaption: "Сочетаний пока нет. Добавьте кнопку или направление бокового колёсика.",
        rowWheelNote: "Эта кнопка сейчас открывает радиальное меню, поэтому сочетание ждёт.",
        manageButton: "Настроить…",
        panelCaption: "Дополнительные кнопки и направления бокового колёсика нажимают выбранные вами сочетания клавиш.",
        sideWheelLeftName: "Боковое колёсико влево",
        sideWheelRightName: "Боковое колёсико вправо",
        spacesEnableLabel: "Жест навигации мышью",
        spacesEnableCaption: "Удерживайте кнопку мыши для навигации.",
        spacesPickButton: "Выбрать кнопку",
        spacesShortcutsOffNote: "Жест не может переключать пространства, поскольку нужные сочетания клавиш отключены. Откройте Системные настройки > Клавиатура > Сочетания клавиш > Mission Control и включите переход в пространство слева и справа.",
        spacesCaptureWaiting: "Теперь нажмите дополнительную кнопку.",
        spacesCaptureUnsupported: "Этот элемент нельзя удерживать для перетаскивания. Используйте дополнительную кнопку.",
        spacesCaptureExists: "У этой кнопки уже есть сочетание. Выберите другую.",
        spacesFollowsDragLabel: "Обратить направление горизонтального перетаскивания",
        spacesFollowsDragCaption: "Если включено, перетаскивание вправо переключает на Space слева."
    )

    static let es = MouseButtonFeatureStrings(
        pageTitle: "Atajos en los botones del ratón",
        hubDescription: "Los botones extra y las direcciones de la rueda lateral pulsan una combinación de teclas que tú eliges.",
        enableLabel: "Atajos de ratón personalizados",
        enableCaption: "Asigna atajos de teclado a los controles del ratón.",
        addButton: "Añadir botón o rueda lateral",
        captureWaiting: "Esperando una entrada del ratón…",
        captureCancel: "Cancelar",
        captureBlind: "Lattice no puede observar el ratón ahora mismo.",
        captureUnsupported: "Entrada del ratón no válida, prueba con otra.",
        captureWheel: "Ese botón ya abre el menú radial. Elige otro, o libéralo allí primero.",
        captureExists: "Ese botón o dirección ya está en la lista de abajo.",
        captureHint: "Los controles asignados en otro lugar no se pueden detectar.",
        backButtonName: "Botón lateral de retroceso",
        forwardButtonName: "Botón lateral de avance",
        otherButtonFormat: "Botón %d",
        setShortcutButton: "Definir atajo",
        removeButton: "Eliminar",
        emptyCaption: "Aún no hay atajos. Añade un botón o una dirección de la rueda lateral.",
        rowWheelNote: "Ese botón abre el menú radial ahora, así que el atajo queda en espera.",
        manageButton: "Configurar…",
        panelCaption: "Los botones extra y las direcciones de la rueda lateral pulsan combinaciones de teclas que tú eliges.",
        sideWheelLeftName: "Rueda lateral a la izquierda",
        sideWheelRightName: "Rueda lateral a la derecha",
        spacesEnableLabel: "Gesto de navegación con el ratón",
        spacesEnableCaption: "Mantén pulsado un botón del ratón para navegar.",
        spacesPickButton: "Elegir un botón",
        spacesShortcutsOffNote: "Este gesto no puede cambiar de espacio porque los atajos necesarios están desactivados. Abre Ajustes del Sistema > Teclado > Funciones rápidas de teclado > Mission Control y activa los atajos para ir al espacio de la izquierda y de la derecha.",
        spacesCaptureWaiting: "Ahora pulsa un botón extra.",
        spacesCaptureUnsupported: "Esa entrada no se puede mantener pulsada para arrastrar. Usa un botón extra.",
        spacesCaptureExists: "Ese botón ya tiene un atajo. Elige otro.",
        spacesFollowsDragLabel: "Invertir la dirección horizontal del arrastre",
        spacesFollowsDragCaption: "Al activarlo, arrastrar a la derecha cambia al Space de la izquierda."
    )

    static let sk = MouseButtonFeatureStrings(
        pageTitle: "Skratky tlačidiel myši",
        hubDescription: "Extra tlačidlá a smery bočného kolieska stláčajú kombináciu klávesov, ktorú si vyberiete.",
        enableLabel: "Vlastné skratky myši",
        enableCaption: "Priraďte klávesové skratky ovládacím prvkom myši.",
        addButton: "Pridať tlačidlo alebo bočné koliesko",
        captureWaiting: "Čaká sa na vstup z myši…",
        captureCancel: "Zrušiť",
        captureBlind: "Lattice teraz nemôže sledovať myš.",
        captureUnsupported: "Neplatný vstup z myši, skúste iný.",
        captureWheel: "Toto tlačidlo už otvára radiálne menu. Vyberte iné, alebo ho tam najprv uvoľnite.",
        captureExists: "Toto tlačidlo alebo smer už je v zozname nižšie.",
        captureHint: "Ovládacie prvky priradené inde sa nedajú rozpoznať.",
        backButtonName: "Bočné tlačidlo späť",
        forwardButtonName: "Bočné tlačidlo dopredu",
        otherButtonFormat: "Tlačidlo %d",
        setShortcutButton: "Nastaviť skratku",
        removeButton: "Odstrániť",
        emptyCaption: "Zatiaľ žiadne skratky. Pridajte tlačidlo alebo smer bočného kolieska.",
        rowWheelNote: "Toto tlačidlo teraz otvára radiálne menu, takže skratka čaká.",
        manageButton: "Nastaviť…",
        panelCaption: "Extra tlačidlá a smery bočného kolieska stláčajú kombinácie klávesov, ktoré si vyberiete.",
        sideWheelLeftName: "Bočné koliesko vľavo",
        sideWheelRightName: "Bočné koliesko vpravo",
        spacesEnableLabel: "Navigačné gesto myšou",
        spacesEnableCaption: "Na navigáciu podržte tlačidlo myši.",
        spacesPickButton: "Vybrať tlačidlo",
        spacesShortcutsOffNote: "Toto gesto nemôže prepínať plochy, pretože potrebné klávesové skratky sú vypnuté. Otvorte Systémové nastavenia > Klávesnica > Klávesové skratky > Mission Control a zapnite presun o plochu doľava a doprava.",
        spacesCaptureWaiting: "Teraz stlačte extra tlačidlo.",
        spacesCaptureUnsupported: "Tento vstup nemožno podržať pre presunutie. Použite extra tlačidlo.",
        spacesCaptureExists: "Toto tlačidlo už má skratku. Vyberte iné.",
        spacesFollowsDragLabel: "Obrátiť vodorovný smer ťahania",
        spacesFollowsDragCaption: "Keď je zapnuté, ťahanie doprava prepne na plochu vľavo."
    )

    static let de = MouseButtonFeatureStrings(
        pageTitle: "Kurzbefehle auf Maustasten",
        hubDescription: "Zusätzliche Maustasten und Richtungen des seitlichen Rads drücken einen Tastaturkurzbefehl deiner Wahl.",
        enableLabel: "Eigene Maus-Kurzbefehle",
        enableCaption: "Weise Steuerelementen der Maus Tastaturkurzbefehle zu.",
        addButton: "Taste oder seitliches Rad hinzufügen",
        captureWaiting: "Warte auf Mauseingabe…",
        captureCancel: "Abbrechen",
        captureBlind: "Lattice kann die Maus gerade nicht beobachten.",
        captureUnsupported: "Ungültige Mauseingabe, versuche eine andere.",
        captureWheel: "Diese Taste öffnet bereits das Radialmenü. Wähle eine andere oder gib sie dort zuerst frei.",
        captureExists: "Diese Taste oder Richtung steht schon in der Liste unten.",
        captureHint: "Anderswo belegte Steuerelemente können nicht erkannt werden.",
        backButtonName: "Seitliche Zurück-Taste",
        forwardButtonName: "Seitliche Vorwärts-Taste",
        otherButtonFormat: "Taste %d",
        setShortcutButton: "Kurzbefehl festlegen",
        removeButton: "Entfernen",
        emptyCaption: "Noch keine Kurzbefehle. Füge eine Taste oder Richtung des seitlichen Rads hinzu.",
        rowWheelNote: "Diese Taste öffnet gerade das Radialmenü, der Kurzbefehl wartet daher.",
        manageButton: "Einrichten…",
        panelCaption: "Zusätzliche Maustasten und Richtungen des seitlichen Rads drücken Tastaturkurzbefehle deiner Wahl.",
        sideWheelLeftName: "Seitliches Rad nach links",
        sideWheelRightName: "Seitliches Rad nach rechts",
        spacesEnableLabel: "Maus-Navigationsgeste",
        spacesEnableCaption: "Halte eine Maustaste gedrückt, um zu navigieren.",
        spacesPickButton: "Taste wählen",
        spacesShortcutsOffNote: "Diese Geste kann Spaces nicht wechseln, weil die benötigten Tastaturkurzbefehle deaktiviert sind. Öffne Systemeinstellungen > Tastatur > Tastaturkurzbefehle > Mission Control und aktiviere den Wechsel zum linken und rechten Space.",
        spacesCaptureWaiting: "Drücke jetzt eine Zusatztaste.",
        spacesCaptureUnsupported: "Diese Eingabe lässt sich nicht gedrückt halten und ziehen. Verwende eine Zusatztaste.",
        spacesCaptureExists: "Diese Taste hat schon einen Kurzbefehl. Wähle eine andere.",
        spacesFollowsDragLabel: "Horizontale Ziehrichtung umkehren",
        spacesFollowsDragCaption: "Wenn aktiviert, wechselt Ziehen nach rechts zum Space links."
    )

    static let fr = MouseButtonFeatureStrings(
        pageTitle: "Raccourcis sur les boutons de la souris",
        hubDescription: "Les boutons supplémentaires et les directions de la molette latérale appuient sur une combinaison de touches de votre choix.",
        enableLabel: "Raccourcis souris personnalisés",
        enableCaption: "Attribuez des raccourcis clavier aux commandes de la souris.",
        addButton: "Ajouter un bouton ou la molette latérale",
        captureWaiting: "En attente d’une action de la souris…",
        captureCancel: "Annuler",
        captureBlind: "Lattice ne peut pas observer la souris pour le moment.",
        captureUnsupported: "Action de la souris non valide, essayez-en une autre.",
        captureWheel: "Ce bouton ouvre déjà le menu radial. Choisissez-en un autre, ou libérez-le là-bas d’abord.",
        captureExists: "Ce bouton ou cette direction est déjà dans la liste ci-dessous.",
        captureHint: "Les commandes attribuées ailleurs ne peuvent pas être détectées.",
        backButtonName: "Bouton latéral précédent",
        forwardButtonName: "Bouton latéral suivant",
        otherButtonFormat: "Bouton %d",
        setShortcutButton: "Définir le raccourci",
        removeButton: "Supprimer",
        emptyCaption: "Aucun raccourci pour l’instant. Ajoutez un bouton ou une direction de la molette latérale.",
        rowWheelNote: "Ce bouton ouvre le menu radial en ce moment, le raccourci attend donc.",
        manageButton: "Configurer…",
        panelCaption: "Les boutons supplémentaires et les directions de la molette latérale appuient sur des combinaisons de touches de votre choix.",
        sideWheelLeftName: "Molette latérale vers la gauche",
        sideWheelRightName: "Molette latérale vers la droite",
        spacesEnableLabel: "Geste de navigation à la souris",
        spacesEnableCaption: "Maintenez un bouton de la souris pour naviguer.",
        spacesPickButton: "Choisir un bouton",
        spacesShortcutsOffNote: "Ce geste ne peut pas changer d’espace, car les raccourcis nécessaires sont désactivés. Ouvrez Réglages Système > Clavier > Raccourcis clavier > Mission Control et activez le déplacement vers l’espace de gauche et de droite.",
        spacesCaptureWaiting: "Appuyez sur un bouton supplémentaire.",
        spacesCaptureUnsupported: "Cette commande ne peut pas être maintenue pour un glissement. Utilisez un bouton supplémentaire.",
        spacesCaptureExists: "Ce bouton a déjà un raccourci. Choisissez-en un autre.",
        spacesFollowsDragLabel: "Inverser le sens du glissement horizontal",
        spacesFollowsDragCaption: "Une fois activé, glisser vers la droite ouvre l’espace de gauche."
    )

    static let it = MouseButtonFeatureStrings(
        pageTitle: "Abbreviazioni sui pulsanti del mouse",
        hubDescription: "I pulsanti extra e le direzioni della rotella laterale premono una combinazione di tasti a tua scelta.",
        enableLabel: "Abbreviazioni mouse personalizzate",
        enableCaption: "Assegna abbreviazioni da tastiera ai controlli del mouse.",
        addButton: "Aggiungi pulsante o rotella laterale",
        captureWaiting: "In attesa di input dal mouse…",
        captureCancel: "Annulla",
        captureBlind: "Lattice al momento non riesce a osservare il mouse.",
        captureUnsupported: "Input del mouse non valido, provane un altro.",
        captureWheel: "Quel pulsante apre già il menu radiale. Scegline un altro, oppure liberalo prima lì.",
        captureExists: "Quel pulsante o quella direzione è già nell’elenco qui sotto.",
        captureHint: "I controlli assegnati altrove non possono essere rilevati.",
        backButtonName: "Pulsante laterale indietro",
        forwardButtonName: "Pulsante laterale avanti",
        otherButtonFormat: "Pulsante %d",
        setShortcutButton: "Imposta abbreviazione",
        removeButton: "Rimuovi",
        emptyCaption: "Ancora nessuna abbreviazione. Aggiungi un pulsante o una direzione della rotella laterale.",
        rowWheelNote: "Questo pulsante ora apre il menu radiale, quindi l’abbreviazione resta in attesa.",
        manageButton: "Configura…",
        panelCaption: "I pulsanti extra e le direzioni della rotella laterale premono combinazioni di tasti a tua scelta.",
        sideWheelLeftName: "Rotella laterale a sinistra",
        sideWheelRightName: "Rotella laterale a destra",
        spacesEnableLabel: "Gesto di navigazione con il mouse",
        spacesEnableCaption: "Tieni premuto un pulsante del mouse per navigare.",
        spacesPickButton: "Scegli un pulsante",
        spacesShortcutsOffNote: "Questo gesto non può cambiare spazio perché le abbreviazioni necessarie sono disattivate. Apri Impostazioni di Sistema > Tastiera > Abbreviazioni da tastiera > Mission Control e attiva il passaggio allo spazio a sinistra e a destra.",
        spacesCaptureWaiting: "Ora premi un pulsante extra.",
        spacesCaptureUnsupported: "Questo comando non si può tenere premuto per trascinare. Usa un pulsante extra.",
        spacesCaptureExists: "Quel pulsante ha già un’abbreviazione. Scegline un altro.",
        spacesFollowsDragLabel: "Inverti la direzione del trascinamento orizzontale",
        spacesFollowsDragCaption: "Se attivo, trascinando a destra passi allo spazio a sinistra."
    )

    static let ja = MouseButtonFeatureStrings(
        pageTitle: "マウスボタンのショートカット",
        hubDescription: "マウスの拡張ボタンとサイドホイールの左右に、選んだキーの組み合わせを割り当てられます。",
        enableLabel: "カスタムマウスショートカット",
        enableCaption: "マウスの操作にキーボードショートカットを割り当てます。",
        addButton: "ボタンまたはサイドホイールを追加",
        captureWaiting: "マウスの入力を待っています…",
        captureCancel: "キャンセル",
        captureBlind: "Latticeは今マウスを監視できません。",
        captureUnsupported: "無効なマウス入力です。別の操作を試してください。",
        captureWheel: "そのボタンはすでにラジアルメニューを開きます。別のボタンを選ぶか、先にそちらで解除してください。",
        captureExists: "そのボタンまたは方向はすでに下のリストにあります。",
        captureHint: "ほかで割り当てられている操作は検出できません。",
        backButtonName: "サイドの「戻る」ボタン",
        forwardButtonName: "サイドの「進む」ボタン",
        otherButtonFormat: "ボタン %d",
        setShortcutButton: "ショートカットを設定",
        removeButton: "削除",
        emptyCaption: "まだショートカットがありません。ボタンまたはサイドホイールの方向を追加してください。",
        rowWheelNote: "このボタンは今ラジアルメニューを開くため、ショートカットは待機中です。",
        manageButton: "設定…",
        panelCaption: "拡張ボタンとサイドホイールの左右が、選んだキーの組み合わせを押します。",
        sideWheelLeftName: "サイドホイールを左へ",
        sideWheelRightName: "サイドホイールを右へ",
        spacesEnableLabel: "マウスナビゲーションジェスチャ",
        spacesEnableCaption: "マウスボタンを押したままにしてナビゲートします。",
        spacesPickButton: "ボタンを選ぶ",
        spacesShortcutsOffNote: "必要なキーボードショートカットがオフのため、このジェスチャで操作スペースを切り替えられません。システム設定 > キーボード > キーボードショートカット > Mission Control で、左右の操作スペースに移動するショートカットをオンにしてください。",
        spacesCaptureWaiting: "拡張ボタンを押してください。",
        spacesCaptureUnsupported: "この入力は押したままドラッグできません。拡張ボタンを使ってください。",
        spacesCaptureExists: "そのボタンにはすでにショートカットがあります。別のボタンを選んでください。",
        spacesFollowsDragLabel: "横方向のドラッグを反転する",
        spacesFollowsDragCaption: "オンの場合、右にドラッグすると左の操作スペースに切り替わります。"
    )

    static let ko = MouseButtonFeatureStrings(
        pageTitle: "마우스 버튼 단축키",
        hubDescription: "마우스의 추가 버튼과 측면 휠 방향이 선택한 키 조합을 눌러 줍니다.",
        enableLabel: "사용자 지정 마우스 단축키",
        enableCaption: "마우스 조작에 키보드 단축키를 지정합니다.",
        addButton: "버튼 또는 측면 휠 추가",
        captureWaiting: "마우스 입력을 기다리는 중…",
        captureCancel: "취소",
        captureBlind: "Lattice가 지금은 마우스를 지켜볼 수 없습니다.",
        captureUnsupported: "잘못된 마우스 입력입니다. 다른 입력을 시도하세요.",
        captureWheel: "그 버튼은 이미 방사형 메뉴를 엽니다. 다른 버튼을 고르거나 먼저 거기서 해제하세요.",
        captureExists: "그 버튼이나 방향은 이미 아래 목록에 있습니다.",
        captureHint: "다른 곳에 할당된 조작은 감지할 수 없습니다.",
        backButtonName: "뒤로 가기 측면 버튼",
        forwardButtonName: "앞으로 가기 측면 버튼",
        otherButtonFormat: "버튼 %d",
        setShortcutButton: "단축키 설정",
        removeButton: "제거",
        emptyCaption: "아직 단축키가 없습니다. 버튼이나 측면 휠 방향을 추가하세요.",
        rowWheelNote: "이 버튼은 지금 방사형 메뉴를 열기 때문에 단축키는 대기합니다.",
        manageButton: "설정…",
        panelCaption: "추가 버튼과 측면 휠 방향이 선택한 키 조합을 누릅니다.",
        sideWheelLeftName: "측면 휠 왼쪽",
        sideWheelRightName: "측면 휠 오른쪽",
        spacesEnableLabel: "마우스 탐색 제스처",
        spacesEnableCaption: "마우스 버튼을 누른 채로 탐색합니다.",
        spacesPickButton: "버튼 선택",
        spacesShortcutsOffNote: "필요한 키보드 단축키가 꺼져 있어 이 제스처로 Spaces를 전환할 수 없습니다. 시스템 설정 > 키보드 > 키보드 단축키 > Mission Control에서 왼쪽 및 오른쪽 공간으로 이동하는 단축키를 켜세요.",
        spacesCaptureWaiting: "이제 추가 버튼을 누르세요.",
        spacesCaptureUnsupported: "이 입력은 누른 채 드래그할 수 없습니다. 추가 버튼을 사용하세요.",
        spacesCaptureExists: "그 버튼에는 이미 단축키가 있습니다. 다른 버튼을 고르세요.",
        spacesFollowsDragLabel: "가로 드래그 방향 반전",
        spacesFollowsDragCaption: "켜면 오른쪽으로 드래그할 때 왼쪽 Space로 전환됩니다."
    )

    static let zhHans = MouseButtonFeatureStrings(
        pageTitle: "鼠标按键快捷键",
        hubDescription: "鼠标的额外按键和侧滚轮方向会按下你选择的按键组合。",
        enableLabel: "自定鼠标快捷键",
        enableCaption: "为鼠标控件指定键盘快捷键。",
        addButton: "添加按键或侧滚轮",
        captureWaiting: "正在等待鼠标输入…",
        captureCancel: "取消",
        captureBlind: "Lattice 目前无法监听鼠标。",
        captureUnsupported: "鼠标输入无效，请换一个试试。",
        captureWheel: "该按键已用于打开径向菜单。请换一个，或先在那里释放它。",
        captureExists: "该按键或方向已在下方列表中。",
        captureHint: "无法检测已在其他地方指定的控件。",
        backButtonName: "侧面后退键",
        forwardButtonName: "侧面前进键",
        otherButtonFormat: "按键 %d",
        setShortcutButton: "设置快捷键",
        removeButton: "移除",
        emptyCaption: "还没有快捷键。请添加按键或侧滚轮方向。",
        rowWheelNote: "该按键目前用于打开径向菜单，快捷键暂不生效。",
        manageButton: "设置…",
        panelCaption: "额外按键和侧滚轮方向会按下你选择的按键组合。",
        sideWheelLeftName: "侧滚轮向左",
        sideWheelRightName: "侧滚轮向右",
        spacesEnableLabel: "鼠标导航手势",
        spacesEnableCaption: "按住鼠标按钮进行导航。",
        spacesPickButton: "选择一个按键",
        spacesShortcutsOffNote: "所需的键盘快捷键已关闭，此手势无法切换空间。请打开系统设置 > 键盘 > 键盘快捷键 > 调度中心，启用向左和向右移动一个空间的快捷键。",
        spacesCaptureWaiting: "现在请按下额外按键。",
        spacesCaptureUnsupported: "该输入无法按住拖动。请使用额外按键。",
        spacesCaptureExists: "该按键已设有快捷键。请换一个。",
        spacesFollowsDragLabel: "反转水平拖动方向",
        spacesFollowsDragCaption: "开启后，向右拖动会切换到左侧的空间。"
    )

    static let zhTW = MouseButtonFeatureStrings(
        pageTitle: "滑鼠按鍵快速鍵",
        hubDescription: "滑鼠的額外按鍵和側滾輪方向會按下你選擇的按鍵組合。",
        enableLabel: "自訂滑鼠快速鍵",
        enableCaption: "為滑鼠控制項指定鍵盤快速鍵。",
        addButton: "加入按鍵或側滾輪",
        captureWaiting: "正在等待滑鼠輸入…",
        captureCancel: "取消",
        captureBlind: "Lattice 目前無法監看滑鼠。",
        captureUnsupported: "滑鼠輸入無效，請換一個試試。",
        captureWheel: "該按鍵已用於打開放射狀選單。請換一個，或先在那裡釋放它。",
        captureExists: "該按鍵或方向已在下方列表中。",
        captureHint: "無法偵測已在其他地方指定的控制項。",
        backButtonName: "側面上一頁鍵",
        forwardButtonName: "側面下一頁鍵",
        otherButtonFormat: "按鍵 %d",
        setShortcutButton: "設定快速鍵",
        removeButton: "移除",
        emptyCaption: "還沒有快速鍵。請加入按鍵或側滾輪方向。",
        rowWheelNote: "該按鍵目前用於打開放射狀選單，快速鍵暫不生效。",
        manageButton: "設定…",
        panelCaption: "額外按鍵和側滾輪方向會按下你選擇的按鍵組合。",
        sideWheelLeftName: "側滾輪向左",
        sideWheelRightName: "側滾輪向右",
        spacesEnableLabel: "滑鼠導覽手勢",
        spacesEnableCaption: "按住滑鼠按鈕進行導覽。",
        spacesPickButton: "選擇一個按鍵",
        spacesShortcutsOffNote: "所需的鍵盤快速鍵已關閉，此手勢無法切換空間。請開啟系統設定 > 鍵盤 > 鍵盤快速鍵 > 指揮中心，啟用向左和向右移動一個空間的快速鍵。",
        spacesCaptureWaiting: "現在請按下額外按鍵。",
        spacesCaptureUnsupported: "此操作無法按住拖曳。請使用額外按鍵。",
        spacesCaptureExists: "該按鍵已設有快速鍵。請換一個。",
        spacesFollowsDragLabel: "反轉水平拖移方向",
        spacesFollowsDragCaption: "開啟後，向右拖移會切換到左側的空間。"
    )

    static let zhHK = MouseButtonFeatureStrings(
        pageTitle: "滑鼠按鍵快捷鍵",
        hubDescription: "滑鼠的額外按鍵和側滾輪方向會按下你選擇的按鍵組合。",
        enableLabel: "自訂滑鼠快速鍵",
        enableCaption: "為滑鼠控制項指定鍵盤快速鍵。",
        addButton: "加入按鍵或側滾輪",
        captureWaiting: "正在等待滑鼠輸入…",
        captureCancel: "取消",
        captureBlind: "Lattice 目前無法監看滑鼠。",
        captureUnsupported: "滑鼠輸入無效，請換一個試試。",
        captureWheel: "該按鍵已用於打開放射狀選單。請換一個，或先在那裡釋放它。",
        captureExists: "該按鍵或方向已在下方列表中。",
        captureHint: "無法偵測已在其他地方指定的控制項。",
        backButtonName: "側面上一頁鍵",
        forwardButtonName: "側面下一頁鍵",
        otherButtonFormat: "按鍵 %d",
        setShortcutButton: "設定快捷鍵",
        removeButton: "移除",
        emptyCaption: "還沒有快捷鍵。請加入按鍵或側滾輪方向。",
        rowWheelNote: "該按鍵目前用於打開放射狀選單，快捷鍵暫不生效。",
        manageButton: "設定…",
        panelCaption: "額外按鍵和側滾輪方向會按下你選擇的按鍵組合。",
        sideWheelLeftName: "側滾輪向左",
        sideWheelRightName: "側滾輪向右",
        spacesEnableLabel: "滑鼠導覽手勢",
        spacesEnableCaption: "按住滑鼠按鈕進行導覽。",
        spacesPickButton: "選擇一個按鍵",
        spacesShortcutsOffNote: "所需的鍵盤快捷鍵已關閉，此手勢無法切換空間。請開啟系統設定 > 鍵盤 > 鍵盤快捷鍵 > 指揮中心，啟用向左和向右移動一個空間的快捷鍵。",
        spacesCaptureWaiting: "現在請按下額外按鍵。",
        spacesCaptureUnsupported: "此操作無法按住拖曳。請使用額外按鍵。",
        spacesCaptureExists: "該按鍵已設有快捷鍵。請換一個。",
        spacesFollowsDragLabel: "反轉水平拖移方向",
        spacesFollowsDragCaption: "開啟後，向右拖移會切換到左側的空間。"
    )
    static let uk = MouseButtonFeatureStrings(
        pageTitle: "Клавіатурні скорочення кнопок миші",
        hubDescription: "Додаткові кнопки та напрямки бокового колеса натискають обране вами клавіатурне скорочення.",
        enableLabel: "Власні скорочення для миші",
        enableCaption: "Призначайте скорочення клавіш елементам керування миші.",
        addButton: "Додати кнопку або бокове колесо",
        captureWaiting: "Очікування введення з миші…",
        captureCancel: "Скасувати",
        captureBlind: "Lattice не може стежити за мишею зараз.",
        captureUnsupported: "Недійсне введення з миші, спробуйте інше.",
        captureWheel: "Ця кнопка вже відкриває радіальне меню. Виберіть іншу або спочатку звільніть її там.",
        captureExists: "Ця кнопка або напрямок вже є в списку нижче.",
        captureHint: "Елементи, призначені деінде, не розпізнаються.",
        backButtonName: "Задня бокова кнопка",
        forwardButtonName: "Передня бокова кнопка",
        otherButtonFormat: "Кнопка %d",
        setShortcutButton: "Призначити",
        removeButton: "Видалити",
        emptyCaption: "Ще немає клавіатурних скорочень. Додайте кнопку або напрямок бокового колеса.",
        rowWheelNote: "Ця кнопка зараз відкриває радіальне меню, тому клавіатурне скорочення недоступне.",
        manageButton: "Налаштувати…",
        panelCaption: "Додаткові кнопки та напрямки бокового колеса натискають обрані вами клавіатурні скорочення.",
        sideWheelLeftName: "Бокове колесо ліворуч",
        sideWheelRightName: "Бокове колесо праворуч",
        spacesEnableLabel: "Жест навігації мишею",
        spacesEnableCaption: "Утримуйте кнопку миші для навігації.",
        spacesPickButton: "Виберіть кнопку",
        spacesShortcutsOffNote: "Цей жест не може перемикати простори, оскільки потрібні клавіатурні скорочення вимкнені. Відкрийте Системні параметри > Клавіатура > Клавіатурні скорочення > Mission Control і ввімкніть перехід до простору ліворуч і праворуч.",
        spacesCaptureWaiting: "Тепер натисніть додаткову кнопку.",
        spacesCaptureUnsupported: "Це введення не можна утримувати для перетягування. Використовуйте додаткову кнопку.",
        spacesCaptureExists: "Ця кнопка вже має клавіатурне скорочення. Виберіть іншу.",
        spacesFollowsDragLabel: "Обернути напрямок горизонтального перетягування",
        spacesFollowsDragCaption: "Якщо ввімкнено, перетягування праворуч перемикає на Space ліворуч."
    )
}
