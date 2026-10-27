// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

enum VideoDownloaderLocalizationTests {
    static func run(_ suite: TestSuite) {
        testAllLanguagesNonEmpty(suite)
        testFormattersAcrossLanguages(suite)
        testExactKeyTranslations(suite)
        testDynamicLanguageReactivity(suite)
    }

    private static func testAllLanguagesNonEmpty(_ suite: TestSuite) {
        suite.expect(AppLanguage.allCases.count == 15, "Lattice defines exactly 15 supported languages")

        for lang in AppLanguage.allCases {
            let s = FeatureStrings.videoDownloader(lang)

            // Page & Enablement
            suite.expect(!s.pageTitle.isEmpty, "\(lang.rawValue): pageTitle is non-empty")
            suite.expect(!s.enableTitle.isEmpty, "\(lang.rawValue): enableTitle is non-empty")
            suite.expect(!s.enableSubtitle.isEmpty, "\(lang.rawValue): enableSubtitle is non-empty")

            // Download video section
            suite.expect(!s.downloadVideoSectionTitle.isEmpty, "\(lang.rawValue): downloadVideoSectionTitle is non-empty")
            suite.expect(!s.downloadVideoSectionSubtitle.isEmpty, "\(lang.rawValue): downloadVideoSectionSubtitle is non-empty")
            suite.expect(!s.urlPlaceholder.isEmpty, "\(lang.rawValue): urlPlaceholder is non-empty")
            suite.expect(!s.search.isEmpty, "\(lang.rawValue): search is non-empty")
            suite.expect(!s.clear.isEmpty, "\(lang.rawValue): clear is non-empty")
            suite.expect(!s.paste.isEmpty, "\(lang.rawValue): paste is non-empty")
            suite.expect(!s.pasteClipboardURL.isEmpty, "\(lang.rawValue): pasteClipboardURL is non-empty")
            suite.expect(!s.searchClipboardURL.isEmpty, "\(lang.rawValue): searchClipboardURL is non-empty")

            // Preview & Options
            suite.expect(!s.quality.isEmpty, "\(lang.rawValue): quality is non-empty")
            suite.expect(!s.saveTo.isEmpty, "\(lang.rawValue): saveTo is non-empty")
            suite.expect(!s.defaultFolder.isEmpty, "\(lang.rawValue): defaultFolder is non-empty")
            suite.expect(!s.bestQuality.isEmpty, "\(lang.rawValue): bestQuality is non-empty")
            suite.expect(!s.audioQuality.isEmpty, "\(lang.rawValue): audioQuality is non-empty")
            suite.expect(!s.savesToFormat.isEmpty && s.savesToFormat.contains("%@"),
                         "\(lang.rawValue): savesToFormat contains '%@' format placeholder")

            // Download actions & state
            suite.expect(!s.fetchingDetails.isEmpty, "\(lang.rawValue): fetchingDetails is non-empty")
            suite.expect(!s.downloading.isEmpty, "\(lang.rawValue): downloading is non-empty")
            suite.expect(!s.paused.isEmpty, "\(lang.rawValue): paused is non-empty")
            suite.expect(!s.downloadComplete.isEmpty, "\(lang.rawValue): downloadComplete is non-empty")
            suite.expect(!s.downloadFailed.isEmpty, "\(lang.rawValue): downloadFailed is non-empty")
            suite.expect(!s.downloadAgain.isEmpty, "\(lang.rawValue): downloadAgain is non-empty")
            suite.expect(!s.finishingVideo.isEmpty, "\(lang.rawValue): finishingVideo is non-empty")
            suite.expect(!s.pause.isEmpty, "\(lang.rawValue): pause is non-empty")
            suite.expect(!s.resume.isEmpty, "\(lang.rawValue): resume is non-empty")
            suite.expect(!s.cancel.isEmpty, "\(lang.rawValue): cancel is non-empty")
            suite.expect(!s.download.isEmpty, "\(lang.rawValue): download is non-empty")
            suite.expect(!s.retry.isEmpty, "\(lang.rawValue): retry is non-empty")

            // Recent section
            suite.expect(!s.recent.isEmpty, "\(lang.rawValue): recent is non-empty")
            suite.expect(!s.clearHistory.isEmpty, "\(lang.rawValue): clearHistory is non-empty")
            suite.expect(!s.showInFinder.isEmpty, "\(lang.rawValue): showInFinder is non-empty")

            // Error notices & warnings
            suite.expect(!s.fetchFailedNotice.isEmpty, "\(lang.rawValue): fetchFailedNotice is non-empty")
            suite.expect(!s.featureDisabledNotice.isEmpty, "\(lang.rawValue): featureDisabledNotice is non-empty")
            suite.expect(!s.invalidURL.isEmpty, "\(lang.rawValue): invalidURL is non-empty")
            suite.expect(!s.unsupportedMetadata.isEmpty, "\(lang.rawValue): unsupportedMetadata is non-empty")
            suite.expect(!s.missingTools.isEmpty, "\(lang.rawValue): missingTools is non-empty")
            suite.expect(!s.invalidOutput.isEmpty, "\(lang.rawValue): invalidOutput is non-empty")
            suite.expect(!s.timedOut.isEmpty, "\(lang.rawValue): timedOut is non-empty")
            suite.expect(!s.denoRequired.isEmpty, "\(lang.rawValue): denoRequired is non-empty")
            suite.expect(!s.singleVideoOnlyNotice.isEmpty, "\(lang.rawValue): singleVideoOnlyNotice is non-empty")
            suite.expect(!s.loginRequiredNotice.isEmpty, "\(lang.rawValue): loginRequiredNotice is non-empty")
            suite.expect(!s.noAccessNotice.isEmpty, "\(lang.rawValue): noAccessNotice is non-empty")
            suite.expect(!s.manageSessions.isEmpty, "\(lang.rawValue): manageSessions is non-empty")
            suite.expect(!s.tryDifferentSessions.isEmpty, "\(lang.rawValue): tryDifferentSessions is non-empty")

            // Toolchain & Components setup
            suite.expect(!s.missingToolsTitle.isEmpty, "\(lang.rawValue): missingToolsTitle is non-empty")
            suite.expect(!s.missingToolsBody.isEmpty, "\(lang.rawValue): missingToolsBody is non-empty")
            suite.expect(!s.downloadRequiredTitle.isEmpty, "\(lang.rawValue): downloadRequiredTitle is non-empty")
            suite.expect(!s.downloadRequiredBody.isEmpty, "\(lang.rawValue): downloadRequiredBody is non-empty")
            suite.expect(!s.continueAction.isEmpty, "\(lang.rawValue): continueAction is non-empty")
            suite.expect(!s.installComponentsTitle.isEmpty, "\(lang.rawValue): installComponentsTitle is non-empty")
            suite.expect(!s.installComponentsSubtitle.isEmpty, "\(lang.rawValue): installComponentsSubtitle is non-empty")
            suite.expect(!s.keepOff.isEmpty, "\(lang.rawValue): keepOff is non-empty")
            suite.expect(!s.install.isEmpty, "\(lang.rawValue): install is non-empty")
            suite.expect(!s.installationFailed.isEmpty, "\(lang.rawValue): installationFailed is non-empty")
            suite.expect(!s.gettingReady.isEmpty, "\(lang.rawValue): gettingReady is non-empty")
            suite.expect(!s.gettingReadySubtitle.isEmpty, "\(lang.rawValue): gettingReadySubtitle is non-empty")
            suite.expect(!s.repairTitle.isEmpty, "\(lang.rawValue): repairTitle is non-empty")
            suite.expect(!s.repairSubtitle.isEmpty, "\(lang.rawValue): repairSubtitle is non-empty")
            suite.expect(!s.repairAction.isEmpty, "\(lang.rawValue): repairAction is non-empty")
            suite.expect(!s.technicalDetails.isEmpty, "\(lang.rawValue): technicalDetails is non-empty")
            suite.expect(!s.advanced.isEmpty, "\(lang.rawValue): advanced is non-empty")
            suite.expect(!s.useSystemTools.isEmpty, "\(lang.rawValue): useSystemTools is non-empty")
            suite.expect(!s.checkUpdates.isEmpty, "\(lang.rawValue): checkUpdates is non-empty")

            // Browser session child setting & dialog
            suite.expect(!s.browserSessionTitle.isEmpty, "\(lang.rawValue): browserSessionTitle is non-empty")
            suite.expect(!s.browserSignInDescription.isEmpty, "\(lang.rawValue): browserSignInDescription is non-empty")
            suite.expect(!s.inactive.isEmpty, "\(lang.rawValue): inactive is non-empty")
            suite.expect(!s.manage.isEmpty, "\(lang.rawValue): manage is non-empty")
            suite.expect(!s.browserSectionLabel.isEmpty, "\(lang.rawValue): browserSectionLabel is non-empty")
            suite.expect(!s.profileFolderSectionLabel.isEmpty, "\(lang.rawValue): profileFolderSectionLabel is non-empty")
            suite.expect(!s.noneAnonymous.isEmpty, "\(lang.rawValue): noneAnonymous is non-empty")
            suite.expect(!s.otherChromiumBrowser.isEmpty, "\(lang.rawValue): otherChromiumBrowser is non-empty")
            suite.expect(!s.readyTitleFormat.isEmpty && s.readyTitleFormat.contains("%@"),
                         "\(lang.rawValue): readyTitleFormat contains '%@'")
            suite.expect(!s.readyDescriptionFormat.isEmpty && s.readyDescriptionFormat.contains("%@"),
                         "\(lang.rawValue): readyDescriptionFormat contains '%@'")
            suite.expect(!s.allowFullDiskAccess.isEmpty, "\(lang.rawValue): allowFullDiskAccess is non-empty")
            suite.expect(!s.allowFullDiskAccessDescriptionFormat.isEmpty && s.allowFullDiskAccessDescriptionFormat.contains("%@"),
                         "\(lang.rawValue): allowFullDiskAccessDescriptionFormat contains '%@'")
            suite.expect(!s.openSystemSettings.isEmpty, "\(lang.rawValue): openSystemSettings is non-empty")
            suite.expect(!s.browserNotFoundTitleFormat.isEmpty && s.browserNotFoundTitleFormat.contains("%@"),
                         "\(lang.rawValue): browserNotFoundTitleFormat contains '%@'")
            suite.expect(!s.browserNotFoundDescriptionFormat.isEmpty && s.browserNotFoundDescriptionFormat.contains("%@"),
                         "\(lang.rawValue): browserNotFoundDescriptionFormat contains '%@'")
            suite.expect(!s.chooseProfileFolder.isEmpty, "\(lang.rawValue): chooseProfileFolder is non-empty")
            suite.expect(!s.chooseProfileFolderDescription.isEmpty, "\(lang.rawValue): chooseProfileFolderDescription is non-empty")
            suite.expect(!s.chooseFolderAction.isEmpty, "\(lang.rawValue): chooseFolderAction is non-empty")
            suite.expect(!s.changeFolderAction.isEmpty, "\(lang.rawValue): changeFolderAction is non-empty")
            suite.expect(!s.footnoteAnonymous.isEmpty, "\(lang.rawValue): footnoteAnonymous is non-empty")
            suite.expect(!s.footnoteSignedIn.isEmpty, "\(lang.rawValue): footnoteSignedIn is non-empty")
            suite.expect(!s.disconnect.isEmpty, "\(lang.rawValue): disconnect is non-empty")
            suite.expect(!s.save.isEmpty, "\(lang.rawValue): save is non-empty")
            suite.expect(!s.disconnectConfirmTitle.isEmpty, "\(lang.rawValue): disconnectConfirmTitle is non-empty")
            suite.expect(!s.disconnectConfirmMessage.isEmpty, "\(lang.rawValue): disconnectConfirmMessage is non-empty")
            suite.expect(!s.selectProfilePanelPrompt.isEmpty, "\(lang.rawValue): selectProfilePanelPrompt is non-empty")
            suite.expect(!s.selectProfilePanelMessage.isEmpty, "\(lang.rawValue): selectProfilePanelMessage is non-empty")
        }
    }

