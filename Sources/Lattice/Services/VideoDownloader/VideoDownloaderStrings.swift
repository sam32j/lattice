// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Localized strings for the Video Downloader feature across all supported AppLanguages.
struct VideoDownloaderFeatureStrings {
    // Page & Enablement
    let pageTitle: String
    let enableTitle: String
    let enableSubtitle: String

    // Download a video section
    let downloadVideoSectionTitle: String
    let downloadVideoSectionSubtitle: String
    let urlPlaceholder: String
    let search: String
    let clear: String
    let paste: String
    let pasteClipboardURL: String
    let searchClipboardURL: String

    // Preview & Options
    let quality: String
    let saveTo: String
    let defaultFolder: String
    let bestQuality: String
    let audioQuality: String
    let savesToFormat: String

    // Download actions & state
    let fetchingDetails: String
    let downloading: String
    let paused: String
    let downloadComplete: String
    let downloadFailed: String
    let downloadAgain: String
    let finishingVideo: String
    let pause: String
    let resume: String
    let cancel: String
    let download: String
    let retry: String

    // Recent section
    let recent: String
    let clearHistory: String
    let showInFinder: String

    // Error notices & warnings
    let fetchFailedNotice: String
    let featureDisabledNotice: String
    let invalidURL: String
    let unsupportedMetadata: String
    let missingTools: String
    let invalidOutput: String
    let timedOut: String
    let denoRequired: String
    let singleVideoOnlyNotice: String
    let loginRequiredNotice: String
    let noAccessNotice: String
    let browserAccessNotice: String
    let manageSessions: String
    let tryDifferentSessions: String

    // Toolchain & Components setup
    let missingToolsTitle: String
    let missingToolsBody: String
    let downloadRequiredTitle: String
    let downloadRequiredBody: String
    let continueAction: String
    let installComponentsTitle: String
    let installComponentsSubtitle: String
    let keepOff: String
    let install: String
    let installationFailed: String
    let gettingReady: String
    let gettingReadySubtitle: String
    let repairTitle: String
    let repairSubtitle: String
    let repairAction: String
    let technicalDetails: String
    let advanced: String
    let useSystemTools: String
    let checkUpdates: String

    // Browser session child setting & dialog
    let browserSessionTitle: String
    let browserSignInDescription: String
    let inactive: String
    let manage: String
    let browserSectionLabel: String
    let profileFolderSectionLabel: String
    let noneAnonymous: String
    let otherChromiumBrowser: String
    let readyTitleFormat: String
    let readyDescriptionFormat: String
    let allowFullDiskAccess: String
    let allowFullDiskAccessDescriptionFormat: String
    let openSystemSettings: String
    let browserNotFoundTitleFormat: String
    let browserNotFoundDescriptionFormat: String
    let chooseProfileFolder: String
    let chooseProfileFolderDescription: String
    let chooseFolderAction: String
    let changeFolderAction: String
    let footnoteAnonymous: String
    let footnoteSignedIn: String
    let disconnect: String
    let save: String
    let disconnectConfirmTitle: String
    let disconnectConfirmMessage: String
    let selectProfilePanelPrompt: String
    let selectProfilePanelMessage: String

    func readyTitle(browser: String) -> String {
        String(format: readyTitleFormat, browser)
    }

    func readyDescription(browser: String) -> String {
        String(format: readyDescriptionFormat, browser)
    }

    func allowFullDiskAccessDescription(browser: String) -> String {
        String(format: allowFullDiskAccessDescriptionFormat, browser)
    }

    func browserNotFoundTitle(browser: String) -> String {
        String(format: browserNotFoundTitleFormat, browser)
    }

    func browserNotFoundDescription(browser: String) -> String {
        String(format: browserNotFoundDescriptionFormat, browser)
    }

    func savesTo(folder: String) -> String {
        String(format: savesToFormat, folder)
    }
}

extension FeatureStrings {
    static func videoDownloader(_ language: AppLanguage) -> VideoDownloaderFeatureStrings {
        VideoDownloaderFeatureStrings.localized(language)
    }
}

