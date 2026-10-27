import Foundation

enum VideoDownloaderTests {
    static func run(_ suite: TestSuite) {
        suite.expect((try? VideoDownloadRequest.validatedURL(" https://example.com/watch?v=1&list=2 "))?.host == "example.com",
                     "a pasted HTTP video link is trimmed without interpreting shell syntax")
        for invalid in ["file:///etc/passwd", "javascript:alert(1)", "--exec=bad", "https://user:password@example.com/x", "https://", "https://example.com/\n--exec=bad"] {
            suite.expect((try? VideoDownloadRequest.validatedURL(invalid)) == nil,
                         "non-web, credential-bearing and control-character links are rejected")
        }
        let json = Data(#"{"id":"abc","title":"A video","duration":95,"uploader":"A creator","formats":[{"format_id":"18","ext":"mp4","height":360,"vcodec":"avc1","acodec":"mp4a"},{"format_id":"137","ext":"mp4","height":1080,"vcodec":"avc1","acodec":"none"},{"format_id":"140","ext":"m4a","vcodec":"none","acodec":"mp4a"},{"format_id":"drm","ext":"mp4","height":2160,"vcodec":"avc1","has_drm":true}]}"#.utf8)
        do {
            let info = try VideoDownloadInfo.decode(json)
            suite.expect(info.title == "A video" && info.qualities.map(\.height) == [1080, 360],
                         "quality choices include usable video formats, highest first, excluding DRM and audio-only")
            let args = VideoDownloadRequest.metadataArguments(url: try VideoDownloadRequest.validatedURL("https://example.com/$(touch%20bad)"))
            suite.expect(args.suffix(2).first == "--" && args.last == "https://example.com/$(touch%20bad)",
                         "URL remains a literal final argument after the option terminator")
        } catch { suite.expect(false, "valid single-video metadata decodes: \(error)") }
        for data in [Data("{}".utf8), Data(#"{"_type":"playlist","entries":[]}"#.utf8)] {
            suite.expect((try? VideoDownloadInfo.decode(data)) == nil, "empty and playlist results are not downloadable single videos")
        }
        let absurdTbrJson = Data(#"{"id":"absurd","title":"Absurd TBR","duration":100,"formats":[{"format_id":"1","ext":"mp4","height":720,"vcodec":"avc1","acodec":"mp4a","tbr":1e300}]}"#.utf8)
        suite.expect((try? VideoDownloadInfo.decode(absurdTbrJson)) != nil,
                     "absurd bitrate estimate does not trap Int64 conversion")
        suite.expect(VideoDownloadRequest.hasPlayableVideo(Data(#"{"streams":[{"codec_type":"video","width":1280,"height":720}],"format":{"duration":"10.5"}}"#.utf8)),
                     "a probed video stream with dimensions and duration can be published")
        suite.expect(!VideoDownloadRequest.hasPlayableVideo(Data(#"{"streams":[{"codec_type":"audio"}],"format":{"duration":"10"}}"#.utf8)),
                     "an audio-only result cannot claim successful video download")
        let absent = VideoDownloadDependencies.discover(environment: ["PATH": "relative/bin"], executable: { _ in false })
        suite.expect(!absent.ready && absent.brew == nil && absent.installArguments == ["install", "yt-dlp", "ffmpeg", "deno"],
                     "a machine without dependencies gets a concrete installation plan including ffprobe via ffmpeg")
        let onlyProbeMissing = VideoDownloadDependencies(tools: ["yt-dlp": "/tools/yt-dlp", "ffmpeg": "/tools/ffmpeg", "deno": "/tools/deno"], environment: [:])
        suite.expect(onlyProbeMissing.installArguments == ["install", "ffmpeg"], "a missing ffprobe is repaired by installing its owning formula")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("io.github.sam32j.lattice.tests.download-containment-\(UUID())")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            defer { try? FileManager.default.removeItem(at: folder) }
            let empty = folder.appendingPathComponent("empty.mp4")
            try Data().write(to: empty)
            suite.expect((try? VideoDownloadRequest.validatedOutput(empty, from: folder)) == nil,
                         "empty results are rejected before ffprobe")
            suite.expect((try? VideoDownloadRequest.validatedOutput(URL(fileURLWithPath: "/etc/hosts"), from: folder)) == nil,
                         "reported paths outside owned staging cannot be probed or published")
            let audioArgs = VideoDownloadRequest.downloadArguments(url: try VideoDownloadRequest.validatedURL("https://example.com/v"),
                                                                  quality: .audio, staging: folder, ffmpeg: "/tools/ffmpeg")
            suite.expect(audioArgs.contains("--extract-audio") && audioArgs.contains("m4a"),
                         "audio quality requests audio stream extraction to m4a format")
            suite.expect(audioArgs.contains(#"before_dl:LATTICE_PARTS:{"parts":%(requested_formats.:.{format_id,filesize,filesize_approx}|[])j,"single":%(format_id)j}"#),
                         "parts output template defaults absent requested formats to empty json array")
            let parsedProgress = VideoDownloadRequest.parseProgress("LATTICE_PROGRESS:42%|612000000|1400000000|8400000|60")
            suite.expect(parsedProgress?.fraction == 0.42 && parsedProgress?.downloadedBytes == 612000000 && parsedProgress?.totalBytes == 1400000000,
                         "detailed progress line parses fraction, bytes, and rate")
            suite.expect(VideoDownloadRequest.hasPlayableMedia(Data(#"{"streams":[{"codec_type":"audio"}],"format":{"duration":"10"}}"#.utf8), isAudio: true),
                         "audio extraction verifies playable audio duration and stream")
            let history = DownloadHistoryStore(storeURL: folder.appendingPathComponent("history.json"))
            let sampleFile = folder.appendingPathComponent("sample.mp4")
            try Data("sample".utf8).write(to: sampleFile)
            history.record(fileURL: sampleFile, title: "Sample Video", qualityTag: "1080p")
            suite.expect(history.items.first?.title == "Sample Video" && history.items.first?.qualityTag == "1080p",
                         "recent downloads store records file, title and quality")
            history.clear()
            suite.expect(history.items.isEmpty, "history store clear removes records")
        } catch { suite.expect(false, "contained publication validation: \(error)") }
        // Website Sessions & Profile Detection Tests
        let memoryDefaults = UserDefaults(suiteName: "io.github.sam32j.lattice.tests.session-\(UUID())")!
        let sessions = VideoWebsiteSessions(defaults: memoryDefaults)
        suite.expect(!sessions.hasSession && sessions.summaryText == "None (Anonymous)",
                     "default sessions state is anonymous")
        sessions.saveSession(browser: .safari)
        suite.expect(sessions.hasSession && sessions.summaryText == "Safari",
                     "safari session summary displays clean browser name")
        sessions.saveSession(browser: .chrome, profile: "Default")
        suite.expect(sessions.summaryText == "Chrome",
                     "chrome default profile displays clean browser name without appending Default")
        sessions.saveSession(browser: .chrome, profile: "Work")
        suite.expect(sessions.summaryText == "Chrome · Work",
                     "chrome custom profile displays browser and profile name")
        sessions.saveSession(browser: .chromium, profile: "/Users/test/Library/Application Support/Crest-024F49D9-2F79-425F-84CC-D29E367143D8")
        suite.expect(sessions.summaryText.hasPrefix("Chromium · Crest-024F49") && sessions.summaryText.hasSuffix("…"),
                     "long profile path is truncated to prevent multiline wrap in UI")
        sessions.clearSession()
        suite.expect(!sessions.hasSession, "clearSession removes active session")

        suite.expect(VideoSessionBrowser.standardBrowsers.count == 8 && !VideoSessionBrowser.standardBrowsers.contains(.chromium),
                     "standard browsers list excludes generic chromium")
        suite.expect(VideoSessionBrowser.chromium.title == "Other Chromium browser…",
                     "generic chromium browser title is user-facing")

        suite.expect(VideoDownloaderStrings.searchClipboardURL == "Get Clipboard Video",
                     "clipboard action button displays 'Get Clipboard Video'")
        suite.expect(VideoWebsiteFailure.authentication.message(hasActiveSession: false) == "This video requires an authenticated session",
                     "anonymous auth failure notice asks for authenticated session")
        suite.expect(VideoWebsiteFailure.authentication.message(hasActiveSession: true) == "You don't have access to this video.",
                     "signed-in auth failure notice reports no access")
        suite.expect(VideoDownloaderStrings.tryDifferentSessions == "Try different browser sessions",
                     "signed-in auth failure action button says 'Try different browser sessions'")

        // Bilibili detection & HTTP 567 fallback retry tests
        let biliURL1 = URL(string: "https://www.bilibili.com/video/BV1zH4y1s7Ln/")!
        let biliURL2 = URL(string: "https://bilibili.com/video/BV1zH4y1s7Ln/")!
        let b23URL = URL(string: "https://b23.tv/BV1zH4y1s7Ln")!
        let youtubeURL = URL(string: "https://www.youtube.com/watch?v=123")!
        let notBiliURL = URL(string: "https://notbilibili.com/video/BV1zH4y1s7Ln")!

        suite.expect(VideoDownloadRequest.isBilibiliURL(biliURL1), "www.bilibili.com is detected as Bilibili")
        suite.expect(VideoDownloadRequest.isBilibiliURL(biliURL2), "bilibili.com is detected as Bilibili")
        suite.expect(VideoDownloadRequest.isBilibiliURL(b23URL), "b23.tv is detected as Bilibili")
        suite.expect(!VideoDownloadRequest.isBilibiliURL(youtubeURL), "youtube.com is not Bilibili")
        suite.expect(!VideoDownloadRequest.isBilibiliURL(notBiliURL), "notbilibili.com is not Bilibili")

        let error567Output = "[download] Got error: HTTP Error 567: Unknown Status. Retrying (1/10)..."
        suite.expect(VideoDownloadRequest.shouldRetryBilibili567(url: biliURL1, output: error567Output, didUseRangeFallback: false),
                     "Bilibili URL with HTTP Error 567 triggers retry when fallback unused")
        suite.expect(VideoDownloadRequest.shouldRetryBilibili567(url: youtubeURL, output: "[BiliBili] Extracting URL...\n" + error567Output, didUseRangeFallback: false),
                     "Extractor marker [BiliBili] triggers retry even if URL host differs")
        suite.expect(!VideoDownloadRequest.shouldRetryBilibili567(url: biliURL1, output: error567Output, didUseRangeFallback: true),
                     "Retry is not triggered if fallback was already attempted")
        suite.expect(!VideoDownloadRequest.shouldRetryBilibili567(url: youtubeURL, output: error567Output, didUseRangeFallback: false),
                     "Non-Bilibili download with 567 does not trigger retry")
        suite.expect(!VideoDownloadRequest.shouldRetryBilibili567(url: biliURL1, output: "HTTP Error 403: Forbidden", didUseRangeFallback: false),
                     "HTTP 403 does not trigger fallback retry")
        suite.expect(!VideoDownloadRequest.shouldRetryBilibili567(url: biliURL1, output: "HTTP Error 404: Not Found", didUseRangeFallback: false),
                     "HTTP 404 does not trigger fallback retry")
        suite.expect(!VideoDownloadRequest.shouldRetryBilibili567(url: biliURL1, output: "HTTP Error 429: Too Many Requests", didUseRangeFallback: false),
                     "HTTP 429 does not trigger fallback retry")
        suite.expect(!VideoDownloadRequest.shouldRetryBilibili567(url: biliURL1, output: "you have to become a premium member", didUseRangeFallback: false),
                     "Premium member warning alone does not trigger retry")

        // Download arguments compatibility options
        let defaultArgs = VideoDownloadRequest.downloadArguments(url: biliURL1, quality: .best, staging: folder, ffmpeg: "/tools/ffmpeg")
        suite.expect(!defaultArgs.contains("--add-headers") && !defaultArgs.contains("Range:bytes=0-"),
                     "Normal download arguments do not include Range header")
        let fallbackArgs = VideoDownloadRequest.downloadArguments(url: biliURL1, quality: .best, staging: folder, ffmpeg: "/tools/ffmpeg", compatibility: .init(bilibiliRangeFallback: true))
        suite.expect(fallbackArgs.contains("--add-headers") && fallbackArgs.contains("Range:bytes=0-"),
                     "Compatibility fallback arguments include Range:bytes=0- header")

        // Clean error message tests
        suite.expect(VideoDownloadRequest.cleanErrorMessage("ERROR: unable to download video data: HTTP Error 567: Unknown Status") == "HTTP Error 567: Unknown Status",
                     "cleanErrorMessage extracts HTTP Error from yt-dlp error line")
        suite.expect(VideoDownloadRequest.cleanErrorMessage("HTTP Error 404: Not Found") == "HTTP Error 404: Not Found",
                     "cleanErrorMessage preserves direct HTTP Error")
        suite.expect(VideoDownloadRequest.cleanErrorMessage("This video requires sign-in. Configure browser sign-in below to download.") == "This video requires sign-in. Configure browser sign-in below to download.",
                     "cleanErrorMessage preserves authentication failure message")

        // Thumbnail URL HTTP to HTTPS upgrade test
        let httpThumbJson = Data(#"{"id":"bili1","title":"Bili Video","duration":100,"thumbnail":"http://i2.hdslb.com/bfs/archive/pic.jpg","formats":[{"format_id":"1","ext":"mp4","height":720,"vcodec":"avc1","acodec":"mp4a"}]}"#.utf8)
        let decodedInfo = try? VideoDownloadInfo.decode(httpThumbJson)
        suite.expect(decodedInfo?.thumbnailURL?.absoluteString == "https://i2.hdslb.com/bfs/archive/pic.jpg",
                     "HTTP thumbnail URLs are upgraded to HTTPS for ATS compatibility")

        // Video Downloader Internationalization Tests
        let initialLang = L10n.shared.language
        defer { L10n.shared.language = initialLang }

        for lang in AppLanguage.allCases {
            let localized = FeatureStrings.videoDownloader(lang)
            suite.expect(!localized.pageTitle.isEmpty && !localized.downloadVideoSectionTitle.isEmpty,
                         "\(lang.rawValue) provides non-empty page title and section title")
            suite.expect(!localized.browserSessionTitle.isEmpty && !localized.noneAnonymous.isEmpty,
                         "\(lang.rawValue) provides non-empty browser session strings")
            suite.expect(!localized.search.isEmpty && !localized.searchClipboardURL.isEmpty,
                         "\(lang.rawValue) provides non-empty search and action strings")
            suite.expect(localized.savesTo(folder: "Downloads").contains("Downloads"),
                         "\(lang.rawValue) formats savesTo with destination folder")
            suite.expect(localized.readyTitle(browser: "Safari").contains("Safari"),
                         "\(lang.rawValue) formats readyTitle with browser name")
        }

        // Specific language checks
        let zhHans = FeatureStrings.videoDownloader(.zhHans)
        suite.expect(zhHans.pageTitle == "视频下载器" && zhHans.search == "获取视频" && zhHans.browserSessionTitle == "浏览器会话",
                     "zhHans has accurate translations")

        let ja = FeatureStrings.videoDownloader(.ja)
        suite.expect(ja.pageTitle == "動画ダウンローダー" && ja.search == "動画を取得" && ja.browserSessionTitle == "ブラウザセッション",
                     "ja has accurate translations")

        let de = FeatureStrings.videoDownloader(.de)
        suite.expect(de.pageTitle == "Video-Downloader" && de.search == "Video laden" && de.browserSessionTitle == "Browsersitzung",
                     "de has accurate translations")

        // Dynamic reactivity check
        L10n.shared.language = .zhHans
        suite.expect(VideoDownloaderStrings.pageTitle == "视频下载器",
                     "VideoDownloaderStrings dynamically reflects zhHans")
        L10n.shared.language = .enUS
        suite.expect(VideoDownloaderStrings.pageTitle == "Video Downloader",
                     "VideoDownloaderStrings dynamically reflects enUS")

        VideoDownloadProgressTests.run(suite)
        VideoDownloadProcessTests.run(suite)
        VideoDownloaderServiceTests.run(suite)
        VideoDownloaderInputTests.run(suite)
        VideoDownloaderSearchBarTests.run(suite)
    }
}
