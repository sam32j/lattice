// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import Foundation

/// One folder for screenshot and recording exports. The bookmark follows a
/// folder when Finder moves or renames it; it never belongs in settings backup.
enum CaptureSaveLocation {
    enum Failure: Error { case notSelected, notWritable }

    static var defaultFolder: URL {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }

    static func resolvedFolder(defaults: UserDefaults = .standard) -> URL? {
        guard let data = defaults.data(forKey: DefaultsKey.captureSaveLocationBookmark),
              !data.isEmpty else { return defaultFolder }
        var stale = false
        guard let url = (try? URL(resolvingBookmarkData: data, options: [.withSecurityScope],
                                  relativeTo: nil, bookmarkDataIsStale: &stale))
            ?? (try? URL(resolvingBookmarkData: data, options: [],
                         relativeTo: nil, bookmarkDataIsStale: &stale)) else { return nil }
        if stale { try? store(url, defaults: defaults) }
        return url
    }

    static func store(_ url: URL, defaults: UserDefaults = .standard) throws {
        let bookmark: Data
        if let scoped = try? url.bookmarkData(options: [.withSecurityScope],
                                               includingResourceValuesForKeys: nil, relativeTo: nil) {
            bookmark = scoped
        } else {
            bookmark = try url.bookmarkData(options: [],
                                            includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        defaults.set(bookmark, forKey: DefaultsKey.captureSaveLocationBookmark)
    }

    static func isWritable(_ url: URL?) -> Bool {
        guard let url else { return false }
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue && FileManager.default.isWritableFile(atPath: url.path)
    }

    /// Resolve before writing, including a recovery picker for a removed or
    /// unmounted folder. Never silently redirect a configured save to Desktop.
    static func withFolder<T>(_ work: (URL) throws -> T) throws -> T {
        var folder = resolvedFolder()
        if let resolved = folder {
            let scoped = resolved.startAccessingSecurityScopedResource()
            defer { if scoped { resolved.stopAccessingSecurityScopedResource() } }
            if isWritable(resolved) { return try work(resolved) }
        }
        folder = try chooseFolderOrThrow()
        guard let folder else { throw Failure.notSelected }
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        guard isWritable(folder) else { throw Failure.notWritable }
        return try work(folder)
    }

    /// AppKit's file panel must run on the main thread. Work queued from an
    /// export background task waits here only when an unavailable bookmark
    /// needs an explicit recovery choice.
    static func presentSaveError(_ error: Error) {
        if let failure = error as? Failure, case .notSelected = failure { return }
        let show = {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = CaptureSaveStrings.localized(L10n.shared.language).saveFailed
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: FeatureStrings.screenshot(L10n.shared.language).done)
            alert.runModal()
        }
        if Thread.isMainThread { show() }
        else { DispatchQueue.main.async(execute: show) }
    }

    static func chooseFolder() -> URL? {
        do { return try chooseFolderOrThrow() }
        catch {
            presentSaveError(error)
            return nil
        }
    }

    private static func chooseFolderOrThrow() throws -> URL {
        if Thread.isMainThread { return try presentPicker() }
        return try DispatchQueue.main.sync { try presentPicker() }
    }

    private static func presentPicker() throws -> URL {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = resolvedFolder() ?? defaultFolder
        guard panel.runModal() == .OK, let chosen = panel.url else { throw Failure.notSelected }
        try store(chosen)
        return chosen
    }
}