extension VideoDownloaderFeatureStrings {
    static func localized(_ language: AppLanguage) -> VideoDownloaderFeatureStrings {
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

    static let enUS = VideoDownloaderFeatureStrings(
        pageTitle: "Video Downloader",
        enableTitle: "Enable Video Downloader",
        enableSubtitle: "Download videos and audio via the URL.",
        downloadVideoSectionTitle: "Download a video",
        downloadVideoSectionSubtitle: "Paste a video link to get started.",
        urlPlaceholder: "Video URL",
        search: "Get video",
        clear: "Clear",
        paste: "Paste",
        pasteClipboardURL: "Paste clipboard URL",
        searchClipboardURL: "Get Clipboard Video",
        quality: "Quality",
        saveTo: "Save to",
        defaultFolder: "~/Downloads",
        bestQuality: "Best",
        audioQuality: "Audio",
        savesToFormat: "Saves to %@",
        fetchingDetails: "Fetching video details…",
        downloading: "Downloading…",
        paused: "Paused",
        downloadComplete: "Download complete",
        downloadFailed: "Download failed",
        downloadAgain: "Download again",
        finishingVideo: "Finishing video…",
        pause: "Pause",
        resume: "Resume",
        cancel: "Cancel",
        download: "Download",
        retry: "Retry",
        recent: "Recent",
        clearHistory: "Clear history",
        showInFinder: "Show in Finder",
        fetchFailedNotice: "Couldn't fetch the video. Check the link and retry.",
        featureDisabledNotice: "Video Downloader is turned off and its tools have been removed. Turn on above to use.",
        invalidURL: "Paste a complete http:// or https:// video link without a username or password.",
        unsupportedMetadata: "No downloadable video was found. Use a single video link, not a playlist or live stream.",
        missingTools: "Install the missing tools below, then check again.",
        invalidOutput: "The download did not produce a complete video file. Try another quality or link.",
        timedOut: "The operation took too long. Check your connection and try again.",
        denoRequired: "This video site requires an additional component (Deno). Lattice is setting it up…",
        singleVideoOnlyNotice: "Using this video only (playlists are not supported).",
        loginRequiredNotice: "This video requires an authenticated session",
        noAccessNotice: "You don't have access to this video.",
        browserAccessNotice: "Could not read browser cookies. Check your profile folder or permissions.",
        manageSessions: "Manage Sessions",
        tryDifferentSessions: "Try different browser sessions",
        missingToolsTitle: "Some tools are missing",
        missingToolsBody: "Some components are missing. Repair now?",
        downloadRequiredTitle: "Download Components Required",
        downloadRequiredBody: "Allow Lattice to download and install required components for media processing?",
        continueAction: "Continue",
        installComponentsTitle: "Download Components Required",
        installComponentsSubtitle: "Lattice needs self-managed download components (yt-dlp, ffmpeg) to process media. These will be kept in Application Support.",
        keepOff: "Keep Off",
        install: "Install",
        installationFailed: "Installation Failed",
        gettingReady: "Preparing video downloader…",
        gettingReadySubtitle: "Lattice is setting up the tools needed for video downloads.",
        repairTitle: "Video download unavailable",
        repairSubtitle: "One of Lattice's download components is missing or damaged.",
        repairAction: "Repair",
        technicalDetails: "Technical details",
        advanced: "Advanced",
        useSystemTools: "Use system / custom tools",
        checkUpdates: "Check for updates",
        browserSessionTitle: "Browser Session",
        browserSignInDescription: "Downloads private videos using your signed-in browser session.",
        inactive: "Inactive",
        manage: "Manage",
        browserSectionLabel: "BROWSER",
        profileFolderSectionLabel: "PROFILE FOLDER",
        noneAnonymous: "None (Anonymous)",
        otherChromiumBrowser: "Other Chromium browser…",
        readyTitleFormat: "%@ Is Ready",
        readyDescriptionFormat: "Lattice is using your %@ sign-in.",
        allowFullDiskAccess: "Allow Full Disk Access",
        allowFullDiskAccessDescriptionFormat: "Lattice needs this to read your %@ sign-in.",
        openSystemSettings: "Open System Settings…",
        browserNotFoundTitleFormat: "%@ Not Found",
        browserNotFoundDescriptionFormat: "Install %@, or choose another browser.",
        chooseProfileFolder: "Choose a Profile Folder",
        chooseProfileFolderDescription: "Select a Profile Folder for your browser.",
        chooseFolderAction: "Choose Folder…",
        changeFolderAction: "Change…",
        footnoteAnonymous: "No cookies attached. Downloads will request public streams only.",
        footnoteSignedIn: "Your sign-in stays on this Mac and is only used for downloads.",
        disconnect: "Disconnect",
        save: "Save",
        disconnectConfirmTitle: "Disconnect Browser Session?",
        disconnectConfirmMessage: "Are you sure you want to disconnect this browser session? Downloads will no longer use your signed-in cookies.",
        selectProfilePanelPrompt: "Select Profile",
        selectProfilePanelMessage: "Choose the browser profile directory containing your session cookies"
    )

    static let zhHans = VideoDownloaderFeatureStrings(
        pageTitle: "视频下载器",
        enableTitle: "启用视频下载器",
        enableSubtitle: "通过链接下载视频与音频。",
        downloadVideoSectionTitle: "下载视频",
        downloadVideoSectionSubtitle: "粘贴视频链接以开始下载。",
        urlPlaceholder: "视频链接",
        search: "获取视频",
        clear: "清除",
        paste: "粘贴",
        pasteClipboardURL: "粘贴剪贴板链接",
        searchClipboardURL: "获取剪贴板视频",
        quality: "清晰度",
        saveTo: "保存至",
        defaultFolder: "~/Downloads",
        bestQuality: "最佳",
        audioQuality: "音频",
        savesToFormat: "保存至 %@",
        fetchingDetails: "正在获取视频信息…",
        downloading: "正在下载…",
        paused: "已暂停",
        downloadComplete: "下载完成",
        downloadFailed: "下载失败",
        downloadAgain: "重新下载",
        finishingVideo: "正在完成视频…",
        pause: "暂停",
        resume: "继续",
        cancel: "取消",
        download: "下载",
        retry: "重试",
        recent: "最近",
        clearHistory: "清除历史记录",
        showInFinder: "在访达中显示",
        fetchFailedNotice: "无法获取视频，请检查链接后重试。",
        featureDisabledNotice: "视频下载器已关闭，其工具已移除。请在上方开启后使用。",
        invalidURL: "请粘贴完整的 http:// 或 https:// 视频链接，且不含用户名或密码。",
        unsupportedMetadata: "未找到可下载的视频。请使用单个视频链接，不支持播放列表或直播流。",
        missingTools: "请安装下方缺失的工具，然后重试。",
        invalidOutput: "下载未生成完整的视频文件。请尝试其他清晰度或链接。",
        timedOut: "操作超时，请检查网络连接后重试。",
        denoRequired: "该视频网站需要额外组件 (Deno)，Lattice 正在配置…",
        singleVideoOnlyNotice: "仅使用此单集视频（暂不支持播放列表）。",
        loginRequiredNotice: "此视频需要登录认证的会话",
        noAccessNotice: "你没有访问此视频的权限。",
        browserAccessNotice: "无法读取浏览器 Cookie。请检查个人资料文件夹或权限。",
        manageSessions: "管理会话",
        tryDifferentSessions: "尝试不同的浏览器会话",
        missingToolsTitle: "部分工具缺失",
        missingToolsBody: "部分组件缺失。是否立即修复？",
        downloadRequiredTitle: "需要下载组件",
        downloadRequiredBody: "是否允许 Lattice 下载并安装媒体处理所需的必要组件？",
        continueAction: "继续",
        installComponentsTitle: "需要下载组件",
        installComponentsSubtitle: "Lattice 需要独立管理的下载组件（yt-dlp、ffmpeg）以处理媒体文件。这些组件将保存在 Application Support 目录。",
        keepOff: "保持关闭",
        install: "安装",
        installationFailed: "安装失败",
        gettingReady: "正在准备视频下载器…",
        gettingReadySubtitle: "Lattice 正在配置视频下载所需的工具。",
        repairTitle: "视频下载暂不可用",
        repairSubtitle: "Lattice 的某个下载组件缺失或已损坏。",
        repairAction: "修复",
        technicalDetails: "技术详情",
        advanced: "高级",
        useSystemTools: "使用系统 / 自定义工具",
        checkUpdates: "检查更新",
        browserSessionTitle: "浏览器会话",
        browserSignInDescription: "使用已登录的浏览器会话下载私密视频。",
        inactive: "未启用",
        manage: "管理",
        browserSectionLabel: "浏览器",
        profileFolderSectionLabel: "个人资料文件夹",
        noneAnonymous: "无（匿名）",
        otherChromiumBrowser: "其他 Chromium 浏览器…",
        readyTitleFormat: "%@ 已就绪",
        readyDescriptionFormat: "Lattice 正在使用你的 %@ 登录状态。",
        allowFullDiskAccess: "允许完全磁盘访问权限",
        allowFullDiskAccessDescriptionFormat: "Lattice 需要此权限来读取你的 %@ 登录状态。",
        openSystemSettings: "打开系统设置…",
        browserNotFoundTitleFormat: "未找到 %@",
        browserNotFoundDescriptionFormat: "请安装 %@，或选择其他浏览器。",
        chooseProfileFolder: "选择个人资料文件夹",
        chooseProfileFolderDescription: "为你的浏览器选择一个包含配置的个人资料文件夹。",
        chooseFolderAction: "选择文件夹…",
        changeFolderAction: "更改…",
        footnoteAnonymous: "未附加 Cookie。下载将仅请求公开视频流。",
        footnoteSignedIn: "你的登录信息保留在本机，仅用于下载。",
        disconnect: "断开连接",
        save: "存储",
        disconnectConfirmTitle: "断开浏览器会话？",
        disconnectConfirmMessage: "确定要断开此浏览器会话吗？下载将不再使用已登录的 Cookie。",
        selectProfilePanelPrompt: "选择个人资料",
        selectProfilePanelMessage: "选择包含会话 Cookie 的浏览器个人资料目录"
    )

    static let zhTW = VideoDownloaderFeatureStrings(
        pageTitle: "影片下載器",
        enableTitle: "啟用影片下載器",
        enableSubtitle: "透過網址下載影片與音訊。",
        downloadVideoSectionTitle: "下載影片",
        downloadVideoSectionSubtitle: "貼上影片連結即可開始。",
        urlPlaceholder: "影片網址",
        search: "取得影片",
        clear: "清除",
        paste: "貼上",
        pasteClipboardURL: "貼上剪貼簿網址",
        searchClipboardURL: "取得剪貼簿影片",
        quality: "畫質",
        saveTo: "儲存至",
        defaultFolder: "~/Downloads",
        bestQuality: "最佳",
        audioQuality: "音訊",
        savesToFormat: "儲存至 %@",
        fetchingDetails: "正在取得影片詳細資訊…",
        downloading: "正在下載…",
        paused: "已暫停",
        downloadComplete: "下載完成",
        downloadFailed: "下載失敗",
        downloadAgain: "重新下載",
        finishingVideo: "正在完成影片…",
        pause: "暫停",
        resume: "繼續",
        cancel: "取消",
        download: "下載",
        retry: "重試",
        recent: "最近",
        clearHistory: "清除記錄",
        showInFinder: "在 Finder 中顯示",
        fetchFailedNotice: "無法取得影片，請檢查連結後重試。",
        featureDisabledNotice: "影片下載器已關閉，相關工具已被移除。請在上方開啟後使用。",
        invalidURL: "請貼上完整的 http:// 或 https:// 影片連結，且不含使用者名稱或密碼。",
        unsupportedMetadata: "找不到可下載的影片。請使用單一影片連結，不支援播放清單或直播串流。",
        missingTools: "請安裝下方遺失的工具，然後重試。",
        invalidOutput: "下載未產生完整的影片檔案。請嘗試其他畫質或連結。",
        timedOut: "作業逾時，請檢查連線後重試。",
        denoRequired: "此影片網站需要額外組件 (Deno)，Lattice 正在設定…",
        singleVideoOnlyNotice: "僅使用此單集影片（不支援播放清單）。",
        loginRequiredNotice: "此影片需要已驗證的登入階段",
        noAccessNotice: "你沒有存取此影片的權限。",
        browserAccessNotice: "無法讀取瀏覽器 Cookie。請檢查個人檔案資料夾或權限。",
        manageSessions: "管理登入階段",
        tryDifferentSessions: "嘗試不同的瀏覽器登入階段",
        missingToolsTitle: "部分工具遺失",
        missingToolsBody: "部分組件遺失。要立即修復嗎？",
        downloadRequiredTitle: "需要下載組件",
        downloadRequiredBody: "是否允許 Lattice 下載並安裝處理媒體所需的必要組件？",
        continueAction: "繼續",
        installComponentsTitle: "需要下載組件",
        installComponentsSubtitle: "Lattice 需要獨立管理的下載組件（yt-dlp、ffmpeg）以處理媒體檔案。這些組件將存放在 Application Support 目錄中。",
        keepOff: "保持關閉",
        install: "安裝",
        installationFailed: "安裝失敗",
        gettingReady: "正在準備影片下載器…",
        gettingReadySubtitle: "Lattice 正在設定影片下載所需的工具。",
        repairTitle: "影片下載暫不可用",
        repairSubtitle: "Lattice 的其中一個下載組件遺失或損壞。",
        repairAction: "修復",
        technicalDetails: "技術詳細資訊",
        advanced: "進階",
        useSystemTools: "使用系統 / 自訂工具",
        checkUpdates: "檢查更新",
        browserSessionTitle: "瀏覽器登入階段",
        browserSignInDescription: "使用已登入的瀏覽器工作階段下載私人影片。",
        inactive: "未啟用",
        manage: "管理",
        browserSectionLabel: "瀏覽器",
        profileFolderSectionLabel: "設定檔資料夾",
        noneAnonymous: "無（匿名）",
        otherChromiumBrowser: "其他 Chromium 瀏覽器…",
        readyTitleFormat: "%@ 已就緒",
        readyDescriptionFormat: "Lattice 正在使用你的 %@ 登入階段。",
        allowFullDiskAccess: "允許完整磁碟取用權限",
        allowFullDiskAccessDescriptionFormat: "Lattice 需要此權限才能讀取你的 %@ 登入階段。",
        openSystemSettings: "打開系統設定…",
        browserNotFoundTitleFormat: "找不到 %@",
        browserNotFoundDescriptionFormat: "請安裝 %@，或選擇其他瀏覽器。",
        chooseProfileFolder: "選擇設定檔資料夾",
        chooseProfileFolderDescription: "為你的瀏覽器選擇包含設定的個人設定檔資料夾。",
        chooseFolderAction: "選擇資料夾…",
        changeFolderAction: "變更…",
        footnoteAnonymous: "未附加 Cookie。下載僅會請求公開串流。",
        footnoteSignedIn: "你的登入資訊僅保留在此 Mac 上，且只用於下載。",
        disconnect: "中斷連線",
        save: "儲存",
        disconnectConfirmTitle: "中斷瀏覽器工作階段連線？",
        disconnectConfirmMessage: "確定要中斷此瀏覽器工作階段嗎？下載將不再使用已登入的 Cookie。",
        selectProfilePanelPrompt: "選擇設定檔",
        selectProfilePanelMessage: "選擇包含工作階段 Cookie 的瀏覽器個人設定檔目錄"
    )

    static let zhHK = VideoDownloaderFeatureStrings(
        pageTitle: "影片下載器",
        enableTitle: "啟用影片下載器",
        enableSubtitle: "透過網址下載影片與音訊。",
        downloadVideoSectionTitle: "下載影片",
        downloadVideoSectionSubtitle: "貼上影片連結即可開始。",
        urlPlaceholder: "影片網址",
        search: "取得影片",
        clear: "清除",
        paste: "貼上",
        pasteClipboardURL: "貼上剪貼簿網址",
        searchClipboardURL: "取得剪貼簿影片",
        quality: "畫質",
        saveTo: "儲存至",
        defaultFolder: "~/Downloads",
        bestQuality: "最佳",
        audioQuality: "音訊",
        savesToFormat: "儲存至 %@",
        fetchingDetails: "正在取得影片詳細資訊…",
        downloading: "正在下載…",
        paused: "已暫停",
        downloadComplete: "下載完成",
        downloadFailed: "下載失敗",
        downloadAgain: "重新下載",
        finishingVideo: "正在完成影片…",
        pause: "暫停",
        resume: "繼續",
        cancel: "取消",
        download: "下載",
        retry: "重試",
        recent: "最近",
        clearHistory: "清除記錄",
        showInFinder: "在 Finder 中顯示",
        fetchFailedNotice: "無法取得影片，請檢查連結後重試。",
        featureDisabledNotice: "影片下載器已關閉，相關工具已被移除。請在上方開啟後使用。",
        invalidURL: "請貼上完整的 http:// 或 https:// 影片連結，且不含使用者名稱或密碼。",
        unsupportedMetadata: "找不到可下載的影片。請使用單一影片連結，不支援播放清單或直播串流。",
        missingTools: "請安裝下方遺失的工具，然後重試。",
        invalidOutput: "下載未產生完整的影片檔案。請嘗試其他畫質或連結。",
        timedOut: "作業逾時，請檢查連線後重試。",
        denoRequired: "此影片網站需要額外組件 (Deno)，Lattice 正在設定…",
        singleVideoOnlyNotice: "僅使用此單集影片（不支援播放清單）。",
        loginRequiredNotice: "此影片需要已驗證的登入階段",
        noAccessNotice: "你沒有存取此影片的權限。",
        browserAccessNotice: "無法讀取瀏覽器 Cookie。請檢查個人檔案資料夾或權限。",
        manageSessions: "管理登入階段",
        tryDifferentSessions: "嘗試不同的瀏覽器登入階段",
        missingToolsTitle: "部分工具遺失",
        missingToolsBody: "部分組件遺失。要立即修復嗎？",
        downloadRequiredTitle: "需要下載組件",
        downloadRequiredBody: "是否允許 Lattice 下載並安裝處理媒體所需的必要組件？",
        continueAction: "繼續",
        installComponentsTitle: "需要下載組件",
        installComponentsSubtitle: "Lattice 需要獨立管理的下載組件（yt-dlp、ffmpeg）以處理媒體檔案。這些組件將存放在 Application Support 目錄中。",
        keepOff: "保持關閉",
        install: "安裝",
        installationFailed: "安裝失敗",
        gettingReady: "正在準備影片下載器…",
        gettingReadySubtitle: "Lattice 正在設定影片下載所需的工具。",
        repairTitle: "影片下載暫不可用",
        repairSubtitle: "Lattice 的其中一個下載組件遺失或損壞。",
        repairAction: "修復",
        technicalDetails: "技術詳細資訊",
        advanced: "進階",
        useSystemTools: "使用系統 / 自訂工具",
        checkUpdates: "檢查更新",
        browserSessionTitle: "瀏覽器登入階段",
        browserSignInDescription: "使用已登入的瀏覽器工作階段下載私人影片。",
        inactive: "未啟用",
        manage: "管理",
        browserSectionLabel: "瀏覽器",
        profileFolderSectionLabel: "設定檔資料夾",
        noneAnonymous: "無（匿名）",
        otherChromiumBrowser: "其他 Chromium 瀏覽器…",
        readyTitleFormat: "%@ 已就緒",
        readyDescriptionFormat: "Lattice 正在使用你的 %@ 登入階段。",
        allowFullDiskAccess: "允許完整磁碟取用權限",
        allowFullDiskAccessDescriptionFormat: "Lattice 需要此權限才能讀取你的 %@ 登入階段。",
        openSystemSettings: "打開系統設定…",
        browserNotFoundTitleFormat: "找不到 %@",
        browserNotFoundDescriptionFormat: "請安裝 %@，或選擇其他瀏覽器。",
        chooseProfileFolder: "選擇設定檔資料夾",
        chooseProfileFolderDescription: "為你的瀏覽器選擇包含設定的個人設定檔資料夾。",
        chooseFolderAction: "選擇資料夾…",
        changeFolderAction: "變更…",
        footnoteAnonymous: "未附加 Cookie。下載僅會請求公開串流。",
        footnoteSignedIn: "你的登入資訊僅保留在此 Mac 上，且只用於下載。",
        disconnect: "中斷連線",
        save: "儲存",
        disconnectConfirmTitle: "中斷瀏覽器工作階段連線？",
        disconnectConfirmMessage: "確定要中斷此瀏覽器工作階段嗎？下載將不再使用已登入的 Cookie。",
        selectProfilePanelPrompt: "選擇設定檔",
        selectProfilePanelMessage: "選擇包含工作階段 Cookie 的瀏覽器個人設定檔目錄"
    )

    static let ja = VideoDownloaderFeatureStrings(
        pageTitle: "動画ダウンローダー",
        enableTitle: "動画ダウンローダーを有効にする",
        enableSubtitle: "URLから動画や音声をダウンロードします。",
        downloadVideoSectionTitle: "動画をダウンロード",
        downloadVideoSectionSubtitle: "動画のリンクを貼り付けて開始します。",
        urlPlaceholder: "動画のURL",
        search: "動画を取得",
        clear: "消去",
        paste: "ペースト",
        pasteClipboardURL: "クリップボードのURLをペースト",
        searchClipboardURL: "クリップボードの動画を取得",
        quality: "画質",
        saveTo: "保存先",
        defaultFolder: "~/Downloads",
        bestQuality: "最高画質",
        audioQuality: "音声",
        savesToFormat: "%@ に保存",
        fetchingDetails: "動画情報を取得中…",
        downloading: "ダウンロード中…",
        paused: "一時停止中",
        downloadComplete: "ダウンロード完了",
        downloadFailed: "ダウンロード失敗",
        downloadAgain: "再ダウンロード",
        finishingVideo: "動画を処理中…",
        pause: "一時停止",
        resume: "再開",
        cancel: "キャンセル",
        download: "ダウンロード",
        retry: "再試行",
        recent: "履歴",
        clearHistory: "履歴を消去",
        showInFinder: "Finderで表示",
        fetchFailedNotice: "動画を取得できませんでした。リンクを確認して再試行してください。",
        featureDisabledNotice: "動画ダウンローダーはオフになっており、ツールは削除されました。使用するには上でオンにしてください。",
        invalidURL: "ユーザー名やパスワードを含まない完全な http:// または https:// 動画リンクを貼り付けてください。",
        unsupportedMetadata: "ダウンロード可能な動画が見つかりませんでした。プレイリストやライブ配信ではなく、単一の動画リンクを使用してください。",
        missingTools: "不足しているツールをインストールしてから再確認してください。",
        invalidOutput: "完全な動画ファイルが生成されませんでした。別の画質またはリンクを試してください。",
        timedOut: "処理がタイムアウトしました。接続を確認して再試行してください。",
        denoRequired: "この動画サイトには追加コンポーネント (Deno) が必要です。セットアップ中…",
        singleVideoOnlyNotice: "この動画のみを使用します（プレイリストには対応していません）。",
        loginRequiredNotice: "この動画には認証済みセッションが必要です",
        noAccessNotice: "この動画へのアクセス権がありません。",
        browserAccessNotice: "ブラウザのCookieを読み取れませんでした。プロファイルフォルダまたは権限を確認してください。",
        manageSessions: "セッションを管理",
        tryDifferentSessions: "別のブラウザセッションを試す",
        missingToolsTitle: "一部のツールが見つかりません",
        missingToolsBody: "一部のコンポーネントが不足しています。修復しますか？",
        downloadRequiredTitle: "コンポーネントのダウンロードが必要です",
        downloadRequiredBody: "メディア処理に必要なコンポーネントのダウンロードとインストールを許可しますか？",
        continueAction: "続ける",
        installComponentsTitle: "コンポーネントのダウンロードが必要です",
        installComponentsSubtitle: "メディア処理には独立管理のダウンロードコンポーネント（yt-dlp、ffmpeg）が必要です。これらはApplication Supportに保存されます。",
        keepOff: "オフのままにする",
        install: "インストール",
        installationFailed: "インストールに失敗しました",
        gettingReady: "動画ダウンローダーを準備中…",
        gettingReadySubtitle: "動画のダウンロードに必要なツールをセットアップしています。",
        repairTitle: "動画ダウンロードを利用できません",
        repairSubtitle: "ダウンロードコンポーネントが見つからないか破損しています。",
        repairAction: "修復",
        technicalDetails: "技術詳細",
        advanced: "詳細設定",
        useSystemTools: "システム / カスタムツールを使用",
        checkUpdates: "アップデートを確認",
        browserSessionTitle: "ブラウザセッション",
        browserSignInDescription: "ログイン済みのブラウザセッションを使用して限定動画をダウンロードします。",
        inactive: "無効",
        manage: "管理",
        browserSectionLabel: "ブラウザ",
        profileFolderSectionLabel: "プロファイルフォルダ",
        noneAnonymous: "なし（匿名）",
        otherChromiumBrowser: "その他のChromiumブラウザ…",
        readyTitleFormat: "%@ は準備完了です",
        readyDescriptionFormat: "Latticeは %@ のログイン情報を使用しています。",
        allowFullDiskAccess: "フルディスクアクセスを許可",
        allowFullDiskAccessDescriptionFormat: "Latticeが %@ のログイン情報を読み取るにはこの権限が必要です。",
        openSystemSettings: "システム設定を開く…",
        browserNotFoundTitleFormat: "%@ が見つかりません",
        browserNotFoundDescriptionFormat: "%@ をインストールするか、別のブラウザを選択してください。",
        chooseProfileFolder: "プロファイルフォルダを選択",
        chooseProfileFolderDescription: "ブラウザのプロファイルフォルダを選択してください。",
        chooseFolderAction: "フォルダを選択…",
        changeFolderAction: "変更…",
        footnoteAnonymous: "Cookieは付加されません。公開ストリームのみをダウンロードします。",
        footnoteSignedIn: "ログイン情報はMac内に保持され、ダウンロードのみに使用されます。",
        disconnect: "接続解除",
        save: "保存",
        disconnectConfirmTitle: "ブラウザセッションを解除しますか？",
        disconnectConfirmMessage: "このブラウザセッションを解除してもよろしいですか？ダウンロードにログインCookieが使用されなくなります。",
        selectProfilePanelPrompt: "プロファイルを選択",
        selectProfilePanelMessage: "セッションCookieを含むブラウザプロファイルディレクトリを選択してください"
    )

    static let ko = VideoDownloaderFeatureStrings(
        pageTitle: "비디오 다운로더",
        enableTitle: "비디오 다운로더 활성화",
        enableSubtitle: "URL을 통해 비디오 및 오디오를 다운로드합니다.",
        downloadVideoSectionTitle: "비디오 다운로드",
        downloadVideoSectionSubtitle: "비디오 링크를 붙여넣어 시작하세요.",
        urlPlaceholder: "비디오 URL",
        search: "비디오 가져오기",
        clear: "지우기",
        paste: "붙여넣기",
        pasteClipboardURL: "클립보드 URL 붙여넣기",
        searchClipboardURL: "클립보드 비디오 가져오기",
        quality: "화질",
        saveTo: "저장 위치",
        defaultFolder: "~/Downloads",
        bestQuality: "최고 화질",
        audioQuality: "오디오",
        savesToFormat: "%@에 저장됨",
        fetchingDetails: "비디오 정보를 가져오는 중…",
        downloading: "다운로드 중…",
        paused: "일시 정지됨",
        downloadComplete: "다운로드 완료",
        downloadFailed: "다운로드 실패",
        downloadAgain: "다시 다운로드",
        finishingVideo: "비디오 마무리 중…",
        pause: "일시 정지",
        resume: "재개",
        cancel: "취소",
        download: "다운로드",
        retry: "재시도",
        recent: "최근 항목",
        clearHistory: "기록 지우기",
        showInFinder: "Finder에서 보기",
        fetchFailedNotice: "비디오를 가져올 수 없습니다. 링크를 확인하고 다시 시도하세요.",
        featureDisabledNotice: "비디오 다운로더가 꺼져 있으며 도구가 제거되었습니다. 사용하려면 위에서 켜세요.",
        invalidURL: "사용자 이름이나 비밀번호가 없는 완전한 http:// 또는 https:// 비디오 링크를 붙여넣으세요.",
        unsupportedMetadata: "다운로드 가능한 비디오를 찾을 수 없습니다. 재생목록이나 라이브 스트림이 아닌 단일 비디오 링크를 사용하세요.",
        missingTools: "아래의 누락된 도구를 설치한 후 다시 확인하세요.",
        invalidOutput: "완전한 비디오 파일이 생성되지 않았습니다. 다른 화질이나 링크를 시도하세요.",
        timedOut: "작업 시간이 초과되었습니다. 연결을 확인하고 다시 시도하세요.",
        denoRequired: "이 비디오 사이트에는 추가 구성 요소(Deno)가 필요합니다. Lattice에서 설정 중입니다…",
        singleVideoOnlyNotice: "이 비디오만 사용합니다(재생목록은 지원되지 않음).",
        loginRequiredNotice: "이 비디오는 인증된 세션이 필요합니다",
        noAccessNotice: "이 비디오에 접근할 권한이 없습니다.",
        browserAccessNotice: "브라우저 쿠키를 읽을 수 없습니다. 프로필 폴더 또는 권한을 확인하세요.",
        manageSessions: "세션 관리",
        tryDifferentSessions: "다른 브라우저 세션 시도",
        missingToolsTitle: "일부 도구가 누락됨",
        missingToolsBody: "일부 구성 요소가 누락되었습니다. 지금 복구하시겠습니까?",
        downloadRequiredTitle: "다운로드 구성 요소 필요",
        downloadRequiredBody: "Lattice가 미디어 처리에 필요한 구성 요소를 다운로드하고 설치하도록 허용하시겠습니까?",
        continueAction: "계속",
        installComponentsTitle: "다운로드 구성 요소 필요",
        installComponentsSubtitle: "Lattice가 미디어를 처리하려면 자체 관리 다운로드 구성 요소(yt-dlp, ffmpeg)가 필요합니다. 이는 Application Support에 보관됩니다.",
        keepOff: "끈 상태 유지",
        install: "설치",
        installationFailed: "설치 실패",
        gettingReady: "비디오 다운로더 준비 중…",
        gettingReadySubtitle: "Lattice가 비디오 다운로드에 필요한 도구를 설정하고 있습니다.",
        repairTitle: "비디오 다운로드 사용 불가",
        repairSubtitle: "Lattice의 다운로드 구성 요소 중 하나가 누락되었거나 손상되었습니다.",
        repairAction: "복구",
        technicalDetails: "기술 세부정보",
        advanced: "고급",
        useSystemTools: "시스템 / 사용자 지정 도구 사용",
        checkUpdates: "업데이트 확인",
        browserSessionTitle: "브라우저 세션",
        browserSignInDescription: "로그인된 브라우저 세션을 사용하여 비공개 비디오를 다운로드합니다.",
        inactive: "비활성",
        manage: "관리",
        browserSectionLabel: "브라우저",
        profileFolderSectionLabel: "프로필 폴더",
        noneAnonymous: "없음(익명)",
        otherChromiumBrowser: "기타 Chromium 브라우저…",
        readyTitleFormat: "%@ 준비 완료",
        readyDescriptionFormat: "Lattice가 %@ 로그인 정보를 사용하고 있습니다.",
        allowFullDiskAccess: "전체 디스크 접근 권한 허용",
        allowFullDiskAccessDescriptionFormat: "Lattice가 %@ 로그인 정보를 읽으려면 이 권한이 필요합니다.",
        openSystemSettings: "시스템 설정 열기…",
        browserNotFoundTitleFormat: "%@을(를) 찾을 수 없음",
        browserNotFoundDescriptionFormat: "%@을(를) 설치하거나 다른 브라우저를 선택하세요.",
        chooseProfileFolder: "프로필 폴더 선택",
        chooseProfileFolderDescription: "브라우저의 프로필 폴더를 선택하세요.",
        chooseFolderAction: "폴더 선택…",
        changeFolderAction: "변경…",
        footnoteAnonymous: "쿠키가 첨부되지 않습니다. 공개 스트림만 요청합니다.",
        footnoteSignedIn: "로그인 정보는 이 Mac에만 유지되며 다운로드에만 사용됩니다.",
        disconnect: "연결 해제",
        save: "저장",
        disconnectConfirmTitle: "브라우저 세션의 연결을 해제하시겠습니까?",
        disconnectConfirmMessage: "이 브라우저 세션의 연결을 해제하시겠습니까? 다운로드 시 더 이상 로그인 쿠키를 사용하지 않습니다.",
        selectProfilePanelPrompt: "프로필 선택",
        selectProfilePanelMessage: "세션 쿠키가 포함된 브라우저 프로필 디렉토리를 선택하세요"
    )

    static let de = VideoDownloaderFeatureStrings(
        pageTitle: "Video-Downloader",
        enableTitle: "Video-Downloader aktivieren",
        enableSubtitle: "Videos und Audio über die URL herunterladen.",
        downloadVideoSectionTitle: "Video herunterladen",
        downloadVideoSectionSubtitle: "Videolink einfügen, um zu beginnen.",
        urlPlaceholder: "Video-URL",
        search: "Video laden",
        clear: "Löschen",
        paste: "Einsetzen",
        pasteClipboardURL: "Zwischenablage-URL einsetzen",
        searchClipboardURL: "Video aus Zwischenablage laden",
        quality: "Qualität",
        saveTo: "Sichern in",
        defaultFolder: "~/Downloads",
        bestQuality: "Beste",
        audioQuality: "Audio",
        savesToFormat: "Sichert in %@",
        fetchingDetails: "Videodetails werden geladen…",
        downloading: "Wird heruntergeladen…",
        paused: "Pausiert",
        downloadComplete: "Download abgeschlossen",
        downloadFailed: "Download fehlgeschlagen",
        downloadAgain: "Erneut herunterladen",
        finishingVideo: "Video wird fertiggestellt…",
        pause: "Pause",
        resume: "Fortsetzen",
        cancel: "Abbrechen",
        download: "Laden",
        retry: "Wiederholen",
        recent: "Zuletzt",
        clearHistory: "Verlauf löschen",
        showInFinder: "Im Finder anzeigen",
        fetchFailedNotice: "Video konnte nicht geladen werden. Link prüfen und wiederholen.",
        featureDisabledNotice: "Video-Downloader ist deaktiviert und Werkzeuge wurden entfernt. Oben aktivieren.",
        invalidURL: "Vollständigen http://- oder https://-Link ohne Benutzername oder Passwort einfügen.",
        unsupportedMetadata: "Kein ladbares Video gefunden. Einzellink verwenden, keine Wiedergabeliste oder Livestream.",
        missingTools: "Fehlende Werkzeuge unten installieren, dann erneut prüfen.",
        invalidOutput: "Download erzeugte keine vollständige Datei. Andere Qualität oder Link versuchen.",
        timedOut: "Vorgang hat zu lange gedauert. Verbindung prüfen und wiederholen.",
        denoRequired: "Diese Seite benötigt eine zusätzliche Komponente (Deno). Lattice richtet sie ein…",
        singleVideoOnlyNotice: "Nur dieses Video wird verwendet (Wiedergabelisten nicht unterstützt).",
        loginRequiredNotice: "Dieses Video erfordert eine authentifizierte Sitzung",
        noAccessNotice: "Kein Zugriff auf dieses Video.",
        browserAccessNotice: "Browser-Cookies konnten nicht gelesen werden. Profilordner oder Berechtigungen prüfen.",
        manageSessions: "Sitzungen verwalten",
        tryDifferentSessions: "Andere Browsersitzung versuchen",
        missingToolsTitle: "Einige Werkzeuge fehlen",
        missingToolsBody: "Einige Komponenten fehlen. Jetzt reparieren?",
        downloadRequiredTitle: "Download-Komponenten erforderlich",
        downloadRequiredBody: "Lattice das Laden und Installieren erforderlicher Komponenten zur Medienverarbeitung erlauben?",
        continueAction: "Fortfahren",
        installComponentsTitle: "Download-Komponenten erforderlich",
        installComponentsSubtitle: "Lattice benötigt verwaltete Komponenten (yt-dlp, ffmpeg) zur Medienverarbeitung in Application Support.",
        keepOff: "Auslassen",
        install: "Installieren",
        installationFailed: "Installation fehlgeschlagen",
        gettingReady: "Video-Downloader wird vorbereitet…",
        gettingReadySubtitle: "Lattice richtet die erforderlichen Werkzeuge ein.",
        repairTitle: "Video-Download nicht verfügbar",
        repairSubtitle: "Eine Download-Komponente fehlt oder ist beschädigt.",
        repairAction: "Reparieren",
        technicalDetails: "Technische Details",
        advanced: "Erweitert",
        useSystemTools: "System- / benutzerdefinierte Werkzeuge verwenden",
        checkUpdates: "Nach Updates suchen",
        browserSessionTitle: "Browsersitzung",
        browserSignInDescription: "Private Videos mit Ihrer angemeldeten Browsersitzung herunterladen.",
        inactive: "Inaktiv",
        manage: "Verwalten",
        browserSectionLabel: "BROWSER",
        profileFolderSectionLabel: "PROFILORDNER",
        noneAnonymous: "Keiner (Anonym)",
        otherChromiumBrowser: "Anderer Chromium-Browser…",
        readyTitleFormat: "%@ ist bereit",
        readyDescriptionFormat: "Lattice verwendet Ihre %@-Anmeldung.",
        allowFullDiskAccess: "Festplattenvollzugriff erlauben",
        allowFullDiskAccessDescriptionFormat: "Lattice benötigt dies zum Lesen Ihrer %@-Anmeldung.",
        openSystemSettings: "Systemeinstellungen öffnen…",
        browserNotFoundTitleFormat: "%@ nicht gefunden",
        browserNotFoundDescriptionFormat: "%@ installieren oder einen anderen Browser wählen.",
        chooseProfileFolder: "Profilordner auswählen",
        chooseProfileFolderDescription: "Einen Profilordner für Ihren Browser auswählen.",
        chooseFolderAction: "Ordner auswählen…",
        changeFolderAction: "Ändern…",
        footnoteAnonymous: "Keine Cookies angehängt. Lädt nur öffentliche Streams.",
        footnoteSignedIn: "Ihre Anmeldung bleibt auf diesem Mac und wird nur für Downloads genutzt.",
        disconnect: "Trennen",
        save: "Sichern",
        disconnectConfirmTitle: "Browsersitzung trennen?",
        disconnectConfirmMessage: "Möchten Sie diese Browsersitzung wirklich trennen? Downloads nutzen keine angemeldeten Cookies mehr.",
        selectProfilePanelPrompt: "Profil auswählen",
        selectProfilePanelMessage: "Browser-Profilordner mit Ihren Sitzungs-Cookies auswählen"
    )

    static let fr = VideoDownloaderFeatureStrings(
        pageTitle: "Téléchargeur vidéo",
        enableTitle: "Activer le téléchargeur vidéo",
        enableSubtitle: "Télécharger des vidéos et du son via l'URL.",
        downloadVideoSectionTitle: "Télécharger une vidéo",
        downloadVideoSectionSubtitle: "Collez un lien vidéo pour commencer.",
        urlPlaceholder: "URL de la vidéo",
        search: "Obtenir la vidéo",
        clear: "Effacer",
        paste: "Coller",
        pasteClipboardURL: "Coller l'URL du presse-papiers",
        searchClipboardURL: "Obtenir la vidéo du presse-papiers",
        quality: "Qualité",
        saveTo: "Enregistrer sous",
        defaultFolder: "~/Downloads",
        bestQuality: "Meilleure",
        audioQuality: "Audio",
        savesToFormat: "Enregistre dans %@",
        fetchingDetails: "Récupération des détails…",
        downloading: "Téléchargement…",
        paused: "En pause",
        downloadComplete: "Téléchargement terminé",
        downloadFailed: "Échec du téléchargement",
        downloadAgain: "Télécharger à nouveau",
        finishingVideo: "Finalisation de la vidéo…",
        pause: "Pause",
        resume: "Reprendre",
        cancel: "Annuler",
        download: "Télécharger",
        retry: "Réessayer",
        recent: "Récents",
        clearHistory: "Effacer l'historique",
        showInFinder: "Afficher dans le Finder",
        fetchFailedNotice: "Impossible de récupérer la vidéo. Vérifiez le lien et réessayez.",
        featureDisabledNotice: "Le téléchargeur vidéo est désactivé et ses outils ont été supprimés. Activez-le ci-dessus.",
        invalidURL: "Collez un lien vidéo complet en http:// ou https:// sans identifiant ni mot de passe.",
        unsupportedMetadata: "Aucune vidéo téléchargeable trouvée. Utilisez un lien vers une seule vidéo, pas une playlist ou un direct.",
        missingTools: "Installez les outils manquants ci-dessous, puis réessayez.",
        invalidOutput: "Le téléchargement n'a pas produit de fichier vidéo complet. Essayez une autre qualité ou un autre lien.",
        timedOut: "L'opération a pris trop de temps. Vérifiez votre connexion et réessayez.",
        denoRequired: "Ce site vidéo nécessite un composant supplémentaire (Deno). Lattice le configure…",
        singleVideoOnlyNotice: "Utilisation de cette vidéo uniquement (les playlists ne sont pas prises en charge).",
        loginRequiredNotice: "Cette vidéo nécessite une session authentifiée",
        noAccessNotice: "Vous n'avez pas accès à cette vidéo.",
        browserAccessNotice: "Impossible de lire les cookies du navigateur. Vérifiez votre dossier de profil ou vos autorisations.",
        manageSessions: "Gérer les sessions",
        tryDifferentSessions: "Essayer d'autres sessions de navigateur",
        missingToolsTitle: "Certains outils sont manquants",
        missingToolsBody: "Certains composants sont manquants. Réparer maintenant ?",
        downloadRequiredTitle: "Composants de téléchargement requis",
        downloadRequiredBody: "Autoriser Lattice à télécharger et installer les composants requis pour le traitement multimédia ?",
        continueAction: "Continuer",
        installComponentsTitle: "Composants de téléchargement requis",
        installComponentsSubtitle: "Lattice a besoin de composants de téléchargement dédiés (yt-dlp, ffmpeg) stockés dans Application Support.",
        keepOff: "Laisser désactivé",
        install: "Installer",
        installationFailed: "Échec de l'installation",
        gettingReady: "Préparation du téléchargeur vidéo…",
        gettingReadySubtitle: "Lattice configure les outils nécessaires aux téléchargements.",
        repairTitle: "Téléchargement vidéo indisponible",
        repairSubtitle: "L'un des composants de téléchargement de Lattice est manquant ou endommagé.",
        repairAction: "Réparer",
        technicalDetails: "Détails techniques",
        advanced: "Avancé",
        useSystemTools: "Utiliser les outils système / personnalisés",
        checkUpdates: "Rechercher des mises à jour",
        browserSessionTitle: "Session de navigateur",
        browserSignInDescription: "Télécharge les vidéos privées avec votre session de navigateur connectée.",
        inactive: "Inactif",
        manage: "Gérer",
        browserSectionLabel: "NAVIGATEUR",
        profileFolderSectionLabel: "DOSSIER DE PROFIL",
        noneAnonymous: "Aucun (Anonyme)",
        otherChromiumBrowser: "Autre navigateur Chromium…",
        readyTitleFormat: "%@ est prêt",
        readyDescriptionFormat: "Lattice utilise votre connexion %@.",
        allowFullDiskAccess: "Autoriser l'accès complet au disque",
        allowFullDiskAccessDescriptionFormat: "Lattice a besoin de cet accès pour lire votre connexion %@.",
        openSystemSettings: "Ouvrir Réglages Système…",
        browserNotFoundTitleFormat: "%@ introuvable",
        browserNotFoundDescriptionFormat: "Installez %@ ou choisissez un autre navigateur.",
        chooseProfileFolder: "Choisir un dossier de profil",
        chooseProfileFolderDescription: "Sélectionnez un dossier de profil pour votre navigateur.",
        chooseFolderAction: "Choisir le dossier…",
        changeFolderAction: "Modifier…",
        footnoteAnonymous: "Aucun cookie joint. Les téléchargements demanderont uniquement les flux publics.",
        footnoteSignedIn: "Votre connexion reste sur ce Mac et n'est utilisée que pour les téléchargements.",
        disconnect: "Déconnecter",
        save: "Enregistrer",
        disconnectConfirmTitle: "Déconnecter la session du navigateur ?",
        disconnectConfirmMessage: "Voulez-vous vraiment déconnecter cette session ? Les téléchargements n'utiliseront plus vos cookies de connexion.",
        selectProfilePanelPrompt: "Sélectionner le profil",
        selectProfilePanelMessage: "Choisissez le répertoire de profil du navigateur contenant vos cookies de session"
    )

    static let es = VideoDownloaderFeatureStrings(
        pageTitle: "Descargador de videos",
        enableTitle: "Activar descargador de videos",
        enableSubtitle: "Descarga videos y audio mediante la URL.",
        downloadVideoSectionTitle: "Descargar un video",
        downloadVideoSectionSubtitle: "Pega un enlace de video para comenzar.",
        urlPlaceholder: "URL del video",
        search: "Obtener video",
        clear: "Borrar",
        paste: "Pegar",
        pasteClipboardURL: "Pegar URL del portapapeles",
        searchClipboardURL: "Obtener video del portapapeles",
        quality: "Calidad",
        saveTo: "Guardar en",
        defaultFolder: "~/Downloads",
        bestQuality: "Mejor",
        audioQuality: "Audio",
        savesToFormat: "Guarda en %@",
        fetchingDetails: "Obteniendo detalles del video…",
        downloading: "Descargando…",
        paused: "En pausa",
        downloadComplete: "Descarga completada",
        downloadFailed: "Error en la descarga",
        downloadAgain: "Descargar de nuevo",
        finishingVideo: "Finalizando video…",
        pause: "Pausa",
        resume: "Reanudar",
        cancel: "Cancelar",
        download: "Descargar",
        retry: "Reintentar",
        recent: "Recientes",
        clearHistory: "Borrar historial",
        showInFinder: "Mostrar en el Finder",
        fetchFailedNotice: "No se pudo obtener el video. Revisa el enlace y reintenta.",
        featureDisabledNotice: "El descargador de videos está desactivado y sus herramientas fueron eliminadas. Actívalo arriba.",
        invalidURL: "Pega un enlace de video http:// o https:// completo sin nombre de usuario ni contraseña.",
        unsupportedMetadata: "No se encontró ningún video descargable. Usa el enlace a un solo video, no una lista ni transmisión en vivo.",
        missingTools: "Instala las herramientas faltantes a continuación y revisa de nuevo.",
        invalidOutput: "La descarga no produjo un archivo de video completo. Prueba con otra calidad o enlace.",
        timedOut: "La operación tardó demasiado. Comprueba tu conexión e inténtalo de nuevo.",
        denoRequired: "Este sitio de video requiere un componente adicional (Deno). Lattice lo está configurando…",
        singleVideoOnlyNotice: "Usando solo este video (las listas de reproducción no son compatibles).",
        loginRequiredNotice: "Este video requiere una sesión autenticada",
        noAccessNotice: "No tienes acceso a este video.",
        browserAccessNotice: "No se pudieron leer las cookies del navegador. Revisa la carpeta del perfil o los permisos.",
        manageSessions: "Administrar sesiones",
        tryDifferentSessions: "Probar con otra sesión de navegador",
        missingToolsTitle: "Faltan algunas herramientas",
        missingToolsBody: "Faltan algunos componentes. ¿Reparar ahora?",
        downloadRequiredTitle: "Se requieren componentes de descarga",
        downloadRequiredBody: "¿Permitir que Lattice descargue e instale los componentes necesarios para procesar medios?",
        continueAction: "Continuar",
        installComponentsTitle: "Se requieren componentes de descarga",
        installComponentsSubtitle: "Lattice necesita componentes de descarga independientes (yt-dlp, ffmpeg) en Application Support para procesar medios.",
        keepOff: "Mantener desactivado",
        install: "Instalar",
        installationFailed: "Error en la instalación",
        gettingReady: "Preparando descargador de videos…",
        gettingReadySubtitle: "Lattice está configurando las herramientas necesarias para descargar videos.",
        repairTitle: "Descarga de videos no disponible",
        repairSubtitle: "Uno de los componentes de descarga de Lattice falta o está dañado.",
        repairAction: "Reparar",
        technicalDetails: "Detalles técnicos",
        advanced: "Avanzado",
        useSystemTools: "Usar herramientas del sistema / personalizadas",
        checkUpdates: "Buscar actualizaciones",
        browserSessionTitle: "Sesión de navegador",
        browserSignInDescription: "Descarga videos privados usando tu sesión iniciada en el navegador.",
        inactive: "Inactiva",
        manage: "Administrar",
        browserSectionLabel: "NAVEGADOR",
        profileFolderSectionLabel: "CARPETA DE PERFIL",
        noneAnonymous: "Ninguno (Anónimo)",
        otherChromiumBrowser: "Otro navegador Chromium…",
        readyTitleFormat: "%@ está listo",
        readyDescriptionFormat: "Lattice está usando tu inicio de sesión de %@.",
        allowFullDiskAccess: "Permitir acceso total al disco",
        allowFullDiskAccessDescriptionFormat: "Lattice necesita esto para leer tu inicio de sesión de %@.",
        openSystemSettings: "Abrir Ajustes del Sistema…",
        browserNotFoundTitleFormat: "No se encontró %@",
        browserNotFoundDescriptionFormat: "Instala %@ o elige otro navegador.",
        chooseProfileFolder: "Elige una carpeta de perfil",
        chooseProfileFolderDescription: "Selecciona una carpeta de perfil para tu navegador.",
        chooseFolderAction: "Elegir carpeta…",
        changeFolderAction: "Cambiar…",
        footnoteAnonymous: "Sin cookies adjuntas. Las descargas solo solicitarán transmisiones públicas.",
        footnoteSignedIn: "Tu inicio de sesión permanece en esta Mac y solo se usa para descargas.",
        disconnect: "Desconectar",
        save: "Guardar",
        disconnectConfirmTitle: "¿Desconectar sesión de navegador?",
        disconnectConfirmMessage: "¿Seguro que deseas desconectar esta sesión? Las descargas ya no usarán tus cookies de inicio de sesión.",
        selectProfilePanelPrompt: "Seleccionar perfil",
        selectProfilePanelMessage: "Elige el directorio de perfil del navegador que contiene tus cookies de sesión"
    )

    static let it = VideoDownloaderFeatureStrings(
        pageTitle: "Scaricatore video",
        enableTitle: "Abilita Scaricatore video",
        enableSubtitle: "Scarica video e audio tramite l'URL.",
        downloadVideoSectionTitle: "Scarica un video",
        downloadVideoSectionSubtitle: "Incolla un link video per iniziare.",
        urlPlaceholder: "URL del video",
        search: "Ottieni video",
        clear: "Cancella",
        paste: "Incolla",
        pasteClipboardURL: "Incolla URL dagli appunti",
        searchClipboardURL: "Ottieni video dagli appunti",
        quality: "Qualità",
        saveTo: "Salva in",
        defaultFolder: "~/Downloads",
        bestQuality: "Migliore",
        audioQuality: "Audio",
        savesToFormat: "Salva in %@",
        fetchingDetails: "Recupero dettagli video…",
        downloading: "Download in corso…",
        paused: "In pausa",
        downloadComplete: "Download completato",
        downloadFailed: "Download non riuscito",
        downloadAgain: "Scarica di nuovo",
        finishingVideo: "Finalizzazione video…",
        pause: "Pausa",
        resume: "Riprendi",
        cancel: "Annulla",
        download: "Scarica",
        retry: "Riprova",
        recent: "Recenti",
        clearHistory: "Cancella cronologia",
        showInFinder: "Mostra nel Finder",
        fetchFailedNotice: "Impossibile recuperare il video. Verifica il link e riprova.",
        featureDisabledNotice: "Lo Scaricatore video è disattivato e i suoi strumenti rimossi. Attivalo sopra.",
        invalidURL: "Incolla un link video http:// o https:// completo senza nome utente o password.",
        unsupportedMetadata: "Nessun video scaricabile trovato. Usa il link di un singolo video, non playlist o live stream.",
        missingTools: "Installa gli strumenti mancanti qui sotto, quindi ricontrolla.",
        invalidOutput: "Il download non ha prodotto un file video completo. Prova un'altra qualità o link.",
        timedOut: "L'operazione ha richiesto troppo tempo. Controlla la connessione e riprova.",
        denoRequired: "Questo sito richiede un componente aggiuntivo (Deno). Lattice lo sta configurando…",
        singleVideoOnlyNotice: "Utilizzo di questo singolo video (le playlist non sono supportate).",
        loginRequiredNotice: "Questo video richiede una sessione autenticata",
        noAccessNotice: "Non hai accesso a questo video.",
        browserAccessNotice: "Impossibile leggere i cookie del browser. Verifica la cartella del profilo o i permessi.",
        manageSessions: "Gestisci sessioni",
        tryDifferentSessions: "Prova un'altra sessione del browser",
        missingToolsTitle: "Alcuni strumenti sono mancanti",
        missingToolsBody: "Mancano alcuni componenti. Riparare ora?",
        downloadRequiredTitle: "Componenti di download richiesti",
        downloadRequiredBody: "Consentire a Lattice di scaricare e installare i componenti necessari per l'elaborazione dei media?",
        continueAction: "Continua",
        installComponentsTitle: "Componenti di download richiesti",
        installComponentsSubtitle: "Lattice necessita di componenti di download gestiti (yt-dlp, ffmpeg) in Application Support per elaborare i media.",
        keepOff: "Lascia disattivato",
        install: "Installa",
        installationFailed: "Installazione non riuscita",
        gettingReady: "Preparazione scaricatore video…",
        gettingReadySubtitle: "Lattice sta configurando gli strumenti necessari per i download.",
        repairTitle: "Download video non disponibile",
        repairSubtitle: "Uno dei componenti di download di Lattice è mancante o danneggiato.",
        repairAction: "Ripara",
        technicalDetails: "Dettagli tecnici",
        advanced: "Avanzate",
        useSystemTools: "Usa strumenti di sistema / personalizzati",
        checkUpdates: "Verifica aggiornamenti",
        browserSessionTitle: "Sessione del browser",
        browserSignInDescription: "Scarica video privati utilizzando la sessione del browser in cui hai effettuato l'accesso.",
        inactive: "Non attiva",
        manage: "Gestisci",
        browserSectionLabel: "BROWSER",
        profileFolderSectionLabel: "CARTELLA PROFILO",
        noneAnonymous: "Nessuno (Anonimo)",
        otherChromiumBrowser: "Altro browser Chromium…",
        readyTitleFormat: "%@ è pronto",
        readyDescriptionFormat: "Lattice sta usando l'accesso di %@.",
        allowFullDiskAccess: "Consenti Accesso completo al disco",
        allowFullDiskAccessDescriptionFormat: "Lattice ne ha bisogno per leggere l'accesso di %@.",
        openSystemSettings: "Apri Impostazioni di Sistema…",
        browserNotFoundTitleFormat: "%@ non trovato",
        browserNotFoundDescriptionFormat: "Installa %@ o scegli un altro browser.",
        chooseProfileFolder: "Scegli una cartella profilo",
        chooseProfileFolderDescription: "Seleziona una cartella profilo per il tuo browser.",
        chooseFolderAction: "Scegli cartella…",
        changeFolderAction: "Modifica…",
        footnoteAnonymous: "Nessun cookie allegato. I download richiederanno solo stream pubblici.",
        footnoteSignedIn: "Il tuo accesso rimane su questo Mac ed è usato solo per i download.",
        disconnect: "Disconnetti",
        save: "Salva",
        disconnectConfirmTitle: "Disconnettere la sessione del browser?",
        disconnectConfirmMessage: "Vuoi davvero disconnettere questa sessione? I download non useranno più i tuoi cookie di accesso.",
        selectProfilePanelPrompt: "Seleziona profilo",
        selectProfilePanelMessage: "Scegli la cartella del profilo del browser contenente i tuoi cookie di sessione"
    )

    static let ptBR = VideoDownloaderFeatureStrings(
        pageTitle: "Baixador de Vídeo",
        enableTitle: "Ativar Baixador de Vídeo",
        enableSubtitle: "Baixe vídeos e áudios via URL.",
        downloadVideoSectionTitle: "Baixar um vídeo",
        downloadVideoSectionSubtitle: "Cole o link de um vídeo para começar.",
        urlPlaceholder: "URL do vídeo",
        search: "Obter vídeo",
        clear: "Limpar",
        paste: "Colar",
        pasteClipboardURL: "Colar URL da área de transferência",
        searchClipboardURL: "Obter vídeo da área de transferência",
        quality: "Qualidade",
        saveTo: "Salvar em",
        defaultFolder: "~/Downloads",
        bestQuality: "Melhor",
        audioQuality: "Áudio",
        savesToFormat: "Salva em %@",
        fetchingDetails: "Obtendo detalhes do vídeo…",
        downloading: "Baixando…",
        paused: "Pausado",
        downloadComplete: "Download concluído",
        downloadFailed: "Falha no download",
        downloadAgain: "Baixar novamente",
        finishingVideo: "Finalizando vídeo…",
        pause: "Pausar",
        resume: "Retomar",
        cancel: "Cancelar",
        download: "Baixar",
        retry: "Tentar novamente",
        recent: "Recentes",
        clearHistory: "Limpar histórico",
        showInFinder: "Mostrar no Finder",
        fetchFailedNotice: "Não foi possível obter o vídeo. Verifique o link e tente novamente.",
        featureDisabledNotice: "O Baixador de Vídeo está desativado e suas ferramentas foram removidas. Ative acima para usar.",
        invalidURL: "Cole um link de vídeo http:// ou https:// completo sem nome de usuário ou senha.",
        unsupportedMetadata: "Nenhum vídeo baixável foi encontrado. Use o link de um único vídeo, não listas ou transmissões ao vivo.",
        missingTools: "Instale as ferramentas ausentes abaixo e verifique novamente.",
        invalidOutput: "O download não gerou um arquivo de vídeo completo. Tente outra qualidade ou link.",
        timedOut: "A operação demorou muito. Verifique sua conexão e tente novamente.",
        denoRequired: "Este site requer um componente adicional (Deno). O Lattice está configurando…",
        singleVideoOnlyNotice: "Usando apenas este vídeo (playlists não são suportadas).",
        loginRequiredNotice: "Este vídeo requer uma sessão autenticada",
        noAccessNotice: "Você não tem acesso a este vídeo.",
        browserAccessNotice: "Não foi possível ler os cookies do navegador. Verifique a pasta do perfil ou as permissões.",
        manageSessions: "Gerenciar sessões",
        tryDifferentSessions: "Tentar outra sessão de navegador",
        missingToolsTitle: "Algumas ferramentas estão ausentes",
        missingToolsBody: "Alguns componentes estão faltando. Reparar agora?",
        downloadRequiredTitle: "Componentes de download necessários",
        downloadRequiredBody: "Permitir que o Lattice baixe e instale os componentes necessários para processar mídia?",
        continueAction: "Continuar",
        installComponentsTitle: "Componentes de download necessários",
        installComponentsSubtitle: "O Lattice precisa de componentes de download gerenciados (yt-dlp, ffmpeg) em Application Support para processar mídia.",
        keepOff: "Manter desativado",
        install: "Instalar",
        installationFailed: "Falha na instalação",
        gettingReady: "Preparando baixador de vídeo…",
        gettingReadySubtitle: "O Lattice está configurando as ferramentas necessárias para os downloads.",
        repairTitle: "Download de vídeo indisponível",
        repairSubtitle: "Um dos componentes de download do Lattice está ausente ou corrompido.",
        repairAction: "Reparar",
        technicalDetails: "Detalhes técnicos",
        advanced: "Avançado",
        useSystemTools: "Usar ferramentas do sistema / personalizadas",
        checkUpdates: "Buscar atualizações",
        browserSessionTitle: "Sessão do navegador",
        browserSignInDescription: "Baixa vídeos privados usando sua sessão conectada no navegador.",
        inactive: "Inativo",
        manage: "Gerenciar",
        browserSectionLabel: "NAVEGADOR",
        profileFolderSectionLabel: "PASTA DO PERFIL",
        noneAnonymous: "Nenhum (Anônimo)",
        otherChromiumBrowser: "Outro navegador Chromium…",
        readyTitleFormat: "%@ está pronto",
        readyDescriptionFormat: "O Lattice está usando sua sessão do %@.",
        allowFullDiskAccess: "Permitir Acesso Total ao Disco",
        allowFullDiskAccessDescriptionFormat: "O Lattice precisa disso para ler sua sessão do %@.",
        openSystemSettings: "Abrir Ajustes do Sistema…",
        browserNotFoundTitleFormat: "%@ não encontrado",
        browserNotFoundDescriptionFormat: "Instale o %@ ou escolha outro navegador.",
        chooseProfileFolder: "Escolher pasta do perfil",
        chooseProfileFolderDescription: "Selecione uma pasta de perfil para o seu navegador.",
        chooseFolderAction: "Escolher pasta…",
        changeFolderAction: "Alterar…",
        footnoteAnonymous: "Nenhum cookie anexado. Os downloads solicitarão apenas transmissões públicas.",
        footnoteSignedIn: "Sua sessão permanece neste Mac e é usada apenas para downloads.",
        disconnect: "Desconectar",
        save: "Salvar",
        disconnectConfirmTitle: "Desconectar sessão do navegador?",
        disconnectConfirmMessage: "Tem certeza de que deseja desconectar esta sessão? Os downloads não usarão mais seus cookies de login.",
        selectProfilePanelPrompt: "Selecionar perfil",
        selectProfilePanelMessage: "Escolha a pasta do perfil do navegador contendo seus cookies de sessão"
    )

    static let ru = VideoDownloaderFeatureStrings(
        pageTitle: "Загрузчик видео",
        enableTitle: "Включить загрузчик видео",
        enableSubtitle: "Скачивание видео и аудио по ссылке.",
        downloadVideoSectionTitle: "Скачать видео",
        downloadVideoSectionSubtitle: "Вставьте ссылку на видео, чтобы начать.",
        urlPlaceholder: "Ссылка на видео",
        search: "Получить видео",
        clear: "Очистить",
        paste: "Вставить",
        pasteClipboardURL: "Вставить ссылку из буфера",
        searchClipboardURL: "Получить видео из буфера",
        quality: "Качество",
        saveTo: "Сохранить в",
        defaultFolder: "~/Downloads",
        bestQuality: "Лучшее",
        audioQuality: "Аудио",
        savesToFormat: "Сохраняется в %@",
        fetchingDetails: "Получение сведений о видео…",
        downloading: "Загрузка…",
        paused: "Приостановлено",
        downloadComplete: "Загрузка завершена",
        downloadFailed: "Сбой загрузки",
        downloadAgain: "Скачать снова",
        finishingVideo: "Завершение обработки видео…",
        pause: "Пауза",
        resume: "Продолжить",
        cancel: "Отмена",
        download: "Скачать",
        retry: "Повторить",
        recent: "Недавние",
        clearHistory: "Очистить историю",
        showInFinder: "Показать в Finder",
        fetchFailedNotice: "Не удалось получить видео. Проверьте ссылку и повторите попытку.",
        featureDisabledNotice: "Загрузчик видео выключен, а его инструменты удалены. Включите выше.",
        invalidURL: "Вставьте полную ссылку http:// или https:// без имени пользователя и пароля.",
        unsupportedMetadata: "Доступное для скачивания видео не найдено. Используйте ссылку на одно видео, а не плейлист или стрим.",
        missingTools: "Установите недостающие инструменты ниже и проверьте снова.",
        invalidOutput: "При скачивании не получен полный видеофайл. Попробуйте другое качество или ссылку.",
        timedOut: "Время ожидания операции истекло. Проверьте подключение и повторите попытку.",
        denoRequired: "Для этого сайта требуется дополнительный компонент (Deno). Lattice настраивает его…",
        singleVideoOnlyNotice: "Используется только это видео (плейлисты не поддерживаются).",
        loginRequiredNotice: "Для этого видео требуется авторизованный сеанс",
        noAccessNotice: "У вас нет доступа к этому видео.",
        browserAccessNotice: "Не удалось прочитать файлы cookie браузера. Проверьте папку профиля или разрешения.",
        manageSessions: "Управление сеансами",
        tryDifferentSessions: "Попробовать другой сеанс браузера",
        missingToolsTitle: "Некоторые инструменты отсутствуют",
        missingToolsBody: "Некоторые компоненты отсутствуют. Восстановить сейчас?",
        downloadRequiredTitle: "Требуются компоненты загрузки",
        downloadRequiredBody: "Разрешить Lattice скачать и установить компоненты для обработки медиа?",
        continueAction: "Продолжить",
        installComponentsTitle: "Требуются компоненты загрузки",
        installComponentsSubtitle: "Lattice требуются управляемые компоненты (yt-dlp, ffmpeg) в Application Support для обработки медиа.",
        keepOff: "Оставить выключенным",
        install: "Установить",
        installationFailed: "Сбой установки",
        gettingReady: "Подготовка загрузчика видео…",
        gettingReadySubtitle: "Lattice настраивает необходимые инструменты для загрузки видео.",
        repairTitle: "Загрузка видео недоступна",
        repairSubtitle: "Один из компонентов загрузки Lattice отсутствует или поврежден.",
        repairAction: "Восстановить",
        technicalDetails: "Технические сведения",
        advanced: "Дополнительно",
        useSystemTools: "Использовать системные / пользовательские инструменты",
        checkUpdates: "Проверить обновления",
        browserSessionTitle: "Сеанс браузера",
        browserSignInDescription: "Скачивание приватных видео с использованием авторизованного сеанса браузера.",
        inactive: "Неактивно",
        manage: "Управлять",
        browserSectionLabel: "БРАУЗЕР",
        profileFolderSectionLabel: "ПАПКА ПРОФИЛЯ",
        noneAnonymous: "Нет (Анонимно)",
        otherChromiumBrowser: "Другой браузер Chromium…",
        readyTitleFormat: "%@ готов к работе",
        readyDescriptionFormat: "Lattice использует данные входа в %@.",
        allowFullDiskAccess: "Разрешить полный доступ к диску",
        allowFullDiskAccessDescriptionFormat: "Lattice требуется это разрешение для чтения данных входа в %@.",
        openSystemSettings: "Открыть «Системные настройки»…",
        browserNotFoundTitleFormat: "%@ не найден",
        browserNotFoundDescriptionFormat: "Установите %@ или выберите другой браузер.",
        chooseProfileFolder: "Выберите папку профиля",
        chooseProfileFolderDescription: "Выберите папку профиля для вашего браузера.",
        chooseFolderAction: "Выбрать папку…",
        changeFolderAction: "Изменить…",
        footnoteAnonymous: "Файлы cookie не прикреплены. Загружаются только публичные потоки.",
        footnoteSignedIn: "Данные входа остаются на этом Mac и используются только для загрузки.",
        disconnect: "Отключить",
        save: "Сохранить",
        disconnectConfirmTitle: "Отключить сеанс браузера?",
        disconnectConfirmMessage: "Вы действительно хотите отключить этот сеанс? Для загрузок больше не будут использоваться файлы cookie входа.",
        selectProfilePanelPrompt: "Выбрать профиль",
        selectProfilePanelMessage: "Выберите каталог профиля браузера с файлами cookie сеанса"
    )

    static let uk = VideoDownloaderFeatureStrings(
        pageTitle: "Завантажувач відео",
        enableTitle: "Увімкнути завантажувач відео",
        enableSubtitle: "Завантаження відео та аудіо за посиланням.",
        downloadVideoSectionTitle: "Завантажити відео",
        downloadVideoSectionSubtitle: "Вставте посилання на відео, щоб почати.",
        urlPlaceholder: "Посилання на відео",
        search: "Отримати відео",
        clear: "Очистити",
        paste: "Вставити",
        pasteClipboardURL: "Вставити посилання з буфера",
        searchClipboardURL: "Отримати відео з буфера",
        quality: "Якість",
        saveTo: "Зберегти в",
        defaultFolder: "~/Downloads",
        bestQuality: "Найкраща",
        audioQuality: "Аудіо",
        savesToFormat: "Зберігається в %@",
        fetchingDetails: "Отримання відомостей про відео…",
        downloading: "Завантаження…",
        paused: "Призупинено",
        downloadComplete: "Завантаження завершено",
        downloadFailed: "Помилка завантаження",
        downloadAgain: "Завантажити знову",
        finishingVideo: "Завершення обробки відео…",
        pause: "Пауза",
        resume: "Продовжити",
        cancel: "Скасувати",
        download: "Завантажити",
        retry: "Повторити",
        recent: "Недавні",
        clearHistory: "Очистити історію",
        showInFinder: "Показати у Finder",
        fetchFailedNotice: "Не вдалося отримати відео. Перевірте посилання та повторіть спробу.",
        featureDisabledNotice: "Завантажувач відео вимкнено, а його інструменти видалено. Увімкніть вище.",
        invalidURL: "Вставте повне посилання http:// або https:// без імені користувача та пароля.",
        unsupportedMetadata: "Завантажуване відео не знайдено. Використовуйте посилання на одне відео, а не список чи трансляцію.",
        missingTools: "Установіть відсутні інструменти нижче та перевірте знову.",
        invalidOutput: "Під час завантаження не створено повний файл відео. Спробуйте іншу якість або посилання.",
        timedOut: "Час очікування операції минув. Перевірте підключення та спробуйте знову.",
        denoRequired: "Для цього сайту потрібен додатковий компонент (Deno). Lattice налаштовує його…",
        singleVideoOnlyNotice: "Використовується лише це відео (списки відтворення не підтримуються).",
        loginRequiredNotice: "Для цього відео потрібен автентифікований сеанс",
        noAccessNotice: "У вас немає доступу до цього відео.",
        browserAccessNotice: "Не вдалося прочитати файли cookie браузера. Перевірте папку профілю або дозволи.",
        manageSessions: "Керувати сеансами",
        tryDifferentSessions: "Спробувати інший сеанс браузера",
        missingToolsTitle: "Деякі інструменти відсутні",
        missingToolsBody: "Деякі компоненти відсутні. Відновити зараз?",
        downloadRequiredTitle: "Потрібні компоненти завантаження",
        downloadRequiredBody: "Дозволити Lattice завантажити та встановити необхідні компоненти для обробки медіа?",
        continueAction: "Продовжити",
        installComponentsTitle: "Потрібні компоненти завантаження",
        installComponentsSubtitle: "Lattice потребує автономних компонентів (yt-dlp, ffmpeg) в Application Support для обробки медіа.",
        keepOff: "Залишити вимкненим",
        install: "Установити",
        installationFailed: "Помилка встановлення",
        gettingReady: "Підготовка завантажувача відео…",
        gettingReadySubtitle: "Lattice налаштовує необхідні інструменти для завантаження відео.",
        repairTitle: "Завантаження відео недоступне",
        repairSubtitle: "Один із компонентів завантаження Lattice відсутній або пошкоджений.",
        repairAction: "Відновити",
        technicalDetails: "Технічні відомості",
        advanced: "Додатково",
        useSystemTools: "Використовувати системні / власні інструменти",
        checkUpdates: "Перевірити оновлення",
        browserSessionTitle: "Сеанс браузера",
        browserSignInDescription: "Завантаження приватних відео за допомогою вашого сеансу входу в браузері.",
        inactive: "Неактивно",
        manage: "Керувати",
        browserSectionLabel: "БРАУЗЕР",
        profileFolderSectionLabel: "ПАПКА ПРОФІЛЮ",
        noneAnonymous: "Немає (Анонімно)",
        otherChromiumBrowser: "Інший браузер Chromium…",
        readyTitleFormat: "%@ готовий до роботи",
        readyDescriptionFormat: "Lattice використовує ваші дані входу в %@.",
        allowFullDiskAccess: "Дозволити повний доступ до диска",
        allowFullDiskAccessDescriptionFormat: "Lattice потребує цього дозволу для читання даних входу в %@.",
        openSystemSettings: "Відкрити «Системні параметри»…",
        browserNotFoundTitleFormat: "%@ не знайдено",
        browserNotFoundDescriptionFormat: "Установіть %@ або виберіть інший браузер.",
        chooseProfileFolder: "Виберіть папку профілю",
        chooseProfileFolderDescription: "Виберіть папку профілю для вашого браузера.",
        chooseFolderAction: "Вибрати папку…",
        changeFolderAction: "Змінити…",
        footnoteAnonymous: "Файли cookie не додаються. Завантажуються лише загальнодоступні потоки.",
        footnoteSignedIn: "Ваші дані входу залишаються на цьому Mac і використовуються лише для завантаження.",
        disconnect: "Від'єднати",
        save: "Зберегти",
        disconnectConfirmTitle: "Від'єднати сеанс браузера?",
        disconnectConfirmMessage: "Ви дійсно бажаєте від'єднати цей сеанс? Для завантажень більше не використовуватимуться файли cookie входу.",
        selectProfilePanelPrompt: "Вибрати профіль",
        selectProfilePanelMessage: "Виберіть каталог профілю браузера з файлами cookie сеансу"
    )

    static let tr = VideoDownloaderFeatureStrings(
        pageTitle: "Video İndirici",
        enableTitle: "Video İndiriciyi Etkinleştir",
        enableSubtitle: "URL üzerinden video ve ses indirin.",
        downloadVideoSectionTitle: "Bir video indirin",
        downloadVideoSectionSubtitle: "Başlamak için bir video bağlantısı yapıştırın.",
        urlPlaceholder: "Video URL'si",
        search: "Videoyu al",
        clear: "Temizle",
        paste: "Yapıştır",
        pasteClipboardURL: "Panodaki URL'yi yapıştır",
        searchClipboardURL: "Panodaki Videoyu Al",
        quality: "Kalite",
        saveTo: "Şuraya kaydet",
        defaultFolder: "~/Downloads",
        bestQuality: "En iyi",
        audioQuality: "Ses",
        savesToFormat: "%@ konumuna kaydeder",
        fetchingDetails: "Video ayrıntıları alınıyor…",
        downloading: "İndiriliyor…",
        paused: "Duraklatıldı",
        downloadComplete: "İndirme tamamlandı",
        downloadFailed: "İndirme başarısız",
        downloadAgain: "Yeniden indir",
        finishingVideo: "Video tamamlanıyor…",
        pause: "Duraklat",
        resume: "Sürdür",
        cancel: "Vazgeç",
        download: "İndir",
        retry: "Tekrar dene",
        recent: "Son kullanılanlar",
        clearHistory: "Geçmişi temizle",
        showInFinder: "Finder'da göster",
        fetchFailedNotice: "Video alınamadı. Bağlantıyı kontrol edip tekrar deneyin.",
        featureDisabledNotice: "Video İndirici kapalı ve araçları kaldırıldı. Kullanmak için yukarıdan açın.",
        invalidURL: "Kullanıcı adı veya şifre içermeyen tam bir http:// veya https:// video bağlantısı yapıştırın.",
        unsupportedMetadata: "İndirilebilir video bulunamadı. Oynatma listesi veya canlı yayın değil, tek bir video bağlantısı kullanın.",
        missingTools: "Aşağıdaki eksik araçları yükleyip tekrar kontrol edin.",
        invalidOutput: "İndirme tam bir video dosyası oluşturmadı. Başka bir kalite veya bağlantı deneyin.",
        timedOut: "İşlem zaman aşımına uğradı. Bağlantınızı kontrol edip tekrar deneyin.",
        denoRequired: "Bu video sitesi ek bir bileşen (Deno) gerektiriyor. Lattice ayarlıyor…",
        singleVideoOnlyNotice: "Yalnızca bu video kullanılıyor (oynatma listeleri desteklenmez).",
        loginRequiredNotice: "Bu video kimliği doğrulanmış bir oturum gerektiriyor",
        noAccessNotice: "Bu videoya erişiminiz yok.",
        browserAccessNotice: "Tarayıcı çerezleri okunamadı. Profil klasörünüzü veya izinlerinizi kontrol edin.",
        manageSessions: "Oturumları Yönet",
        tryDifferentSessions: "Farklı tarayıcı oturumlarını dene",
        missingToolsTitle: "Bazı araçlar eksik",
        missingToolsBody: "Bazı bileşenler eksik. Şimdi onarılsın mı?",
        downloadRequiredTitle: "İndirme Bileşenleri Gerekli",
        downloadRequiredBody: "Lattice'in medya işleme için gerekli bileşenleri indirmesine ve yüklemesine izin verilsin mi?",
        continueAction: "Sürdür",
        installComponentsTitle: "İndirme Bileşenleri Gerekli",
        installComponentsSubtitle: "Lattice, medyayı işlemek için Application Support'ta saklanan bağımsız indirme bileşenlerine (yt-dlp, ffmpeg) ihtiyaç duyar.",
        keepOff: "Kapalı tut",
        install: "Yükle",
        installationFailed: "Yükleme başarısız",
        gettingReady: "Video indirici hazırlanıyor…",
        gettingReadySubtitle: "Lattice, video indirmeleri için gereken araçları ayarlıyor.",
        repairTitle: "Video indirme kullanılamıyor",
        repairSubtitle: "Lattice'in indirme bileşenlerinden biri eksik veya hasarlı.",
        repairAction: "Onar",
        technicalDetails: "Teknik ayrıntılar",
        advanced: "Gelişmiş",
        useSystemTools: "Sistem / özel araçları kullan",
        checkUpdates: "Güncellemeleri denetle",
        browserSessionTitle: "Tarayıcı Oturumu",
        browserSignInDescription: "Giriş yapılmış tarayıcı oturumunuzu kullanarak özel videoları indirir.",
        inactive: "Etkin değil",
        manage: "Yönet",
        browserSectionLabel: "TARAYICI",
        profileFolderSectionLabel: "PROFİL KLASÖRÜ",
        noneAnonymous: "Hiçbiri (Anonim)",
        otherChromiumBrowser: "Diğer Chromium tarayıcısı…",
        readyTitleFormat: "%@ Kullanıma Hazır",
        readyDescriptionFormat: "Lattice, %@ oturum açma bilgilerinizi kullanıyor.",
        allowFullDiskAccess: "Tam Disk Erişimine İzin Ver",
        allowFullDiskAccessDescriptionFormat: "Lattice'in %@ oturum açma bilgilerinizi okuması için buna ihtiyacı var.",
        openSystemSettings: "Sistem Ayarlarını Aç…",
        browserNotFoundTitleFormat: "%@ Bulunamadı",
        browserNotFoundDescriptionFormat: "%@ tarayıcısını yükleyin veya başka bir tarayıcı seçin.",
        chooseProfileFolder: "Bir Profil Klasörü Seçin",
        chooseProfileFolderDescription: "Tarayıcınız için bir profil klasörü seçin.",
        chooseFolderAction: "Klasör Seç…",
        changeFolderAction: "Değiştir…",
        footnoteAnonymous: "Çerez eklenmedi. İndirmeler yalnızca herkese açık akışları talep eder.",
        footnoteSignedIn: "Giriş bilgileriniz bu Mac'te kalır ve yalnızca indirmeler için kullanılır.",
        disconnect: "Bağlantıyı Kes",
        save: "Kaydet",
        disconnectConfirmTitle: "Tarayıcı Oturumu Bağlantısı Kesilsin mi?",
        disconnectConfirmMessage: "Bu tarayıcı oturumunun bağlantısını kesmek istediğinizden emin misiniz? İndirmeler artık giriş çerezlerinizi kullanmayacak.",
        selectProfilePanelPrompt: "Profil Seç",
        selectProfilePanelMessage: "Oturum çerezlerinizi içeren tarayıcı profil dizinini seçin"
    )

    static let sk = VideoDownloaderFeatureStrings(
        pageTitle: "Sťahovač videí",
        enableTitle: "Zapnúť Sťahovač videí",
        enableSubtitle: "Sťahujte videá a zvuk cez URL.",
        downloadVideoSectionTitle: "Stiahnuť video",
        downloadVideoSectionSubtitle: "Začnite vložením odkazu na video.",
        urlPlaceholder: "URL videa",
        search: "Získať video",
        clear: "Vymazať",
        paste: "Vložiť",
        pasteClipboardURL: "Vložiť URL zo schránky",
        searchClipboardURL: "Získať video zo schránky",
        quality: "Kvalita",
        saveTo: "Uložiť do",
        defaultFolder: "~/Downloads",
        bestQuality: "Najlepšia",
        audioQuality: "Zvuk",
        savesToFormat: "Ukladá sa do %@",
        fetchingDetails: "Získavajú sa podrobnosti o videu…",
        downloading: "Sťahuje sa…",
        paused: "Pozastavené",
        downloadComplete: "Sťahovanie dokončené",
        downloadFailed: "Sťahovanie zlyhalo",
        downloadAgain: "Stiahnuť znova",
        finishingVideo: "Dokončuje sa video…",
        pause: "Pozastaviť",
        resume: "Pokračovať",
        cancel: "Zrušiť",
        download: "Stiahnuť",
        retry: "Znova",
        recent: "Nedávne",
        clearHistory: "Vymazať históriu",
        showInFinder: "Zobraziť vo Finderi",
        fetchFailedNotice: "Video sa nepodarilo získať. Skontrolujte odkaz a skúste to znova.",
        featureDisabledNotice: "Sťahovač videí je vypnutý a jeho nástroje boli odstránené. Zapnite ho vyššie.",
        invalidURL: "Vložte úplný odkaz http:// alebo https:// bez mena a hesla.",
        unsupportedMetadata: "Nenašlo sa žiadne video na stiahnutie. Použite odkaz na jedno video, nie zoznam ani živé vysielanie.",
        missingTools: "Nainštalujte chýbajúce nástroje nižšie a skontrolujte to znova.",
        invalidOutput: "Sťahovanie nevytvorilo kompletný súbor videa. Skúste inú kvalitu alebo odkaz.",
        timedOut: "Operácia trvala príliš dlho. Skontrolujte pripojenie a skúste to znova.",
        denoRequired: "Tento web vyžaduje dodatočnú súčasť (Deno). Lattice ju nastavuje…",
        singleVideoOnlyNotice: "Používa sa iba toto video (zoznamy videí nie sú podporované).",
        loginRequiredNotice: "Toto video vyžaduje overenú reláciu",
        noAccessNotice: "K tomuto videu nemáte prístup.",
        browserAccessNotice: "Nepodarilo sa načítať cookies prehliadača. Skontrolujte priečinok profilu alebo oprávnenia.",
        manageSessions: "Spravovať relácie",
        tryDifferentSessions: "Skúsiť iné relácie prehliadača",
        missingToolsTitle: "Niektoré nástroje chýbajú",
        missingToolsBody: "Chýbajú niektoré súčasti. Opraviť teraz?",
        downloadRequiredTitle: "Vyžadujú sa súčasti na sťahovanie",
        downloadRequiredBody: "Povoliť aplikácii Lattice stiahnuť a nainštalovať potrebné súčasti na spracovanie médií?",
        continueAction: "Pokračovať",
        installComponentsTitle: "Vyžadujú sa súčasti na sťahovanie",
        installComponentsSubtitle: "Lattice potrebuje samostatné súčasti (yt-dlp, ffmpeg) v Application Support na spracovanie médií.",
        keepOff: "Ponechať vypnuté",
        install: "Inštalovať",
        installationFailed: "Inštalácia zlyhala",
        gettingReady: "Pripravuje sa sťahovač videí…",
        gettingReadySubtitle: "Lattice nastavuje nástroje potrebné na sťahovanie videí.",
        repairTitle: "Sťahovanie videí nie je k dispozícii",
        repairSubtitle: "Jedna zo súčastí sťahovania v Lattice chýba alebo je poškodená.",
        repairAction: "Opraviť",
        technicalDetails: "Technické podrobnosti",
        advanced: "Rozšírené",
        useSystemTools: "Použiť systémové / vlastné nástroje",
        checkUpdates: "Vyhľadať aktualizácie",
        browserSessionTitle: "Relácia prehliadača",
        browserSignInDescription: "Sťahuje súkromné videá pomocou prihlásenej relácie prehliadača.",
        inactive: "Neaktívne",
        manage: "Spravovať",
        browserSectionLabel: "PREHLIADAČ",
        profileFolderSectionLabel: "PRIEČINOK PROFILU",
        noneAnonymous: "Žiadny (Anonymný)",
        otherChromiumBrowser: "Iný prehliadač Chromium…",
        readyTitleFormat: "%@ je pripravený",
        readyDescriptionFormat: "Lattice používa vaše prihlásenie v prehliadači %@.",
        allowFullDiskAccess: "Povoliť úplný prístup k disku",
        allowFullDiskAccessDescriptionFormat: "Lattice potrebuje tento prístup na načítanie vášho prihlásenia v prehliadači %@.",
        openSystemSettings: "Otvoriť Systémové nastavenia…",
        browserNotFoundTitleFormat: "%@ sa nenašiel",
        browserNotFoundDescriptionFormat: "Nainštalujte %@ alebo vyberte iný prehliadač.",
        chooseProfileFolder: "Vybrať priečinok profilu",
        chooseProfileFolderDescription: "Vyberte priečinok profilu pre váš prehliadač.",
        chooseFolderAction: "Vybrať priečinok…",
        changeFolderAction: "Zmeniť…",
        footnoteAnonymous: "Bez cookies. Sťahovanie bude žiadať iba verejné streamy.",
        footnoteSignedIn: "Vaše prihlásenie zostáva na tomto Macu a používa sa iba na sťahovanie.",
        disconnect: "Odpojiť",
        save: "Uložiť",
        disconnectConfirmTitle: "Odpojiť reláciu prehliadača?",
        disconnectConfirmMessage: "Naozaj chcete odpojiť túto reláciu prehliadača? Sťahovanie už nebude používať vaše prihlasovacie cookies.",
        selectProfilePanelPrompt: "Vybrať profil",
        selectProfilePanelMessage: "Vyberte priečinok profilu prehliadača obsahujúci relačné cookies"
    )
}

/// Dynamic interface to VideoDownloader strings observing L10n.shared.language.
enum VideoDownloaderStrings {
    static var current: VideoDownloaderFeatureStrings {
        FeatureStrings.videoDownloader(L10n.shared.language)
    }

