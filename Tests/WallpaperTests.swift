// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Foundation
import UniformTypeIdentifiers

enum WallpaperContract {
    static func run(_ suite: TestSuite) {
        WallpaperPickerContract.run(suite)
        let gallery = WallpaperGalleryLifecycle()
        let firstViewer = UUID()
        let secondViewer = UUID()
        let beforeOpen = gallery.invalidate()
        suite.expect(!gallery.isVisible && !gallery.accepts(beforeOpen),
                     "wallpaper scanning stays unavailable before the gallery opens")
        gallery.begin(firstViewer)
        let firstScan = gallery.invalidate()
        suite.expect(gallery.accepts(firstScan), "the open gallery accepts its current scan")
        gallery.end(firstViewer)
        suite.expect(!gallery.accepts(firstScan), "closing rejects a late scan result")
        gallery.begin(firstViewer)
        let reopenedScan = gallery.invalidate()
        suite.expect(gallery.accepts(reopenedScan) && !gallery.accepts(firstScan),
                     "reopening accepts only the new scan result")
        let replacementScan = gallery.invalidate()
        suite.expect(!gallery.accepts(reopenedScan) && gallery.accepts(replacementScan),
                     "a newer refresh replaces an earlier one")
        gallery.begin(secondViewer)
        let overlappingScan = gallery.invalidate()
        suite.expect(!gallery.end(firstViewer) && gallery.accepts(overlappingScan),
                     "closing the old panel keeps the new panel's scan active")
        suite.expect(gallery.end(secondViewer) && !gallery.accepts(overlappingScan),
                     "closing the last panel cancels its scan")
        gallery.begin(firstViewer)
        gallery.endAll()
        gallery.begin(secondViewer)
        let scanAfterReset = gallery.invalidate()
        suite.expect(!gallery.end(firstViewer) && gallery.accepts(scanAfterReset),
                     "a delayed close from before feature reset cannot cancel a new panel")

        let appleRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("lattice-wallpaper-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: appleRoot) }

        try? FileManager.default.createDirectory(at: appleRoot, withIntermediateDirectories: true)
        let still = appleRoot.appendingPathComponent("Plain Blue.png")
        let png = Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
        )!
        try? png.write(to: still)

        let thumbs = appleRoot.appendingPathComponent(".thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: thumbs, withIntermediateDirectories: true)
        let thumb = thumbs.appendingPathComponent("Peak.heic")
        try? png.write(to: thumb)

        let made = appleRoot.appendingPathComponent("Peak.madesktop")
        let plist: [String: Any] = ["thumbnailPath": thumb.path]
        let data = try? PropertyListSerialization.data(fromPropertyList: plist,
                                                       format: .xml,
                                                       options: 0)
        try? data?.write(to: made)

        // thumb-only madesktop must not appear (would apply a blurry preview)
        let appleThumbOnly = WallpaperSupport.enumerateAppleEntries(at: appleRoot)
        suite.expect(appleThumbOnly.contains { $0.title == "Plain Blue" && $0.source == .apple },
                     "top-level stills become Apple entries")
        suite.expect(!appleThumbOnly.contains { $0.title == "Peak" },
                     "madesktop without a full-size still is omitted")

        let wallpapers = appleRoot
            .appendingPathComponent(".wallpapers", isDirectory: true)
            .appendingPathComponent("Peak", isDirectory: true)
        try? FileManager.default.createDirectory(at: wallpapers, withIntermediateDirectories: true)
        let fullStill = wallpapers.appendingPathComponent("Peak.heic")
        try? png.write(to: fullStill)

        let apple = WallpaperSupport.enumerateAppleEntries(at: appleRoot)
        suite.expect(apple.contains {
            $0.title == "Peak" && $0.source == .apple
                && $0.imageURL.path == fullStill.path
                && $0.previewURL.path == thumb.path
        }, "madesktop with a full-size still uses the still and keeps the thumb as preview")
        suite.expect(apple.filter { $0.title == "Peak" }.count == 1,
                     "a downloaded dynamic asset is listed once beside its madesktop")

        // subfolders (Solid Colors) and downloaded assets with no madesktop
        let solids = appleRoot.appendingPathComponent("Solid Colors", isDirectory: true)
        try? FileManager.default.createDirectory(at: solids, withIntermediateDirectories: true)
        try? png.write(to: solids.appendingPathComponent("Teal.png"))
        let horizon = appleRoot.appendingPathComponent(".wallpapers/Horizon", isDirectory: true)
        try? FileManager.default.createDirectory(at: horizon, withIntermediateDirectories: true)
        try? png.write(to: horizon.appendingPathComponent("Horizon.heic"))
        try? png.write(to: horizon.appendingPathComponent("Horizon Thumbnail.png"))

        // aerial catalog: names from the string table, thumbnails required,
        // portrait variants skipped, appearance-only names take their label
        let aerials = appleRoot.appendingPathComponent("aerials", isDirectory: true)
        let manifest = aerials.appendingPathComponent("manifest", isDirectory: true)
        let tables = manifest.appendingPathComponent("TVIdleScreenStrings.bundle/Contents/Resources",
                                                     isDirectory: true)
        let aerialThumbs = aerials.appendingPathComponent("thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: tables, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: aerialThumbs, withIntermediateDirectories: true)
        let catalog: [String: Any] = ["assets": [
            ["id": "A1", "localizedNameKey": "BAY", "preferredOrder": 1,
             "url-4K-SDR-240FPS": "https://sylvan.apple.com/a1.mov"],
            ["id": "A2", "localizedNameKey": "LIGHT", "accessibilityLabel": "macOS",
             "variant": ["appearance": "light", "orientation": "landscape"]],
            ["id": "A3", "localizedNameKey": "LIGHT", "accessibilityLabel": "macOS",
             "variant": ["appearance": "light", "orientation": "portrait"]],
            ["id": "A4", "localizedNameKey": "NOTHUMB"],
        ]]
        try? JSONSerialization.data(withJSONObject: catalog)
            .write(to: manifest.appendingPathComponent("entries.json"))
        try? PropertyListSerialization.data(
            fromPropertyList: ["en": ["BAY": "Bay", "LIGHT": "Light", "NOTHUMB": "Missing"],
                               "de": ["BAY": "Bucht"]],
            format: .binary, options: 0)
            .write(to: tables.appendingPathComponent("Localizable.nocache.loctable"))
        for id in ["A1", "A2", "A3"] {
            try? png.write(to: aerialThumbs.appendingPathComponent("\(id).png"))
        }
        let aerialVideos = aerials.appendingPathComponent("videos", isDirectory: true)
        try? FileManager.default.createDirectory(at: aerialVideos, withIntermediateDirectories: true)
        try? png.write(to: aerialVideos.appendingPathComponent("A2.mov"))
        let everything = WallpaperSupport.enumerateAppleEntries(at: appleRoot, aerialsRoot: aerials)
        let bay = everything.first { $0.aerialAssetID == "A1" }
        suite.expect(bay?.pendingVideo?.url.absoluteString == "https://sylvan.apple.com/a1.mov"
                        && bay?.pendingVideo?.destination.lastPathComponent == "A1.mov"
                        && bay?.needsDownload == true,
                     "an aerial without its cached video offers the download")
        suite.expect(everything.first { $0.aerialAssetID == "A2" }?.needsDownload == false,
                     "an aerial whose video is cached needs no download")
        suite.expect(!WallpaperSupport.isAppleDownloadURL(URL(string: "https://apple.com.evil.net/x.mov")!)
                        && !WallpaperSupport.isAppleDownloadURL(URL(string: "http://sylvan.apple.com/x.mov")!),
                     "downloads only come from HTTPS Apple hosts")
        suite.expect(everything.contains { $0.title == "Teal" && $0.source == .apple },
                     "Desktop Pictures subfolders are listed")
        suite.expect(everything.contains { $0.title == "Horizon" && $0.previewURL.lastPathComponent == "Horizon Thumbnail.png" },
                     "downloaded dynamic assets without a madesktop are listed with their thumbnail")
        let aerialTitles = everything.filter { $0.aerialAssetID != nil }.map(\.title).sorted()
        suite.expect(aerialTitles == ["Bay", "macOS Light"],
                     "aerials need a thumbnail, skip portrait variants and name appearance-only variants")
        suite.expect(WallpaperSupport.aerialEntries(at: aerials, languages: ["de"]).first { $0.aerialAssetID == "A1" }?.title == "Bucht",
                     "aerial names follow the app language, falling back to English")
        var aerialRoot: [String: Any] = ["AllSpacesAndDisplays": ["Type": "linked"] as [String: Any]]
        let aerialPatched = WallpaperSupport.patchStoreRoot(&aerialRoot, aerialAssetID: "A1")
        let aerialChoice = (((aerialRoot["AllSpacesAndDisplays"] as? [String: Any])?["Linked"]
            as? [String: Any])?["Content"] as? [String: Any])?["Choices"] as? [[String: Any]]
        let aerialConfig = (aerialChoice?.first?["Configuration"] as? Data)
            .flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) } as? [String: String]
        suite.expect(aerialPatched
                        && aerialChoice?.first?["Provider"] as? String == "com.apple.wallpaper.choice.aerials"
                        && aerialConfig == ["assetID": "A1"],
                     "aerials are set through the store by asset ID")

        // dynamic pictures macOS has not downloaded come from the system catalog
        let catalogURL = appleRoot.appendingPathComponent("catalog.xml")
        let sha = Data([1, 2, 3])
        try? PropertyListSerialization.data(fromPropertyList: ["Assets": [
            ["DesktopPictureID": "Dune", "__BaseURL": "https://updates.cdn-apple.com/x/",
             "__RelativePath": "dune.zip", "_ContentVersion": 1, "_Measurement": sha],
            ["DesktopPictureID": "Dune", "__BaseURL": "https://updates.cdn-apple.com/x/",
             "__RelativePath": "dune2.zip", "_ContentVersion": 2, "_Measurement": sha],
            ["DesktopPictureID": "Evil", "__BaseURL": "https://example.com/",
             "__RelativePath": "evil.zip"],
            ["DesktopPictureID": "Plain", "__BaseURL": "http://updates.cdn-apple.com/",
             "__RelativePath": "plain.zip"],
        ]], format: .xml, options: 0).write(to: catalogURL)
        let pictureCatalog = WallpaperSupport.desktopPictureCatalog(at: catalogURL)
        suite.expect(pictureCatalog.keys.sorted() == ["Dune"]
                        && pictureCatalog["Dune"]?.url.lastPathComponent == "dune2.zip"
                        && pictureCatalog["Dune"]?.sha1 == sha,
                     "the picture catalog keeps HTTPS apple.com zips, newest version first")
        try? png.write(to: thumbs.appendingPathComponent("Dune.heic"))
        try? PropertyListSerialization.data(fromPropertyList: ["mobileAssetID": "Dune"], format: .xml, options: 0)
            .write(to: appleRoot.appendingPathComponent("Dune.madesktop"))
        let downloadsFolder = appleRoot.appendingPathComponent("Downloads", isDirectory: true)
        let downloads = WallpaperSupport.Downloads(catalog: pictureCatalog, folder: downloadsFolder)
        let pending = WallpaperSupport.enumerateAppleEntries(at: appleRoot, downloads: downloads)
            .first { $0.title == "Dune" }
        suite.expect(pending?.remoteAsset?.pictureID == "Dune"
                        && pending?.imageURL.deletingLastPathComponent().path == downloadsFolder.path
                        && pending?.previewURL.lastPathComponent == "Dune.heic",
                     "a picture not downloaded is listed with its thumbnail and where to fetch it")
        try? FileManager.default.createDirectory(at: downloadsFolder, withIntermediateDirectories: true)
        try? png.write(to: WallpaperSupport.downloadedStillURL(pictureID: "Dune", in: downloadsFolder))
        let kept = WallpaperSupport.enumerateAppleEntries(at: appleRoot, downloads: downloads)
            .first { $0.title == "Dune" }
        suite.expect(kept != nil && kept?.remoteAsset == nil,
                     "a picture Lattice downloaded is set from its kept copy")

        let ownFolder = appleRoot.appendingPathComponent("Mine", isDirectory: true)
        try? FileManager.default.createDirectory(at: ownFolder, withIntermediateDirectories: true)
        let ownImage = ownFolder.appendingPathComponent("shot.jpg")
        try? png.write(to: ownImage)
        let own = WallpaperSupport.ownEntries(from: WallpaperSupport.images(inFolder: ownFolder))
        suite.expect(own.count == 1 && own[0].source == .own && own[0].title == "shot",
                     "folder scans produce own entries")

        // packages (Photos Library style) must not be walked
        let package = ownFolder.appendingPathComponent("Library.photoslibrary", isDirectory: true)
        let nested = package.appendingPathComponent("originals", isDirectory: true)
        try? FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let buried = nested.appendingPathComponent("hidden.jpg")
        try? png.write(to: buried)
        // mark as package the way Finder does for bundles
        var values = URLResourceValues()
        values.isPackage = true
        var packageURL = package
        try? packageURL.setResourceValues(values)
        let withoutPackage = WallpaperSupport.images(inFolder: ownFolder)
        suite.expect(withoutPackage.count == 1 && withoutPackage[0].lastPathComponent == "shot.jpg",
                     "folder scans skip package contents")

        var cancelledChecks = 0
        let cancelled = WallpaperSupport.images(inFolder: ownFolder) {
            cancelledChecks += 1
            return cancelledChecks < 2
        }
        suite.expect(cancelled.isEmpty && cancelledChecks >= 2,
                     "folder scans stop when shouldContinue becomes false")

        let merged = WallpaperSupport.merge(apple: apple, own: own)
        suite.expect(WallpaperSupport.filtered(merged, by: .all).count == merged.count,
                     "all keeps every entry")
        suite.expect(WallpaperSupport.filtered(merged, by: .own).allSatisfy { $0.source == .own },
                     "own filter keeps only own entries")
        suite.expect(WallpaperSupport.filtered(merged, by: .apple).allSatisfy { $0.source == .apple },
                     "apple filter keeps only Apple entries")

        func ownEntry(_ path: String) -> WallpaperSupport.Entry {
            let url = URL(fileURLWithPath: path)
            return WallpaperSupport.Entry(id: path, imageURL: url, previewURL: url,
                                          title: WallpaperSupport.title(for: url), source: .own)
        }
        let appleOnly = WallpaperSupport.Entry(id: "/System/a.heic",
                                               imageURL: URL(fileURLWithPath: "/System/a.heic"),
                                               previewURL: URL(fileURLWithPath: "/System/a.heic"),
                                               title: "a", source: .apple)
        let groups = WallpaperSupport.ownGroups([
            ownEntry("/Pics/Walls/one.jpg"),
            ownEntry("/Pics/Walls/Nested/two.jpg"),
            ownEntry("/Pics/Walls/Nested/Deep/three.jpg"),
            ownEntry("/Loose/four.png"),
            ownEntry("/Pics/WallsExtra/five.jpg"),
            appleOnly,
        ], folderRoots: ["/Pics/Walls/Nested", "/Pics/Walls", "/Pics/WallsExtra/"])
        suite.expect(groups.map(\.path) == ["/Pics/Walls/Nested", "/Pics/Walls", "/Pics/WallsExtra", "/Loose"],
                     "imported groups follow folder import order, loose parents last")
        suite.expect(groups.first?.entries.map(\.title) == ["two", "three"]
                        && groups[1].entries.map(\.title) == ["one"],
                     "imported pictures join their deepest imported folder")
        suite.expect(!groups.contains { $0.entries.contains { $0.source == .apple } },
                     "imported groups leave Apple stills out")
        suite.expect(WallpaperSupport.displayPath("/Users/me/Pictures", home: "/Users/me") == "~/Pictures"
                        && WallpaperSupport.displayPath("/Users/me", home: "/Users/me") == "~"
                        && WallpaperSupport.displayPath("/Users/meow/x", home: "/Users/me") == "/Users/meow/x",
                     "display paths abbreviate only the home folder")

        suite.expect(WallpaperSupport.targetScreenIDs(allDisplays: true,
                                                      screenIDs: [1, 2, 3],
                                                      pointerScreenID: 2) == [1, 2, 3],
                     "all displays returns every screen id")
        suite.expect(WallpaperSupport.targetScreenIDs(allDisplays: false,
                                                      screenIDs: [1, 2, 3],
                                                      pointerScreenID: 2) == [2],
                     "single display prefers the pointer screen")
        suite.expect(WallpaperSupport.targetScreenIDs(allDisplays: false,
                                                      screenIDs: [1, 2, 3],
                                                      pointerScreenID: 9) == [1],
                     "missing pointer screen falls back to the first display")
        suite.expect(WallpaperSupport.systemWallpaperSettingsURL != nil,
                     "System Settings wallpaper deep-link is present")

        let numbers = Array(1...50)
        suite.expect(WallpaperSupport.pageCount(itemCount: 0) == 0,
                     "an empty gallery has no pages")
        suite.expect(WallpaperSupport.pageCount(itemCount: 24) == 1
                        && WallpaperSupport.pageCount(itemCount: 25) == 2
                        && WallpaperSupport.pageCount(itemCount: 50) == 3,
                     "pages are 24 items wide")
        suite.expect(WallpaperSupport.clampedPage(0, itemCount: 50) == 1
                        && WallpaperSupport.clampedPage(99, itemCount: 50) == 3,
                     "page index stays inside the valid range")
        suite.expect(WallpaperSupport.pageSlice(numbers, page: 1) == Array(1...24)
                        && WallpaperSupport.pageSlice(numbers, page: 2) == Array(25...48)
                        && WallpaperSupport.pageSlice(numbers, page: 3) == [49, 50],
                     "page slices cover the list without overlap")

        let imageURL = URL(fileURLWithPath: "/tmp/lattice-wallpaper-test.png")
        suite.expect(WallpaperSupport.imageFileConfigurationData(for: imageURL) != nil
                        && WallpaperSupport.fillScreenOptionValuesData() != nil,
                     "store blobs encode for a still image")
        var root: [String: Any] = [
            "AllSpacesAndDisplays": ["Type": "idle"] as [String: Any],
            "Displays": [
                "DISP-1": ["Type": "individual"] as [String: Any],
            ],
            "Spaces": [
                "SPACE-1": [
                    "Default": ["Type": "individual"] as [String: Any],
                    "Displays": [
                        "DISP-1": ["Type": "individual"] as [String: Any],
                    ],
                ] as [String: Any],
            ],
            "SystemDefault": ["Type": "individual"] as [String: Any],
        ]
        suite.expect(WallpaperSupport.patchStoreRoot(&root, imageURL: imageURL),
                     "store patch rewrites every Desktop slot")
        let allDesktop = (root["AllSpacesAndDisplays"] as? [String: Any])?["Desktop"]
        let displayDesktop = ((root["Displays"] as? [String: Any])?["DISP-1"] as? [String: Any])?["Desktop"]
        let spaceEntry = (root["Spaces"] as? [String: Any])?["SPACE-1"] as? [String: Any]
        let spaceDesktop = ((spaceEntry?["Displays"] as? [String: Any])?["DISP-1"] as? [String: Any])?["Desktop"]
        suite.expect(allDesktop != nil && displayDesktop != nil && spaceDesktop != nil,
                     "AllSpaces, Displays and Spaces Desktop entries are filled")

        // shape System Settings leaves after picking a still (Type linked + image choice)
        let priorConfig = WallpaperSupport.imageFileConfigurationData(
            for: URL(fileURLWithPath: "/tmp/prior-system-settings.png")
        )
        let priorOptions = WallpaperSupport.fillScreenOptionValuesData()
        let priorChoice: [String: Any] = [
            "Provider": "com.apple.wallpaper.choice.image",
            "Files": [] as [Any],
            "Configuration": priorConfig as Any,
        ]
        let priorContent: [String: Any] = [
            "Choices": [priorChoice],
            "Shuffle": "$null",
            "EncodedOptionValues": priorOptions as Any,
        ]
        var linkedRoot: [String: Any] = [
            "AllSpacesAndDisplays": [
                "Type": "linked",
                "Linked": [
                    "LastSet": Date(timeIntervalSince1970: 1),
                    "LastUse": Date(timeIntervalSince1970: 1),
                    "Content": priorContent,
                ] as [String: Any],
            ] as [String: Any],
            "SystemDefault": [
                "Type": "linked",
                "Linked": [
                    "LastSet": Date(timeIntervalSince1970: 1),
                    "LastUse": Date(timeIntervalSince1970: 1),
                    "Content": priorContent,
                ] as [String: Any],
            ] as [String: Any],
            "Displays": [:] as [String: Any],
            "Spaces": [:] as [String: Any],
        ]
        suite.expect(WallpaperSupport.patchStoreRoot(&linkedRoot, imageURL: imageURL),
                     "linked store layout is patched")
        let linkedSlot = (linkedRoot["AllSpacesAndDisplays"] as? [String: Any])?["Linked"] as? [String: Any]
        let linkedDesktop = (linkedRoot["AllSpacesAndDisplays"] as? [String: Any])?["Desktop"]
        let systemLinked = (linkedRoot["SystemDefault"] as? [String: Any])?["Linked"] as? [String: Any]
        let linkedChoicesAny = (linkedSlot?["Content"] as? [String: Any])?["Choices"] as? [Any]
        let linkedFirst = linkedChoicesAny?.first as? [String: Any]
        let linkedProvider = linkedFirst?["Provider"] as? String
        let linkedConfig = linkedFirst?["Configuration"] as? Data
        var linkedRelative: String?
        if let linkedConfig,
           let decoded = try? PropertyListSerialization.propertyList(from: linkedConfig,
                                                                     options: [],
                                                                     format: nil) as? [String: Any],
           let urlDict = decoded["url"] as? [String: Any] {
            linkedRelative = urlDict["relative"] as? String
        }
        suite.expect(linkedSlot?["Content"] != nil && linkedDesktop == nil,
                     "linked layout updates Linked and drops Desktop")
        suite.expect(systemLinked?["Content"] != nil,
                     "SystemDefault linked slot matches System Settings still shape")
        suite.expect(linkedProvider == "com.apple.wallpaper.choice.image"
                        && linkedRelative == imageURL.absoluteString
                        && linkedRelative != URL(fileURLWithPath: "/tmp/prior-system-settings.png").absoluteString,
                     "linked patch replaces the System Settings imageFile choice")

        // stray Linked on an individual container must not steal the Desktop slot
        var individualWithStaleLinked: [String: Any] = [
            "AllSpacesAndDisplays": [
                "Type": "individual",
                "Desktop": ["Type": "keep"] as [String: Any],
                "Linked": [
                    "Content": ["Choices": [] as [Any]] as [String: Any],
                ] as [String: Any],
            ] as [String: Any],
            "Displays": [:] as [String: Any],
            "Spaces": [:] as [String: Any],
        ]
        suite.expect(WallpaperSupport.patchStoreRoot(&individualWithStaleLinked, imageURL: imageURL),
                     "individual container with a leftover Linked key still patches")
        let individualAll = individualWithStaleLinked["AllSpacesAndDisplays"] as? [String: Any]
        let patchedDesktop = individualAll?["Desktop"] as? [String: Any]
        let leftoverLinked = individualAll?["Linked"] as? [String: Any]
        let leftoverChoices = (leftoverLinked?["Content"] as? [String: Any])?["Choices"] as? [Any]
        suite.expect(patchedDesktop?["Content"] != nil,
                     "individual Type writes Desktop")
        suite.expect(leftoverChoices?.isEmpty == true,
                     "stray Linked on individual is left alone")

        var missingAllSpaces: [String: Any] = ["Displays": [:] as [String: Any]]
        suite.expect(!WallpaperSupport.patchStoreRoot(&missingAllSpaces, imageURL: imageURL),
                     "store without AllSpacesAndDisplays is rejected")
        var badDisplays: [String: Any] = [
            "AllSpacesAndDisplays": ["Type": "idle"] as [String: Any],
            "Displays": "nope",
        ]
        suite.expect(!WallpaperSupport.patchStoreRoot(&badDisplays, imageURL: imageURL),
                     "store with a non-dict Displays value is rejected")
    }
}