    private static func testFormattersAcrossLanguages(_ suite: TestSuite) {
        for lang in AppLanguage.allCases {
            let s = FeatureStrings.videoDownloader(lang)

            let readyTitle = s.readyTitle(browser: "Safari")
            suite.expect(readyTitle.contains("Safari"), "\(lang.rawValue): readyTitle formats with Safari")

            let readyDesc = s.readyDescription(browser: "Chrome")
            suite.expect(readyDesc.contains("Chrome"), "\(lang.rawValue): readyDescription formats with Chrome")

            let fdaDesc = s.allowFullDiskAccessDescription(browser: "Safari")
            suite.expect(fdaDesc.contains("Safari"), "\(lang.rawValue): allowFullDiskAccessDescription formats with Safari")

            let notFoundTitle = s.browserNotFoundTitle(browser: "Brave")
            suite.expect(notFoundTitle.contains("Brave"), "\(lang.rawValue): browserNotFoundTitle formats with Brave")

            let notFoundDesc = s.browserNotFoundDescription(browser: "Brave")
            suite.expect(notFoundDesc.contains("Brave"), "\(lang.rawValue): browserNotFoundDescription formats with Brave")

            let savesTo = s.savesTo(folder: "Downloads")
            suite.expect(savesTo.contains("Downloads"), "\(lang.rawValue): savesTo formats with folder name")
        }
    }

