// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// A preview exports a copy, never moves or removes its source recording.
enum RecorderFileCopy {
    static func save(from source: URL, to destination: URL, replacing: Bool) throws {
        let manager = FileManager.default
        let source = source.resolvingSymlinksInPath().standardizedFileURL
        guard RecentCaptureStore.isRegularFile(source) else { throw CocoaError(.fileReadNoSuchFile) }
        let target = destination.resolvingSymlinksInPath().standardizedFileURL
        let sourceID = try source.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier as? NSObject
        let targetID = try? target.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier as? NSObject
        if source == target || (sourceID != nil && sourceID == targetID) { return }
        let staged = RecorderSupport.stagingURL(for: destination)
        defer { try? manager.removeItem(at: staged) }
        try manager.copyItem(at: source, to: staged)
        if replacing {
            guard RecorderSupport.commitExport(from: staged, to: destination) else {
                throw CocoaError(.fileWriteUnknown)
            }
        } else {
            try manager.moveItem(at: staged, to: destination)
        }
    }
}
