// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

enum VideoWebsiteSessionsTests {
    static func run(_ suite: TestSuite) {
        testBrowserEnum(suite)
        testSessionModel(suite)
        testSessionsService(suite)
        testHostNormalization(suite)
        testFailureClassifier(suite)
        testSafariFullDiskAccess(suite)
    }

    private static func testBrowserEnum(_ suite: TestSuite) {
        // 1. All 9 cases exist and have distinct IDs
        let allBrowsers = VideoSessionBrowser.allCases
        suite.expect(allBrowsers.count == 9, "VideoSessionBrowser has exactly 9 supported browsers")
        suite.expect(Set(allBrowsers.map(\.id)).count == 9, "all browsers have unique identifiers matching rawValue")

        // 2. supportsProfiles logic
        suite.expect(!VideoSessionBrowser.safari.supportsProfiles, "Safari does not support profile directories")
        suite.expect(!VideoSessionBrowser.opera.supportsProfiles, "Opera does not support profile directories")
        for browser in [VideoSessionBrowser.chrome, .firefox, .brave, .edge, .chromium, .vivaldi, .whale] {
            suite.expect(browser.supportsProfiles, "\(browser.rawValue) supports multiple profiles")
        }

        // 3. isGenericChromium
        suite.expect(VideoSessionBrowser.chromium.isGenericChromium, "chromium is marked as generic chromium")
        for browser in allBrowsers where browser != .chromium {
            suite.expect(!browser.isGenericChromium, "\(browser.rawValue) is not generic chromium")
        }

        // 4. standardBrowsers excludes chromium
        let standard = VideoSessionBrowser.standardBrowsers
        suite.expect(standard.count == 8 && !standard.contains(.chromium),
                     "standardBrowsers contains 8 preset browsers, excluding generic chromium")

        // 5. Titles
        suite.expect(VideoSessionBrowser.safari.title == "Safari", "Safari title is Safari")
        suite.expect(VideoSessionBrowser.chrome.title == "Chrome", "Chrome title is Chrome")
        suite.expect(VideoSessionBrowser.firefox.title == "Firefox", "Firefox title is Firefox")
        suite.expect(VideoSessionBrowser.brave.title == "Brave", "Brave title is Brave")
        suite.expect(VideoSessionBrowser.edge.title == "Microsoft Edge", "Edge title is Microsoft Edge")
        suite.expect(VideoSessionBrowser.vivaldi.title == "Vivaldi", "Vivaldi title is Vivaldi")
        suite.expect(VideoSessionBrowser.opera.title == "Opera", "Opera title is Opera")
        suite.expect(VideoSessionBrowser.whale.title == "Whale", "Whale title is Whale")
        suite.expect(!VideoSessionBrowser.chromium.title.isEmpty, "generic chromium title is localized")
    }

    private static func testSessionModel(_ suite: TestSuite) {
        // Trimming whitespace
        let sessionWhitespace = VideoWebsiteSession(browser: .chrome, profile: "   Profile 1   ", host: "youtube.com")
        suite.expect(sessionWhitespace.profile == "Profile 1", "session profile trims leading and trailing whitespace")

        // Stripping surrounding double and single quotes
        let sessionDoubleQuotes = VideoWebsiteSession(browser: .chrome, profile: "\"Profile 2\"", host: "youtube.com")
        suite.expect(sessionDoubleQuotes.profile == "Profile 2", "session profile strips surrounding double quotes")

        let sessionSingleQuotes = VideoWebsiteSession(browser: .chrome, profile: "'Profile 3'", host: "youtube.com")
        suite.expect(sessionSingleQuotes.profile == "Profile 3", "session profile strips surrounding single quotes")

        // Tilde path expansion
        let sessionTilde = VideoWebsiteSession(browser: .chromium, profile: "~/Library/Test", host: "example.com")
        suite.expect(sessionTilde.profile.hasPrefix("/") && !sessionTilde.profile.contains("~"),
                     "tilde prefix in profile path is expanded to home directory")

        // Safari & Opera profile ignoring
        let safariSession = VideoWebsiteSession(browser: .safari, profile: "Profile 1", host: "youtube.com")
        suite.expect(safariSession.profile.isEmpty, "Safari session enforces empty profile string")

        let operaSession = VideoWebsiteSession(browser: .opera, profile: "Profile 1", host: "youtube.com")
        suite.expect(operaSession.profile.isEmpty, "Opera session enforces empty profile string")

        // Arguments generation
        suite.expect(safariSession.arguments == ["--cookies-from-browser", "safari"],
                     "Safari arguments omit profile argument")

        let chromeDefault = VideoWebsiteSession(browser: .chrome, profile: "", host: "youtube.com")
        suite.expect(chromeDefault.arguments == ["--cookies-from-browser", "chrome"],
                     "Chrome default session omits colon and profile name")

        let chromeCustom = VideoWebsiteSession(browser: .chrome, profile: "Work", host: "youtube.com")
        suite.expect(chromeCustom.arguments == ["--cookies-from-browser", "chrome:Work"],
                     "Chrome custom session appends :profile to browser argument")

        let chromiumCustom = VideoWebsiteSession(browser: .chromium, profile: "/path/to/profile", host: "youtube.com")
        suite.expect(chromiumCustom.arguments == ["--cookies-from-browser", "chromium:/path/to/profile"],
                     "Chromium custom session formats path in cookies argument")

        // Codable roundtrip
        do {
            let encoded = try JSONEncoder().encode(chromeCustom)
            let decoded = try JSONDecoder().decode(VideoWebsiteSession.self, from: encoded)
            suite.expect(decoded == chromeCustom && decoded.id == "chrome",
                         "VideoWebsiteSession encodes and decodes losslessly via Codable")
        } catch {
            suite.expect(false, "session Codable serialization failed: \(error)")
        }
    }

