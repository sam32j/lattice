// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct NotchLockScreenStrings {
    /// The name System Settings gives its own Lock Screen pane.
    let title: String
    let show: String
    let showHint: String
    /// Beside the names of the agents working while the Mac is locked.
    let working: String
}

extension FeatureStrings {
    static func notchLockScreen(_ language: AppLanguage) -> NotchLockScreenStrings {
        switch language {
        case .enUS: return NotchLockScreenStrings(
            title: "Lock Screen",
            show: "Show on Lock Screen",
            showHint: "Music and the Dynamic Island’s activities, like a timer, AI agents, downloads and your next event, appear above the password field. Anyone who can see your screen can read them.",
            working: "Working")
        case .ptBR: return NotchLockScreenStrings(
            title: "Tela Bloqueada",
            show: "Mostrar na Tela Bloqueada",
            showHint: "A música e as atividades do Dynamic Island, como temporizador, agentes de IA, downloads e o próximo compromisso, aparecem acima do campo de senha. Quem puder ver sua tela também poderá lê-las.",
            working: "Trabalhando")
        case .es: return NotchLockScreenStrings(
            title: "Pantalla de bloqueo",
            show: "Mostrar en la pantalla de bloqueo",
            showHint: "La música y las actividades del Dynamic Island, como el temporizador, los agentes de IA, las descargas y tu próxima cita, aparecen sobre el campo de contraseña. Cualquiera que vea tu pantalla podrá leerlas.",
            working: "Trabajando")
        case .sk: return NotchLockScreenStrings(
            title: "Zamknutá obrazovka",
            show: "Zobraziť na zamknutej obrazovke",
            showHint: "Hudba a aktivity Dynamic Island, ako časovač, AI agenti, sťahovanie a vaše najbližšie stretnutie, sa zobrazia nad poľom na heslo. Prečíta si ich každý, kto vidí vašu obrazovku.",
            working: "Pracuje")
        case .de: return NotchLockScreenStrings(
            title: "Sperrbildschirm",
            show: "Auf dem Sperrbildschirm zeigen",
            showHint: "Musik und die Aktivitäten des Dynamic Island, etwa Timer, KI-Agenten, Downloads und dein nächster Termin, erscheinen über dem Passwortfeld. Wer deinen Bildschirm sieht, kann sie lesen.",
            working: "Arbeitet")
        case .fr: return NotchLockScreenStrings(
            title: "Écran verrouillé",
            show: "Afficher sur l’écran verrouillé",
            showHint: "La musique et les activités du Dynamic Island, comme le minuteur, les agents IA, les téléchargements et votre prochain rendez-vous, apparaissent au-dessus du champ du mot de passe. Toute personne qui voit votre écran peut les lire.",
            working: "En cours")
        case .it: return NotchLockScreenStrings(
            title: "Schermata di blocco",
            show: "Mostra nella schermata di blocco",
            showHint: "La musica e le attività del Dynamic Island, come timer, agenti IA, download e il prossimo appuntamento, appaiono sopra il campo della password. Chiunque veda il tuo schermo può leggerle.",
            working: "Al lavoro")
        case .ru: return NotchLockScreenStrings(
            title: "Экран блокировки",
            show: "Показывать на экране блокировки",
            showHint: "Музыка и активности из выреза экрана, например таймер, ИИ-агенты, загрузки и ближайшая встреча, появляются над полем пароля. Их может прочитать любой, кто видит ваш экран.",
            working: "Работает")
        case .tr: return NotchLockScreenStrings(
            title: "Kilitli Ekran",
            show: "Kilitli Ekranda göster",
            showHint: "Müzik ve çentikteki etkinlikler, örneğin zamanlayıcı, YZ ajanları, indirmeler ve sıradaki randevunuz, parola alanının üstünde görünür. Ekranınızı gören herkes bunları okuyabilir.",
            working: "Çalışıyor")
        case .ja: return NotchLockScreenStrings(
            title: "ロック画面",
            show: "ロック画面に表示",
            showHint: "音楽と、タイマー、AIエージェント、ダウンロード、次の予定などのDynamic Islandのアクティビティが、パスワード欄の上に表示されます。画面が見える人なら誰でも読めます。",
            working: "作業中")
        case .ko: return NotchLockScreenStrings(
            title: "잠금 화면",
            show: "잠금 화면에 표시",
            showHint: "음악과 타이머, AI 에이전트, 다운로드, 다음 일정 같은 Dynamic Island 활동이 암호 입력란 위에 나타납니다. 화면을 볼 수 있는 사람은 누구나 읽을 수 있습니다.",
            working: "작업 중")
        case .zhHans: return NotchLockScreenStrings(
            title: "锁屏",
            show: "在锁屏上显示",
            showHint: "音乐以及计时器、AI 智能体、下载和下一个日程等Dynamic Island活动会显示在密码栏上方。任何能看到你屏幕的人都能读到它们。",
            working: "工作中")
        case .zhTW: return NotchLockScreenStrings(
            title: "鎖定畫面",
            show: "在鎖定畫面上顯示",
            showHint: "音樂以及計時器、AI 代理、下載和下一個行程等Dynamic Island活動會顯示在密碼欄位上方。任何看得到你螢幕的人都能讀到。",
            working: "工作中")
        case .zhHK: return NotchLockScreenStrings(
            title: "鎖定畫面",
            show: "在鎖定畫面上顯示",
            showHint: "音樂以及計時器、AI 代理、下載和下一個行程等Dynamic Island活動會顯示在密碼欄位上方。任何看到你螢幕的人都能讀到。",
            working: "工作中")
        case .uk: return NotchLockScreenStrings(
            title: "Замкнений екран",
            show: "Показувати на замкненому екрані",
            showHint: "Музика й активності Dynamic Island, як-от таймер, ШІ-агенти, завантаження та найближча подія, з’являються над полем пароля. Їх може прочитати будь-хто, хто бачить ваш екран.",
            working: "Працює")
        }
    }
}