    static var pageTitle: String { current.pageTitle }
    static var enableTitle: String { current.enableTitle }
    static var enableSubtitle: String { current.enableSubtitle }
    static var showOnDynamicIsland: String {
        SettingsOwnershipStrings.text(.showIsland, L10n.shared.language)
    }

    static var downloadVideoSectionTitle: String { current.downloadVideoSectionTitle }
    static var downloadVideoSectionSubtitle: String { current.downloadVideoSectionSubtitle }
    static var urlPlaceholder: String { current.urlPlaceholder }
    static var search: String { current.search }
    static var clear: String { current.clear }
    static var paste: String { current.paste }
    static var pasteClipboardURL: String { current.pasteClipboardURL }
    static var searchClipboardURL: String { current.searchClipboardURL }

    static var quality: String { current.quality }
    static var saveTo: String { current.saveTo }
    static var defaultFolder: String { current.defaultFolder }
    static var bestQuality: String { current.bestQuality }
    static var audioQuality: String { current.audioQuality }

    static var fetchingDetails: String { current.fetchingDetails }
    static var downloading: String { current.downloading }
    static var paused: String { current.paused }
    static var downloadComplete: String { current.downloadComplete }
    static var downloadFailed: String { current.downloadFailed }
    static var downloadAgain: String { current.downloadAgain }
    static var finishingVideo: String { current.finishingVideo }
    static var pause: String { current.pause }
    static var resume: String { current.resume }
    static var cancel: String { current.cancel }
    static var download: String { current.download }
    static var retry: String { current.retry }

