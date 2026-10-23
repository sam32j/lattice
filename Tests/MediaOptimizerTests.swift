import Foundation
import UniformTypeIdentifiers

enum MediaOptimizerTests {
    static func run(_ suite: TestSuite) {
        suite.expect(MediaTool.allCases == [.imageCompressor, .videoCompressor], "Media Optimizer exposes only images and videos")
        suite.expect(MediaOptimizerPolicy.accepts(.gif, tool: .imageCompressor), "GIF belongs to images")
        suite.expect(!MediaOptimizerPolicy.accepts(.pdf, tool: .imageCompressor), "documents do not silently rasterize")
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent("com.vorssaint.tests.optimizer-\(UUID())")
        defer { try? fm.removeItem(at: folder) }
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            let original = folder.appendingPathComponent("original.gif")
            try Data("original".utf8).write(to: original)
            let staged = try MediaOptimizerPolicy.stage(original, in: folder)
            try Data("optimized".utf8).write(to: staged.input)
            suite.expect(try Data(contentsOf: original) == Data("original".utf8), "encoder receives a copy, never the original")
            suite.expect((try? MediaOptimizerPolicy.validateOutput(original, in: staged.directory)) == nil,
                         "an encoder response outside the job directory is rejected")
            try MediaOptimizerPolicy.validateOutput(staged.input, in: staged.directory)
            let alias = staged.directory.appendingPathComponent("alias.gif")
            try fm.createSymbolicLink(at: alias, withDestinationURL: staged.input)
            suite.expect((try? MediaOptimizerPolicy.validateOutput(alias, in: staged.directory)) == nil,
                         "an encoder symlink response cannot become a broken published file after staging cleanup")
            try fm.removeItem(at: staged.directory)
            let unavailable = MediaService(makeClient: { MediaOptimizerClient(optimize: { _, _, _ in
                throw NativeMediaError.missingTool("gifsicle")
            }, cancel: {}) })
            unavailable.optimize(inputs: [original], destination: folder, tool: .imageCompressor, aggressive: false)
            wait(unavailable)
            if case .failed(let message) = unavailable.state {
                suite.expect(message.contains("Reinstall Lattice"), "missing bundled encoder has an actionable error")
            } else { suite.expect(false, "missing encoder cannot claim success") }
            let client = MediaOptimizerClient(optimize: { _, _, directory in
                let output = directory.appendingPathComponent("encoded.gif")
                try Data("smaller".utf8).write(to: output); return output
            }, cancel: {})
            let service = MediaService(makeClient: { client })
            service.optimize(inputs: [original], destination: folder, tool: .imageCompressor, aggressive: false)
            let deadline = Date().addingTimeInterval(3)
            while Date() < deadline {
                if case .running = service.state { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
                else { break }
            }
            if case .completed(let result) = service.state {
                suite.expect(result.outputURLs.first?.lastPathComponent == "original-optimized.gif"
                             && result.outputBytes == 7, "encoder response publishes a uniquely named copy with actual size")
                suite.expect(try Data(contentsOf: original) == Data("original".utf8), "service preserves source bytes")
            } else { suite.expect(false, "isolated optimization completes: \(service.state)") }
            let larger = MediaService(makeClient: { MediaOptimizerClient(optimize: { _, _, directory in
                let output = directory.appendingPathComponent("larger.gif")
                try Data(repeating: 0, count: 1000).write(to: output); return output
            }, cancel: {}) })
            larger.optimize(inputs: [original], destination: folder, tool: .imageCompressor, aggressive: false)
            wait(larger)
            if case .completed(let result) = larger.state {
                suite.expect(result.unchangedCount == 1 && result.outputBytes == 8,
                             "an encoding larger than the source keeps original-quality bytes and reports no reduction")
                suite.expect(try Data(contentsOf: result.outputURLs[0]) == Data("original".utf8),
                             "no-savings output is an intact copy with collision-safe naming")
            } else { suite.expect(false, "no-savings result completes") }
            let photo = folder.appendingPathComponent("convert.jpg")
            try Data("source".utf8).write(to: photo)
            let otherFolder = folder.appendingPathComponent("second-folder", isDirectory: true)
            try fm.createDirectory(at: otherFolder, withIntermediateDirectories: false)
            let otherPhoto = otherFolder.appendingPathComponent("convert.jpg")
            try Data("second source".utf8).write(to: otherPhoto)
            let conversion = MediaService(makeClient: {
                MediaOptimizerClient(optimize: client.optimize, cancel: {}, convert: { _, _, _, directory in
                    let output = directory.appendingPathComponent("converted.png")
                    try Data(repeating: 7, count: 100).write(to: output); return output
                })
            })
            conversion.optimize(inputs: [photo, otherPhoto], destination: otherFolder, tool: .imageCompressor,
                                aggressive: false, format: .png, besideOriginals: true)
            wait(conversion)
            if case .completed(let result) = conversion.state {
                suite.expect(result.outputURLs[0].pathExtension == "png" && result.outputBytes == 200,
                             "explicit format conversion honors the chosen format even when larger")
                suite.expect(result.outputURLs[0].deletingLastPathComponent().standardizedFileURL.path == folder.standardizedFileURL.path && result.unchangedCount == 0,
                             "quick conversion saves beside its source and never mislabels an original copy")
                suite.expect(result.outputURLs[1].deletingLastPathComponent().path == otherFolder.path,
                             "a multi-folder quick batch publishes each output beside its own source")
            } else { suite.expect(false, "explicit conversion completes") }
            let second = folder.appendingPathComponent("second.gif")
            try Data("second original".utf8).write(to: second)
            let release = DispatchSemaphore(value: 0)
            let partialClient = MediaOptimizerClient(optimize: { copy, _, directory in
                if copy.lastPathComponent == "second.gif" { _ = release.wait(timeout: .now() + 5) }
                let output = directory.appendingPathComponent("small.gif")
                try Data("small".utf8).write(to: output); return output
            }, cancel: { release.signal() })
            let partial = MediaService(makeClient: { partialClient })
            partial.optimize(inputs: [original, second], destination: folder, tool: .imageCompressor, aggressive: false)
            let partialDeadline = Date().addingTimeInterval(3)
            while partial.completedOutputs.isEmpty && Date() < partialDeadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.01))
            }
            partial.cancel()
            suite.expect(partial.completedOutputs.count == 1 && fm.fileExists(atPath: partial.completedOutputs[0].path),
                         "cancelled batches keep completed output URLs visible and leave their files intact")
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        } catch { suite.expect(false, "isolated original preservation: \(error)") }
    }
    private static func wait(_ service: MediaService) {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if case .running = service.state { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
            else { return }
        }
    }
}
