// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum CaptureRetentionTests {
    class State {
        let defaults: UserDefaults
        let store = RecentCaptureStore(directoryURL: nil)
        init(_ defaults: UserDefaults) { self.defaults = defaults }
        func entryExists(_ entry: RecentCaptureEntry) -> Bool { true }
    }
    static func entry(_ kind: RecentCaptureEntry.Kind, _ age: Double) -> RecentCaptureEntry {
        RecentCaptureEntry(id: UUID(), kind: kind, createdAt: Date().addingTimeInterval(-age),
            screenshotName: nil, recordingPath: nil, thumbnailName: nil, scale: nil,
            anchorX: nil, anchorY: nil, anchorWidth: nil, anchorHeight: nil)
    }
    static func run(_ suite: TestSuite) {
        suite.expect(Defaults.registeredDefaults[DefaultsKey.recentRecordingLimit] as? Int == 0,
                     "recording retention defaults to unlimited")
        suite.expect(SettingsBackupSupport.exportKeys().contains(DefaultsKey.recentRecordingLimit),
                     "recording retention travels with portable settings")
        let domain = "vorss.tests.pr3-retention.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(1, forKey: DefaultsKey.cleanerScreenshotAgeDays)
        let service = Service(defaults)
        let oldRecording = entry(.recording, 172800)
        service.store.entries = [oldRecording, entry(.screenshot, 172800), entry(.screenshot, 10)]
        service.pruneMissingEntries()
        suite.expect(service.store.entries.contains(oldRecording),
                     "screenshot age cleanup does not expire recording originals")
        suite.expect(service.store.entries.filter { $0.kind == .screenshot }.count == 1,
                     "screenshot age cleanup still expires old screenshots")
        let recent = (0..<12).map { entry(.recording, Double($0)) }
        let screenshot = entry(.screenshot, 2)
        service.store.entries = recent.reversed() + [screenshot]
        for (limit, expected) in [(5, 5), (10, 10), (0, 12), (-1, 12)] {
            defaults.set(limit, forKey: DefaultsKey.recentRecordingLimit)
            service.store.entries = recent.reversed() + [screenshot]
            service.pruneMissingEntries()
            let movies = service.store.entries.filter { $0.kind == .recording }
            suite.expect(movies == Array(recent.prefix(expected)),
                         "recording limit \(limit) retains the newest \(expected) recordings")
            suite.expect(service.store.entries.contains(screenshot),
                         "recording limit \(limit) does not consume screenshot slots")
        }
        for language in AppLanguage.allCases {
            let labels = CaptureWorkflowStrings.localized(language)
            suite.expect(labels.selectedWindows(1).contains("1") && labels.selectedWindows(12).contains("12"),
                         "selected-window guide formats counts in \(language)")
            suite.expect(FeatureStrings.screenshot(language).hintFullScreen.contains("F")
                         && !FeatureStrings.screenshot(language).hintFullScreen.contains("Return"),
                         "full-screen hint uses F in \(language)")
            suite.expect(!labels.recentRecordings.isEmpty && !labels.unlimited.isEmpty,
                         "recording retention controls are localized in \(language)")
        }
        checkDiskRetention(suite)
    }
    private static func checkDiskRetention(_ suite: TestSuite) {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("CaptureRetention-\(UUID())")
        defer { try? manager.removeItem(at: root) }
        do {
            try manager.createDirectory(at: root, withIntermediateDirectories: true)
            let owned = root.appendingPathComponent("history")
            let store = RecentCaptureStore(directoryURL: owned)
            suite.expect(store.loadIfNeeded(), "retention fixture creates a readable store")
            var entries: [RecentCaptureEntry] = []
            for index in 0..<12 {
                let id = UUID()
                let path = "\(id.uuidString).mov"
                try Data([UInt8(index)]).write(to: owned.appendingPathComponent(path))
                entries.append(RecentCaptureEntry(id: id, kind: .recording,
                    createdAt: Date(timeIntervalSince1970: Double(100 - index)), screenshotName: nil,
                    recordingPath: path, thumbnailName: nil, scale: nil,
                    anchorX: nil, anchorY: nil, anchorWidth: nil, anchorHeight: nil))
            }
            let exported = root.appendingPathComponent("export.mov")
            let bytes = Data("external export".utf8)
            try bytes.write(to: exported)
            entries.append(RecentCaptureEntry(id: UUID(), kind: .recording,
                createdAt: Date(timeIntervalSince1970: 0), screenshotName: nil,
                recordingPath: exported.path, thumbnailName: nil, scale: nil,
                anchorX: nil, anchorY: nil, anchorWidth: nil, anchorHeight: nil))
            store.entries = entries
            suite.expect(store.persist(), "retention fixture commits all recording entries")
            store.entries = RecentCaptureRetention.entries(store.entries, screenshotCutoff: nil, recordingLimit: 5)
            suite.expect(store.persist(), "a recording cap commits before cleaning unreferenced copies")
            suite.expect(entries.prefix(5).allSatisfy {
                manager.fileExists(atPath: owned.appendingPathComponent($0.recordingPath!).path)
            } && entries.dropFirst(5).dropLast().allSatisfy {
                !manager.fileExists(atPath: owned.appendingPathComponent($0.recordingPath!).path)
            }, "retention removes old owned movies and keeps the five newest copies")
            suite.expect((try? Data(contentsOf: exported)) == bytes,
                         "removing an external export from history never deletes or changes its file")
        } catch {
            suite.expect(false, "recording retention disk fixture: \(error)")
        }
    }

}