    static var recent: String { current.recent }
    static var clearHistory: String { current.clearHistory }
    static var showInFinder: String { current.showInFinder }

    static var fetchFailedNotice: String { current.fetchFailedNotice }
    static var featureDisabledNotice: String { current.featureDisabledNotice }
    static var invalidURL: String { current.invalidURL }
    static var unsupportedMetadata: String { current.unsupportedMetadata }
    static var missingTools: String { current.missingTools }
    static var invalidOutput: String { current.invalidOutput }
    static var timedOut: String { current.timedOut }
    static var denoRequired: String { current.denoRequired }
    static var singleVideoOnlyNotice: String { current.singleVideoOnlyNotice }
    static var loginRequiredNotice: String { current.loginRequiredNotice }
    static var noAccessNotice: String { current.noAccessNotice }
    static var browserAccessNotice: String { current.browserAccessNotice }
    static var manageSessions: String { current.manageSessions }
    static var tryDifferentSessions: String { current.tryDifferentSessions }

    static var missingToolsTitle: String { current.missingToolsTitle }
    static var missingToolsBody: String { current.missingToolsBody }
    static var downloadRequiredTitle: String { current.downloadRequiredTitle }
    static var downloadRequiredBody: String { current.downloadRequiredBody }
    static var continueAction: String { current.continueAction }
    static var installComponentsTitle: String { current.installComponentsTitle }
    static var installComponentsSubtitle: String { current.installComponentsSubtitle }
    static var keepOff: String { current.keepOff }
    static var install: String { current.install }
    static var installationFailed: String { current.installationFailed }
    static var gettingReady: String { current.gettingReady }
    static var gettingReadySubtitle: String { current.gettingReadySubtitle }
    static var repairTitle: String { current.repairTitle }
    static var repairSubtitle: String { current.repairSubtitle }
    static var repairAction: String { current.repairAction }
    static var technicalDetails: String { current.technicalDetails }
    static var advanced: String { current.advanced }
    static var useSystemTools: String { current.useSystemTools }
    static var checkUpdates: String { current.checkUpdates }

