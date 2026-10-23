import Foundation

enum PermissionResetCopy {
    enum Key: Int { case description, confirmation, restartTitle, restartDescription, restartButton }
    static func text(_ key: Key, _ language: AppLanguage) -> String {
        let values: [String]
        switch language {
        case .enUS: values = [
            "Reset permissions and disable Launch at login. Your preference settings will not reset.",
            "Reset permissions and disable Launch at login?",
            "Restart to complete the permissions reset.", "Restart Lattice for the reset to take effect.", "Restart now"]
        case .ptBR: values = ["Redefine as permissões e desativa a inicialização ao entrar. Suas preferências serão mantidas.",
            "Redefinir as permissões e desativar a inicialização ao entrar?", "Reinicie para concluir a redefinição das permissões.",
            "Reinicie o Lattice para aplicar a redefinição.", "Reiniciar agora"]
        case .es: values = ["Restablece los permisos y desactiva el inicio de sesión automático. Tus preferencias no se restablecerán.",
            "¿Restablecer los permisos y desactivar el inicio automático?", "Reinicia para completar el restablecimiento de permisos.",
            "Reinicia Lattice para aplicar el restablecimiento.", "Reiniciar ahora"]
        case .de: values = ["Setzt Berechtigungen zurück und deaktiviert den Start bei der Anmeldung. Deine Einstellungen bleiben erhalten.",
            "Berechtigungen zurücksetzen und den Start bei der Anmeldung deaktivieren?", "Zum Abschließen der Berechtigungsrücksetzung neu starten.",
            "Starte Lattice neu, damit die Rücksetzung wirksam wird.", "Jetzt neu starten"]
        case .fr: values = ["Réinitialise les autorisations et désactive le lancement à la connexion. Vos préférences seront conservées.",
            "Réinitialiser les autorisations et désactiver le lancement à la connexion ?", "Redémarrez pour terminer la réinitialisation des autorisations.",
            "Redémarrez Lattice pour appliquer la réinitialisation.", "Redémarrer"]
        case .it: values = ["Reimposta i permessi e disattiva l’avvio al login. Le preferenze saranno conservate.",
            "Reimpostare i permessi e disattivare l’avvio al login?", "Riavvia per completare la reimpostazione dei permessi.",
            "Riavvia Lattice per applicare la reimpostazione.", "Riavvia ora"]
        case .ja: values = ["アクセス権をリセットし、ログイン時の起動を無効にします。環境設定はリセットされません。",
            "アクセス権をリセットし、ログイン時の起動を無効にしますか？", "アクセス権のリセットを完了するには再起動してください。",
            "リセットを反映するには、Latticeを再起動してください。", "今すぐ再起動"]
        case .ko: values = ["권한을 초기화하고 로그인 시 실행을 끕니다. 환경설정은 유지됩니다.",
            "권한을 초기화하고 로그인 시 실행을 끌까요?", "권한 초기화를 완료하려면 재시작하세요.",
            "초기화를 적용하려면 Lattice를 재시작하세요.", "지금 재시작"]
        case .zhHans: values = ["重置权限并关闭登录时启动。你的偏好设置不会重置。", "重置权限并关闭登录时启动？",
            "重新启动以完成权限重置。", "重新启动 Lattice 以使重置生效。", "立即重新启动"]
        case .zhTW, .zhHK: values = ["重設權限並關閉登入時啟動。你的偏好設定不會重設。", "重設權限並關閉登入時啟動？",
            "重新啟動以完成權限重設。", "重新啟動 Lattice 以使重設生效。", "立即重新啟動"]
        case .ru: values = ["Сбрасывает разрешения и отключает запуск при входе. Ваши настройки сохранятся.",
            "Сбросить разрешения и отключить запуск при входе?", "Перезапустите приложение, чтобы завершить сброс разрешений.",
            "Перезапустите Lattice, чтобы сброс вступил в силу.", "Перезапустить"]
        case .uk: values = ["Скидає дозволи та вимикає запуск під час входу. Ваші налаштування збережуться.",
            "Скинути дозволи та вимкнути запуск під час входу?", "Перезапустіть програму, щоб завершити скидання дозволів.",
            "Перезапустіть Lattice, щоб скидання набуло чинності.", "Перезапустити"]
        case .tr: values = ["İzinleri sıfırlar ve oturum açılışında başlatmayı kapatır. Tercihleriniz sıfırlanmaz.",
            "İzinler sıfırlansın ve oturum açılışında başlatma kapatılsın mı?", "İzin sıfırlamayı tamamlamak için yeniden başlatın.",
            "Sıfırlamanın uygulanması için Lattice’i yeniden başlatın.", "Şimdi yeniden başlat"]
        case .sk: values = ["Obnoví povolenia a vypne spustenie pri prihlásení. Vaše nastavenia zostanú zachované.",
            "Obnoviť povolenia a vypnúť spustenie pri prihlásení?", "Obnovenie povolení dokončíte reštartovaním.",
            "Reštartujte Lattice, aby sa obnovenie prejavilo.", "Reštartovať teraz"]
        }
        return values[key.rawValue]
    }
}
