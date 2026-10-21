// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum RecorderFileCopyTests {
    static func run(_ suite: TestSuite) {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("RecorderCopy-\(UUID())")
        do {
            try manager.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? manager.removeItem(at: root) }
            let source = root.appendingPathComponent("original.mov")
            let destination = root.appendingPathComponent("saved.mov")
            let original = Data("original movie".utf8), previous = Data("previous movie".utf8)
            try original.write(to: source)
            try RecorderFileCopy.save(from: source, to: source, replacing: true)
            suite.expect(try Data(contentsOf: source) == original, "saving over the source preserves the movie")
            let alias = root.appendingPathComponent("alias.mov")
            try manager.createSymbolicLink(at: alias, withDestinationURL: source)
            try RecorderFileCopy.save(from: source, to: alias, replacing: true)
            suite.expect(try Data(contentsOf: source) == original, "saving through a source alias preserves the movie")
            let hardLink = root.appendingPathComponent("hard-link.mov")
            try manager.linkItem(at: source, to: hardLink)
            try RecorderFileCopy.save(from: source, to: hardLink, replacing: true)
            suite.expect(try Data(contentsOf: source) == original, "saving through a hard link preserves the source movie")
            try previous.write(to: destination)
            do {
                try RecorderFileCopy.save(from: source, to: destination, replacing: false)
                suite.expect(false, "ordinary Save never overwrites an existing destination")
            } catch {
                suite.expect(try Data(contentsOf: destination) == previous, "a Save collision preserves the destination")
            }
            do {
                try RecorderFileCopy.save(from: root.appendingPathComponent("missing.mov"), to: destination, replacing: true)
                suite.expect(false, "a missing source fails explicitly")
            } catch {
                suite.expect(try Data(contentsOf: destination) == previous, "failed copying never removes the existing movie")
            }
            try RecorderFileCopy.save(from: source, to: destination, replacing: true)
            suite.expect(try Data(contentsOf: destination) == original, "confirmed replacement publishes the completed copy")
            suite.expect(try manager.contentsOfDirectory(atPath: root.path).count == 4,
                         "successful and failed exports leave no staged movies")
        } catch { suite.expect(false, "recording copy fixture failed: \(error)") }
    }
}
