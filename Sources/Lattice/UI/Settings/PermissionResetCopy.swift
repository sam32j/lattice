import Foundation

enum PermissionResetCopy {
    enum Key: Int { case description, confirmation, restartTitle, restartDescription, restartButton, clearTitle, clearButton }
    static func text(_ key: Key, _ language: AppLanguage) -> String {
        let values: [String]
        switch language {
        case .enUS: values = [
            "Reset permissions and stop Launch at login. Some permission-dependent settings will turn off.",
            "Reset permissions and stop launch at login? Some of the features may stop working.",
            "Restart Lattice", "Restart Lattice to finish permission reset.", "Restart",
            "Clear All Permissions", "Clear"]
        case .ptBR: values = ["Redefine as permissões e desativa a inicialização ao entrar. Suas preferências serão mantidas.",
            "Redefinir as permissões e desativar a inicialização ao entrar?", "Reiniciar Lattice",
            "Reinicie o Lattice para aplicar a redefinição.", "Reiniciar agora",
            "Limpar todas as permissões", "Limpar"]
        case .es: values = ["Restablece los permisos y desactiva el inicio de sesión automático. Tus preferencias no se restablecerán.",
            "¿Restablecer los permisos y desactivar el inicio automático?", "Reiniciar Lattice",
            "Reinicia Lattice para aplicar el restablecimiento.", "Reiniciar ahora",
            "Borrar todos los permisos", "Borrar"]
        case .de: values = ["Setzt Berechtigungen zurück und deaktiviert den Start bei der Anmeldung. Deine Einstellungen bleiben erhalten.",
            "Berechtigungen zurücksetzen und den Start bei der Anmeldung deaktivieren?", "Lattice neu starten",
            "Starte Lattice neu, damit die Rücksetzung wirksam wird.", "Jetzt neu starten",
            "Alle Berechtigungen löschen", "Löschen"]
        case .fr: values = ["Réinitialise les autorisations et désactive le lancement à la connexion. Vos préférences seront conservées.",
            "Réinitialiser les autorisations et désactiver le lancement à la connexion ?", "Redémarrer Lattice",
            "Redémarrez Lattice pour appliquer la réinitialisation.", "Redémarrer",
            "Effacer toutes les autorisations", "Effacer"]
        case .it: values = ["Reimposta i permessi e disattiva l’avvio al login. Le preferenze saranno conservate.",
            "Reimpostare i permessi e disattivare l’avvio al login?", "Riavvia Lattice",
            "Riavvia Lattice per applicare la reimpostazione.", "Riavvia ora",
            "Cancella tutti i permessi", "Cancella"]
        case .ja: values = ["アクセス権をリセットし、ログイン時の起動を無効にします。環境設定はリセットされません。",
            "アクセス権をリセットし、ログイン時の起動を無効にしますか？", "Latticeを再起動",
            "リセットを反映するには、Latticeを再起動してください。", "今すぐ再起動",
            "すべてのアクセス権を消去", "消去"]
        case .ko: values = ["권한을 초기화하고 로그인 시 실행을 끕니다. 환경설정은 유지됩니다.",
            "권한을 초기화하고 로그인 시 실행을 끌까요?", "Lattice 재시작",
            "초기화를 적용하려면 Lattice를 재시작하세요.", "지금 재시작",
            "모든 권한 지우기", "지우기"]
        case .zhHans: values = ["重置权限并关闭登录时启动。你的偏好设置不会重置。", "重置权限并关闭登录时启动？",
            "重新启动 Lattice", "重新启动 Lattice 以使重置生效。", "立即重新启动",
            "清除所有权限", "清除"]
        case .zhTW, .zhHK: values = ["重設權限並關閉登入時啟動。你的偏好設定不會重設。", "重設權限並關閉登入時啟動？",
            "重新啟動 Lattice", "重新啟動 Lattice 以使重設生效。", "立即重新啟動",
            "清除所有權限", "清除"]
        case .ru: values = ["Сбрасывает разрешения и отключает запуск при входе. Ваши настройки сохранятся.",
            "Сбросить разрешения и отключить запуск при входе?", "Перезапустить Lattice",
            "Перезапустите Lattice, чтобы сброс вступил в силу.", "Перезапустить",
            "Очистить все разрешения", "Очистить"]
        case .uk: values = ["Скидає дозволи та вимикає запуск під час входу. Ваші налаштування збережуться.",
            "Скинути дозволи та вимкнути запуск під час входу?", "Перезапустити Lattice",
            "Перезапустіть Lattice, щоб скидання набуло чинності.", "Перезапустити",
            "Очистити всі дозволи", "Очистити"]
        case .tr: values = ["İzinleri sıfırlar ve oturum açılışında başlatmayı kapatır. Tercihleriniz sıfırlanmaz.",
            "İzinler sıfırlansın ve oturum açılışında başlatma kapatılsın mı?", "Lattice’i yeniden başlat",
            "Sıfırlamanın uygulanması için Lattice’i yeniden başlatın.", "Şimdi yeniden başlat",
            "Tüm İzinleri Temizle", "Temizle"]
        case .sk: values = ["Obnoví povolenia a vypne spustenie pri prihlásení. Vaše nastavenia zostanú zachované.",
            "Obnoviť povolenia a vypnúť spustenie pri prihlásení?", "Reštartovať Lattice",
            "Reštartujte Lattice, aby sa obnovenie prejavilo.", "Reštartovať teraz",
            "Vymazať všetky povolenia", "Vymazať"]
        }
        return values[key.rawValue]
    }
}