    private static func testExactKeyTranslations(_ suite: TestSuite) {
        // enUS
        let en = FeatureStrings.videoDownloader(.enUS)
        suite.expect(en.pageTitle == "Video Downloader" && en.search == "Get video"
                     && en.searchClipboardURL == "Get Clipboard Video"
                     && en.browserSessionTitle == "Browser Session"
                     && en.loginRequiredNotice == "This video requires an authenticated session"
                     && en.noAccessNotice == "You don't have access to this video."
                     && en.manageSessions == "Manage Sessions"
                     && en.tryDifferentSessions == "Try different browser sessions",
                     "enUS strings match specification")

        // zhHans
        let zhHans = FeatureStrings.videoDownloader(.zhHans)
        suite.expect(zhHans.pageTitle == "视频下载器" && zhHans.search == "获取视频"
                     && zhHans.searchClipboardURL == "获取剪贴板视频"
                     && zhHans.browserSessionTitle == "浏览器会话"
                     && zhHans.manageSessions == "管理会话"
                     && zhHans.tryDifferentSessions == "尝试不同的浏览器会话",
                     "zhHans strings match specification")

        // zhTW
        let zhTW = FeatureStrings.videoDownloader(.zhTW)
        suite.expect(zhTW.pageTitle == "影片下載器" && zhTW.search == "取得影片"
                     && zhTW.searchClipboardURL == "取得剪貼簿影片"
                     && zhTW.browserSessionTitle == "瀏覽器登入階段"
                     && zhTW.manageSessions == "管理登入階段"
                     && zhTW.tryDifferentSessions == "嘗試不同的瀏覽器登入階段",
                     "zhTW strings match specification")

        // zhHK
        let zhHK = FeatureStrings.videoDownloader(.zhHK)
        suite.expect(zhHK.pageTitle == "影片下載器" && zhHK.search == "取得影片"
                     && zhHK.searchClipboardURL == "取得剪貼簿影片"
                     && zhHK.browserSessionTitle == "瀏覽器登入階段",
                     "zhHK strings match specification")

        // ja
        let ja = FeatureStrings.videoDownloader(.ja)
        suite.expect(ja.pageTitle == "動画ダウンローダー" && ja.search == "動画を取得"
                     && ja.searchClipboardURL == "クリップボードの動画を取得"
                     && ja.browserSessionTitle == "ブラウザセッション"
                     && ja.manageSessions == "セッションを管理"
                     && ja.tryDifferentSessions == "別のブラウザセッションを試す",
                     "ja strings match specification")

        // ko
        let ko = FeatureStrings.videoDownloader(.ko)
        suite.expect(ko.pageTitle == "비디오 다운로더" && ko.search == "비디오 가져오기"
                     && ko.searchClipboardURL == "클립보드 비디오 가져오기"
                     && ko.browserSessionTitle == "브라우저 세션"
                     && ko.manageSessions == "세션 관리"
                     && ko.tryDifferentSessions == "다른 브라우저 세션 시도",
                     "ko strings match specification")

        // de
        let de = FeatureStrings.videoDownloader(.de)
        suite.expect(de.pageTitle == "Video-Downloader" && de.search == "Video laden"
                     && de.searchClipboardURL == "Video aus Zwischenablage laden"
                     && de.browserSessionTitle == "Browsersitzung"
                     && de.manageSessions == "Sitzungen verwalten"
                     && de.tryDifferentSessions == "Andere Browsersitzung versuchen",
                     "de strings match specification")

        // fr
        let fr = FeatureStrings.videoDownloader(.fr)
        suite.expect(fr.pageTitle == "Téléchargeur vidéo" && fr.search == "Obtenir la vidéo"
                     && fr.searchClipboardURL == "Obtenir la vidéo du presse-papiers"
                     && fr.browserSessionTitle == "Session de navigateur"
                     && fr.manageSessions == "Gérer les sessions"
                     && fr.tryDifferentSessions == "Essayer d'autres sessions de navigateur",
                     "fr strings match specification")

        // es
        let es = FeatureStrings.videoDownloader(.es)
        suite.expect(es.pageTitle == "Descargador de videos" && es.search == "Obtener video"
                     && es.searchClipboardURL == "Obtener video del portapapeles"
                     && es.browserSessionTitle == "Sesión de navegador"
                     && es.manageSessions == "Administrar sesiones"
                     && es.tryDifferentSessions == "Probar con otra sesión de navegador",
                     "es strings match specification")

        // it
        let it = FeatureStrings.videoDownloader(.it)
        suite.expect(it.pageTitle == "Scaricatore video" && it.search == "Ottieni video"
                     && it.searchClipboardURL == "Ottieni video dagli appunti"
                     && it.browserSessionTitle == "Sessione del browser"
                     && it.manageSessions == "Gestisci sessioni"
                     && it.tryDifferentSessions == "Prova un'altra sessione del browser",
                     "it strings match specification")

        // ptBR
        let ptBR = FeatureStrings.videoDownloader(.ptBR)
        suite.expect(ptBR.pageTitle == "Baixador de Vídeo" && ptBR.search == "Obter vídeo"
                     && ptBR.searchClipboardURL == "Obter vídeo da área de transferência"
                     && ptBR.browserSessionTitle == "Sessão do navegador"
                     && ptBR.manageSessions == "Gerenciar sessões"
                     && ptBR.tryDifferentSessions == "Tentar outra sessão de navegador",
                     "ptBR strings match specification")

        // ru
        let ru = FeatureStrings.videoDownloader(.ru)
        suite.expect(ru.pageTitle == "Загрузчик видео" && ru.search == "Получить видео"
                     && ru.searchClipboardURL == "Получить видео из буфера"
                     && ru.browserSessionTitle == "Сеанс браузера"
                     && ru.manageSessions == "Управление сеансами"
                     && ru.tryDifferentSessions == "Попробовать другой сеанс браузера",
                     "ru strings match specification")

        // uk
        let uk = FeatureStrings.videoDownloader(.uk)
        suite.expect(uk.pageTitle == "Завантажувач відео" && uk.search == "Отримати відео"
                     && uk.searchClipboardURL == "Отримати відео з буфера"
                     && uk.browserSessionTitle == "Сеанс браузера"
                     && uk.manageSessions == "Керувати сеансами"
                     && uk.tryDifferentSessions == "Спробувати інший сеанс браузера",
                     "uk strings match specification")

        // tr
        let tr = FeatureStrings.videoDownloader(.tr)
        suite.expect(tr.pageTitle == "Video İndirici" && tr.search == "Videoyu al"
                     && tr.searchClipboardURL == "Panodaki Videoyu Al"
                     && tr.browserSessionTitle == "Tarayıcı Oturumu"
                     && tr.manageSessions == "Oturumları Yönet"
                     && tr.tryDifferentSessions == "Farklı tarayıcı oturumlarını dene",
                     "tr strings match specification")

        // sk
        let sk = FeatureStrings.videoDownloader(.sk)
        suite.expect(sk.pageTitle == "Sťahovač videí" && sk.search == "Získať video"
                     && sk.searchClipboardURL == "Získať video zo schránky"
                     && sk.browserSessionTitle == "Relácia prehliadača"
                     && sk.manageSessions == "Spravovať relácie"
                     && sk.tryDifferentSessions == "Skúsiť iné relácie prehliadača",
                     "sk strings match specification")
    }

    private static func testDynamicLanguageReactivity(_ suite: TestSuite) {
        let initialLang = L10n.shared.language
        defer { L10n.shared.language = initialLang }

        let testCases: [(AppLanguage, String, String)] = [
            (.zhHans, "视频下载器", "获取视频"),
            (.ja, "動画ダウンローダー", "動画を取得"),
            (.de, "Video-Downloader", "Video laden"),
            (.fr, "Téléchargeur vidéo", "Obtenir la vidéo"),
            (.es, "Descargador de videos", "Obtener video"),
            (.ru, "Загрузчик видео", "Получить видео"),
            (.enUS, "Video Downloader", "Get video")
        ]

        for (lang, expectedPage, expectedSearch) in testCases {
            L10n.shared.language = lang
            suite.expect(VideoDownloaderStrings.pageTitle == expectedPage,
                         "VideoDownloaderStrings.pageTitle dynamically matches \(lang.rawValue)")
            suite.expect(VideoDownloaderStrings.search == expectedSearch,
                         "VideoDownloaderStrings.search dynamically matches \(lang.rawValue)")
        }
    }
}
