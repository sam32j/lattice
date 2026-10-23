import AppKit

enum MediaHUDModelTests {
    static func run(_ suite: TestSuite) {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent("com.vorssaint.tests.hud-\(UUID())")
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: false)
            defer { try? fm.removeItem(at: folder) }
            let photo = folder.appendingPathComponent("photo.jpg")
            try Data(repeating: 1, count: 500).write(to: photo)
            let service = MediaService(makeClient: { MediaOptimizerClient(optimize: { _, _, directory in
                let output = directory.appendingPathComponent("small.jpg")
                try Data(repeating: 1, count: 100).write(to: output); return output
            }, cancel: {}) })
            let model = MediaHUDModel(service: service, writable: { _ in false })
            suite.expect(model.receive([photo]) && model.needsDestination,
                         "read-only source folders request a destination before starting")
            suite.expect(service.state == .idle, "a destination request never starts a doomed encoding")
            model.chooseDestination(folder)
            let deadline = Date().addingTimeInterval(5)
            while model.busy && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
            suite.expect(model.outputs.count == 1 && model.outputs[0].lastPathComponent == "photo-optimized.jpg",
                         "choosing a destination resumes quick optimization with a unique copy")
            suite.expect(model.inputs == [photo], "HUD retains original input for future recompression")
            model.selectedIndex = 1
            suite.expect(model.selectedOutput == nil && model.selectedOriginal == nil,
                         "an unavailable batch selection never shows another file's result or original")
            model.selectedIndex = 0
            let unsupported = folder.appendingPathComponent("document.pdf")
            try Data("pdf".utf8).write(to: unsupported)
            suite.expect(!model.receive([photo, unsupported]) && model.error != nil && model.inputs == [photo],
                         "mixed unsupported drops are rejected without losing the previous job")
            suite.expect(MediaOutputFormat.choices(for: [photo]) == [.jpeg, .png, .heic],
                         "still image format bar exposes only supported native image outputs")
            let board = NSPasteboard.withUniqueName()
            defer { board.releaseGlobally() }
            board.writeObjects([photo as NSURL])
            suite.expect(MediaHUDPayload.urls(from: board) == [photo], "native file drops expose the entire supported payload")
            board.clearContents(); board.writeObjects([photo as NSURL, unsupported as NSURL])
            suite.expect(MediaHUDPayload.urls(from: board) == nil, "mixed native drops cannot silently discard unsupported companions")
            suite.expect(MediaHUDLocation.wantsIsland(location: .window, cacheUsesIsland: true, islandAvailable: true) == false,
                         "explicit standalone MO stays standalone even when File Cache uses the island")
            suite.expect(MediaHUDLocation.wantsIsland(location: .island, cacheUsesIsland: false, islandAvailable: true),
                         "MO can independently use the available island Files surface")
            suite.expect(!MediaHUDLocation.wantsIsland(location: .island, cacheUsesIsland: true, islandAvailable: false),
                         "unavailable island routing never strands the optimizer")
            var enabled = true
            let revoked = MediaHUDModel(service: service, writable: { _ in false }, allowed: { enabled })
            _ = revoked.receive([photo])
            let ticket = revoked.dialogTicket
            enabled = false; revoked.cancel(); enabled = true
            revoked.acceptDestination(folder, ticket: ticket)
            suite.expect(service.state == .cancelled, "a pending destination dialog cannot restart work after disable and re-enable")
        } catch { suite.expect(false, "HUD fixture: \(error)") }
    }
}
