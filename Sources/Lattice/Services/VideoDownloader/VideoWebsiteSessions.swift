// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import Combine
import Foundation

enum VideoSessionBrowser: String, CaseIterable, Codable, Identifiable {
    case safari, chrome, firefox, brave, edge, chromium, vivaldi, opera, whale
    var id: String { rawValue }
    var title: String {
        switch self {
        case .safari: return "Safari"
        case .chrome: return "Chrome"
        case .firefox: return "Firefox"
        case .brave: return "Brave"
        case .edge: return "Microsoft Edge"
        case .chromium: return VideoDownloaderStrings.otherChromiumBrowser
        case .vivaldi: return "Vivaldi"
        case .opera: return "Opera"
        case .whale: return "Whale"
        }
    }
    var supportsProfiles: Bool { self != .safari && self != .opera }
    var isGenericChromium: Bool { self == .chromium }

    static var standardBrowsers: [VideoSessionBrowser] {
        [.safari, .chrome, .firefox, .brave, .edge, .vivaldi, .opera, .whale]
    }
}

struct VideoWebsiteSession: Codable, Equatable, Identifiable {
    var host: String
    var browser: VideoSessionBrowser
    var profile: String
    var id: String { browser.rawValue }

    var arguments: [String] {
        ["--cookies-from-browser", browser.rawValue + (profile.isEmpty ? "" : ":" + profile)]
    }

    init(browser: VideoSessionBrowser, profile: String = "", host: String = "") {
        var cleaned = (browser != .safari && browser != .opera) ? profile.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        if (cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"")) ||
           (cleaned.hasPrefix("'") && cleaned.hasSuffix("'")), cleaned.count >= 2 {
            cleaned = String(cleaned.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if cleaned.hasPrefix("~") {
            cleaned = (cleaned as NSString).expandingTildeInPath
        }
        self.host = host
        self.browser = browser
        self.profile = (browser != .safari && browser != .opera) ? cleaned : ""
    }

    init(host: String, browser: VideoSessionBrowser, profile: String) throws {
        self.init(browser: browser, profile: profile, host: host)
    }
}

enum VideoWebsiteSessionError: LocalizedError {
    case invalidHost, invalidProfile
    var errorDescription: String? {
        switch self {
        case .invalidHost: return "Enter a valid website address."
        case .invalidProfile: return "Use a valid browser profile name or folder path."
        }
    }
}

struct DiscoveredProfile: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
}

struct BrowserProfileDetection {
    let isFound: Bool
    let path: String?
    let name: String?
    let description: String
    let profiles: [DiscoveredProfile]

    init(isFound: Bool, path: String? = nil, name: String? = nil, description: String, profiles: [DiscoveredProfile] = []) {
        self.isFound = isFound
        self.path = path
        self.name = name
        self.description = description
        self.profiles = profiles
    }
}

/// Manages global browser session selection for authenticated or restricted video downloads.
final class VideoWebsiteSessions: ObservableObject {
    static let shared = VideoWebsiteSessions()
    static let preferencesKey = "videoDownloaderBrowserSession"
    static let legacyKey = "videoDownloaderWebsiteSessions"

    @Published private(set) var activeSession: VideoWebsiteSession?
    @Published private(set) var entries: [VideoWebsiteSession] = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // 1. Try loading new global browser session
        if let data = defaults.data(forKey: Self.preferencesKey),
           let session = try? JSONDecoder().decode(VideoWebsiteSession.self, from: data) {
            self.activeSession = session
            self.entries = [session]
            return
        }

        // 2. Backward compatibility: migrate from legacy per-website sessions if present
        struct LegacyEntry: Decodable {
            let host: String?
            let browser: VideoSessionBrowser
            let profile: String?
        }
        if let data = defaults.data(forKey: Self.legacyKey),
           let list = try? JSONDecoder().decode([LegacyEntry].self, from: data),
           let first = list.first {
            let migrated = VideoWebsiteSession(browser: first.browser, profile: first.profile ?? "", host: first.host ?? "")
            self.activeSession = migrated
            self.entries = [migrated]
            self.persist()
            return
        }