/// Add image and Add folder, compiled from the service against these doubles.
/// The island never activates the app, and an inactive app's picker opens
/// behind the active app's window, so every picker has to come forward.
enum WallpaperPickerContract {
    static var steps: [String] = []

    final class Window {
        struct Level { let rawValue: Int }
        var level = Level(rawValue: 26)
    }
    final class Application {
        func activate(ignoringOtherApps: Bool) { WallpaperPickerContract.steps.append("activate") }
    }
    final class Panel {
        static var latest: Panel?
        var canChooseFiles = true
        var canChooseDirectories = false
        var allowsMultipleSelection = false
        var allowedContentTypes: [UTType] = []
        var message = ""
        var level = Window.Level(rawValue: 0)
        var urls: [URL] = []
        var completion: ((NSApplication.ModalResponse) -> Void)?
        init() { Self.latest = self }
        func begin(completionHandler: @escaping (NSApplication.ModalResponse) -> Void) {
            WallpaperPickerContract.steps.append("begin")
            completion = completionHandler
        }
        func makeKeyAndOrderFront(_ sender: Any?) { WallpaperPickerContract.steps.append("front") }
        func finish(_ response: NSApplication.ModalResponse) {
            let callback = completion
            completion = nil
            callback?(response)
        }
    }
    final class Island {
        static let shared = Island()
        var presentationWindow: Window?
    }
    final class Interaction {
        static let shared = Interaction()
        var isPresentingPopoverModal = false
    }
    class Fixture {
        typealias NSOpenPanel = Panel
        typealias NSWindow = Window
        typealias NotchService = Island
        typealias PanelInteractionState = Interaction
        var NSApp = Application()
        var isAvailable = true
        var openPanel: Panel?
        var remembered: [[URL]] = []
        func remember(urls: [URL]) { remembered.append(urls) }
    }

