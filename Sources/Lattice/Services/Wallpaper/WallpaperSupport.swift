// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Lets a folder scan publish only while its gallery is open and it is the
/// latest scan. The scan reads this from a worker queue while the UI changes
/// visibility on the main thread.
final class WallpaperGalleryLifecycle {
    private let lock = NSLock()
    private var viewers = Set<UUID>()
    private var generation = UUID()

    var isVisible: Bool { lock.withLock { !viewers.isEmpty } }

    func begin(_ viewer: UUID) { lock.withLock { _ = viewers.insert(viewer) } }

    /// A closing panel cancels work only when no other gallery is still open.
    @discardableResult
    func end(_ viewer: UUID) -> Bool {
        lock.withLock {
            guard viewers.remove(viewer) != nil, viewers.isEmpty else { return false }
            generation = UUID()
            return true
        }
    }

    func endAll() {
        lock.withLock {
            viewers.removeAll()
            generation = UUID()
        }
    }

    @discardableResult
    func invalidate() -> UUID {
        lock.withLock {
            generation = UUID()
            return generation
        }
    }

    func accepts(_ token: UUID) -> Bool {
        lock.withLock { !viewers.isEmpty && generation == token }
    }
}

/// Catalog / filter / store-patch helpers. No AppKit (test harness).
enum WallpaperSupport {
    enum Source: String, Equatable {
        case apple
        case own
    }

    enum Filter: String, CaseIterable, Identifiable {
        case all
        case own
        case apple

        var id: String { rawValue }
    }

    struct Entry: Equatable, Identifiable {
        let id: String
        let imageURL: URL
        let previewURL: URL
        let title: String
        let source: Source
        /// An Apple aerial, applied through the wallpaper store by its ID;
        /// its image is only the catalog thumbnail.
        var aerialAssetID: String? = nil
        /// A dynamic picture macOS has not downloaded yet: where to fetch it.
        /// Its image URL is where the download will be kept.
        var remoteAsset: RemoteAsset? = nil
        /// An aerial whose video is not in the system's cache yet.
        var pendingVideo: RemoteVideo? = nil

        var needsDownload: Bool { remoteAsset != nil || pendingVideo != nil }
    }

    /// An aerial video to fetch, and where the system keeps it.
    struct RemoteVideo: Equatable {
        let url: URL
        let destination: URL
    }

    /// Only HTTPS addresses on Apple's domains are fetched.
    static func isAppleDownloadURL(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host?.lowercased() else { return false }
        return ["apple.com", "cdn-apple.com"].contains { host == $0 || host.hasSuffix("." + $0) }
    }

    /// One desktop picture in the system's MobileAsset catalog.
    struct RemoteAsset: Equatable {
        let pictureID: String
        let url: URL
        /// SHA-1 of the zip, as the catalog measures it.
        let sha1: Data?
    }

    /// Downloadable desktop pictures, and the folder their stills are kept in.
    struct Downloads {
        let catalog: [String: RemoteAsset]
        let folder: URL
    }

    /// The system's own catalog of desktop pictures it downloads on demand.
    static let desktopPictureCatalogURL = URL(fileURLWithPath:
        "/System/Library/AssetsV2/com_apple_MobileAsset_DesktopPicture/com_apple_MobileAsset_DesktopPicture.xml")