        self.activeSession = nil
        self.entries = []
    }

    var hasSession: Bool { activeSession != nil }

    var summaryText: String {
        guard let session = activeSession else { return "None (Anonymous)" }
        let browserName = session.browser == .chromium ? "Chromium" : session.browser.title
        if session.browser == .safari || session.browser == .opera {
            return browserName
        }
        if session.profile.isEmpty || session.profile == "Default" {
            return browserName
        }
        var folderName = (session.profile as NSString).lastPathComponent
        if folderName.count > 20 {
            folderName = String(folderName.prefix(12)) + "…"
        }
        return "\(browserName) · \(folderName)"
    }

    func session(for url: URL? = nil) -> VideoWebsiteSession? {
        activeSession
    }

    func saveSession(browser: VideoSessionBrowser, profile: String = "") {
        let session = VideoWebsiteSession(browser: browser, profile: profile)
        activeSession = session
        entries = [session]
        persist()
    }

    func clearSession() {
        activeSession = nil
        entries = []
        defaults.removeObject(forKey: Self.preferencesKey)
        defaults.removeObject(forKey: Self.legacyKey)
    }

    func save(_ session: VideoWebsiteSession) {
        saveSession(browser: session.browser, profile: session.profile)
    }

    func forget(_ host: String = "") {
        clearSession()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(activeSession) {
            defaults.set(data, forKey: Self.preferencesKey)
        }
    }

    // MARK: - Browser Profile Detection

    static func detectDefaultProfile(for browser: VideoSessionBrowser) -> BrowserProfileDetection {
        let fm = FileManager.default
        let home = NSHomeDirectory()

        switch browser {
        case .safari:
            let secondary = home + "/Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies"
            let primary = home + "/Library/Cookies/Cookies.binarycookies"
            let exists = fm.fileExists(atPath: secondary) || fm.fileExists(atPath: primary)
            return BrowserProfileDetection(
                isFound: exists,
                path: exists ? (fm.fileExists(atPath: secondary) ? secondary : primary) : nil,
                name: "Safari",
                description: exists ? "Safari Is Ready" : "Safari Not Found"
            )

        case .chrome:
            let root = home + "/Library/Application Support/Google/Chrome"
            let profiles = discoverChromiumProfiles(in: root)
            let defaultProfile = profiles.first
            let isFound = !profiles.isEmpty
            return BrowserProfileDetection(
                isFound: isFound,
                path: defaultProfile?.path,
                name: defaultProfile?.name,
                description: isFound ? "Default profile found" : "Chrome Not Found",
                profiles: profiles
            )

        case .brave:
            let root = home + "/Library/Application Support/BraveSoftware/Brave-Browser"
            let profiles = discoverChromiumProfiles(in: root)
            let defaultProfile = profiles.first
            let isFound = !profiles.isEmpty
            return BrowserProfileDetection(
                isFound: isFound,
                path: defaultProfile?.path,
                name: defaultProfile?.name,
                description: isFound ? "Default profile found" : "Brave Not Found",
                profiles: profiles
            )

        case .edge:
            let root = home + "/Library/Application Support/Microsoft Edge"
            let profiles = discoverChromiumProfiles(in: root)
            let defaultProfile = profiles.first
            let isFound = !profiles.isEmpty
            return BrowserProfileDetection(
                isFound: isFound,
                path: defaultProfile?.path,
                name: defaultProfile?.name,
                description: isFound ? "Default profile found" : "Microsoft Edge Not Found",
                profiles: profiles
            )

        case .vivaldi:
            let root = home + "/Library/Application Support/Vivaldi"
            let profiles = discoverChromiumProfiles(in: root)
            let defaultProfile = profiles.first
            let isFound = !profiles.isEmpty
            return BrowserProfileDetection(
                isFound: isFound,
                path: defaultProfile?.path,
                name: defaultProfile?.name,
                description: isFound ? "Default profile found" : "Vivaldi Not Found",
                profiles: profiles
            )

        case .opera:
            let root = home + "/Library/Application Support/com.operasoftware.Opera"
            let cookiePath = root + "/Cookies"
            let netCookiePath = root + "/Network/Cookies"
            let hasCookies = fm.fileExists(atPath: cookiePath) || fm.fileExists(atPath: netCookiePath)
            return BrowserProfileDetection(
                isFound: hasCookies,
                path: hasCookies ? root : nil,
                name: "Opera",
                description: hasCookies ? "Opera cookies found" : "Opera Not Found"
            )

        case .whale:
            let root = home + "/Library/Application Support/Naver/Whale"
            let profiles = discoverChromiumProfiles(in: root)
            let defaultProfile = profiles.first
            let isFound = !profiles.isEmpty
            return BrowserProfileDetection(
                isFound: isFound,
                path: defaultProfile?.path,
                name: defaultProfile?.name,
                description: isFound ? "Default profile found" : "Whale Not Found",
                profiles: profiles
            )

        case .firefox:
            let profilesDir = home + "/Library/Application Support/Firefox/Profiles"
            if let contents = try? fm.contentsOfDirectory(atPath: profilesDir) {
                let validDirs = contents.filter { !$0.hasPrefix(".") }
                var profiles: [DiscoveredProfile] = []
                for dirName in validDirs {
                    let path = (profilesDir as NSString).appendingPathComponent(dirName)
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                        let displayName = dirName.components(separatedBy: ".").dropFirst().joined(separator: ".")
                        profiles.append(DiscoveredProfile(id: dirName, name: displayName.isEmpty ? dirName : displayName, path: path))
                    }
                }
                if !profiles.isEmpty {
                    let defaultProf = profiles.first(where: { $0.id.contains(".default-release") })
                        ?? profiles.first(where: { $0.id.contains(".default") })
                        ?? profiles.first!
                    return BrowserProfileDetection(
                        isFound: true,
                        path: defaultProf.path,
                        name: defaultProf.name,
                        description: "Default profile found",
                        profiles: profiles
                    )
                }
            }
            return BrowserProfileDetection(isFound: false, path: nil, name: nil, description: "Firefox Not Found")

        case .chromium:
            let root = home + "/Library/Application Support/Chromium"
            let profiles = discoverChromiumProfiles(in: root)
            let defaultProfile = profiles.first
            let isFound = !profiles.isEmpty
            return BrowserProfileDetection(
                isFound: isFound,
                path: defaultProfile?.path,
                name: defaultProfile?.name,
                description: isFound ? "Standard Chromium profile found" : "Choose a Profile Folder",
                profiles: profiles
            )
        }
    }

    private static func discoverChromiumProfiles(in rootDir: String) -> [DiscoveredProfile] {
        let fm = FileManager.default
        var profiles: [DiscoveredProfile] = []
        let localStateURL = URL(fileURLWithPath: rootDir).appendingPathComponent("Local State")
        if let data = try? Data(contentsOf: localStateURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let profileObj = json["profile"] as? [String: Any],
           let infoCache = profileObj["info_cache"] as? [String: [String: Any]] {
            for (dirName, info) in infoCache {
                let profilePath = (rootDir as NSString).appendingPathComponent(dirName)
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: profilePath, isDirectory: &isDir), isDir.boolValue {
                    let displayName = (info["name"] as? String) ?? dirName
                    profiles.append(DiscoveredProfile(id: dirName, name: displayName, path: profilePath))
                }
            }
        }
        if profiles.isEmpty {
            let defaultPath = (rootDir as NSString).appendingPathComponent("Default")
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: defaultPath, isDirectory: &isDir), isDir.boolValue {
                let hasCookieOrPrefs = fm.fileExists(atPath: defaultPath + "/Cookies")
                    || fm.fileExists(atPath: defaultPath + "/Network/Cookies")
                    || fm.fileExists(atPath: defaultPath + "/Preferences")
                if hasCookieOrPrefs {
                    profiles.append(DiscoveredProfile(id: "Default", name: "Default", path: defaultPath))
                }
            }
        }
        profiles.sort {
            if $0.id == "Default" { return true }
            if $1.id == "Default" { return false }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        return profiles
    }

    // MARK: - Safari Full Disk Access Check

    static var isSafariFullDiskAccessGranted: Bool {
        let primary = ("~/Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies" as NSString).expandingTildeInPath
        let secondary = ("~/Library/Cookies/Cookies.binarycookies" as NSString).expandingTildeInPath
        let dir = ("~/Library/Containers/com.apple.Safari/Data/Library/Cookies" as NSString).expandingTildeInPath

        for path in [primary, secondary] {
            let fd = open(path, O_RDONLY)
            if fd >= 0 {
                close(fd)
                return true
            }
            if errno == EPERM || errno == EACCES {
                return false
            }
        }

        let fd = open(dir, O_RDONLY)
        if fd >= 0 {
            close(fd)
            return true
        }
        return errno != EPERM && errno != EACCES
    }

    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    static func host(_ input: String) -> String? {
        let input = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, !input.contains(where: { $0.isWhitespace }),
              let components = URLComponents(string: input.contains("://") ? input : "https://" + input),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              components.user == nil, components.password == nil,
              var host = components.host?.lowercased(), host.contains("."),
              !host.hasPrefix("."), !host.hasSuffix(".") else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        if ["youtu.be", "m.youtube.com", "music.youtube.com"].contains(host) { return "youtube.com" }
        return host
    }
}

enum VideoWebsiteFailure {
    case authentication, browserAccess

    static func classify(_ error: Error) -> Self? {
        let message = error.localizedDescription.lowercased()
        if ["cookie database", "cookies database", "failed to decrypt", "could not decrypt",
            "keychain", "failed to load cookies", "could not find chrome cookies",
            "could not find safari cookies"].contains(where: message.contains) {
            return .browserAccess
        }
        if ["sign in", "sign-in", "log in", "login required", "authentication required",
            "use --cookies", "members-only", "members only", "confirm your age", "age-restricted",
            "private video", "video is private", "permission denied", "forbidden", "http error 403",
            "no access", "access denied", "not authorized"].contains(where: message.contains) {
            return .authentication
        }
        return nil
    }

    var message: String {
        message(hasActiveSession: false)
    }

    func message(hasActiveSession: Bool) -> String {
        switch self {
        case .authentication:
            return hasActiveSession ? VideoDownloaderStrings.noAccessNotice : VideoDownloaderStrings.loginRequiredNotice
        case .browserAccess:
            return "Could not read browser cookies. Check your profile folder or permissions."
        }
    }
}
