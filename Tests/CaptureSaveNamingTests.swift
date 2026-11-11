// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum CaptureSaveNamingTests {
    static func run(_ suite: TestSuite) {
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 10,
                                                       hour: 0, minute: 36, second: 31))!
        let expanded = CaptureSaveNaming.expand("%month-%mo-%mi-%%-%foo-%media-%id",
                                                 date: date, media: .screenshot,
                                                 uuid: "1", shortID: "7c3e9a1f", includeCounter: true)
        suite.expect(expanded.template.contains("November-11-36-%-%foo-screenshot-7c3e9a1f"),
                     "longest-match tokens, unknown literals, escaped percent, media, short ID")
        suite.expect(CaptureSaveNaming.counterCount("%%#-%#-%###") == 2,
                     "counter lexer ignores escaped percent and reads runs as one")
        suite.expect(CaptureSaveNaming.counterCount("%#/%#") == 2,
                     "two counter tokens are invalid for a file name")
        let padded = CaptureSaveNaming.preparedName(template: "Shot-%###", date: date,
                                                     media: .screenshot, ext: "png")
        suite.expect(CaptureSaveNaming.proposedName(padded, names: []) == "Shot-001.png",
                     "padded counter starts at one")
        suite.expect(CaptureSaveNaming.proposedName(padded, names: ["Shot-001.png", "Shot-003.PNG", "Shot-002.png"]) == "Shot-004.png",
                     "counter recognizes mixed-case names and all occupied slots")
        suite.expect(CaptureSaveNaming.proposedName(padded, names: ["Shot-001.png", "Shot-003.PNG"]) == "Shot-002.png",
                     "counter fills gaps after deletion")
        suite.expect(CaptureSaveNaming.proposedName(padded, names: [".Shot-001.png.icloud"]) == "Shot-002.png",
                     "iCloud placeholders count as occupied names")
        let collision = CaptureSaveNaming.preparedName(template: "Capture", date: date,
                                                        media: .screenshot, ext: "png")
        suite.expect(CaptureSaveNaming.proposedName(collision, names: ["Capture.png", "Capture 2.PNG"]) == "Capture 3.png",
                     "names without a counter add next free collision suffix")
        suite.expect(CaptureSaveNaming.cleanComponent(" /a:b. ") == "-a-b",
                     "unsafe filename separators and whitespace are sanitized")
        suite.expect(CaptureSaveNaming.subfolders("../2026/%mo//~/", date: date, media: .screenshot) == ["2026", "11"],
                     "subfolder traversal and unsafe components are discarded")
        suite.expect(CaptureSaveNaming.preparedName(template: String(repeating: "é", count: 400),
                     date: date, media: .screenshot, ext: "png").stem.utf8.count <= 231,
                     "byte truncation preserves a valid UTF-8 character boundary")
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("SaveSettings-\(UUID())")
        defer { try? FileManager.default.removeItem(at: base) }
        do {
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            let first = try CaptureSaveNaming.saveData(Data("one".utf8), in: base,
                subfolderTemplate: "%year/%mo", fileNameTemplate: "clip-%##",
                date: date, media: .screenshot, ext: "png")
            let second = try CaptureSaveNaming.saveData(Data("two".utf8), in: base,
                subfolderTemplate: "%year/%mo", fileNameTemplate: "clip-%##",
                date: date, media: .screenshot, ext: "png")
            suite.expect(first.lastPathComponent == "clip-01.png" && second.lastPathComponent == "clip-02.png",
                         "two captures receive unique names in nested folders")
            suite.expect((try? Data(contentsOf: first)) == Data("one".utf8),
                         "later saves never overwrite an earlier capture")
            struct IntentionalFailure: Error {}
            do {
                _ = try CaptureSaveNaming.save(in: base, subfolderTemplate: "", fileNameTemplate: "failed",
                    date: date, media: .screenshot, ext: "png") { _ in throw IntentionalFailure() }
                suite.expect(false, "failing writes must throw")
            } catch {
                suite.expect(!FileManager.default.fileExists(atPath: base.appendingPathComponent("failed.png").path),
                             "write failure removes the exclusive claim")
            }
        } catch {
            suite.expect(false, "save path fixture failed: \(error)")
        }
    }
}