    /// Reads the catalog: each picture's zip on Apple's servers. Only HTTPS
    /// addresses on Apple's domains are kept; the newest content version wins.
    static func desktopPictureCatalog(at url: URL = desktopPictureCatalogURL,
                                      fileManager: FileManager = .default) -> [String: RemoteAsset] {
        guard let data = fileManager.contents(atPath: url.path),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any],
              let assets = plist["Assets"] as? [[String: Any]]
        else { return [:] }
        var result: [String: (version: Int, asset: RemoteAsset)] = [:]
        for asset in assets {
            guard let id = asset["DesktopPictureID"] as? String, !id.isEmpty,
                  let base = asset["__BaseURL"] as? String,
                  let relative = asset["__RelativePath"] as? String,
                  let remote = URL(string: base + relative),
                  isAppleDownloadURL(remote)
            else { continue }
            let version = asset["_ContentVersion"] as? Int ?? 0
            if let existing = result[id], existing.version >= version { continue }
            result[id] = (version, RemoteAsset(pictureID: id, url: remote,
                                               sha1: asset["_Measurement"] as? Data))
        }
        return result.mapValues(\.asset)
    }

    /// Where a downloaded picture's still is kept.
    static func downloadedStillURL(pictureID: String, in folder: URL) -> URL {
        let safe = pictureID.replacingOccurrences(of: "/", with: "-")
        return folder.appendingPathComponent("\(safe).heic")
    }

    static let appleDesktopPicturesPath = "/System/Library/Desktop Pictures"
    static let appleDesktopPicturesURL = URL(fileURLWithPath: appleDesktopPicturesPath,
                                             isDirectory: true)

    static let imageExtensions: Set<String> = [
        "heic", "jpg", "jpeg", "png", "tif", "tiff", "gif", "bmp", "webp",
    ]

    static func isStillImageURL(_ url: URL) -> Bool {
        imageExtensions.contains(url.pathExtension.lowercased())
    }

    static func title(for url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }

    /// Where macOS keeps the aerial catalog: its manifest, names and thumbnails.
    static var appleAerialsURL: URL {
        URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent("Library/Application Support/com.apple.wallpaper/aerials",
                                    isDirectory: true)
    }

    /// Every Apple wallpaper the system has on disk, read at runtime: the
    /// stills and dynamic HEICs at the top of Desktop Pictures, its
    /// subfolders (Solid Colors), dynamic pictures whose full asset has been
    /// downloaded, and, when given its root, the aerial catalog. A dynamic
    /// picture still waiting for its download has only a thumbnail, so it
    /// cannot be set and is left out.
    static func enumerateAppleEntries(
        at root: URL = appleDesktopPicturesURL,
        aerialsRoot: URL? = nil,
        downloads: Downloads? = nil,
        languages: [String] = ["en"],
        fileManager: FileManager = .default
    ) -> [Entry] {
        guard let names = try? fileManager.contentsOfDirectory(atPath: root.path) else {
            return []
        }
        var entries: [Entry] = []
        var seen = Set<String>()
        func add(_ entry: Entry) {
            guard seen.insert(entry.imageURL.standardizedFileURL.path).inserted else { return }
            entries.append(entry)
        }
        for name in names.sorted() where !name.hasPrefix(".") {
            let url = root.appendingPathComponent(name)
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue,
               url.pathExtension.isEmpty {
                let children = (try? fileManager.contentsOfDirectory(atPath: url.path)) ?? []
                for child in children.sorted() where !child.hasPrefix(".") {
                    let childURL = url.appendingPathComponent(child)
                    if isStillImageURL(childURL) {
                        add(Entry(id: childURL.standardizedFileURL.path, imageURL: childURL,
                                  previewURL: childURL, title: title(for: childURL), source: .apple))
                    }
                }
                continue
            }
            if let resolved = resolveAppleStill(at: url, root: root, downloads: downloads,
                                                 fileManager: fileManager) {
                add(resolved)
            }
        }
        // Downloaded dynamic assets with no .madesktop beside them (Sonoma Horizon).
        let assets = root.appendingPathComponent(".wallpapers", isDirectory: true)
        for stem in ((try? fileManager.contentsOfDirectory(atPath: assets.path)) ?? []).sorted()
        where !stem.hasPrefix(".") {
            let folder = assets.appendingPathComponent(stem, isDirectory: true)
            let image = folder.appendingPathComponent("\(stem).heic")
            guard fileManager.fileExists(atPath: image.path) else { continue }
            let candidates = [
                folder.appendingPathComponent("\(stem) Thumbnail@2x.png"),
                folder.appendingPathComponent("\(stem) Thumbnail.png"),
                root.appendingPathComponent(".thumbnails/\(stem).heic"),
            ]
            let preview = candidates.first { fileManager.fileExists(atPath: $0.path) } ?? image
            add(Entry(id: image.standardizedFileURL.path, imageURL: image, previewURL: preview,
                      title: stem, source: .apple))
        }
        if let aerialsRoot {
            for entry in aerialEntries(at: aerialsRoot, languages: languages, fileManager: fileManager) {
                add(entry)
            }
        }
        return entries.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    /// The aerials in the system's catalog, named as System Settings names
    /// them. WallpaperAgent fetches the video itself once one is chosen, so
    /// each needs only its local thumbnail. Portrait variants are skipped,
    /// and a variant named only for its appearance takes its label first
    /// ("macOS Light").
    static func aerialEntries(at root: URL,
                              languages: [String] = ["en"],
                              fileManager: FileManager = .default) -> [Entry] {
        let manifest = root.appendingPathComponent("manifest", isDirectory: true)
        guard let data = fileManager.contents(atPath: manifest.appendingPathComponent("entries.json").path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let assets = json["assets"] as? [[String: Any]]
        else { return [] }
        let tablePath = manifest
            .appendingPathComponent("TVIdleScreenStrings.bundle/Contents/Resources/Localizable.nocache.loctable")
        let tables = fileManager.contents(atPath: tablePath.path)
            .flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) }
            as? [String: [String: String]] ?? [:]
        let table = languages.lazy.compactMap { tables[$0] }.first ?? tables["en"] ?? [:]
        let english = tables["en"] ?? [:]
        let thumbnails = root.appendingPathComponent("thumbnails", isDirectory: true)
        let videos = root.appendingPathComponent("videos", isDirectory: true)

        var entries: [Entry] = []
        var titles = Set<String>()
        for asset in assets.sorted(by: { ($0["preferredOrder"] as? Int ?? 0) < ($1["preferredOrder"] as? Int ?? 0) }) {
            guard let id = asset["id"] as? String, !id.isEmpty else { continue }
            let variant = asset["variant"] as? [String: Any]
            if variant?["orientation"] as? String == "portrait" { continue }
            let thumbnail = thumbnails.appendingPathComponent("\(id).png")
            guard fileManager.fileExists(atPath: thumbnail.path) else { continue }
            let key = asset["localizedNameKey"] as? String ?? ""
            let label = asset["accessibilityLabel"] as? String
            var name = table[key] ?? english[key] ?? label ?? id
            if variant != nil, let label, !label.isEmpty, !name.localizedCaseInsensitiveContains(label) {
                name = "\(label) \(name)"
            }
            guard titles.insert(name).inserted else { continue }
            // the system caches each video as videos/<id>.mov
            let video = videos.appendingPathComponent("\(id).mov")
            var pending: RemoteVideo?
            if !fileManager.fileExists(atPath: video.path),
               let address = asset.first(where: { $0.key.hasPrefix("url-") })?.value as? String,
               let remote = URL(string: address), isAppleDownloadURL(remote) {
                pending = RemoteVideo(url: remote, destination: video)
            }
            entries.append(Entry(id: "aerial:\(id)", imageURL: thumbnail, previewURL: thumbnail,
                                 title: name, source: .apple, aerialAssetID: id,
                                 pendingVideo: pending))
        }
        return entries
    }

    static func resolveAppleStill(at url: URL,
                                  root: URL = appleDesktopPicturesURL,
                                  downloads: Downloads? = nil,
                                  fileManager: FileManager = .default) -> Entry? {
        if isStillImageURL(url), fileManager.fileExists(atPath: url.path) {
            return Entry(id: url.standardizedFileURL.path,
                         imageURL: url,
                         previewURL: url,
                         title: title(for: url),
                         source: .apple)
        }
        guard url.pathExtension.lowercased() == "madesktop" else { return nil }
        let stem = url.deletingPathExtension().lastPathComponent
        let wallpaperAsset = root
            .appendingPathComponent(".wallpapers", isDirectory: true)
            .appendingPathComponent(stem, isDirectory: true)
            .appendingPathComponent("\(stem).heic")
        let thumbnail = root
            .appendingPathComponent(".thumbnails", isDirectory: true)
            .appendingPathComponent("\(stem).heic")
        let plistThumbnail = madesktopThumbnailPath(at: url).map { URL(fileURLWithPath: $0) }

        let imageURL: URL?
        var remote: RemoteAsset?
        // full-size still only; .thumbnails / thumbnailPath are preview-sized
        if fileManager.fileExists(atPath: wallpaperAsset.path) {
            imageURL = wallpaperAsset
        } else if let downloads {
            // not downloaded by macOS: Lattice's own copy, or one to fetch
            let pictureID = madesktopValue("mobileAssetID", at: url) ?? stem
            let kept = downloadedStillURL(pictureID: pictureID, in: downloads.folder)
            if fileManager.fileExists(atPath: kept.path) {
                imageURL = kept
            } else if let asset = downloads.catalog[pictureID] {
                imageURL = kept
                remote = asset
            } else {
                imageURL = nil
            }
        } else {
            imageURL = nil
        }
        guard let imageURL else { return nil }
        let previewURL: URL
        if let plistThumbnail, fileManager.fileExists(atPath: plistThumbnail.path) {
            previewURL = plistThumbnail
        } else if fileManager.fileExists(atPath: thumbnail.path) {
            previewURL = thumbnail
        } else if remote == nil {
            previewURL = imageURL
        } else {
            return nil
        }
        return Entry(id: url.standardizedFileURL.path,
                     imageURL: imageURL,
                     previewURL: previewURL,
                     title: stem,
                     source: .apple,
                     remoteAsset: remote)
    }

    static func madesktopValue(_ key: String, at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any],
              let value = plist[key] as? String, !value.isEmpty
        else { return nil }
        return value
    }

    static func madesktopThumbnailPath(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data,
                                                                      options: [],
                                                                      format: nil)
                as? [String: Any],
              let path = plist["thumbnailPath"] as? String,
              !path.isEmpty
        else { return nil }
        return path
    }

    static func images(inFolder folder: URL,
                       fileManager: FileManager = .default,
                       shouldContinue: () -> Bool = { true }) -> [URL] {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey, .isDirectoryKey, .isPackageKey, .isSymbolicLinkKey,
        ]
        guard let enumerator = fileManager.enumerator(
            at: folder,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var urls: [URL] = []
        for case let url as URL in enumerator {
            guard shouldContinue() else { return [] }
            let values = try? url.resourceValues(forKeys: keys)
            // don't walk into .app / Photos Library / other bundles
            // The enumerator never follows links; skipDescendants on one would
            // instead cut short the directory it sits in.
            if values?.isSymbolicLink == true { continue }
            if values?.isPackage == true {
                enumerator.skipDescendants()
                continue
            }
            guard isStillImageURL(url), values?.isRegularFile == true else { continue }
            urls.append(url)
        }
        return urls.sorted {
            $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent)
                == .orderedAscending
        }
    }

    static func ownEntries(from urls: [URL]) -> [Entry] {
        var entries: [Entry] = []
        var seen = Set<String>()
        for url in urls {
            let key = url.standardizedFileURL.path
            guard seen.insert(key).inserted else { continue }
            entries.append(Entry(id: key,
                                 imageURL: url,
                                 previewURL: url,
                                 title: title(for: url),
                                 source: .own))
        }
        return entries
    }

    static func merge(apple: [Entry], own: [Entry]) -> [Entry] {
        var seen = Set(apple.map(\.id))
        var merged = apple
        for entry in own where seen.insert(entry.id).inserted {
            merged.append(entry)
        }
        return merged.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    static func filtered(_ entries: [Entry], by filter: Filter) -> [Entry] {
        switch filter {
        case .all: return entries
        case .own: return entries.filter { $0.source == .own }
        case .apple: return entries.filter { $0.source == .apple }
        }
    }

    /// Imported pictures that came from one folder.
    struct OwnGroup: Equatable, Identifiable {
        let path: String
        let entries: [Entry]
        var id: String { path }
    }

    /// Imported pictures under the folder they came from. A picture joins
    /// its deepest imported folder, and one added on its own joins its
    /// parent. Imported folders keep their import order; the rest follow.
    static func ownGroups(_ entries: [Entry], folderRoots: [String]) -> [OwnGroup] {
        let roots = folderRoots.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        var rank: [String: Int] = [:]
        for (index, root) in roots.enumerated() where rank[root] == nil {
            rank[root] = index
        }
        var byPath: [String: [Entry]] = [:]
        for entry in entries where entry.source == .own {
            let path = entry.id
            let root = roots
                .filter { path.hasPrefix($0.hasSuffix("/") ? $0 : $0 + "/") }
                .max { $0.count < $1.count }
                ?? (path as NSString).deletingLastPathComponent
            byPath[root, default: []].append(entry)
        }
        return byPath.keys.sorted { lhs, rhs in
            let left = rank[lhs] ?? Int.max
            let right = rank[rhs] ?? Int.max
            if left != right { return left < right }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
        .map { OwnGroup(path: $0, entries: byPath[$0] ?? []) }
    }

    /// A path as Finder shows it, with the home folder as a tilde.
    static func displayPath(_ path: String, home: String = NSHomeDirectory()) -> String {
        guard !home.isEmpty else { return path }
        if path == home { return "~" }
        let prefix = home.hasSuffix("/") ? home : home + "/"
        guard path.hasPrefix(prefix) else { return path }
        return "~/" + path.dropFirst(prefix.count)
    }

    static let pageSize = 24

    static func pageCount(itemCount: Int, pageSize: Int = pageSize) -> Int {
        guard pageSize > 0, itemCount > 0 else { return itemCount == 0 ? 0 : 1 }
        return (itemCount + pageSize - 1) / pageSize
    }

    // 1-based, clamped
    static func clampedPage(_ page: Int, itemCount: Int, pageSize: Int = pageSize) -> Int {
        let pages = pageCount(itemCount: itemCount, pageSize: pageSize)
        guard pages > 0 else { return 1 }
        return min(max(page, 1), pages)
    }

    static func pageSlice<T>(_ items: [T], page: Int, pageSize: Int = pageSize) -> [T] {
        let safe = clampedPage(page, itemCount: items.count, pageSize: pageSize)
        guard !items.isEmpty, pageSize > 0 else { return [] }
        let start = (safe - 1) * pageSize
        guard start < items.count else { return [] }
        let end = min(start + pageSize, items.count)
        return Array(items[start..<end])
    }

    static func targetScreenIDs(allDisplays: Bool,
                                screenIDs: [UInt32],
                                pointerScreenID: UInt32?) -> [UInt32] {
        if allDisplays { return screenIDs }
        if let pointerScreenID, screenIDs.contains(pointerScreenID) {
            return [pointerScreenID]
        }
        return screenIDs.first.map { [$0] } ?? []
    }

    static let systemWallpaperSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension"
    )

    // MARK: - WallpaperAgent store

    // Choice.Configuration bplist
    static func imageFileConfigurationData(for imageURL: URL) -> Data? {
        let payload: [String: Any] = [
            "type": "imageFile",
            "url": ["relative": imageURL.absoluteString],
        ]
        return try? PropertyListSerialization.data(fromPropertyList: payload,
                                                   format: .binary,
                                                   options: 0)
    }

    // Fill Screen = Crop in EncodedOptionValues
    static func fillScreenOptionValuesData() -> Data? {
        let payload: [String: Any] = [
            "values": [
                "placement": [
                    "picker": ["_0": ["id": "Crop"]],
                ],
            ],
        ]
        return try? PropertyListSerialization.data(fromPropertyList: payload,
                                                   format: .binary,
                                                   options: 0)
    }

    // stamp the still into every wallpaper slot (AllSpaces / Displays / Spaces).
    // unknown layouts return false so AppKit current-space apply stays the fallback.
    @discardableResult
    static func patchStoreRoot(_ root: inout [String: Any],
                               imageURL: URL,
                               now: Date = Date()) -> Bool {
        guard let configuration = imageFileConfigurationData(for: imageURL) else { return false }
        return patchStoreRoot(&root, provider: "com.apple.wallpaper.choice.image",
                              configuration: configuration, now: now)
    }

    /// An aerial's choice names only its asset; the agent fetches the video.
    static func aerialConfigurationData(assetID: String) -> Data? {
        try? PropertyListSerialization.data(fromPropertyList: ["assetID": assetID],
                                            format: .binary, options: 0)
    }

    @discardableResult
    static func patchStoreRoot(_ root: inout [String: Any],
                               aerialAssetID: String,
                               displays: Set<String>? = nil,
                               now: Date = Date()) -> Bool {
        guard let configuration = aerialConfigurationData(assetID: aerialAssetID) else { return false }
        return patchStoreRoot(&root, provider: "com.apple.wallpaper.choice.aerials",
                              configuration: configuration, displays: displays, now: now)
    }

    @discardableResult
    static func patchStoreRoot(_ root: inout [String: Any],
                               provider: String,
                               configuration: Data,
                               displays: Set<String>? = nil,
                               now: Date = Date()) -> Bool {
        guard let options = fillScreenOptionValuesData() else { return false }

        // Sonoma+ store always has this container; inventing it rewrites unsupported shapes
        guard var allSpaces = root["AllSpacesAndDisplays"] as? [String: Any] else { return false }

        let slot: [String: Any] = [
            "Content": [
                "Choices": [[
                    "Provider": provider,
                    "Files": [] as [Any],
                    "Configuration": configuration,
                ]],
                "Shuffle": "$null",
                "EncodedOptionValues": options,
            ] as [String: Any],
            "LastSet": now,
            "LastUse": now,
        ]

        // Some displays only: their own entries, in the display list and in
        // each Space, and nothing shared. None found means the choice cannot
        // be scoped, so nothing is written rather than every display changing.
        if let displays {
            return patchDisplayEntries(&root, keys: displays, slot: slot)
        }

        guard patchWallpaperSlot(&allSpaces, slot: slot) else { return false }
        root["AllSpacesAndDisplays"] = allSpaces

        if let displaysValue = root["Displays"] {
            guard var displays = displaysValue as? [String: Any] else { return false }
            for key in displays.keys {
                guard var entry = displays[key] as? [String: Any] else { return false }
                guard patchWallpaperSlot(&entry, slot: slot) else { return false }
                displays[key] = entry
            }
            root["Displays"] = displays
        }

        if let spacesValue = root["Spaces"] {
            guard var spaces = spacesValue as? [String: Any] else { return false }
            for spaceKey in spaces.keys {
                guard var space = spaces[spaceKey] as? [String: Any] else { return false }
                if let defaultValue = space["Default"] {
                    guard var defaultEntry = defaultValue as? [String: Any] else { return false }
                    guard patchWallpaperSlot(&defaultEntry, slot: slot) else { return false }
                    space["Default"] = defaultEntry
                }
                if let spaceDisplaysValue = space["Displays"] {
                    guard var spaceDisplays = spaceDisplaysValue as? [String: Any] else { return false }
                    for displayKey in spaceDisplays.keys {
                        guard var entry = spaceDisplays[displayKey] as? [String: Any] else {
                            return false
                        }
                        guard patchWallpaperSlot(&entry, slot: slot) else { return false }
                        spaceDisplays[displayKey] = entry
                    }
                    space["Displays"] = spaceDisplays
                }
                spaces[spaceKey] = space
            }
            root["Spaces"] = spaces
        }

        if let systemDefaultValue = root["SystemDefault"] {
            guard var systemDefault = systemDefaultValue as? [String: Any] else { return false }
            guard patchWallpaperSlot(&systemDefault, slot: slot) else { return false }
            root["SystemDefault"] = systemDefault
        }

        return true
    }

    // System Settings stills (Sonoma+) write Type=linked + Linked on
    // AllSpacesAndDisplays and SystemDefault, with Content.Choices Provider
    // com.apple.wallpaper.choice.image and an imageFile Configuration blob.
    // Captured from a store that only System Settings wrote (no Lattice bak).
    // Index.plist has no screen saver keys; that choice lives outside this store,
    // so replacing Linked does not rewrite a screen saver slot here.
    // Desktop is the older individual/idle slot. Key off Type so a leftover
    // Linked key on an individual container cannot steal the Desktop slot.
    @discardableResult
    private static func patchDisplayEntries(_ root: inout [String: Any], keys: Set<String>,
                                            slot: [String: Any]) -> Bool {
        var patched = false
        if var displays = root["Displays"] as? [String: Any] {
            for key in keys {
                guard var entry = displays[key] as? [String: Any] else { continue }
                guard patchWallpaperSlot(&entry, slot: slot) else { return false }
                displays[key] = entry
                patched = true
            }
            root["Displays"] = displays
        }
        if var spaces = root["Spaces"] as? [String: Any] {
            for spaceKey in spaces.keys {
                guard var space = spaces[spaceKey] as? [String: Any],
                      var spaceDisplays = space["Displays"] as? [String: Any] else { continue }
                for key in keys {
                    guard var entry = spaceDisplays[key] as? [String: Any] else { continue }
                    guard patchWallpaperSlot(&entry, slot: slot) else { return false }
                    spaceDisplays[key] = entry
                    patched = true
                }
                space["Displays"] = spaceDisplays
                spaces[spaceKey] = space
            }
            root["Spaces"] = spaces
        }
        return patched
    }

    static func patchWallpaperSlot(_ container: inout [String: Any],
                                   slot: [String: Any]) -> Bool {
        let type = container["Type"] as? String

        if type == "linked" {
            guard container["Linked"] == nil || container["Linked"] is [String: Any] else {
                return false
            }
            container["Linked"] = slot
            container.removeValue(forKey: "Desktop")
            return true
        }

        if type == "individual" || container["Desktop"] is [String: Any] {
            container["Desktop"] = slot
            return true
        }

        // idle (and similar) without a slot yet — Desktop path, refuse if Linked is present
        if type != nil {
            if container["Linked"] is [String: Any] { return false }
            container["Desktop"] = slot
            return true
        }

        return false
    }
}