    static var browserSessionTitle: String { current.browserSessionTitle }
    static var browserSignInDescription: String { current.browserSignInDescription }
    static var inactive: String { current.inactive }
    static var manage: String { current.manage }
    static var browserSectionLabel: String { current.browserSectionLabel }
    static var profileFolderSectionLabel: String { current.profileFolderSectionLabel }
    static var noneAnonymous: String { current.noneAnonymous }
    static var otherChromiumBrowser: String { current.otherChromiumBrowser }

    static var allowFullDiskAccess: String { current.allowFullDiskAccess }
    static var openSystemSettings: String { current.openSystemSettings }
    static var chooseProfileFolder: String { current.chooseProfileFolder }
    static var chooseProfileFolderDescription: String { current.chooseProfileFolderDescription }
    static var chooseFolderAction: String { current.chooseFolderAction }
    static var changeFolderAction: String { current.changeFolderAction }
    static var footnoteAnonymous: String { current.footnoteAnonymous }
    static var footnoteSignedIn: String { current.footnoteSignedIn }
    static var disconnect: String { current.disconnect }
    static var save: String { current.save }
    static var disconnectConfirmTitle: String { current.disconnectConfirmTitle }
    static var disconnectConfirmMessage: String { current.disconnectConfirmMessage }
    static var selectProfilePanelPrompt: String { current.selectProfilePanelPrompt }
    static var selectProfilePanelMessage: String { current.selectProfilePanelMessage }

    static func readyTitle(browser: String) -> String {
        current.readyTitle(browser: browser)
    }

    static func readyDescription(browser: String) -> String {
        current.readyDescription(browser: browser)
    }

    static func allowFullDiskAccessDescription(browser: String) -> String {
        current.allowFullDiskAccessDescription(browser: browser)
    }

    static func browserNotFoundTitle(browser: String) -> String {
        current.browserNotFoundTitle(browser: browser)
    }

    static func browserNotFoundDescription(browser: String) -> String {
        current.browserNotFoundDescription(browser: browser)
    }

    static func savesTo(folder: String) -> String {
        current.savesTo(folder: folder)
    }
}
