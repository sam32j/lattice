// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import UniformTypeIdentifiers

enum MediaEditorFileTests {
    static func run(_ suite: TestSuite) {
        var installed = true
        var presented = 0
        var discarded = 0
        let desktopLanding = {
            MediaEditorFileSupport.presentIfEnabled(installed, present: { presented += 1; return true },
                                                    discard: { discarded += 1 })
        }
        installed = false
        suite.expect(!desktopLanding() && presented == 0 && discarded == 1,
                     "removing an editor while desktop presentation is deferred never loads it and cleans the imported draft")
        suite.expect(!MediaEditorFileSupport.presentIfEnabled(true, present: { false }, discard: { discarded += 1 })
                     && discarded == 2, "an editor that rejects a draft releases its imported files")
        for type in [UTType.png, .jpeg, .heic, .tiff] {
            suite.expect(MediaEditorFileSupport.kind(for: type) == .image, "image types route to the image editor")
        }
        for type in [UTType.mpeg4Movie, .quickTimeMovie] {
            suite.expect(MediaEditorFileSupport.kind(for: type) == .video, "movie types route to the video editor")
        }
        for type in [UTType.mp3, .plainText, .folder, .zip] {
            suite.expect(MediaEditorFileSupport.kind(for: type) == nil, "non-media inputs never start an editor")
        }
        for image in [false, true] {
            for video in [false, true] {
                suite.expect(MediaEditorFileSupport.isEnabled(.image, image: image, video: video) == image
                             && MediaEditorFileSupport.isEnabled(.video, image: image, video: video) == video,
                             "editor availability depends only on its own installed feature")
            }
        }
        suite.expect(MediaEditorFileSupport.kind(for: URL(string: "https://example.com/a.png")!) == nil
                     && MediaEditorFileSupport.kind(for: URL(fileURLWithPath: "/missing/a.png")) == nil,
                     "remote and missing files cannot become editor drafts")
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("not a file", forType: .string)
        suite.expect(MediaEditorFileSupport.urls(from: pasteboard).isEmpty, "text drops do not open editors")
        let files = [URL(fileURLWithPath: "/tmp/first.png"), URL(fileURLWithPath: "/tmp/second.mov")]
        pasteboard.clearContents()
        pasteboard.writeObjects(files as [NSURL])
        suite.expect(MediaEditorFileSupport.urls(from: pasteboard) == files, "menu bar and Island drops retain every file")
        pasteboard.clearContents()
        let companion = NSPasteboardItem()
        companion.setString("keep this too", forType: .string)
        pasteboard.writeObjects([files[0] as NSURL, companion])
        suite.expect(MediaEditorFileSupport.urls(from: pasteboard).isEmpty,
                     "mixed drops never silently discard non-file companions")
        for language in AppLanguage.allCases {
            let strings = MediaEditorFileStrings.values(language)
            suite.expect(!strings.open.isEmpty && strings.enable.components(separatedBy: "%@").count == 2,
                         "file editor labels and feature guidance are localized: \(language)")
        }
        let data = try? Data(contentsOf: URL(fileURLWithPath: "Resources/Info.plist"))
        let plist = data.flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any] }
        let types = plist?["CFBundleDocumentTypes"] as? [[String: Any]] ?? []
        suite.expect(types.count == 2 && types.allSatisfy { $0["CFBundleTypeRole"] as? String == "Editor"
                     && $0["LSHandlerRank"] as? String == "Alternate" },
                     "Finder advertises alternate editors without claiming default associations")
    }
}
