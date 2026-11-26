// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct NotchNotificationStrings {
    let title: String
    let description: String
    let privacy: String
    let empty: String
    let waiting: String
    let open: String
    let dismiss: String
    let clearAll: String
    let unavailable: String
    let hideSystemBanner: String
    let hideSystemBannerHint: String
}

extension FeatureStrings {
    static func notchNotifications(_ language: AppLanguage) -> NotchNotificationStrings {
        switch language {
        case .enUS: return NotchNotificationStrings(
            title: "Notifications",
            description: "New system notifications in the Dynamic Island.",
            privacy: "Show new visible banners only. Messages stay in memory and are cleared when you lock this Mac or turn this off.",
            empty: "New notifications will appear here",
            waiting: "Waiting for the system notification service",
            open: "Open",
            dismiss: "Dismiss",
            clearAll: "Clear All",
            unavailable: "This notification can no longer accept this action.",
            hideSystemBanner: "Hide the system banner",
            hideSystemBannerHint: "Hides the macOS banner while the Dynamic Island shows it. An app’s notifications appear here only while its desktop alerts are on in macOS.")
        case .ptBR: return NotchNotificationStrings(
            title: "Notificações",
            description: "Novas notificações do sistema no Dynamic Island.",
            privacy: "Mostre apenas os novos avisos visíveis. As mensagens ficam na memória e somem ao bloquear este Mac ou desligar o recurso.",
            empty: "As novas notificações vão aparecer aqui",
            waiting: "Aguardando as notificações do sistema",
            open: "Abrir",
            dismiss: "Dispensar",
            clearAll: "Limpar tudo",
            unavailable: "Esta notificação não aceita mais esta ação.",
            hideSystemBanner: "Esconder aviso do sistema",
            hideSystemBannerHint: "Esconde o aviso do macOS enquanto o Dynamic Island o mostra. As notificações de um app só aparecem aqui se os alertas na área de trabalho dele estiverem ativados no macOS.")
        case .es: return NotchNotificationStrings(
            title: "Notificaciones",
            description: "Nuevas notificaciones del sistema en el Dynamic Island.",
            privacy: "Muestra solo los avisos nuevos visibles. Los mensajes se guardan en memoria y se borran al bloquear este Mac o desactivar la función.",
            empty: "Las nuevas notificaciones aparecerán aquí",
            waiting: "Esperando las notificaciones del sistema",
            open: "Abrir",
            dismiss: "Descartar",
            clearAll: "Borrar todo",
            unavailable: "Esta notificación ya no admite esta acción.",
            hideSystemBanner: "Ocultar el aviso del sistema",
            hideSystemBannerHint: "Oculta el aviso de macOS mientras el Dynamic Island lo muestra. Las notificaciones de una app solo aparecen aquí si sus alertas de escritorio están activadas en macOS.")
        case .sk: return NotchNotificationStrings(
            title: "Hlásenia",
            description: "Nové systémové hlásenia v Dynamic Island.",
            privacy: "Zobrazuje iba nové viditeľné hlásenia. Správy zostávajú v pamäti a vymažú sa pri uzamknutí tohto Macu alebo pri vypnutí tejto funkcie.",
            empty: "Nové hlásenia sa zobrazia tu",
            waiting: "Čaká sa na systémovú službu hlásení",
            open: "Otvoriť",
            dismiss: "Zavrieť",
            clearAll: "Vymazať všetko",
            unavailable: "Toto hlásenie už túto akciu neumožňuje.",
            hideSystemBanner: "Skryť systémové hlásenie",
            hideSystemBannerHint: "Skryje hlásenie macOS, kým ho zobrazuje Dynamic Island. Hlásenia aplikácie sa tu zobrazia, len ak má v macOS zapnuté upozornenia na ploche.")
        case .de: return NotchNotificationStrings(
            title: "Mitteilungen",
            description: "Neue Systemmitteilungen im Dynamic Island.",
            privacy: "Zeigt nur neue sichtbare Hinweise. Nachrichten bleiben im Arbeitsspeicher und werden beim Sperren oder Ausschalten gelöscht.",
            empty: "Neue Mitteilungen erscheinen hier",
            waiting: "Warten auf den Mitteilungsdienst des Systems",
            open: "Öffnen",
            dismiss: "Verwerfen",
            clearAll: "Alle löschen",
            unavailable: "Diese Mitteilung unterstützt diese Aktion nicht mehr.",
            hideSystemBanner: "Systemhinweis ausblenden",
            hideSystemBannerHint: "Blendet den macOS-Hinweis aus, solange die Dynamic Island ihn zeigt. Mitteilungen einer App erscheinen hier nur, wenn ihre Schreibtisch-Hinweise in macOS aktiviert sind.")
        case .fr: return NotchNotificationStrings(
            title: "Notifications",
            description: "Les nouvelles notifications système dans le Dynamic Island.",
            privacy: "Affiche uniquement les nouvelles alertes visibles. Les messages restent en mémoire et sont effacés au verrouillage ou à la désactivation.",
            empty: "Les nouvelles notifications apparaîtront ici",
            waiting: "En attente du service de notifications système",
            open: "Ouvrir",
            dismiss: "Ignorer",
            clearAll: "Tout effacer",
            unavailable: "Cette notification ne permet plus cette action.",
            hideSystemBanner: "Masquer la bannière système",
            hideSystemBannerHint: "Masque la bannière de macOS pendant que la Dynamic Island l’affiche. Les notifications d’une app n’apparaissent ici que si ses alertes sur le bureau sont activées dans macOS.")
        case .it: return NotchNotificationStrings(
            title: "Notifiche",
            description: "Nuove notifiche di sistema nel Dynamic Island.",
            privacy: "Mostra solo i nuovi avvisi visibili. I messaggi restano in memoria e vengono cancellati al blocco o alla disattivazione.",
            empty: "Le nuove notifiche appariranno qui",
            waiting: "In attesa del servizio notifiche di sistema",
            open: "Apri",
            dismiss: "Ignora",
            clearAll: "Cancella tutto",
            unavailable: "Questa notifica non consente più questa azione.",
            hideSystemBanner: "Nascondi l’avviso di sistema",
            hideSystemBannerHint: "Nasconde l’avviso di macOS mentre il Dynamic Island lo mostra. Le notifiche di un’app compaiono qui solo se i suoi avvisi sulla scrivania sono attivi in macOS.")
        case .ru: return NotchNotificationStrings(
            title: "Уведомления",
            description: "Новые системные уведомления в вырезе экрана.",
            privacy: "Только новые видимые уведомления. Сообщения хранятся в памяти и удаляются при блокировке Mac или отключении функции.",
            empty: "Здесь появятся новые уведомления",
            waiting: "Ожидание службы системных уведомлений",
            open: "Открыть",
            dismiss: "Убрать",
            clearAll: "Очистить все",
            unavailable: "Это уведомление больше не поддерживает данное действие.",
            hideSystemBanner: "Скрывать системное уведомление",
            hideSystemBannerHint: "Скрывает баннер macOS, пока его показывает Dynamic Island. Уведомления приложения появляются здесь, только если в macOS для него включены уведомления на рабочем столе.")
        case .tr: return NotchNotificationStrings(
            title: "Bildirimler",
            description: "Yeni sistem bildirimleri çentikte.",
            privacy: "Yalnızca yeni ve görünür bildirimleri gösterir. Mesajlar bellekte kalır ve Mac kilitlendiğinde veya özellik kapatıldığında silinir.",
            empty: "Yeni bildirimler burada görünecek",
            waiting: "Sistem bildirim hizmeti bekleniyor",
            open: "Aç",
            dismiss: "Kapat",
            clearAll: "Tümünü temizle",
            unavailable: "Bu bildirim artık bu işlemi desteklemiyor.",
            hideSystemBanner: "Sistem bildirimini gizle",
            hideSystemBannerHint: "Dynamic Island gösterirken macOS bildirimini gizler. Bir uygulamanın bildirimleri burada yalnızca macOS’te masaüstü uyarıları açıksa görünür.")
        case .ja: return NotchNotificationStrings(
            title: "通知",
            description: "新しいシステム通知をDynamic Islandに表示します。",
            privacy: "新しく表示された通知のみを表示します。メッセージはメモリ内に保持され、Macのロック時や機能をオフにしたときに消去されます。",
            empty: "新しい通知がここに表示されます",
            waiting: "システムの通知サービスを待機中",
            open: "開く",
            dismiss: "閉じる",
            clearAll: "すべて消去",
            unavailable: "この通知では、この操作を実行できなくなりました。",
            hideSystemBanner: "システムの通知を隠す",
            hideSystemBannerHint: "Dynamic Islandに表示している間、macOSのバナーを隠します。アプリの通知は、macOSでそのアプリのデスクトップ通知がオンのときだけここに表示されます。")
        case .ko: return NotchNotificationStrings(
            title: "알림",
            description: "새 시스템 알림을 Dynamic Island에서 확인하세요.",
            privacy: "새로 표시된 알림만 보여줍니다. 메시지는 메모리에 보관되며 Mac을 잠그거나 기능을 끄면 지워집니다.",
            empty: "새 알림이 여기에 표시됩니다",
            waiting: "시스템 알림 서비스를 기다리는 중",
            open: "열기",
            dismiss: "닫기",
            clearAll: "모두 지우기",
            unavailable: "이 알림에서는 더 이상 이 동작을 사용할 수 없습니다.",
            hideSystemBanner: "시스템 알림 숨기기",
            hideSystemBannerHint: "Dynamic Island에 표시되는 동안 macOS 배너를 숨깁니다. 앱 알림은 macOS에서 해당 앱의 데스크탑 알림이 켜져 있을 때만 여기에 표시됩니다.")
        case .zhHans: return NotchNotificationStrings(
            title: "通知",
            description: "在Dynamic Island中查看新的系统通知。",
            privacy: "仅显示新出现的通知。消息只保存在内存中，锁定此 Mac 或关闭功能时会清除。",
            empty: "新通知将显示在这里",
            waiting: "正在等待系统通知服务",
            open: "打开",
            dismiss: "忽略",
            clearAll: "全部清除",
            unavailable: "此通知已无法执行此操作。",
            hideSystemBanner: "隐藏系统通知",
            hideSystemBannerHint: "在 Dynamic Island 中显示时隐藏 macOS 横幅。只有在 macOS 中为 App 开启桌面提醒，它的通知才会显示在这里。")
        case .zhTW: return NotchNotificationStrings(
            title: "通知",
            description: "在Dynamic Island中查看新的系統通知。",
            privacy: "只顯示新出現的通知。訊息僅保留在記憶體中，鎖定這部 Mac 或關閉功能時會清除。",
            empty: "新通知會顯示在這裡",
            waiting: "正在等待系統通知服務",
            open: "打開",
            dismiss: "關閉",
            clearAll: "全部清除",
            unavailable: "此通知已無法執行此操作。",
            hideSystemBanner: "隱藏系統通知",
            hideSystemBannerHint: "在 Dynamic Island 中顯示時隱藏 macOS 橫幅。只有在 macOS 中為 App 開啟桌面提示，它的通知才會顯示在這裡。")
        case .zhHK: return NotchNotificationStrings(
            title: "通知",
            description: "在Dynamic Island中查看新的系統通知。",
            privacy: "只顯示新出現的通知。訊息只保留在記憶體中，鎖定此 Mac 或關閉功能時會清除。",
            empty: "新通知會顯示在這裏",
            waiting: "正在等候系統通知服務",
            open: "開啟",
            dismiss: "關閉",
            clearAll: "全部清除",
            unavailable: "此通知已無法執行此操作。",
            hideSystemBanner: "隱藏系統通知",
            hideSystemBannerHint: "喺 Dynamic Island 顯示時隱藏 macOS 橫幅。只有喺 macOS 為 App 開啟桌面提示，佢嘅通知先會喺呢度顯示。")
        case .uk: return NotchNotificationStrings(
            title: "Сповіщення",
            description: "Нові системні сповіщення у Dynamic Island.",
            privacy: "Показує лише нові видимі банери. Повідомлення залишаються в пам’яті та очищаються, коли ви блокуєте цей Mac або вимикаєте цю функцію.",
            empty: "Нові сповіщення з’являться тут",
            waiting: "Очікування на службу системних сповіщень",
            open: "Відкрити",
            dismiss: "Відхилити",
            clearAll: "Очистити все",
            unavailable: "Це сповіщення більше не підтримує цю дію.",
            hideSystemBanner: "Приховувати системний банер",
            hideSystemBannerHint: "Приховує банер macOS, поки його показує Dynamic Island. Сповіщення програми з’являються тут, лише якщо в macOS для неї ввімкнено сповіщення на робочому столі.")
        }
    }
}
