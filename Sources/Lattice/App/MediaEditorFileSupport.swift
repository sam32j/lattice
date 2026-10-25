// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import UniformTypeIdentifiers

/// Shared contract for Finder, the menu bar and Island file drops.
enum MediaEditorFileSupport {
    enum Kind: Equatable { case image, video }

    static func kind(for type: UTType?) -> Kind? {
        guard let type else { return nil }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        return nil
    }

    static func kind(for url: URL) -> Kind? {
        guard url.isFileURL,
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentTypeKey]),
              values.isRegularFile == true else { return nil }
        return kind(for: values.contentType ?? UTType(filenameExtension: url.pathExtension))
    }

    static func isEnabled(_ kind: Kind, image: Bool, video: Bool) -> Bool {
        kind == .image ? image : video
    }

    /// Revalidate at desktop landing, not only before an asynchronous import.
    @discardableResult
    static func presentIfEnabled(_ enabled: Bool, present: () -> Bool, discard: () -> Void = {}) -> Bool {
        guard enabled, present() else { discard(); return false }
        return true
    }

    static func urls(from pasteboard: NSPasteboard) -> [URL] {
        guard !pasteboard.canReadObject(forClasses: [NSFilePromiseReceiver.self], options: nil) else { return [] }
        let urls = (pasteboard.readObjects(forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        guard urls.count >= (pasteboard.pasteboardItems?.count ?? 0) else { return [] }
        return urls
    }
}