    private static func testSessionsService(_ suite: TestSuite) {
        let testDefaults = UserDefaults(suiteName: "io.github.sam32j.lattice.tests.sessions-\(UUID())")!
        let store = VideoWebsiteSessions(defaults: testDefaults)

        suite.expect(!store.hasSession && store.activeSession == nil, "new store has no active session")
        suite.expect(store.summaryText == VideoDownloaderStrings.noneAnonymous,
                     "unconfigured store summaryText displays anonymous state")

        // Saving Safari session
        store.saveSession(browser: .safari)
        suite.expect(store.hasSession && store.activeSession?.browser == .safari,
                     "saving Safari session updates activeSession")
        suite.expect(store.summaryText == "Safari", "Safari session displays clean browser title")

        // Saving Chrome session with Default profile
        store.saveSession(browser: .chrome, profile: "Default")
        suite.expect(store.summaryText == "Chrome", "Chrome Default profile displays clean browser title without 'Default'")

        // Saving Chrome session with named profile
        store.saveSession(browser: .chrome, profile: "Work")
        suite.expect(store.summaryText == "Chrome · Work", "Chrome named profile displays 'Browser · Profile'")

        // Saving Chromium session with long profile path (truncation check)
        store.saveSession(browser: .chromium, profile: "/Users/test/Library/Application Support/Crest-A16C1747-9BB6-491C-8BFA-D38410987654")
        suite.expect(store.summaryText.hasPrefix("Chromium · Crest-A16C") && store.summaryText.hasSuffix("…"),
                     "long profile folder name is truncated with trailing ellipsis")

        // Persistence check in separate store instance
        let reloadedStore = VideoWebsiteSessions(defaults: testDefaults)
        suite.expect(reloadedStore.hasSession && reloadedStore.activeSession?.browser == .chromium,
                     "saved session persists across VideoWebsiteSessions instances")

        // Clearing session
        store.clearSession()
        suite.expect(!store.hasSession && store.activeSession == nil, "clearSession removes active session")
        suite.expect(store.summaryText == VideoDownloaderStrings.noneAnonymous, "cleared session returns to anonymous summary")
    }

