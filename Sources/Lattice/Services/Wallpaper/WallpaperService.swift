// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

/// Apple stills + bookmarked own images. Apply-all hits WallpaperAgent's store.
final class WallpaperService: ObservableObject {
    static let shared = WallpaperService()

    struct OwnSource: Identifiable, Equatable {
        let id: String
        let title: String
        /// Where it lives, when the bookmark still resolves.
        let path: String?
        let isFolder: Bool
        let isReachable: Bool
        let bookmark: Data
    }

    @Published private(set) var entries: [WallpaperSupport.Entry] = []
    @Published private(set) var ownSources: [OwnSource] = []
    @Published private(set) var filter: WallpaperSupport.Filter = .all
    @Published private(set) var lastError: String?
    @Published private(set) var appliedPath: String?
    @Published private(set) var isLoading = false
    // true while materializing an iCloud still or finishing apply
    @Published private(set) var isApplying = false
    @Published private(set) var isDownloading = false
    // bumps when thumb generation changes so cell .task restarts
    @Published private(set) var thumbEpoch = 0
    /// Apple pictures being downloaded, by entry ID: 0…1.
    @Published private(set) var downloadProgress: [String: Double] = [:]
    private var downloadObservations: [String: NSKeyValueObservation] = [:]
    // the download the user last chose; only that one is set when it lands
    private var pendingDownloadApply: String?

    private var ownBookmarks: [Data] = []
    // folder-child paths the user hid from the gallery (files stay on disk)
    private var excludedOwnPaths: Set<String> = []
    // file bookmark path → Data (built in rebuildOwnSources; gallery X match without FS)
    private var fileBookmarkByPath: [String: Data] = [:]
    private var scopedURLs: [URL] = []
    private var openPanel: NSOpenPanel?
    // Apple catalog barely changes; keep after first scan to avoid tab hitch
    private var cachedApple: [WallpaperSupport.Entry]?
    private let galleryLifecycle = WallpaperGalleryLifecycle()
    private var applyToken = UUID()
    // lock-backed copy so detached apply-all can bail if a newer apply won
    private let applyGenerationLock = NSLock()
    private var applyGeneration = UUID()

    private init() {
        loadBookmarks()
        loadExclusions()
        loadFilter()
    }

    var isAvailable: Bool { AppFeature.wallpaper.isAvailable }

    var visibleEntries: [WallpaperSupport.Entry] {
        WallpaperSupport.filtered(entries, by: filter)
    }

    /// Imported pictures under the folder each came from.
    var ownGroups: [WallpaperSupport.OwnGroup] {
        let roots = ownSources.filter { $0.isFolder && $0.isReachable }.compactMap(\.path)
        return WallpaperSupport.ownGroups(entries, folderRoots: roots)
    }

    /// Lists the imported sources without scanning them, for Settings.
    func reloadSources() {
        guard isAvailable else { return }
        rebuildOwnSources()
    }

