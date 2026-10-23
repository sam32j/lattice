// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

struct FeedbackDraftStrings {
    let button: String
    let privacy: String
    let review: String
    let opened: String
    let openedCaption: String
    let error: String
    let tooLong: String

    static func text(_ language: AppLanguage) -> Self {
        let values: [String]
        switch language {
        case .enUS: values = [
            "Continue on GitHub", "GitHub sign-in is required. Submitted issues are public and linked to your GitHub account. Do not include secrets or security vulnerabilities.",
            "Review and submit on GitHub. The draft text is included in the URL and may remain in browser history. Nothing is posted automatically.",
            "GitHub draft opened", "Your feedback has not been submitted. Review the draft in your browser, add a descriptive title, then submit it on GitHub.",
            "Could not open the GitHub draft. Your text is still here. Try again.", "This draft is too long for a GitHub URL. Shorten the message or turn off technical details. Your text is still here."]
        case .ptBR: values = [
            "Continuar no GitHub", "É preciso entrar no GitHub. As issues enviadas são públicas e vinculadas à sua conta. Não inclua segredos nem vulnerabilidades de segurança.",
            "Revise e envie no GitHub. O texto fica na URL e pode permanecer no histórico do navegador. Nada é publicado automaticamente.",
            "Rascunho aberto no GitHub", "O feedback ainda não foi enviado. Revise o rascunho no navegador, adicione um título descritivo e envie no GitHub.",
            "Não foi possível abrir o rascunho. Seu texto foi mantido. Tente novamente.", "Rascunho longo demais para a URL. Reduza o texto ou desative os detalhes técnicos. Seu texto foi mantido."]
        case .tr: values = [
            "GitHub’da devam et", "GitHub’a giriş gerekir. Gönderilen sorunlar herkese açıktır ve hesabınızla ilişkilendirilir. Gizli bilgi veya güvenlik açığı eklemeyin.",
            "GitHub’da inceleyip gönderin. Taslak metni URL’de bulunur ve tarayıcı geçmişinde kalabilir. Otomatik paylaşım yapılmaz.",
            "GitHub taslağı açıldı", "Geri bildirim henüz gönderilmedi. Tarayıcıda inceleyin, açıklayıcı bir başlık ekleyin ve GitHub’da gönderin.",
            "Taslak açılamadı. Metniniz burada duruyor. Tekrar deneyin.", "Taslak URL için çok uzun. Metni kısaltın veya teknik ayrıntıları kapatın. Metniniz korundu."]
        case .ru: values = [
            "Продолжить на GitHub", "Нужен вход в GitHub. Отправленные обращения публичны и связаны с вашим аккаунтом. Не включайте секреты и уязвимости.",
            "Проверьте и отправьте на GitHub. Текст включён в URL и может остаться в истории браузера. Автоматической публикации нет.",
            "Черновик GitHub открыт", "Отзыв ещё не отправлен. Проверьте черновик в браузере, добавьте понятный заголовок и отправьте на GitHub.",
            "Не удалось открыть черновик. Текст сохранён здесь. Попробуйте снова.", "Черновик слишком длинный для URL. Сократите текст или отключите технические данные. Текст сохранён."]
        case .es: values = [
            "Continuar en GitHub", "Debes iniciar sesión en GitHub. Las incidencias enviadas son públicas y se vinculan a tu cuenta. No incluyas secretos ni vulnerabilidades.",
            "Revisa y envía en GitHub. El texto se incluye en la URL y puede quedar en el historial. No se publica nada automáticamente.",
            "Borrador abierto en GitHub", "Tu comentario aún no se ha enviado. Revisa el borrador en el navegador, añade un título descriptivo y envíalo en GitHub.",
            "No se pudo abrir el borrador. Tu texto sigue aquí. Inténtalo de nuevo.", "El borrador es demasiado largo para la URL. Acorta el texto o desactiva los detalles técnicos. Tu texto se conserva."]
        case .sk: values = [
            "Pokračovať na GitHube", "Vyžaduje sa prihlásenie do GitHubu. Odoslané hlásenia sú verejné a spojené s vaším účtom. Neuvádzajte tajné údaje ani zraniteľnosti.",
            "Skontrolujte a odošlite na GitHube. Text je súčasťou URL a môže zostať v histórii prehliadača. Nič sa nezverejní automaticky.",
            "Koncept na GitHube otvorený", "Spätná väzba ešte nebola odoslaná. Skontrolujte koncept, pridajte výstižný názov a odošlite ho na GitHube.",
            "Koncept sa nepodarilo otvoriť. Text zostal tu. Skúste znova.", "Koncept je pre URL príliš dlhý. Skráťte text alebo vypnite technické údaje. Text zostal zachovaný."]
        case .de: values = [
            "Auf GitHub fortfahren", "Eine GitHub-Anmeldung ist erforderlich. Eingereichte Issues sind öffentlich und mit deinem Konto verknüpft. Keine Geheimnisse oder Sicherheitslücken angeben.",
            "Auf GitHub prüfen und absenden. Der Text steht in der URL und kann im Browserverlauf bleiben. Nichts wird automatisch veröffentlicht.",
            "GitHub-Entwurf geöffnet", "Dein Feedback wurde noch nicht eingereicht. Prüfe den Entwurf im Browser, ergänze einen aussagekräftigen Titel und sende ihn auf GitHub ab.",
            "Der Entwurf konnte nicht geöffnet werden. Dein Text bleibt erhalten. Versuche es erneut.", "Der Entwurf ist zu lang für die URL. Kürze den Text oder deaktiviere technische Details. Dein Text bleibt erhalten."]
        case .fr: values = [
            "Continuer sur GitHub", "Une connexion à GitHub est nécessaire. Les tickets envoyés sont publics et liés à votre compte. N’incluez aucun secret ni faille de sécurité.",
            "Vérifiez et envoyez sur GitHub. Le texte figure dans l’URL et peut rester dans l’historique du navigateur. Rien n’est publié automatiquement.",
            "Brouillon GitHub ouvert", "Votre retour n’a pas encore été envoyé. Vérifiez le brouillon, ajoutez un titre descriptif, puis envoyez-le sur GitHub.",
            "Impossible d’ouvrir le brouillon. Votre texte est conservé. Réessayez.", "Le brouillon est trop long pour l’URL. Raccourcissez-le ou désactivez les détails techniques. Votre texte est conservé."]
        case .it: values = [
            "Continua su GitHub", "È necessario accedere a GitHub. Le segnalazioni inviate sono pubbliche e associate al tuo account. Non includere segreti o vulnerabilità.",
            "Controlla e invia su GitHub. Il testo è incluso nell’URL e può restare nella cronologia. Nulla viene pubblicato automaticamente.",
            "Bozza GitHub aperta", "Il feedback non è ancora stato inviato. Controlla la bozza nel browser, aggiungi un titolo descrittivo e inviala su GitHub.",
            "Impossibile aprire la bozza. Il testo è conservato. Riprova.", "La bozza è troppo lunga per l’URL. Accorcia il testo o disattiva i dettagli tecnici. Il testo è conservato."]
        case .ja: values = [
            "GitHubで続ける", "GitHubへのログインが必要です。送信したIssueは公開され、アカウントに紐づきます。秘密情報や脆弱性を含めないでください。",
            "GitHubで確認して送信します。本文はURLに含まれ、ブラウザの履歴に残る場合があります。自動では投稿されません。",
            "GitHubの下書きを開きました", "まだ送信されていません。ブラウザで下書きを確認し、内容が分かるタイトルを付けてGitHubで送信してください。",
            "下書きを開けませんでした。入力した内容は保持されています。再試行してください。", "URLに含めるには長すぎます。本文を短くするか、技術情報をオフにしてください。入力内容は保持されています。"]
        case .ko: values = [
            "GitHub에서 계속", "GitHub 로그인이 필요합니다. 제출한 이슈는 공개되며 계정과 연결됩니다. 비밀 정보나 보안 취약점을 포함하지 마세요.",
            "GitHub에서 검토 후 제출하세요. 내용은 URL에 포함되며 브라우저 기록에 남을 수 있습니다. 자동으로 게시되지 않습니다.",
            "GitHub 초안을 열었습니다", "아직 제출되지 않았습니다. 브라우저에서 초안을 확인하고 내용을 설명하는 제목을 추가한 뒤 GitHub에서 제출하세요.",
            "초안을 열 수 없습니다. 입력한 내용은 유지됩니다. 다시 시도하세요.", "URL에 담기에는 초안이 너무 깁니다. 내용을 줄이거나 기술 정보를 끄세요. 입력 내용은 유지됩니다."]
        case .zhHans: values = [
            "在 GitHub 上继续", "需要登录 GitHub。提交的议题会公开并关联到你的 GitHub 账户。请勿包含机密信息或安全漏洞。",
            "在 GitHub 上检查并提交。草稿内容会包含在网址中，可能留在浏览器历史记录里。不会自动发布。",
            "已打开 GitHub 草稿", "反馈尚未提交。请在浏览器中检查草稿，添加清晰的标题，然后在 GitHub 上提交。",
            "无法打开草稿。输入的内容仍然保留，请重试。", "草稿过长，无法放入 GitHub 网址。请缩短内容或关闭技术信息。输入内容仍然保留。"]
        case .zhTW: values = [
            "在 GitHub 上繼續", "需要登入 GitHub。提交的議題會公開並連結至你的 GitHub 帳號。請勿包含機密資訊或安全漏洞。",
            "在 GitHub 上檢查並提交。草稿內容會包含在網址中，可能留在瀏覽器歷史紀錄裡。不會自動發布。",
            "已開啟 GitHub 草稿", "意見尚未提交。請在瀏覽器中檢查草稿，加入清楚的標題，然後在 GitHub 上提交。",
            "無法開啟草稿。輸入的內容仍然保留，請再試一次。", "草稿過長，無法放入 GitHub 網址。請縮短內容或關閉技術資訊。輸入內容仍然保留。"]
        case .zhHK: values = [
            "在 GitHub 上繼續", "需要登入 GitHub。提交的議題會公開並連結至你的 GitHub 帳戶。請勿包含機密資料或安全漏洞。",
            "在 GitHub 上檢查並提交。草稿內容會包含在網址中，可能留在瀏覽器記錄。不會自動發佈。",
            "已開啟 GitHub 草稿", "意見尚未提交。請在瀏覽器檢查草稿，加入清晰的標題，然後在 GitHub 上提交。",
            "無法開啟草稿。輸入的內容仍然保留，請重試。", "草稿太長，無法放入 GitHub 網址。請縮短內容或關閉技術資料。輸入內容仍然保留。"]
        case .uk: values = [
            "Продовжити на GitHub", "Потрібно ввійти в GitHub. Надіслані звернення публічні та пов’язані з вашим обліковим записом. Не додавайте секретів чи вразливостей.",
            "Перевірте й надішліть на GitHub. Текст входить до URL і може залишитися в історії браузера. Нічого не публікується автоматично.",
            "Чернетку GitHub відкрито", "Відгук ще не надіслано. Перевірте чернетку в браузері, додайте змістовний заголовок і надішліть на GitHub.",
            "Не вдалося відкрити чернетку. Текст збережено тут. Спробуйте знову.", "Чернетка задовга для URL. Скоротіть текст або вимкніть технічні дані. Текст збережено."]
        }
        return Self(button: values[0], privacy: values[1], review: values[2], opened: values[3],
                    openedCaption: values[4], error: values[5], tooLong: values[6])
    }
}