    private static func testHostNormalization(_ suite: TestSuite) {
        // Valid hosts
        suite.expect(VideoWebsiteSessions.host("https://www.youtube.com/watch?v=123") == "youtube.com",
                     "www.youtube.com is normalized to youtube.com")
        suite.expect(VideoWebsiteSessions.host("http://youtu.be/abc") == "youtube.com",
                     "youtu.be is normalized to youtube.com")
        suite.expect(VideoWebsiteSessions.host("https://m.youtube.com/watch?v=abc") == "youtube.com",
                     "m.youtube.com is normalized to youtube.com")
        suite.expect(VideoWebsiteSessions.host("https://music.youtube.com/watch?v=abc") == "youtube.com",
                     "music.youtube.com is normalized to youtube.com")
        suite.expect(VideoWebsiteSessions.host("https://www.bilibili.com/video/BV1") == "bilibili.com",
                     "www.bilibili.com strips www prefix")
        suite.expect(VideoWebsiteSessions.host("bilibili.com/video/BV1") == "bilibili.com",
                     "URL without scheme infers https and extracts host")
        suite.expect(VideoWebsiteSessions.host("https://vimeo.com/123456") == "vimeo.com",
                     "vimeo.com extracts clean host")

        // Invalid hosts rejected
        suite.expect(VideoWebsiteSessions.host("") == nil, "empty string rejected")
        suite.expect(VideoWebsiteSessions.host("   ") == nil, "whitespace string rejected")
        suite.expect(VideoWebsiteSessions.host("not a url") == nil, "spaces inside host rejected")
        suite.expect(VideoWebsiteSessions.host("https://user:pass@example.com") == nil, "credential-bearing URL rejected")
        suite.expect(VideoWebsiteSessions.host(".example.com") == nil, "leading dot host rejected")
        suite.expect(VideoWebsiteSessions.host("example.com.") == nil, "trailing dot host rejected")
        suite.expect(VideoWebsiteSessions.host("ftp://example.com/file") == nil, "non-http/https scheme rejected")
    }

    private static func testFailureClassifier(_ suite: TestSuite) {
        func makeError(_ text: String) -> Error {
            NSError(domain: "io.github.sam32j.lattice.test", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: text])
        }

        // Authentication failures
        let authPhrases = [
            "ERROR: Sign in to confirm you're not a bot",
            "This video requires a sign-in",
            "Login required to view this video",
            "HTTP Error 403: Forbidden",
            "Video is private and cannot be downloaded without authentication",
            "Members-only content: join this channel to view",
            "Confirm your age: sign in to confirm your age",
            "Please use --cookies to pass authentication cookies",
            "HTTP Error 401: Unauthorized",
            "Access denied by remote server",
            "Not authorized to access video stream"
        ]
        for phrase in authPhrases {
            let failure = VideoWebsiteFailure.classify(makeError(phrase))
            suite.expect(failure == .authentication,
                         "'\(phrase)' is classified as authentication failure")
        }

        // Browser access failures
        let accessPhrases = [
            "Could not find chrome cookies database at path",
            "Failed to load cookies from Safari",
            "Could not decrypt keychain item",
            "Error opening cookie database: permission denied"
        ]
        for phrase in accessPhrases {
            let failure = VideoWebsiteFailure.classify(makeError(phrase))
            suite.expect(failure == .browserAccess,
                         "'\(phrase)' is classified as browserAccess failure")
        }

        // Unrelated errors return nil
        let unrelated = [
            "HTTP Error 404: Not Found",
            "Connection reset by peer",
            "Video unavailable in your country",
            "Operation timed out",
            "[Errno 13] Permission denied: '/Users/test/Downloads/video.mp4'"
        ]
        for phrase in unrelated {
            suite.expect(VideoWebsiteFailure.classify(makeError(phrase)) == nil,
                         "'\(phrase)' is not classified as website failure")
        }

        // Messages and button titles
        let auth = VideoWebsiteFailure.authentication
        suite.expect(auth.message(hasActiveSession: false) == VideoDownloaderStrings.loginRequiredNotice,
                     "anonymous auth failure message prompts for authenticated session")
        suite.expect(auth.message(hasActiveSession: true) == VideoDownloaderStrings.noAccessNotice,
                     "signed-in auth failure message informs user of lack of access")

        let browserAccess = VideoWebsiteFailure.browserAccess
        suite.expect(browserAccess.message(hasActiveSession: false) == VideoDownloaderStrings.browserAccessNotice,
                     "browserAccess uses localized browserAccessNotice")
        suite.expect(browserAccess.message(hasActiveSession: false).contains("cookies"),
                     "browserAccess error informs user of cookie reading issue")
    }

    private static func testSafariFullDiskAccess(_ suite: TestSuite) {
        // Verify isSafariFullDiskAccessGranted can be called safely without crashing or throwing
        let fda = VideoWebsiteSessions.isSafariFullDiskAccessGranted
        suite.expect(fda == true || fda == false, "Safari Full Disk Access check returns boolean safely")
    }
}
