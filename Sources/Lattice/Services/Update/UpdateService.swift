// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine

/// Checks GitHub Releases for a newer version and, when asked, downloads the
/// release DMG and installs it over the running app. Self-update for an app
/// distributed outside the App Store, with no third-party framework.
final class UpdateService: ObservableObject {
    static let shared = UpdateService()

    typealias State = AppUpdateState

    @Published var state: State = .idle
    @Published var lastChecked: Date?
    /// Markdown release notes for the available update, shown in the pre-install
    /// preview. Set alongside `.available`; cleared otherwise.
    @Published var availableNotes: String?

    private let repository = DownstreamIdentity.repository
    var downloadURL: URL?
    /// Size the release advertises for the asset, used to bound the download.
    var downloadExpectedBytes: Int64?
    private var refreshTimer: Timer?
    private var notifiedVersion: String?   // last release we posted a notification for
    var downloadSession: URLSession?

    private init() {
        let saved = UserDefaults.standard.double(forKey: DefaultsKey.lastUpdateCheckTime)
        if saved > 0 {
            let date = Date(timeIntervalSince1970: saved)
            self.lastChecked = date
        }
    }

    private func recordLastChecked(_ date: Date = Date()) {
        self.lastChecked = date
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: DefaultsKey.lastUpdateCheckTime)
    }

    var autoCheckEnabled: Bool {
        get { UserDefaults.standard.object(forKey: DefaultsKey.autoCheckUpdates) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: DefaultsKey.autoCheckUpdates)
            configureAutomaticChecks()
        }
    }

    var includeBetaUpdates: Bool {
        get {
            if let explicit = UserDefaults.standard.object(forKey: DefaultsKey.includeBetaUpdates) as? Bool {
                return explicit
            }
            return AppInfo.isBeta
        }
        set {
            UserDefaults.standard.set(newValue, forKey: DefaultsKey.includeBetaUpdates)
        }
    }

    // MARK: - Scheduling

    /// Called at launch: checks shortly after start and then daily, if enabled.
    func startAutomaticChecks() {
        consumeInstallResult()
        if AppInfo.isBeta && UserDefaults.standard.object(forKey: DefaultsKey.includeBetaUpdates) == nil {
            UserDefaults.standard.set(true, forKey: DefaultsKey.includeBetaUpdates)
        }
        if AppInfo.isDeveloperBuild {
            check(manual: false)
            return
        }
        configureAutomaticChecks()
        if autoCheckEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
                self?.check(manual: false)
            }
        }
    }

    private func configureAutomaticChecks() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        guard autoCheckEnabled else { return }
        // Hourly (was daily). Combined with the activate / panel-open checks, a new
        // release surfaces within the hour instead of up to a day later.
        let timer = Timer(timeInterval: 60 * 60, repeats: true) { [weak self] _ in
            self?.check(manual: false)
        }
        timer.tolerance = 60 * 5
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    // MARK: - Check

    func check(manual: Bool) {
        if AppInfo.isDeveloperBuild {
            state = .upToDate
            availableNotes = nil
            recordLastChecked()
            return
        }
        if case .checking = state { return }
        if case .downloading = state { return }
        if case .installing = state { return }
        state = .checking

        let endpoint = includeBetaUpdates
            ? "https://api.github.com/repos/\(repository)/releases?per_page=10"
            : "https://api.github.com/repos/\(repository)/releases/latest"

        var request = URLRequest(url: URL(string: endpoint)!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Lattice/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.recordLastChecked()
                if let failure = UpdateCheckResponse.failure(response: response, error: error) {
                    self.availableNotes = nil
                    self.state = .failed(failure)
                    return
                }
                guard let data else {
                    self.availableNotes = nil
                    self.state = .failed(URLError(.zeroByteResource).localizedDescription)
                    return
                }

                let releases: [GitHubRelease]
                if self.includeBetaUpdates {
                    releases = (try? JSONDecoder().decode([GitHubRelease].self, from: data)) ?? []
                } else if let single = try? JSONDecoder().decode(GitHubRelease.self, from: data) {
                    releases = [single]
                } else {
                    releases = []
                }

                guard !releases.isEmpty else {
                    self.availableNotes = nil
                    self.state = .failed(URLError(.cannotParseResponse).localizedDescription)
                    return
                }

                let candidates = releases.map { rel -> UpdateServiceSupport.ReleaseCandidate in
                    let asset = rel.assets.first { $0.name.hasSuffix(".dmg") }
                    return UpdateServiceSupport.ReleaseCandidate(
                        tagName: rel.tagName,
                        isPrerelease: rel.prerelease ?? false,
                        isDraft: rel.draft ?? false,
                        dmgURL: asset?.browserDownloadURL,
                        dmgExpectedBytes: asset?.size,
                        body: rel.body
                    )
                }

                if let chosen = UpdateServiceSupport.selectUpdate(
                    from: candidates,
                    currentVersion: AppInfo.version,
                    includeBetas: self.includeBetaUpdates
                ) {
                    let versionClean = chosen.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
                    self.downloadURL = chosen.dmgURL
                    self.downloadExpectedBytes = chosen.dmgExpectedBytes
                    self.availableNotes = ReleaseNotes.inAppUpdateNotes(from: chosen.body)
                    self.state = .available(version: versionClean)
                    // Notify once per distinct release, not on every hourly re-check.
                    if !manual, versionClean != self.notifiedVersion {
                        self.notifiedVersion = versionClean
                        let s = L10n.shared.s
                        Notifier.post(title: s.updateNotifyTitle,
                                      body: "\(s.updateAvailablePrefix) \(versionClean)")
                    }
                } else {
                    self.availableNotes = nil
                    self.state = .upToDate
                }
            }
        }.resume()
    }

    /// Re-checks only if the last check is stale — called when the app reactivates
    /// or the panel opens, so a new release surfaces promptly without hammering the
    /// API. The hourly timer is the floor; this makes it feel immediate.
    func checkIfStale(maxAge: TimeInterval = 15 * 60) {
        guard autoCheckEnabled else { return }
        switch state {
        case .checking, .downloading, .installing: return
        default: break
        }
        if state != .idle, let last = lastChecked, Date().timeIntervalSince(last) < maxAge { return }
        check(manual: false)
    }

    // MARK: - Version compare

    /// True when `latest` is a higher semantic version than `current`.
    static func isNewer(_ latest: String, than current: String) -> Bool {
        UpdateServiceSupport.isNewer(latest, than: current)
    }
}

// MARK: - GitHub API shapes

private struct GitHubRelease: Decodable {
    let tagName: String
    let prerelease: Bool?
    let draft: Bool?
    let assets: [Asset]
    let body: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case prerelease
        case draft
        case assets
        case body
    }

    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL
        let size: Int64?

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
            case size
        }
    }
}