    static func run(_ suite: TestSuite) {
        defer {
            steps = []
            Panel.latest = nil
            Island.shared.presentationWindow = nil
            Interaction.shared.isPresentingPopoverModal = false
        }
        let picked = [URL(fileURLWithPath: "/tmp/one.png"), URL(fileURLWithPath: "/tmp/two.heic")]
        for inNotch in [false, true] {
            let host = inNotch ? "island" : "menu panel"
            let island = Window()
            Island.shared.presentationWindow = island
            let service = Service()
            steps = []
            Panel.latest = nil
            service.addImages(inNotch: inNotch)
            guard let images = Panel.latest else {
                suite.expect(false, "Add image opens a picker from the \(host)")
                continue
            }
            suite.expect(steps == ["begin", "activate", "front"],
                         "a picker from the \(host) activates the app and comes to the front")
            suite.expect(inNotch ? images.level.rawValue > island.level.rawValue : images.level.rawValue == 0,
                         inNotch ? "the island's picker opens above the island" : "the menu panel's picker keeps its level")
            suite.expect(images.canChooseFiles && !images.canChooseDirectories && images.allowsMultipleSelection
                            && Interaction.shared.isPresentingPopoverModal == !inNotch,
                         "Add image picks several images and holds only the menu panel open")
            steps = []
            service.addFolder(inNotch: inNotch)
            suite.expect(Panel.latest === images && steps == ["activate", "front"],
                         "a click while the \(host)'s picker is up brings it forward instead of doing nothing")
            images.urls = picked
            images.finish(.OK)
            suite.expect(service.remembered == [picked] && service.openPanel == nil
                            && !Interaction.shared.isPresentingPopoverModal,
                         "choosing images keeps them and frees the buttons")
            steps = []
            service.addFolder(inNotch: inNotch)
            guard let folders = Panel.latest, folders !== images else {
                suite.expect(false, "Add folder opens its own picker once the first one closed")
                continue
            }
            suite.expect(!folders.canChooseFiles && folders.canChooseDirectories && !folders.allowsMultipleSelection
                            && steps == ["begin", "activate", "front"],
                         "Add folder opens a folder picker in front")
            folders.finish(.cancel)
            suite.expect(service.remembered == [picked] && service.openPanel == nil
                            && !Interaction.shared.isPresentingPopoverModal,
                         "cancelling keeps nothing and frees the buttons")
        }
        let lone = Service()
        Island.shared.presentationWindow = nil
        steps = []
        Panel.latest = nil
        lone.addImages(inNotch: true)
        suite.expect(Panel.latest?.level.rawValue == 0 && steps == ["begin", "activate", "front"],
                     "without an island window the picker still comes forward at its own level")
        Panel.latest?.finish(.cancel)

        let crossing = Service()
        let crossingIsland = Window()
        Island.shared.presentationWindow = crossingIsland
        Panel.latest = nil
        crossing.addImages(inNotch: false)
        let fromMenuPanel = Panel.latest
        steps = []
        crossing.addFolder(inNotch: true)
        suite.expect(fromMenuPanel != nil && Panel.latest === fromMenuPanel && steps == ["activate", "front"]
                        && (fromMenuPanel?.level.rawValue ?? 0) > crossingIsland.level.rawValue,
                     "a click from the island raises the menu panel's picker above the island")
        fromMenuPanel?.finish(.cancel)
        suite.expect(crossing.openPanel == nil && !Interaction.shared.isPresentingPopoverModal,
                     "closing that picker frees the buttons and the menu panel")

        let unavailable = Service()
        unavailable.isAvailable = false
        steps = []
        Panel.latest = nil
        unavailable.addImages(inNotch: false)
        unavailable.addFolder(inNotch: true)
        suite.expect(Panel.latest == nil && steps.isEmpty, "the feature turned off opens no picker")
    }
}