    var applyAllDisplays: Bool {
        get {
            if UserDefaults.standard.object(forKey: DefaultsKey.wallpaperApplyAllDisplays) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: DefaultsKey.wallpaperApplyAllDisplays)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: DefaultsKey.wallpaperApplyAllDisplays)
            objectWillChange.send()
        }
    }

    func syncWithPreferences() {
        if !isAvailable {
            galleryLifecycle.endAll()
            let cancelled = UUID()
            applyToken = cancelled
            setApplyGeneration(cancelled)
            stopAccessing()
            cachedApple = nil
            bumpThumbGeneration()
            WallpaperThumbnailCache.clear()
            // keep bookmarks (settings intact on reinstall); clear live catalog only
            ownSources = []
            entries = []
            lastError = nil
            appliedPath = nil
            isLoading = false
            isApplying = false
            isDownloading = false
            WallpaperStore.removeBackup()
            return
        }
        WallpaperStore.migrateLegacyBackupIfNeeded()
        if galleryLifecycle.isVisible { refresh(forceAppleRescan: false) }
    }

    func suspend() {
        stopAccessing()
    }

    func setFilter(_ filter: WallpaperSupport.Filter) {
        self.filter = filter
        UserDefaults.standard.set(filter.rawValue, forKey: DefaultsKey.wallpaperFilter)
        preparePageThumbs(for: filter, around: 1)
    }

    func prefetchNearbyPages(for filter: WallpaperSupport.Filter, around page: Int) {
        let visible = WallpaperSupport.filtered(entries, by: filter)
        let current = WallpaperSupport.pageSlice(visible, page: page)
        let next = WallpaperSupport.pageSlice(visible, page: page + 1)
        WallpaperThumbnailCache.prefetch(current.map(\.previewURL) + next.map(\.previewURL))
    }

    // bump decode generation then prefetch the new page (cancels older cell/prefetch work)
    func preparePageThumbs(for filter: WallpaperSupport.Filter, around page: Int) {
        bumpThumbGeneration()
        prefetchNearbyPages(for: filter, around: page)
    }

    func beginViewing(_ viewer: UUID) {
        galleryLifecycle.begin(viewer)
        refresh(forceAppleRescan: false)
    }

    func endViewing(_ viewer: UUID) {
        guard galleryLifecycle.end(viewer) else { return }
        isLoading = false
        bumpThumbGeneration()
    }

    private func bumpThumbGeneration() {
        WallpaperThumbnailCache.beginGeneration()
        thumbEpoch &+= 1
    }

    /// The aerial catalog's string tables for an app language, best first.
    static func aerialLanguages(_ language: AppLanguage) -> [String] {
        switch language {
        case .enUS: return ["en"]
        case .ptBR: return ["pt_BR"]
        case .tr: return ["tr"]
        case .ru: return ["ru"]
        case .es: return ["es"]
        case .sk: return ["sk"]
        case .de: return ["de"]
        case .fr: return ["fr"]
        case .it: return ["it"]
        case .ja: return ["ja"]
        case .ko: return ["ko"]
        case .uk: return ["uk"]
        case .zhHans: return ["zh_CN"]
        case .zhTW: return ["zh_TW"]
        case .zhHK: return ["zh_HK", "zh_TW"]
        }
    }

    // scan off-main; publish catalog first, thumbs later
    func refresh(forceAppleRescan: Bool = false) {
        guard isAvailable else {
            entries = []
            isLoading = false
            return
        }
        guard galleryLifecycle.isVisible else { return }
        // one resolve pass — startAccessing / own roots / sources share it
        let resolved = resolveOwnBookmarks()
        startAccessing(resolved)
        rebuildOwnSources(from: resolved)
        let roots = resolved.map(\.url)
        let excluded = excludedOwnPaths
        let appleCache = forceAppleRescan ? nil : cachedApple
        let languages = Self.aerialLanguages(L10n.shared.language)
        let token = galleryLifecycle.invalidate()
        bumpThumbGeneration()
        if entries.isEmpty {
            isLoading = true
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let apple = appleCache ?? WallpaperSupport.enumerateAppleEntries(
                aerialsRoot: WallpaperSupport.appleAerialsURL,
                downloads: WallpaperSupport.Downloads(catalog: WallpaperSupport.desktopPictureCatalog(),
                                                      folder: Self.downloadsFolder),
                languages: languages)
            guard self?.galleryLifecycle.accepts(token) == true else { return }

            var imageURLs: [URL] = []
            for root in roots {
                guard self?.galleryLifecycle.accepts(token) == true else { return }
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDir) else {
                    continue
                }
                if isDir.boolValue {
                    let found = WallpaperSupport.images(inFolder: root) {
                        self?.galleryLifecycle.accepts(token) == true
                    }
                    guard self?.galleryLifecycle.accepts(token) == true else { return }
                    for url in found where !excluded.contains(url.standardizedFileURL.path) {
                        imageURLs.append(url)
                    }
                } else if WallpaperSupport.isStillImageURL(root) {
                    let path = root.standardizedFileURL.path
                    if !excluded.contains(path) {
                        imageURLs.append(root)
                    }
                }
            }
            guard self?.galleryLifecycle.accepts(token) == true else { return }

            let own = WallpaperSupport.ownEntries(from: imageURLs)
            let merged = WallpaperSupport.merge(apple: apple, own: own)
            DispatchQueue.main.async {
                guard let self, self.galleryLifecycle.accepts(token) else { return }
                if appleCache == nil {
                    self.cachedApple = apple
                }
                self.entries = merged
                self.isLoading = false
                self.prefetchNearbyPages(for: self.filter, around: 1)
            }
        }
    }

    func apply(_ entry: WallpaperSupport.Entry) {
        guard isAvailable else { return }
        lastError = nil
        if let remote = entry.remoteAsset,
           !FileManager.default.fileExists(atPath: entry.imageURL.path) {
            pendingDownloadApply = entry.id
            download(entry, from: remote.url) { location, _ in
                Self.installDownloadedPicture(zip: location, expectedSHA1: remote.sha1,
                                              to: entry.imageURL)
            }
            return
        }
        if let video = entry.pendingVideo,
           !FileManager.default.fileExists(atPath: video.destination.path) {
            pendingDownloadApply = entry.id
            download(entry, from: video.url) { location, response in
                Self.installAerialVideo(location, response: response, source: video.url,
                                        to: video.destination)
            }
            return
        }
        pendingDownloadApply = nil
        let url = entry.imageURL.standardizedFileURL
        let chosen = targetScreens()
        guard !chosen.isEmpty else {
            lastError = FeatureStrings.wallpaper(L10n.shared.language).applyFailed
            return
        }

        let token = UUID()
        applyToken = token
        setApplyGeneration(token)
        let applyAll = applyAllDisplays
        isApplying = true
        if let assetID = entry.aerialAssetID {
            applyAerial(assetID, path: url.path, token: token)
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.applyToken == token {
                    self.isApplying = false
                    self.isDownloading = false
                }
            }

            let localOK = await self.ensureLocalFile(url, token: token)
            guard self.isAvailable, self.applyToken == token else { return }
            if !localOK {
                self.lastError = FeatureStrings.wallpaper(L10n.shared.language).downloadFailed
                return
            }

            let currentOK = await self.setDesktopImage(url, on: chosen, token: token)
            guard self.isAvailable, self.applyToken == token else { return }

            if applyAll {
                // plist + killall off main; bail if a newer apply superseded us
                let expected = token
                let allOK = await Task.detached(priority: .userInitiated) { [weak self] in
                    guard let self else { return false }
                    return WallpaperStore.setImageOnAllSpaces(url) {
                        self.currentApplyGeneration() == expected
                    }
                }.value
                guard self.isAvailable, self.applyToken == token else { return }
                if allOK || currentOK {
                    self.appliedPath = url.path
                }
                // store patch miss keeps current-space apply; do not banner as failure
                if !allOK && !currentOK {
                    self.lastError = FeatureStrings.wallpaper(L10n.shared.language).applyFailed
                }
                return
            }

            if currentOK {
                self.appliedPath = url.path
            } else {
                self.lastError = FeatureStrings.wallpaper(L10n.shared.language).applyFailed
            }
        }
    }

    // iCloud Drive placeholder — pull the bytes before NSWorkspace / store write
    // MARK: - Downloadable Apple pictures

    /// Lattice's own copies of Apple pictures macOS has not downloaded.
    static var downloadsFolder: URL {
        let fallback = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent("Library/Application Support/io.github.sam32j.lattice",
                                    isDirectory: true)
        return (PrivateFileStore.containerURL ?? fallback)
            .appendingPathComponent("Wallpapers", isDirectory: true)
    }

    // fetch one file with progress; install runs on the session's queue
    private func download(_ entry: WallpaperSupport.Entry, from url: URL,
                          install: @escaping (URL, HTTPURLResponse) -> Bool) {
        guard downloadProgress[entry.id] == nil else { return }
        downloadProgress[entry.id] = 0
        let task = URLSession.shared.downloadTask(with: url) { [weak self] location, response, error in
            var ok = false
            if error == nil, let location, let http = response as? HTTPURLResponse, http.statusCode == 200 {
                ok = install(location, http)
            }
            DispatchQueue.main.async {
                self?.finishDownload(entry, ok: ok)
            }
        }
        downloadObservations[entry.id] = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            let fraction = progress.fractionCompleted
            DispatchQueue.main.async {
                guard let self, self.downloadProgress[entry.id] != nil else { return }
                self.downloadProgress[entry.id] = min(max(fraction, 0), 1)
            }
        }
        task.resume()
    }

    /// Puts a video where the system caches aerials, tagged as the system tags
    /// its own downloads, so WallpaperAgent plays it instead of fetching again.
    private static func installAerialVideo(_ location: URL, response: HTTPURLResponse,
                                           source: URL, to destination: URL) -> Bool {
        let manager = FileManager.default
        try? manager.createDirectory(at: destination.deletingLastPathComponent(),
                                     withIntermediateDirectories: true)
        let staging = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).lattice-download")
        try? manager.removeItem(at: staging)
        do {
            try manager.moveItem(at: location, to: staging)
        } catch {
            return false
        }
        try? manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: staging.path)
        setExtendedAttribute("SourceURL", source.absoluteString, at: staging)
        if let etag = response.value(forHTTPHeaderField: "ETag") {
            setExtendedAttribute("LastETag", etag, at: staging)
        }
        guard !manager.fileExists(atPath: destination.path) else {
            // the system finished its own copy meanwhile
            try? manager.removeItem(at: staging)
            return true
        }
        do {
            try manager.moveItem(at: staging, to: destination)
        } catch {
            try? manager.removeItem(at: staging)
            return false
        }
        return true
    }

    private static func setExtendedAttribute(_ name: String, _ value: String, at url: URL) {
        let bytes = Array(value.utf8)
        _ = url.withUnsafeFileSystemRepresentation { path in
            bytes.withUnsafeBytes { buffer in
                setxattr(path, name, buffer.baseAddress, buffer.count, 0, 0)
            }
        }
    }

    private func finishDownload(_ entry: WallpaperSupport.Entry, ok: Bool) {
        downloadObservations[entry.id] = nil
        downloadProgress[entry.id] = nil
        guard isAvailable else { return }
        guard ok else {
            if pendingDownloadApply == entry.id {
                lastError = FeatureStrings.wallpaper(L10n.shared.language).downloadFailed
            }
            return
        }
        var local = entry
        local.remoteAsset = nil
        local.pendingVideo = nil
        if let index = entries.firstIndex(where: { $0.id == entry.id }) { entries[index] = local }
        if let index = cachedApple?.firstIndex(where: { $0.id == entry.id }) { cachedApple?[index] = local }
        if pendingDownloadApply == entry.id { apply(local) }
    }

    /// Unzips a catalog download and keeps its picture (AssetData/*.heic).
    private static func installDownloadedPicture(zip: URL, expectedSHA1: Data?, to destination: URL) -> Bool {
        let manager = FileManager.default
        if let expectedSHA1 {
            guard let data = try? Data(contentsOf: zip, options: .mappedIfSafe),
                  Data(Insecure.SHA1.hash(data: data)) == expectedSHA1 else { return false }
        }
        let work = manager.temporaryDirectory
            .appendingPathComponent("lattice-wallpaper-\(UUID().uuidString)", isDirectory: true)
        defer { try? manager.removeItem(at: work) }
        guard (try? manager.createDirectory(at: work, withIntermediateDirectories: true)) != nil,
              Shell.run("/usr/bin/ditto", ["-x", "-k", zip.path, work.path], timeout: 60).status == 0
        else { return false }
        let assetData = work.appendingPathComponent("AssetData", isDirectory: true)
        let found = (try? manager.contentsOfDirectory(at: assetData, includingPropertiesForKeys: [.fileSizeKey]))?
            .filter { WallpaperSupport.isStillImageURL($0) }
            .max { lhs, rhs in
                let left = (try? lhs.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                let right = (try? rhs.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return left < right
            }
        guard let found else { return false }
        let folder = destination.deletingLastPathComponent()
        _ = PrivateFileStore.createDirectory(at: folder)
        if !manager.fileExists(atPath: folder.path) {
            try? manager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        try? manager.removeItem(at: destination)
        do {
            try manager.moveItem(at: found, to: destination)
        } catch {
            return false
        }
        return true
    }

    // aerials only go through the store, on every Space and display
    private func applyAerial(_ assetID: String, path: String, token: UUID) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if self.applyToken == token { self.isApplying = false } }
            let ok = await Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return false }
                return WallpaperStore.setAerialOnAllSpaces(assetID) {
                    self.currentApplyGeneration() == token
                }
            }.value
            guard self.isAvailable, self.applyToken == token else { return }
            if ok {
                self.appliedPath = path
            } else {
                self.lastError = FeatureStrings.wallpaper(L10n.shared.language).applyFailed
            }
        }
    }

    static func needsCloudDownload(_ url: URL) -> Bool {
        let keys: Set<URLResourceKey> = [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey,
        ]
        guard let values = try? url.resourceValues(forKeys: keys),
              values.isUbiquitousItem == true
        else { return false }
        return values.ubiquitousItemDownloadingStatus != .current
    }

    @MainActor
    private func ensureLocalFile(_ url: URL, token: UUID) async -> Bool {
        guard Self.needsCloudDownload(url) else { return true }
        isDownloading = true
        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
        } catch {
            return false
        }
        let deadline = ContinuousClock.now + .seconds(60)
        while ContinuousClock.now < deadline {
            guard isAvailable, applyToken == token else { return false }
            if (try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingErrorKey])
                .ubiquitousItemDownloadingError) != nil {
                return false
            }
            if !Self.needsCloudDownload(url) { return true }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return !Self.needsCloudDownload(url)
    }

    private func setApplyGeneration(_ token: UUID) {
        applyGenerationLock.lock()
        applyGeneration = token
        applyGenerationLock.unlock()
    }

    private func currentApplyGeneration() -> UUID {
        applyGenerationLock.lock()
        defer { applyGenerationLock.unlock() }
        return applyGeneration
    }

    private func targetScreens() -> [NSScreen] {
        if applyAllDisplays {
            return NSScreen.screens
        }
        if let screen = NSScreen.withMouse {
            return [screen]
        }
        return NSScreen.screens.first.map { [$0] } ?? []
    }

    // fill crop; clear same-URL first (macOS skips refresh otherwise).
    // MainActor so NSWorkspace + applyToken/isAvailable stay on one thread; sleep still yields.
    @MainActor
    private func setDesktopImage(_ url: URL, on screens: [NSScreen], token: UUID) async -> Bool {
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: true,
        ]
        var needsPause = false
        for screen in screens {
            if NSWorkspace.shared.desktopImageURL(for: screen)?.standardizedFileURL == url {
                do {
                    try NSWorkspace.shared.setDesktopImageURL(
                        URL(fileURLWithPath: ""), for: screen, options: [:])
                    needsPause = true
                } catch {
                    // still try the set below
                }
            }
        }
        if needsPause {
            try? await Task.sleep(for: .milliseconds(400))
            guard isAvailable, applyToken == token else { return false }
        }
        var ok = true
        for screen in screens {
            do {
                try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: options)
            } catch {
                ok = false
            }
        }
        return ok
    }

    func addImages(inNotch: Bool = false) {
        guard isAvailable else { return }
        // a picker already up, maybe behind another window, comes forward again
        if let openPanel { bringForward(openPanel, inNotch: inNotch); return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        // match gallery extensions so a pick always gets a cell
        let types = WallpaperSupport.imageExtensions.compactMap { UTType(filenameExtension: $0) }
        panel.allowedContentTypes = types.isEmpty ? [.image] : types
        panel.message = FeatureStrings.wallpaper(L10n.shared.language).addImagePrompt
        present(panel, inNotch: inNotch) { [weak self] urls in
            self?.remember(urls: urls)
        }
    }

    func addFolder(inNotch: Bool = false) {
        guard isAvailable else { return }
        if let openPanel { bringForward(openPanel, inNotch: inNotch); return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = FeatureStrings.wallpaper(L10n.shared.language).addFolderPrompt
        present(panel, inNotch: inNotch) { [weak self] urls in
            self?.remember(urls: urls)
        }
    }

    // MARK: - Bookmarks

    private func present(_ panel: NSOpenPanel, inNotch: Bool = false, completion: @escaping ([URL]) -> Void) {
        openPanel = panel
        if !inNotch { PanelInteractionState.shared.isPresentingPopoverModal = true }
        panel.begin { [weak self] response in
            if !inNotch { PanelInteractionState.shared.isPresentingPopoverModal = false }
            guard let self else { return }
            self.openPanel = nil
            guard response == .OK else { return }
            completion(panel.urls)
        }
        bringForward(panel, inNotch: inNotch)
    }

    // an inactive app's picker opens behind the front app's window, and the
    // island never activates the app, so the buttons seemed to do nothing
    private func bringForward(_ panel: NSOpenPanel, inNotch: Bool) {
        // the island floats above ordinary windows; stand just above it there
        if inNotch, let island = NotchService.shared.presentationWindow {
            panel.level = NSWindow.Level(rawValue: island.level.rawValue + 1)
        }
        NSApp.activate(ignoringOtherApps: true)
        // activation alone can leave the nonactivating island holding focus
        panel.makeKeyAndOrderFront(nil)
    }

    private func remember(urls: [URL]) {
        for url in urls {
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            if exists && !isDir.boolValue && !WallpaperSupport.isStillImageURL(url) {
                continue
            }
            guard let data = try? url.bookmarkData(options: .withSecurityScope,
                                                   includingResourceValuesForKeys: nil,
                                                   relativeTo: nil)
            else { continue }
            let path = url.standardizedFileURL.path
            // drop older bookmarks that resolve to the same path (Data blobs differ)
            ownBookmarks.removeAll { existing in
                resolveBookmark(existing)?.standardizedFileURL.path == path
            }
            ownBookmarks.append(data)
            // re-adding clears a prior hide of this path (and children if folder)
            excludedOwnPaths.remove(path)
            if exists && isDir.boolValue {
                excludedOwnPaths = excludedOwnPaths.filter { !$0.hasPrefix(path + "/") }
            }
        }
        persistBookmarks()
        persistExclusions()
        rebuildOwnSources()
        refresh(forceAppleRescan: false)
    }

    func removeOwnSource(_ source: OwnSource) {
        guard isAvailable else { return }
        removeOwnBookmark(source.bookmark, knownFolder: source.isFolder)
    }

    // gallery X: drop a file bookmark, or hide one image under a folder bookmark
    func removeOwnEntry(_ entry: WallpaperSupport.Entry) {
        guard isAvailable, entry.source == .own else { return }
        let path = entry.id
        if let data = fileBookmarkByPath[path] {
            removeOwnBookmark(data, knownFolder: false)
            return
        }
        excludedOwnPaths.insert(path)
        persistExclusions()
        // drop in-flight scan so it cannot republish this path
        galleryLifecycle.invalidate()
        entries.removeAll { $0.id == path }
    }

    private func removeOwnBookmark(_ data: Data, knownFolder: Bool?) {
        if let url = resolveBookmark(data) {
            let path = url.standardizedFileURL.path
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            let isFolder = knownFolder ?? (exists ? isDir.boolValue : url.hasDirectoryPath)
            if isFolder {
                excludedOwnPaths = excludedOwnPaths.filter { !$0.hasPrefix(path + "/") }
            } else {
                excludedOwnPaths.remove(path)
            }
            persistExclusions()
        }
        ownBookmarks.removeAll { $0 == data }
        persistBookmarks()
        rebuildOwnSources()
        refresh(forceAppleRescan: false)
    }

    private func loadBookmarks() {
        ownBookmarks = UserDefaults.standard.array(forKey: DefaultsKey.wallpaperOwnBookmarks) as? [Data]
            ?? []
    }

    private func persistBookmarks() {
        UserDefaults.standard.set(ownBookmarks, forKey: DefaultsKey.wallpaperOwnBookmarks)
    }

    private func loadExclusions() {
        let list = UserDefaults.standard.array(forKey: DefaultsKey.wallpaperExcludedOwnPaths) as? [String]
            ?? []
        excludedOwnPaths = Set(list)
    }

    private func persistExclusions() {
        UserDefaults.standard.set(Array(excludedOwnPaths).sorted(),
                                  forKey: DefaultsKey.wallpaperExcludedOwnPaths)
    }

    private func rebuildOwnSources(from resolved: [ResolvedBookmark]? = nil) {
        let unavailable = FeatureStrings.wallpaper(L10n.shared.language).sourceUnavailable
        var byData: [Data: URL] = [:]
        if let resolved {
            for item in resolved {
                byData[item.data] = item.url
            }
        }
        var fileMap: [String: Data] = [:]
        ownSources = ownBookmarks.enumerated().map { index, data in
            let id = bookmarkIdentity(data, index: index)
            let url = byData[data] ?? resolveBookmark(data)
            if let url {
                var isDir: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                let isFolder = exists ? isDir.boolValue : url.hasDirectoryPath
                if exists && !isDir.boolValue {
                    let path = url.standardizedFileURL.path
                    fileMap[path] = data
                }
                return OwnSource(id: id,
                                 title: url.lastPathComponent,
                                 path: url.standardizedFileURL.path,
                                 isFolder: isFolder,
                                 isReachable: exists,
                                 bookmark: data)
            }
            // resolve failed (unmounted volume, stale bookmark) — still list so user can remove
            return OwnSource(id: id,
                             title: unavailable,
                             path: nil,
                             isFolder: false,
                             isReachable: false,
                             bookmark: data)
        }
        fileBookmarkByPath = fileMap
    }

    // stable ForEach id from bookmark bytes (index is fallback salt only)
    private func bookmarkIdentity(_ data: Data, index: Int) -> String {
        var hasher = Hasher()
        hasher.combine(data)
        return "bm-\(hasher.finalize())-\(index)"
    }

    private func loadFilter() {
        let raw = UserDefaults.standard.string(forKey: DefaultsKey.wallpaperFilter) ?? ""
        filter = WallpaperSupport.Filter(rawValue: raw) ?? .all
    }

    private func stopAccessing() {
        for url in scopedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        scopedURLs.removeAll()
    }

    private func startAccessing(_ resolved: [ResolvedBookmark]? = nil) {
        stopAccessing()
        let items = resolved ?? resolveOwnBookmarks()
        for item in items {
            if item.url.startAccessingSecurityScopedResource() {
                scopedURLs.append(item.url)
            }
        }
    }

    private struct ResolvedBookmark {
        let data: Data
        let url: URL
    }

    // resolve once per pass; withoutMounting so a missing network volume cannot stall
    private func resolveOwnBookmarks() -> [ResolvedBookmark] {
        var result: [ResolvedBookmark] = []
        var seen = Set<String>()
        for data in ownBookmarks {
            guard let url = resolveBookmark(data) else { continue }
            let path = url.standardizedFileURL.path
            guard seen.insert(path).inserted else { continue }
            result.append(ResolvedBookmark(data: data, url: url))
        }
        return result
    }

    private func resolveBookmark(_ data: Data) -> URL? {
        var stale = false
        return try? URL(resolvingBookmarkData: data,
                        options: [.withSecurityScope, .withoutUI, .withoutMounting],
                        relativeTo: nil,
                        bookmarkDataIsStale: &stale)
    }
}

// panel thumbs; process lifetime, cleared on uninstall
enum WallpaperThumbnailCache {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 400
        return cache
    }()

    private static let lock = NSLock()
    private static var generation = UUID()

    private static let prefetchQueue = DispatchQueue(
        label: "io.github.sam32j.lattice.wallpaper-thumbs",
        qos: .utility,
        attributes: .concurrent
    )

    static func image(for url: URL, maxPixel: Int = 160) -> NSImage? {
        cache.object(forKey: key(url, maxPixel))
    }

    static func store(_ image: NSImage, for url: URL, maxPixel: Int = 160) {
        cache.setObject(image, forKey: key(url, maxPixel))
    }

    static func clear() {
        cache.removeAllObjects()
    }

    // bump so in-flight scan/decode loops bail out
    static func beginGeneration() {
        lock.lock()
        generation = UUID()
        lock.unlock()
    }

    static func cancelPending() {
        beginGeneration()
    }

    static func snapshotGeneration() -> UUID {
        currentGeneration
    }

    static func matchesGeneration(_ generation: UUID) -> Bool {
        currentGeneration == generation
    }

    private static var currentGeneration: UUID {
        lock.lock()
        defer { lock.unlock() }
        return generation
    }

    static func prefetch(_ urls: [URL], maxPixel: Int = 160) {
        guard !urls.isEmpty else { return }
        let gen = currentGeneration
        prefetchQueue.async {
            prefetchSync(urls, maxPixel: maxPixel, generation: gen)
        }
    }

    // call from a background queue only
    static func prefetchSync(_ urls: [URL], maxPixel: Int = 160, generation: UUID? = nil) {
        let gen = generation ?? currentGeneration
        for url in urls {
            guard currentGeneration == gen else { return }
            _ = loadSync(url: url, maxPixel: maxPixel, generation: gen)
        }
    }

    // cell loads hop here so SwiftUI .task cancellation can drop the result
    static func load(url: URL, maxPixel: Int = 160, generation: UUID) async -> NSImage? {
        if let hit = image(for: url, maxPixel: maxPixel) { return hit }
        return await withCheckedContinuation { continuation in
            prefetchQueue.async {
                let loaded = loadSync(url: url, maxPixel: maxPixel, generation: generation)
                continuation.resume(returning: loaded)
            }
        }
    }

    static func loadSync(url: URL, maxPixel: Int = 160, generation: UUID? = nil) -> NSImage? {
        if let hit = image(for: url, maxPixel: maxPixel) { return hit }
        if let generation, currentGeneration != generation { return nil }
        guard let cgImage = decodeCGThumbnail(url: url, maxPixel: maxPixel) else { return nil }
        if let generation, currentGeneration != generation { return nil }
        let image = NSImage(cgImage: cgImage,
                            size: NSSize(width: cgImage.width, height: cgImage.height))
        store(image, for: url, maxPixel: maxPixel)
        return image
    }

    private static func decodeCGThumbnail(url: URL, maxPixel: Int) -> CGImage? {
        // reading an iCloud placeholder downloads the whole file; show the
        // placeholder cell instead until apply brings the picture down
        guard !WallpaperService.needsCloudDownload(url) else { return nil }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func key(_ url: URL, _ maxPixel: Int) -> NSString {
        "\(url.standardizedFileURL.path)#\(maxPixel)" as NSString
    }
}
