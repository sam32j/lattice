// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox
import Combine
import CoreAudio
import CoreGraphics
import Darwin
import Foundation
import ImageIO
import VMStatisticsCompat

enum RepositoryFeatureTests {
    /// Run the production `result` and `copy` of the manual cleaner in the
    /// menu panel, with a cleaner whose rules the test changes, recording
    /// what reaches the clipboard.
    final class URLCleanerManualCleaner {
        var rules = URLCleaning.Rules.builtIn
        var copied: [String] = []
        func clean(_ text: String) -> URLCleaning.Result? { URLCleaning.clean(text, rules: rules) }
        var recorded: [String] = []
        func copy(_ urlString: String) { copied.append(urlString) }
        func record(original: String, result: URLCleaning.Result) {
            if !result.removals.isEmpty { recorded.append(original) }
        }
    }
    protocol URLCleanerManualSurface: AnyObject {
        var cleaner: URLCleanerManualCleaner { get }
        var input: String { get set }
        func copy()
    }
    final class URLCleanerManualPanel: URLCleanerManualSurface {
        let cleaner = URLCleanerManualCleaner()
        var input = ""
        var copied: String?
        var storedSites = ""
    }

    private struct SourceRead: Sendable {
        let path: String
        let source: String?
        let lines: [String]
        let error: String?
    }

    private final class SourceReadCollector: @unchecked Sendable {
        private let lock = NSLock()
        private var reads: [SourceRead] = []

        func append(contentsOf batch: [SourceRead]) {
            lock.withLock { reads.append(contentsOf: batch) }
        }

        func sortedReads() -> [SourceRead] {
            lock.withLock { reads.sorted { $0.path < $1.path } }
        }
    }

    /// Runs the production `pollPasteboard` against a pasteboard the test
    /// fills, recording what would be written back.
    enum URLCleanerPollHost {
        typealias Kind = AppKit.NSPasteboard.PasteboardType
        final class Pasteboard {
            static let general = Pasteboard()
            var changeCount = 1
            var types: [Kind]? = []
            var items = 1
            var text = ""
            var html = ""
            var copiedDuringRead = false
            var source: String?
            var onRead: ((Kind) -> Void)?
            var metadata: Data?
            var pasteboardItems: [Int]? { Array(repeating: 0, count: items) }
            func string(forType type: Kind) -> String? {
                if copiedDuringRead { changeCount += 1 }
                onRead?(type)
                return type == .string ? text : type == .html ? html : type == .source ? source : nil
            }
            func data(forType type: Kind) -> Data? {
                onRead?(type)
                return metadata
            }
        }
        typealias NSPasteboard = Pasteboard
        final class PollToken { var isCancelled = false }
        struct PollResult {
            let changeCount: Int
            let cleaned: URLCleaning.Result?
            var original: String? = nil
        }
        static let urlType = Kind(rawValue: "public.url")
        static var rules: URLCleaning.Rules { .builtIn }
        static var written: [String] = []
        static var writtenSources: [String?] = []
        static var writtenRemote: [Bool] = []
        static var writtenMarkers: [[String]] = []
        static func writeToPasteboard(_ urlString: String, source: String? = nil, remote: Bool = false,
                                     linkMetadata: Data? = nil, markers: [String] = []) -> Int {
            writtenMarkers.append(markers)
            written.append(urlString)
            writtenSources.append(source)
            writtenRemote.append(remote)
            return 0
        }
    }

    private struct RepositorySnapshot {
        let swiftPaths: [String]
        let swiftSources: [String: String]
        let swiftLines: [String: [String]]
        let enumerationError: String?
        let readTimedOut: Bool
        let unreadablePaths: [String]
        let emptyPaths: [String]

        init(fileManager: FileManager = .default) {
            let paths: [String]
            var traversalError: String?
            do {
                paths = Array(Set(try fileManager.subpathsOfDirectory(atPath: "Sources")
                    .filter { $0.hasSuffix(".swift") }
                    .map { "Sources/" + $0 })).sorted()
            } catch {
                paths = []
                traversalError = String(describing: error)
            }

            let workerCount = min(paths.count, max(1, min(8, ProcessInfo.processInfo.activeProcessorCount)))
            let collector = SourceReadCollector()
            let queue = OperationQueue()
            queue.name = "RepositorySnapshot.SourceReads"
            queue.qualityOfService = .userInitiated
            queue.maxConcurrentOperationCount = max(1, workerCount)
            let readGroup = DispatchGroup()
            let operations: [Operation] = (0..<workerCount).map { workerIndex in
                readGroup.enter()
                return BlockOperation {
                    defer { readGroup.leave() }
                    var batch: [SourceRead] = []
                    batch.reserveCapacity((paths.count + workerCount - 1) / workerCount)
                    for index in stride(from: workerIndex, to: paths.count, by: workerCount) {
                        let path = paths[index]
                        do {
                            let source = try String(contentsOfFile: path, encoding: .utf8)
                            batch.append(SourceRead(path: path, source: source,
                                                   lines: source.components(separatedBy: "\n"),
                                                   error: nil))
                        } catch {
                            batch.append(SourceRead(path: path, source: nil, lines: [],
                                                   error: String(describing: error)))
                        }
                    }
                    collector.append(contentsOf: batch)
                }
            }
            queue.addOperations(operations, waitUntilFinished: false)
            let timedOut = readGroup.wait(timeout: .now() + 15) == .timedOut
            if timedOut { queue.cancelAllOperations() }

            let reads = collector.sortedReads()
            let sources = Dictionary(uniqueKeysWithValues: reads.compactMap { read in
                read.source.map { (read.path, $0) }
            })
            let lines = Dictionary(uniqueKeysWithValues: reads.compactMap { read in
                read.source.map { _ in (read.path, read.lines) }
            })

            swiftPaths = paths
            swiftSources = sources
            swiftLines = lines
            enumerationError = traversalError
            readTimedOut = timedOut
            unreadablePaths = reads.compactMap { read in
                read.error.map { "\(read.path): \($0)" }
            }
            emptyPaths = reads.compactMap { read in
                guard let source = read.source,
                      source.rangeOfCharacter(from: .whitespacesAndNewlines.inverted) == nil else { return nil }
                return read.path
            }
        }

        func source(at path: String) -> String {
            swiftSources[path] ?? ""
        }

        func moduleSource(at path: String) -> String {
            let prefix = String(path.dropLast(6)) + "+"
            return ([path] + swiftPaths.filter { $0.hasPrefix(prefix) }.sorted())
                .compactMap { swiftSources[$0] }.joined(separator: "\n")
        }

        func lines(at path: String) -> [String] {
            swiftLines[path] ?? []
        }
    }

    static func run(_ suite: TestSuite) {
        func expectEqual(_ actual: String, _ expected: String, _ label: String,
                         file: StaticString = #filePath, line: UInt = #line) {
            suite.expect(actual == expected, "\(label): got \(actual), expected \(expected)",
                         file: file, line: line)
        }
        let repository = RepositorySnapshot()
        suite.expect(repository.enumerationError == nil,
               "the Swift source corpus is enumerable: \(repository.enumerationError ?? "")")
        suite.expect(!repository.swiftPaths.isEmpty,
               "the Swift source corpus contains files")
        suite.expect(!repository.readTimedOut,
               "the Swift source corpus finishes reading inside its bounded deadline")
        suite.expect(repository.unreadablePaths.isEmpty,
               "every Swift source is readable: \(repository.unreadablePaths)")
        suite.expect(repository.emptyPaths.isEmpty,
               "no Swift source is empty: \(repository.emptyPaths)")
        let requiredSourcePaths = [
            "Sources/Lattice/Services/CommandBar/CommandBarSupport.swift",
            "Sources/Lattice/Services/Homebrew/HomebrewManager.swift",
            "Sources/Lattice/Services/Metrics/DiskSampler.swift",
            "Sources/Lattice/Services/QuickTools/RecentCaptureService.swift",
            "Sources/Lattice/Services/QuickTools/RecentCaptureStore.swift",
            "Sources/Lattice/Services/SelfUninstall.swift",
            "Sources/Lattice/Services/Shelf/ShelfService.swift",
            "Sources/Lattice/Services/URLCleanerService.swift",
            "Sources/Lattice/Support/Uninstaller.swift",
            "Sources/Lattice/UI/MenuPanel/PanelURLCleanerView.swift",
            "Sources/Lattice/UI/Settings/URLSanitizerSettings.swift",
            "Sources/Lattice/UI/Theme.swift",
        ]
        let missingSourcePaths = requiredSourcePaths.filter {
            repository.swiftSources[$0] == nil
        }
        suite.expect(missingSourcePaths.isEmpty,
               "every directly inspected Swift source is present: \(missingSourcePaths)")
        let buildScript = (try? String(contentsOfFile: "build.sh", encoding: .utf8)) ?? ""
        suite.expect(!buildScript.isEmpty, "build.sh is readable for repository contracts")

        // MARK: URL cleaning

        expectEqual(URLCleaning.clean("https://example.com/path?utm_source=news&id=42&fbclid=abc")?.url ?? "",
                    "https://example.com/path?id=42",
                    "URL cleaner removes tracking and preserves useful query")
        expectEqual(URLCleaning.clean(" https://example.com/?GCLID=one&utm_campaign=x#section ")?.url ?? "",
                    "https://example.com/#section",
                    "URL cleaner is case-insensitive and preserves fragments")
        expectEqual(URLCleaning.clean("https://example.com/?id=42")?.url ?? "",
                    "https://example.com/?id=42",
                    "URL cleaner leaves clean URLs alone")
        // A grouped Form keeps a label column even for an empty label, which
        // left every field on the right half of its row. The hint has to
        // travel as `prompt:` and the label has to be hidden for a field to
        // own its whole row.
        for path in ["Sources/Lattice/UI/Settings/URLSanitizerSettings.swift",
                     "Sources/Lattice/UI/Settings/URLSanitizerTestCard.swift",
                     "Sources/Lattice/UI/Settings/URLSanitizerSiteSheet.swift"] {
            let lines = repository.lines(at: path)
            let fields = lines.indices.filter { lines[$0].contains("TextField(") }
            let labelled = fields.filter { start in
                !lines[start..<min(start + 8, lines.count)].contains { $0.contains(".labelsHidden()") }
                    || !lines[start].contains("prompt:") && !lines[start + 1].contains("prompt:")
            }
            suite.expect(!fields.isEmpty && labelled.isEmpty && !lines.contains { $0.contains("TextField(l10n.s.") },
                         "every URL Sanitizer field hides its label and carries its hint as a prompt: \(path) \(labelled)")
        }

        // The manual result is worked out from the field, so editing the link
        // or the rules can never leave an older result for Copy to take.
        let panelHost = URLCleanerManualPanel()
        panelHost.input = "https://youtu.be/abc?si=x"
        panelHost.copy()
        panelHost.input = "https://example.com/?utm_source=a&keep=1"
        panelHost.copy()
        var keepRules = URLCleaning.Rules.builtIn.sites
        keepRules[0].tokens.append(URLCleaning.Token(name: "keep", isCustom: true))
        panelHost.cleaner.rules = URLCleaning.Rules(sites: keepRules)
        panelHost.copy()
        suite.expect(panelHost.cleaner.copied == ["https://youtu.be/abc", "https://example.com/?keep=1",
                                                  "https://example.com/"],
                     "menu panel Copy takes the field's link under the current rules: \(panelHost.cleaner.copied)")
        suite.expect(panelHost.cleaner.recorded == ["https://youtu.be/abc?si=x", "https://example.com/?utm_source=a&keep=1",
                                                    "https://example.com/?utm_source=a&keep=1"],
                     "menu panel Copy adds what it cleaned to Recently cleaned: \(panelHost.cleaner.recorded)")
        // The result reads the stored rules through the service, so each
        // surface has to observe every key they come from and read it where
        // the body works the result out. SwiftUI only redraws for a stored
        // value the last render read, so a rule changed in Settings beside
        // the open menu panel would leave the panel showing a link Copy no
        // longer takes.
        func memberText(_ lines: [String], _ prefix: String) -> String {
            lines.firstIndex { $0.hasPrefix(prefix) }.map { start in
                lines[start...].prefix { $0 != "    }" }.joined(separator: "\n")
            } ?? ""
        }
        let storedRules = memberText(repository.lines(at: "Sources/Lattice/Services/URLCleanerService.swift"),
                                     "    private static var rules: URLCleaning.Rules {")
        let ruleKeys = storedRules.components(separatedBy: "DefaultsKey.").dropFirst()
            .map { rest in String(rest.prefix { $0.isLetter || $0.isNumber }) }
        for (surface, path) in [("Settings", "Sources/Lattice/UI/Settings/URLSanitizerSettings.swift"),
                                ("menu panel", "Sources/Lattice/UI/MenuPanel/PanelURLCleanerView.swift")] {
            let lines = repository.lines(at: path)
            let reads = memberText(lines, "    private var result:") + "\n" + memberText(lines, "    private var rules:")
            let unobserved = ruleKeys.filter { key in
                guard let declaration = lines.first(where: { $0.contains("@AppStorage(DefaultsKey.\(key)) private var ") }),
                      let name = declaration.components(separatedBy: "private var ").last?
                        .prefix(while: { $0.isLetter || $0.isNumber }),
                      !name.isEmpty else { return true }
                // A value read, not an argument label of the same name.
                return reads.range(of: "(?<![\\w.])\(name)(?![\\w:])", options: .regularExpression) == nil
            }
            suite.expect(!ruleKeys.isEmpty && unobserved.isEmpty,
                   "\(surface) redraws its result when a rule changes: \(ruleKeys), unobserved \(unobserved)")
        }
        // Recently cleaned holds whole URLs: memory only, never logged.
        let cleanerSource = repository.source(at: "Sources/Lattice/Services/URLCleanerService.swift")
        suite.expect(!cleanerSource.isEmpty
                        && ["print(", "NSLog", "os_log", "Logger", "debugPrint", ".set("]
                            .allSatisfy { !cleanerSource.contains($0) },
                     "the URL Sanitizer service neither logs nor stores the links it cleans")

        suite.expect([DefaultsKey.urlSanitizerSites, DefaultsKey.urlSanitizerAutoRemove].allSatisfy {
                    Defaults.registeredDefaults[$0] != nil && SettingsBackupSupport.exportKeys().contains($0)
                } && Defaults.registeredDefaults[DefaultsKey.urlSanitizerSites] as? String == "",
               "URL Sanitizer rules start as the built-ins and travel in Settings backups")
        suite.expect(URLCleaning.clean("https://example.com/?utm_source=a&fbclid=b&id=1")?.removed
                == ["utm_source", "fbclid"],
               "cleaning answers with the names it took out, in the order the link carried them")
        suite.expect(URLCleaning.outcome(for: nil, input: "nope") == .notAURL,
               "text that is not a link reads as no URL")
        let paddedLink = " https://example.com/?id=1 "
        suite.expect(URLCleaning.outcome(for: URLCleaning.clean(paddedLink), input: paddedLink) == .unchanged,
               "trimming alone does not count as a clean")
        expectEqual(URLCleaning.clean("https://www.xiaohongshu.com/?shareRedId=a&exSource=b&id=1")?.url ?? "",
                    "https://www.xiaohongshu.com/?id=1",
                    "a built-in name spelled in mixed case by the site is still removed")
        suite.expect(URLCleaning.clean("not a url") == nil,
               "URL cleaner rejects plain text")
        expectEqual(URLCleaning.clean("https://www.bilibili.com/video/BV1TY8J67EUB/?spm_id_from=333.1007.tianma.1-1-1.click&vd_source=3b2eea5")?.url ?? "",
                    "https://www.bilibili.com/video/BV1TY8J67EUB/",
                    "URL cleaner strips Bilibili share tracking")
        expectEqual(URLCleaning.clean("https://www.bilibili.com/video/BV1xx411c7mD/?p=3&t=90&vd_source=abc")?.url ?? "",
                    "https://www.bilibili.com/video/BV1xx411c7mD/?p=3&t=90",
                    "URL cleaner keeps the Bilibili part number and playback position")
        expectEqual(URLCleaning.clean("https://search.bilibili.com/all?keyword=swift&from_source=webtop_search")?.url ?? "",
                    "https://search.bilibili.com/all?keyword=swift",
                    "URL cleaner keeps the Bilibili search keyword")
        expectEqual(URLCleaning.clean("https://youtu.be/TImSMeurR84?si=Xq1&t=42")?.url ?? "",
                    "https://youtu.be/TImSMeurR84?t=42",
                    "URL cleaner strips the YouTube share token and keeps the timestamp")
        expectEqual(URLCleaning.clean("https://www.youtube.com/watch?v=TImSMeurR84")?.url ?? "",
                    "https://www.youtube.com/watch?v=TImSMeurR84",
                    "URL cleaner leaves a bare YouTube watch link alone")
        expectEqual(URLCleaning.clean("https://x.com/user/status/1?s=20&t=abc")?.url ?? "",
                    "https://x.com/user/status/1",
                    "URL cleaner strips X share tracking")
        expectEqual(URLCleaning.clean("https://example.com/?si=keep&t=keep&s=keep")?.url ?? "",
                    "https://example.com/?si=keep&t=keep&s=keep",
                    "site rules never leak onto other hosts")
        expectEqual(URLCleaning.clean("https://open.spotify.com/track/abc?si=xyz")?.url ?? "",
                    "https://open.spotify.com/track/abc",
                    "site rules match subdomains")
        expectEqual(URLCleaning.clean("https://www.reddit.com/r/swift/comments/abc/?%24deep_link=true&%243p=x&share_id=y&sort=new")?.url ?? "",
                    "https://www.reddit.com/r/swift/comments/abc/?sort=new",
                    "URL cleaner strips Reddit's deep-link tracking in either spelling")

        // MARK: URL cleaning is a pure deletion

        // Cleaning a link is only allowed to take parameters out of it. The
        // query is therefore filtered while it is still percent-encoded and
        // the survivors are put back byte for byte. Decoding them and writing
        // them back through `queryItems` re-encodes with a much wider allowed
        // set, so the cleaner respells a value it was never asked to touch —
        // and on a link with nothing to remove it respells the whole query
        // and then reports a clean.
        let wrappedLink = "https://example.com/?redirect=https%3A%2F%2Fexample.org%2F%3Futm_source%3Dkeepme%26z%3D9&gclid=1"
        let wrappedClean = URLCleaning.clean(wrappedLink)
        expectEqual(wrappedClean?.url ?? "",
                    "https://example.com/?redirect=https%3A%2F%2Fexample.org%2F%3Futm_source%3Dkeepme%26z%3D9",
                    "cleaning a wrapper link takes the tracker out and leaves the wrapped target encoded")
        suite.expect(wrappedClean?.removed == ["gclid"],
               "a wrapper link reports only the tracker it really removed")
        // A link with nothing to remove must come back identical, or the
        // clipboard poll replaces the user's copy with a different, wrong one
        // and the UI calls it a clean.
        let nothingToRemove = "https://example.com/url?q=https%3A%2F%2Fexample.com%2Fpage%3Fa%3D1%26utm_source%3Dnews&sa=U"
        suite.expect(URLCleaning.clean(nothingToRemove)?.url == nothingToRemove
               && URLCleaning.outcome(for: URLCleaning.clean(nothingToRemove), input: nothingToRemove) == .unchanged,
               "a link with no tracked parameter is returned byte for byte and reads as unchanged")
        for untouched in [
            "https://example.com/",
            "https://example.com/?",
            "https://example.com/path?a=1&a=2",
            "https://example.com/?q=a+b&r=%5B%5D&s=%20x",
            "https://user:pw@example.com:8443/p?id=1",
            "https://[::1]:8443/p?id=1",
        ] {
            suite.expect(URLCleaning.clean(untouched)?.url == untouched,
                   "a link with no tracked parameter is never re-encoded, reordered or normalised: \(untouched)")
        }
        expectEqual(URLCleaning.clean("https://example.com/?flag&utm_medium&utm_source=news&id=1")?.url ?? "",
                    "https://example.com/?flag&id=1",
                    "a pair with no equals sign is judged by its whole text and a valueless tracker still goes")
        expectEqual(URLCleaning.clean("https://example.com/?%75tm_source=news&id=1")?.url ?? "",
                    "https://example.com/?id=1",
                    "a tracker name spelled percent-encoded is decoded before it is matched")
        suite.expect(URLCleaning.clean("https://example.com/?utm_source=a&fbclid=b&utm_source=c")?.removed
                == ["utm_source", "fbclid"],
               "a name repeated in one link is still reported once")

        let unicodeURL = "https://éxample.com/cafe\u{0301}?x=%2f&q=é#re\u{0301}sume\u{0301}"
        let unchangedUnicode = URLCleaning.clean(unicodeURL)
        suite.expect(unchangedUnicode?.url.utf8.elementsEqual(unicodeURL.utf8) == true
               && unchangedUnicode?.removed.isEmpty == true,
               "a no-op preserves Unicode spelling and existing escapes byte for byte")
        let preservedURLCases = [
            ("https://example.com/p?x=%2f&q=é&utm_source=x", "https://example.com/p?x=%2f&q=é"),
            ("https://éxample.com/cafe\u{0301}?x=%2f&utm_source=x#re\u{0301}sume\u{0301}",
             "https://éxample.com/cafe\u{0301}?x=%2f#re\u{0301}sume\u{0301}"),
            ("https://example.com/p?utm_source=x&\u{0301}id=1", "https://example.com/p?\u{0301}id=1"),
            ("https://example.com/p?fbclid=\u{0301}x&id=1", "https://example.com/p?id=1"),
            ("https://example.com/p?\u{0301}id=1&utm_source=x", "https://example.com/p?\u{0301}id=1"),
            ("https://example.com/p?utm_source=x#\u{0301}keep?utm_medium=y", "https://example.com/p#\u{0301}keep?utm_medium=y"),
            ("https://example.com/p?utm_source=x#", "https://example.com/p#"),
            ("https://example.com/p?utm_source=x&", "https://example.com/p?"),
            ("https://example.com/p?&utm_source=x&&id=%26%3D%3F%23", "https://example.com/p?&&id=%26%3D%3F%23"),
            ("https://example.com/p#fragment?utm_source=x", "https://example.com/p#fragment?utm_source=x"),
        ]
        for (input, expected) in preservedURLCases {
            suite.expect(URLCleaning.clean(input)?.url.utf8.elementsEqual(expected.utf8) == true,
                   "cleaning preserves every surviving byte, including delimiters beside combining marks: \(input)")
        }
        for separator in ["\n", "\r\n", "\t", " ", "\u{00A0}"] {
            suite.expect(URLCleaning.clean("https://a.example/x?utm_source=x\(separator)https://b.example/y") == nil,
                   "automatic URL cleaning cannot discard a second link from a separated text copy")
        }

        suite.expect(URLCleaning.canRewritePasteboard(types: [
            "public.utf8-plain-text", "public.url", "public.url-name",
            "NSStringPboardType", "NSURLPboardType",
        ]), "a plain link copy can be rewritten")
        suite.expect(!URLCleaning.canRewritePasteboard(types: []),
               "an empty pasteboard is left alone")
        suite.expect(URLCleaning.canRewritePasteboard(types: [
            "public.utf8-plain-text", "public.html", "public.rtf", "com.apple.flat-rtfd",
            "public.utf16-external-plain-text",
        ]), "formatted copies of the same link are dropped by the rewrite, not protected")
        suite.expect(URLCleaning.canRewritePasteboard(types: [
            "public.utf8-plain-text", "public.url", "org.chromium.source-url",
            "org.chromium.web-custom-data", "com.apple.WebKit.custom-pasteboard-data",
            "dyn.ah62d4rv4gu8y6y4grf0gn5xbrzw1gydcr7u1e3cytf2gn",
        ]), "a browser's or a messaging app's private notes about the copy do not block the rewrite")
        suite.expect(URLCleaning.canRewritePasteboard(types: [
            "public.utf8-plain-text", "public.url", "com.apple.linkpresentation.metadata",
        ]), "Safari's rich-link metadata can be rewritten with the link")
        suite.expect(!URLCleaning.canRewritePasteboard(types: [
            "public.utf8-plain-text", "public.url", "public.tiff", "public.png",
        ]), "a copied picture with its source link as text is left alone")
        suite.expect(!URLCleaning.canRewritePasteboard(types: [
            "public.utf8-plain-text", "public.file-url", "NSFilenamesPboardType",
        ]) && !URLCleaning.canRewritePasteboard(types: [
            "public.utf8-plain-text", "NSFilenamesPboardType",
        ]) && !URLCleaning.canRewritePasteboard(types: [
            "public.utf8-plain-text", "com.apple.pasteboard.promised-file-url",
            "com.apple.pasteboard.promised-file-content-type",
        ]), "a copied or promised file is left alone")
        suite.expect(!URLCleaning.canRewritePasteboard(types: [
            "public.utf8-plain-text", "com.adobe.pdf",
        ]) && !URLCleaning.canRewritePasteboard(types: [
            "public.utf8-plain-text", "public.mpeg-4",
        ]) && !URLCleaning.canRewritePasteboard(types: [
            "public.utf8-plain-text", "com.apple.webarchive",
        ]), "a document, a movie or a web archive next to the text is left alone")
        suite.expect(!URLCleaning.canRewritePasteboard(types: [
            "public.utf8-plain-text", "org.nspasteboard.ConcealedType",
        ]) && !URLCleaning.canRewritePasteboard(types: [
            "public.utf8-plain-text", "org.nspasteboard.TransientType",
        ]), "a concealed or transient copy is never rewritten")

        // Automatic cleaning replaces the whole copy, so it only does so when
        // the copy is this one link and is still on the pasteboard.
        let pollLink = "https://x.com/a/status/1?s=20&t=x"
        let chromiumTypes = ["public.html", "Apple HTML pasteboard type", "public.utf8-plain-text",
                             "NSStringPboardType", "org.chromium.internal.source-rfh-token",
                             "org.chromium.source-url"]
        for (types, items, html, copiedDuringRead, expected, copy) in [
            (["public.utf8-plain-text"], 1, "", false, true, "a plain link"),
            (["public.utf8-plain-text"], 2, "", false, false, "two copied items"),
            (["public.utf8-plain-text"], 1, "", true, false, "a link another app replaced during the read"),
            (chromiumTypes, 1, "<meta charset='utf-8'><a href=\"\(pollLink.replacingOccurrences(of: "&", with: "&amp;"))\">"
                + "\(pollLink)</a>", false, true, "a Chromium app's link copy (#1643)"),
            (chromiumTypes, 1, "<meta charset='utf-8'><img src=\"\(pollLink)\">", false, false,
             "a picture's markup with its address as the text"),
            (chromiumTypes, 1, "<a href=\"\(pollLink)\">A post</a>", false, true, "a link under a title"),
            (chromiumTypes, 1, "<a href=\"https://example.com/\">\(pollLink)</a>", false, false,
             "a link pointing somewhere else"),
        ] {
            let pasteboard = URLCleanerPollHost.Pasteboard.general
            pasteboard.types = types.map(URLCleanerPollHost.Kind.init(rawValue:))
            pasteboard.items = items
            pasteboard.text = pollLink
            pasteboard.html = html
            pasteboard.copiedDuringRead = copiedDuringRead
            URLCleanerPollHost.written = []
            _ = URLCleanerPollHost.pollPasteboard(sinceChangeCount: 0, token: URLCleanerPollHost.PollToken())
            suite.expect(URLCleanerPollHost.written == (expected ? ["https://x.com/a/status/1"] : []),
                   "automatic cleaning \(expected ? "rewrites" : "leaves alone") \(copy): \(URLCleanerPollHost.written)")
        }
        // The app a copy names as its source stays named after the rewrite,
        // so the clipboard history does not credit the link to the app in front.
        do {
            let pasteboard = URLCleanerPollHost.Pasteboard.general
            pasteboard.types = ["public.utf8-plain-text", "org.nspasteboard.source"].map(URLCleanerPollHost.Kind.init(rawValue:))
            pasteboard.items = 1
            pasteboard.text = pollLink
            pasteboard.html = ""
            pasteboard.copiedDuringRead = false
            pasteboard.source = "com.example.writer"
            URLCleanerPollHost.written = []
            URLCleanerPollHost.writtenSources = []
            URLCleanerPollHost.writtenRemote = []
            _ = URLCleanerPollHost.pollPasteboard(sinceChangeCount: 0, token: URLCleanerPollHost.PollToken())
            pasteboard.source = nil
            suite.expect(URLCleanerPollHost.written == ["https://x.com/a/status/1"]
                    && URLCleanerPollHost.writtenSources == ["com.example.writer"]
                    && URLCleanerPollHost.writtenRemote == [false],
                   "automatic cleaning keeps the source a copy names: \(URLCleanerPollHost.writtenSources)")
            pasteboard.types = ["public.utf8-plain-text", "com.apple.is-remote-clipboard"].map(URLCleanerPollHost.Kind.init(rawValue:))
            URLCleanerPollHost.written = []
            URLCleanerPollHost.writtenRemote = []
            _ = URLCleanerPollHost.pollPasteboard(sinceChangeCount: 0, token: URLCleanerPollHost.PollToken())
            suite.expect(URLCleanerPollHost.written == ["https://x.com/a/status/1"] && URLCleanerPollHost.writtenRemote == [true],
                   "automatic cleaning keeps a copy from another device marked as one: \(URLCleanerPollHost.writtenRemote)")
        }

        // A title over the same link, an href the browser resolved and a
        // head or text that is never shown all go with the rewrite. Shown
        // text beyond the link, or far more markup than a link copy needs,
        // stays.
        let escapedPollLink = pollLink.replacingOccurrences(of: "&", with: "&amp;")
        let unicodeLink = "https://example.com/wiki/北京?utm_source=x"
        let titledCopy = "<meta charset='utf-8'><a href=\"\(escapedPollLink)\">Example page title</a>"
        let encodedCopy = "<meta charset='utf-8'><a href=\"https://example.com/wiki/%E5%8C%97%E4%BA%AC?utm_source=x\">"
            + "\(unicodeLink)</a>"
        let documentCopy = "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0//EN\">\n<html><head>"
            + "<meta charset=\"utf-8\" /><title>Untitled</title><style type=\"text/css\">\n"
            + "p, li { white-space: pre-wrap; }\n</style></head><body style=\" font-family:sans-serif;\">\n"
            + "<!--StartFragment-->\(escapedPollLink)<!--EndFragment--></body></html>"
        let linkedDocumentCopy = "<html><head><meta http-equiv=Content-Type content=\"text/html; charset=utf-8\">"
            + "<link rel=File-List href=\"file:///tmp/clip_filelist.xml\"><style>p { margin: 0; }</style></head>"
            + "<body><p><a href=\"\(escapedPollLink)\">\(escapedPollLink)</a></p></body></html>"
        let oversizedCopy = "<meta charset='utf-8'><a href=\"\(escapedPollLink)\">\(escapedPollLink)</a>"
            + String(repeating: " ", count: 64 * 1024)
        let markupCases: [(text: String, html: String, expected: [String], copy: String)] = [
            (pollLink, titledCopy, ["https://x.com/a/status/1"],
             "an address bar copy that writes the link under the page title"),
            (unicodeLink, encodedCopy, ["https://example.com/wiki/北京"],
             "a selected non-ASCII link whose href the browser wrote percent-encoded"),
            ("https://example.com?utm_source=x",
             "<a href=\"https://example.com/?utm_source=x\">https://example.com?utm_source=x</a>",
             ["https://example.com"], "a link to a site's root whose href the browser wrote with a slash"),
            (pollLink, documentCopy, ["https://x.com/a/status/1"],
             "a rich-text document copy whose title and stylesheet are not shown"),
            (pollLink, "<meta charset='utf-8'><style>p { margin: 0; }</style><p>\(escapedPollLink)</p>",
             ["https://x.com/a/status/1"], "a fragment copy that carries its stylesheet"),
            (pollLink, linkedDocumentCopy, ["https://x.com/a/status/1"],
             "a document copy whose head links the document's own files"),
            (pollLink, "<meta charset='utf-8'><p>Read this: \(escapedPollLink)</p>", [],
             "formatted text that shows more than the link"),
            (pollLink, oversizedCopy, [], "a link copy with far more markup than one link needs"),
            ("https://example.com/Report?utm_source=x", "<a href='https://example.com/report?utm_source=x'>Report</a>", [],
             "an anchor whose case-sensitive path points to a different resource"),
            ("https://example.com/?id=ABC&utm_source=x", "<a href='https://example.com/?id=abc&amp;utm_source=x'>Report</a>", [],
             "an anchor whose case-sensitive query points to a different resource"),
            ("https://EXAMPLE.com/Report?utm_source=x", "<a href='https://example.com/Report?utm_source=x'>Report</a>",
             ["https://EXAMPLE.com/Report"], "an anchor whose host differs only in case"),
            (pollLink, "<a href = 'https://example.com/'>\(escapedPollLink)</a>", [],
             "an anchor with whitespace around its different destination"),
            (pollLink, "<a href=\(escapedPollLink)>A post</a>", ["https://x.com/a/status/1"],
             "a link under a title with an unquoted destination"),
            ("https://example.com/Report?utm_source=x", "<p>https://example.com/report?utm_source=x</p>", [],
             "formatted text that spells a case-sensitive path differently"),
        ]
        for markupCase in markupCases {
            let pasteboard = URLCleanerPollHost.Pasteboard.general
            pasteboard.types = chromiumTypes.map(URLCleanerPollHost.Kind.init(rawValue:))
            pasteboard.items = 1
            pasteboard.text = markupCase.text
            pasteboard.html = markupCase.html
            pasteboard.copiedDuringRead = false
            URLCleanerPollHost.written = []
            _ = URLCleanerPollHost.pollPasteboard(sinceChangeCount: 0, token: URLCleanerPollHost.PollToken())
            suite.expect(URLCleanerPollHost.written == markupCase.expected,
                   "automatic cleaning \(markupCase.expected.isEmpty ? "leaves alone" : "rewrites") "
                       + "\(markupCase.copy): \(URLCleanerPollHost.written)")
        }

        // Delayed providers can answer after the cleaner was turned off or
        // another app copied. The final source read must not reopen that race.
        for scenario in ["copy during source", "cancel during source", "cancel during HTML",
                         "copy during metadata", "cancel during metadata"] {
            let pasteboard = URLCleanerPollHost.Pasteboard.general
            let token = URLCleanerPollHost.PollToken()
            pasteboard.types = (chromiumTypes + [URLCleanerLinkMetadata.pasteboardType.rawValue])
                .map(URLCleanerPollHost.Kind.init(rawValue:))
            pasteboard.items = 1
            pasteboard.text = pollLink
            pasteboard.html = titledCopy
            pasteboard.copiedDuringRead = false
            pasteboard.onRead = { kind in
                if scenario == "copy during source", kind == .source { pasteboard.changeCount += 1 }
                if scenario == "cancel during source", kind == .source { token.isCancelled = true }
                if scenario == "cancel during HTML", kind == .html { token.isCancelled = true }
                if scenario == "copy during metadata", kind == URLCleanerLinkMetadata.pasteboardType {
                    pasteboard.changeCount += 1
                }
                if scenario == "cancel during metadata", kind == URLCleanerLinkMetadata.pasteboardType {
                    token.isCancelled = true
                }
            }
            URLCleanerPollHost.written = []
            _ = URLCleanerPollHost.pollPasteboard(sinceChangeCount: 0, token: token)
            pasteboard.onRead = nil
            suite.expect(URLCleanerPollHost.written.isEmpty,
                         "automatic cleaning preserves the clipboard after \(scenario)")
        }

        // The poll holds the queue every pasteboard feature shares, so markup
        // that never closes is read once rather than once per '<'.
        for (html, shape) in [(String(repeating: "<", count: 20_000), "unclosed tags"),
                              (String(repeating: "<style>", count: 6_000), "unclosed elements")] {
            let pasteboard = URLCleanerPollHost.Pasteboard.general
            pasteboard.types = chromiumTypes.map(URLCleanerPollHost.Kind.init(rawValue:))
            pasteboard.items = 1
            pasteboard.text = pollLink
            pasteboard.html = html
            pasteboard.copiedDuringRead = false
            URLCleanerPollHost.written = []
            let started = Date()
            _ = URLCleanerPollHost.pollPasteboard(sinceChangeCount: 0, token: URLCleanerPollHost.PollToken())
            let elapsed = Date().timeIntervalSince(started)
            suite.expect(elapsed < 0.25, "automatic cleaning reads a copy of \(shape) in one pass: \(elapsed) s")
        }

        // MARK: Homebrew command building and parsing

        let homebrewManagerSource = repository.moduleSource(
            at: "Sources/Lattice/Services/Homebrew/HomebrewManager.swift")
        let homebrewRunStreaming = homebrewManagerSource.components(separatedBy: "func runStreaming(")
            .dropFirst().first?.components(separatedBy: "private func appendLog").first ?? ""
        suite.expect(homebrewRunStreaming.contains("brewSilenceTimeout")
                && !homebrewRunStreaming.contains("waitUntilExit"),
               "Homebrew operations wait on a bounded semaphore, not waitUntilExit")

        suite.expect(HomebrewPackageKind.allCases == [.cask, .formula],
               "Homebrew package kinds keep casks before formulae")
        suite.expect(HomebrewCommandBuilder.isValidToken("jq"), "simple Homebrew token is valid")
        suite.expect(HomebrewCommandBuilder.isValidToken("python@3.14"), "versioned formula token is valid")
        suite.expect(HomebrewCommandBuilder.isValidToken("visual-studio-code"), "cask token is valid")
        suite.expect(HomebrewCommandBuilder.isValidToken("homebrew/cask-fonts/font-iosevka"), "tapped token is valid")
        suite.expect(!HomebrewCommandBuilder.isValidToken(""), "empty Homebrew token is invalid")
        suite.expect(HomebrewCommandBuilder.untrustedTapName(fromOutput:
            "Error: Refusing to load formula foo from untrusted tap someone/sometap.\nRun `brew trust someone/sometap` to trust it.")
            == "someone/sometap",
               "untrusted tap name is extracted from Homebrew's refusal")
        suite.expect(HomebrewCommandBuilder.untrustedTapName(fromOutput: "Error: no such formula") == nil,
               "other Homebrew errors extract no tap")
        suite.expect(HomebrewCommandBuilder.untrustedTapName(fromOutput:
            "from untrusted tap ../evil") == nil,
               "a tap name that fails token validation is rejected")
        let trustCommand = HomebrewCommandBuilder.trustTap(brewPath: "/opt/homebrew/bin/brew", tap: "someone/sometap")
        suite.expect(trustCommand.arguments == ["trust", "--tap", "someone/sometap"],
               "trust command targets the tap explicitly")
        suite.expect(!HomebrewCommandBuilder.isValidToken("-bad"), "leading dash Homebrew token is invalid")
        suite.expect(!HomebrewCommandBuilder.isValidToken("../bad"), "path traversal Homebrew token is invalid")
        suite.expect(!HomebrewCommandBuilder.isValidToken("bad token"), "spaced Homebrew token is invalid")

        let brewPath = "/opt/homebrew/bin/brew"
        let cask = HomebrewPackage(kind: .cask, name: "sample-tool",
                                   displayName: "Sample Tool", desc: nil,
                                   installedVersion: nil, stableVersion: nil, homepage: nil)
        suite.expect(HomebrewCommandBuilder.search(brewPath: brewPath, kind: .formula, query: "jq").arguments
               == ["search", "--formula", "jq"],
               "formula search command uses separated arguments")
        suite.expect(HomebrewCommandBuilder.outdated(brewPath: brewPath).arguments
               == ["outdated", "--json=v2"],
               "Homebrew outdated command uses read-only JSON v2 output")
        suite.expect(HomebrewCommandBuilder.update(brewPath: brewPath).arguments
               == ["update"],
               "Homebrew update command refreshes Homebrew metadata")
        suite.expect(HomebrewCommandBuilder.install(brewPath: brewPath, package: cask).arguments
               == ["install", "--cask", "sample-tool"],
               "cask install command uses --cask")
        suite.expect(HomebrewCommandBuilder.uninstall(brewPath: brewPath, package: cask).arguments
               == ["uninstall", "--cask", "sample-tool"],
               "cask uninstall command uses --cask")
        suite.expect(HomebrewCommandBuilder.upgrade(brewPath: brewPath, package: cask).arguments
               == ["upgrade", "--cask", "sample-tool"],
               "cask upgrade command uses --cask")
        let formula = HomebrewPackage(kind: .formula, name: "jq",
                                      displayName: "jq", desc: nil,
                                      installedVersion: "1.8.1", stableVersion: nil, homepage: nil)
        suite.expect(HomebrewCommandBuilder.upgrade(brewPath: brewPath, package: formula).arguments
               == ["upgrade", "jq"],
               "formula upgrade command uses separated arguments")
        suite.expect(HomebrewCommandBuilder.upgradeAll(brewPath: brewPath).arguments
               == ["upgrade"],
               "Homebrew update all command upgrades all outdated packages")
        suite.expect(HomebrewCommandBuilder.cleanup(brewPath: brewPath).arguments
               == ["cleanup", "--prune=all", "-s"],
               "Homebrew cleanup command prunes stale versions, temp downloads, and caches")
        suite.expect(HomebrewCommandBuilder.cleanupDryRun(brewPath: brewPath).arguments
               == ["cleanup", "--prune=all", "-s", "--dry-run"],
               "Homebrew cleanup dry-run command estimates reclaimable cache size")

        // brew exits non-zero when it could not do all of a run, not only when it
        // did none of it, so the installed and outdated lists have to be re-read
        // after a failed operation too. Read from the source: the refresh happens
        // inside a completion closure that no unit test can drive.
        let managerSource = homebrewManagerSource
        suite.expect(!managerSource.isEmpty, "HomebrewManager source is readable for the refresh checks")
        let managerCode = managerSource
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        let refreshCalls = managerCode
            .components(separatedBy: "self.refreshInstalled(clearingError: false, owner: owner)").count - 1
        suite.expect(refreshCalls == 3,
               "the cancelled, needs-terminal and failed operation paths all re-read, "
               + "found \(refreshCalls)")
        let guardedBannerClears = managerCode
            .components(separatedBy: "if clearingError { errorMessage = nil }").count - 1
        suite.expect(guardedBannerClears == 2,
               "both banner clears in refreshInstalled are behind its parameter, so the reason "
               + "a failed operation gave survives the refresh that follows it, found "
               + "\(guardedBannerClears)")
        suite.expect(HomebrewOperation.Action.install.runningSystemImage == "arrow.down.circle.fill",
               "Homebrew install status uses a download icon")
        suite.expect(HomebrewOperation.Action.uninstall.runningSystemImage == "trash.circle.fill",
               "Homebrew uninstall status uses a trash icon")
        suite.expect(HomebrewOperation.Action.upgrade.runningSystemImage == "arrow.up.circle.fill",
               "Homebrew package update status uses an update icon")
        suite.expect(HomebrewOperation.Action.updateHomebrew.runningSystemImage == "arrow.triangle.2.circlepath",
               "Homebrew metadata refresh status uses a refresh icon")
        suite.expect(HomebrewOperation.Action.cleanup.runningSystemImage == "sparkles",
               "Homebrew cleanup status uses a sparkles icon")
        suite.expect(HomebrewOperation.Action.uninstall.clearsSelectionOnSuccess,
               "Homebrew uninstall clears details for the package that left the installed list")
        suite.expect(!HomebrewOperation.Action.install.clearsSelectionOnSuccess
                && !HomebrewOperation.Action.upgrade.clearsSelectionOnSuccess
                && !HomebrewOperation.Action.cleanup.clearsSelectionOnSuccess,
               "Homebrew install, upgrade, and cleanup preserve package details after success")
        suite.expect(HomebrewCommandBuilder.needsTerminalFallback(output: "sudo: a terminal is required to read the password"),
               "sudo terminal error triggers Homebrew terminal fallback")
        suite.expect(HomebrewCommandBuilder.installerCommand == #"/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)""#,
               "Homebrew installer command matches the official install script entrypoint")
        // The terminal handoff: a script the person's own terminal runs once in
        // their own shell, leaving nothing behind (issue #598).
        do {
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("lattice-terminal-script-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            // A stand-in login shell that writes down the arguments it was given.
            let shell = folder.appendingPathComponent("shell")
            let received = folder.appendingPathComponent("received")
            try? "#!/bin/sh\nprintf '%s\\n' \"$@\" > \(HomebrewCommandBuilder.shellQuote(received.path))\n"
                .write(to: shell, atomically: true, encoding: .utf8)
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: shell.path)
            let command = #"eval (/opt/homebrew/bin/brew shellenv fish); echo "it's $HOME" 'a\b'"#
            let script = try? HomebrewTerminalScript.write(command: command, shellPath: shell.path, directory: folder)
            let permissions = script
                .flatMap { try? FileManager.default.attributesOfItem(atPath: $0.path)[.posixPermissions] as? NSNumber }
            suite.expect(script?.pathExtension == "" && permissions?.intValue == 0o700,
                   "the terminal script has no extension, so macOS opens it in the terminal the person chose, "
                   + "and only they can read or run it")
            if let script {
                let process = Process()
                process.executableURL = script
                try? process.run()
                process.waitUntilExit()
            }
            let arguments = (try? String(contentsOf: received, encoding: .utf8))?
                .split(separator: "\n", omittingEmptySubsequences: false).map(String.init) ?? []
            suite.expect(arguments == ["-l", "-i", "-c", command, ""],
                   "the terminal script hands the command, unchanged, to the person's own shell as a login "
                   + "and interactive shell, the way Terminal ran it before, found \(arguments)")
            suite.expect(script.map { !FileManager.default.fileExists(atPath: $0.path) } ?? false,
                   "the terminal script deletes itself as it runs")
            do {
                for shellPath in ["/bin/csh", "/bin/tcsh"] {
                    let output = folder.appendingPathComponent(URL(fileURLWithPath: shellPath).lastPathComponent)
                    let command = "/usr/bin/printf '%s' 'terminal handoff' > "
                        + HomebrewCommandBuilder.shellQuote(output.path)
                    let script = try HomebrewTerminalScript.write(command: command,
                                                                   shellPath: shellPath, directory: folder)
                    let process = Process()
                    process.executableURL = script
                    let input = Pipe()
                    process.standardInput = input
                    try process.run()
                    try input.fileHandleForWriting.close()
                    process.waitUntilExit()
                    suite.expect(process.terminationStatus == 0
                                 && (try? String(contentsOf: output, encoding: .utf8)) == "terminal handoff",
                                 "the production terminal script runs commands in \(shellPath)")
                    suite.expect(!FileManager.default.fileExists(atPath: script.path),
                                 "the \(shellPath) terminal script removes itself")
                }
            } catch {
                suite.expect(false, "could not run the csh terminal handoff: \(error)")
            }
            suite.expect((try? HomebrewTerminalScript.write(command: command, shellPath: shell.path,
                                                            directory: folder.appendingPathComponent("missing"))) == nil,
                   "a terminal script that cannot be written reports an error instead of opening nothing")
        }
        expectEqual(HomebrewCommandBuilder.shellProfilePath(homeDirectory: "/Users/test", shellPath: "/bin/zsh"),
                    "/Users/test/.zprofile",
                    "Homebrew shell setup uses zprofile for zsh")
        expectEqual(HomebrewCommandBuilder.shellProfilePath(homeDirectory: "/Users/test", shellPath: "/bin/bash"),
                    "/Users/test/.bash_profile",
                    "Homebrew shell setup uses bash_profile for bash")
        expectEqual(HomebrewCommandBuilder.shellProfilePath(homeDirectory: "/Users/test", shellPath: "/opt/homebrew/bin/fish"),
                    "/Users/test/.config/fish/config.fish",
                    "Homebrew shell setup uses the interactive shell config")
        expectEqual(HomebrewCommandBuilder.shellEnvLine(brewPath: brewPath, shellPath: "/bin/zsh"),
                    #"eval "$(/opt/homebrew/bin/brew shellenv)""#,
                    "Homebrew shell setup line uses brew shellenv")
        expectEqual(HomebrewCommandBuilder.shellEnvLine(brewPath: brewPath, shellPath: "/opt/homebrew/bin/fish"),
                    "eval (/opt/homebrew/bin/brew shellenv fish)",
                    "Homebrew shell setup line matches the interactive shell")
        expectEqual(HomebrewAnalytics.url(kind: .formula).absoluteString,
                    "https://formulae.brew.sh/api/analytics/install-on-request/homebrew-core/30d.json",
                    "Homebrew formula popularity uses install-on-request analytics")
        expectEqual(HomebrewAnalytics.url(kind: .cask).absoluteString,
                    "https://formulae.brew.sh/api/analytics/cask-install/homebrew-cask/30d.json",
                    "Homebrew cask popularity uses cask install analytics")
        do {
            let originalLocale = MetricFormat.locale
            defer { MetricFormat.locale = originalLocale }
            // Run independently of both the Mac's region and other suites.
            for (region, thousands, millions) in [
                ("en_US_POSIX", "1.2K", "1.2M"),
                ("pt_BR", "1,2K", "1,2M"),
            ] {
                MetricFormat.locale = Locale(identifier: region)
                expectEqual(HomebrewAnalytics.compactCount(999), "999",
                            "Homebrew popularity under 1K stays plain in \(region)")
                expectEqual(HomebrewAnalytics.compactCount(1_250), thousands,
                            "Homebrew popularity compacts thousands in \(region)")
                expectEqual(HomebrewAnalytics.compactCount(1_200_000), millions,
                            "Homebrew popularity compacts millions in \(region)")
            }
        }
        let shellSetupCommand = HomebrewCommandBuilder.shellConfigCommand(brewPath: brewPath,
                                                                          homeDirectory: "/Users/test",
                                                                          shellPath: "/bin/zsh")
        suite.expect(shellSetupCommand.hasPrefix("/bin/sh -c ")
                && shellSetupCommand.contains("PROFILE=/Users/test/.zprofile")
                && shellSetupCommand.hasSuffix(#"; eval "$(/opt/homebrew/bin/brew shellenv)"; brew --version"#),
               "Homebrew shell setup command targets the detected profile")
        suite.expect(shellSetupCommand.contains(#"grep -qxF "$LINE""#),
               "Homebrew shell setup command avoids duplicate profile lines")
        let alternateShellSetupCommand = HomebrewCommandBuilder.shellConfigCommand(
            brewPath: brewPath,
            homeDirectory: "/Users/test",
            shellPath: "/opt/homebrew/bin/fish"
        )
        suite.expect(alternateShellSetupCommand.hasPrefix("/bin/sh -c ")
                && alternateShellSetupCommand.contains("/bin/mkdir -p /Users/test/.config/fish")
                && alternateShellSetupCommand.hasSuffix("; eval (/opt/homebrew/bin/brew shellenv fish); brew --version"),
               "Homebrew shell setup creates and activates the interactive shell config")

        // The login shell's exports reach brew through an allowlist (issue #1290).
        let loginShell = HomebrewEnvironment.loginShellCommand(shellPath: "/bin/zsh")
        suite.expect(loginShell.executable == "/bin/zsh"
                && loginShell.arguments.contains("-l")
                && loginShell.arguments.contains("-i")
                && (loginShell.arguments.last?.hasSuffix("/usr/bin/env -0") ?? false)
                && (loginShell.arguments.last?.contains(HomebrewEnvironment.dumpMarker) ?? false),
               "Homebrew asks the user's shell as a login and interactive shell, so ~/.zshrc is read too, "
               + "and marks where the NUL-separated environment starts")
        let envDump = Data(("HOME=/Users/test\0https_proxy=http://127.0.0.1:7890\0MULTI=a\nb\0"
                            + "EQUALS=x=y\0EMPTY=\0noequals\0Welcome back\nHOMEBREW_API_DOMAIN=https://mirror.example/api\0").utf8)
        let parsedEnvironment = HomebrewEnvironment.parse(nullSeparated: envDump)
        expectEqual(parsedEnvironment["https_proxy"] ?? "", "http://127.0.0.1:7890",
                    "Homebrew environment parser reads a NAME=value entry")
        expectEqual(parsedEnvironment["MULTI"] ?? "", "a\nb",
                    "Homebrew environment parser keeps a newline inside a value; NUL is the only separator")
        expectEqual(parsedEnvironment["EQUALS"] ?? "", "x=y",
                    "Homebrew environment parser splits on the first equals sign only")
        suite.expect(parsedEnvironment["EMPTY"] == "" && parsedEnvironment["noequals"] == nil,
               "Homebrew environment parser keeps an empty value and drops an entry without one")
        suite.expect(!parsedEnvironment.keys.contains { $0.contains("Welcome") || $0.hasPrefix("HOMEBREW_") },
               "Homebrew environment parser drops an entry whose name is not an identifier, "
               + "such as startup output glued to the variable behind it")
        // What a real `bash -i` does: "no job control in this shell" on the shared
        // pipe, with no NUL of its own, so the first variable rides in behind it.
        let noisyDump = Data(("bash: no job control in this shell\nWelcome back\n"
                              + HomebrewEnvironment.dumpMarker
                              + "https_proxy=http://127.0.0.1:7890\0HOMEBREW_API_DOMAIN=https://mirror.example/api\0").utf8)
        let parsedNoisy = HomebrewEnvironment.parse(nullSeparated: noisyDump)
        expectEqual(parsedNoisy["https_proxy"] ?? "", "http://127.0.0.1:7890",
                    "Homebrew keeps the first variable of the dump when a startup file printed before it")
        expectEqual(parsedNoisy["HOMEBREW_API_DOMAIN"] ?? "", "https://mirror.example/api",
                    "Homebrew reads the rest of a dump that startup output preceded")
        suite.expect(parsedNoisy.count == 2,
               "Homebrew takes nothing a startup file printed as a variable, found \(parsedNoisy.keys.sorted())")
        let echoedMarker = Data(("startup echoed " + HomebrewEnvironment.dumpMarker + " itself\n"
                                 + HomebrewEnvironment.dumpMarker + "no_proxy=localhost\0").utf8)
        expectEqual(HomebrewEnvironment.parse(nullSeparated: echoedMarker)["no_proxy"] ?? "", "localhost",
                    "Homebrew takes the last marker, so a startup file echoing it cannot cut the dump short")
        let passedThrough = HomebrewEnvironment.passthrough([
            "PATH": "/tmp/evil:/usr/bin", "DYLD_INSERT_LIBRARIES": "/tmp/evil.dylib", "HOME": "/Users/test",
            "SHELL": "/bin/zsh", "HTTP_PROXY": "http://127.0.0.1:7890", "https_proxy": "http://127.0.0.1:7890",
            "ALL_PROXY": "socks5://127.0.0.1:7891", "no_proxy": "localhost", "HOMEBREW_API_DOMAIN": "https://mirror.example/api",
            "HOMEBREW_BOTTLE_DOMAIN": "https://mirror.example", "HOMEBREWX": "no", "homebrew_lower": "no",
        ])
        suite.expect(Set(passedThrough.keys) == ["https_proxy", "ALL_PROXY", "no_proxy",
                                           "HOMEBREW_API_DOMAIN", "HOMEBREW_BOTTLE_DOMAIN"],
               "Homebrew passes through only the proxy names brew itself keeps and HOMEBREW_* settings, "
               + "found \(passedThrough.keys.sorted())")
        suite.expect(HomebrewEnvironment.exportsFromLoginShell(shellPath: "").isEmpty
                && HomebrewEnvironment.exportsFromLoginShell(shellPath: "/nonexistent/shell", timeout: 1).isEmpty,
               "Homebrew contributes nothing when there is no login shell or it cannot start")
        suite.expect(HomebrewEnvironment.exportsFromLoginShell(shellPath: "/bin/sh").keys
                .allSatisfy(HomebrewEnvironment.isPassedThrough),
               "Homebrew never hands a login shell's whole environment to brew")
        let plainLogin = HomebrewEnvironment.loginShellCommand(shellPath: "/bin/zsh", interactive: false)
        suite.expect(plainLogin.arguments.contains("-l") && !plainLogin.arguments.contains("-i")
                && plainLogin.arguments.last == loginShell.arguments.last,
               "Homebrew's fallback asks for the same dump from a plain login shell")
        let resolvingEnvironment = HomebrewEnvironment.loginShellEnvironment(base: ["HOME": "/Users/test"])
        suite.expect(HomebrewEnvironment.resolvingVariable == "LATTICE_RESOLVING_ENVIRONMENT"
                && resolvingEnvironment == ["HOME": "/Users/test", "LATTICE_RESOLVING_ENVIRONMENT": "1", "VORSSAINT_RESOLVING_ENVIRONMENT": "1"],
               "Homebrew marks environment resolution with current and legacy names without dropping base exports")
        // A real zsh reading startup files from a scratch ZDOTDIR, so the user's own are never touched.
        let zdotdir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lattice-login-shell-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: zdotdir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: zdotdir) }
        func startupExports(zshrc: String) -> [String: String] {
            try? "export HOMEBREW_API_DOMAIN=https://mirror.example/api\n"
                .write(to: zdotdir.appendingPathComponent(".zprofile"), atomically: true, encoding: .utf8)
            try? zshrc.write(to: zdotdir.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)
            return HomebrewEnvironment.exportsFromLoginShell(
                shellPath: "/bin/zsh",
                baseEnvironment: ["HOME": zdotdir.path, "ZDOTDIR": zdotdir.path, "PATH": "/usr/bin:/bin"])
        }
        let zshrcExports = startupExports(zshrc: "export https_proxy=http://127.0.0.1:7890\n"
                                          + "export HOMEBREW_SEEN_RESOLVING=$LATTICE_RESOLVING_ENVIRONMENT\n"
                                          + "export HOMEBREW_SEEN_LEGACY=$VORSSAINT_RESOLVING_ENVIRONMENT\n")
        suite.expect(zshrcExports["HOMEBREW_API_DOMAIN"] == "https://mirror.example/api"
                && zshrcExports["https_proxy"] == "http://127.0.0.1:7890",
               "Homebrew reads exports from both ~/.zprofile and ~/.zshrc, found \(zshrcExports.keys.sorted())")
        expectEqual(zshrcExports["HOMEBREW_SEEN_RESOLVING"] ?? "", "1",
                    "Homebrew's login shell exposes LATTICE_RESOLVING_ENVIRONMENT to startup files")
        expectEqual(zshrcExports["HOMEBREW_SEEN_LEGACY"] ?? "", "1",
                    "existing startup safeguards still receive the legacy environment marker")
        // A multiplexer autostart that fails without a terminal and exits, or an exec into another shell.
        for takeover in ["multiplexer_autostart_failed_without_a_terminal=1; exit 0", "exec /bin/sh -c true"] {
            let fallbackExports = startupExports(zshrc: takeover + "\n")
            expectEqual(fallbackExports["HOMEBREW_API_DOMAIN"] ?? "", "https://mirror.example/api",
                        "Homebrew falls back to the plain login run when ~/.zshrc ends the shell early: \(takeover)")
        }
        suite.expectClose(HomebrewProgressParser.progressFraction(in: "######## 42.5%") ?? -1,
                    0.425,
                    "Homebrew progress parser reads percentage output")
        suite.expect(HomebrewProgressParser.phase(in: "==> Downloading https://example.com/file",
                                            action: .install) == .downloading,
               "Homebrew progress parser detects downloads")
        suite.expect(HomebrewProgressParser.phase(in: "==> Installing Cask sample-tool",
                                            action: .install) == .installing,
               "Homebrew progress parser detects installs")
        suite.expect(HomebrewProgressParser.phase(in: "==> Uninstalling Cask sample-tool",
                                            action: .uninstall) == .uninstalling,
               "Homebrew progress parser detects uninstalls")
        suite.expect(HomebrewProgressParser.phase(in: "==> Upgrading sample-formula",
                                            action: .upgrade) == .upgrading,
               "Homebrew progress parser detects upgrades")
        suite.expect(HomebrewProgressParser.phase(in: "Already up-to-date.",
                                            action: .updateHomebrew) == .refreshing,
               "Homebrew progress parser detects metadata refresh")
        suite.expect(HomebrewProgressParser.activity(in: "\u{001B}[32m==> Moving App 'Sample.app'\u{001B}[0m")
               == "Moving App 'Sample.app'",
               "Homebrew progress parser cleans activity lines")
        suite.expect(HomebrewProgressParser.phase(in: "Removing: /Users/test/Library/Caches/Homebrew/foo.tar.gz... (12.4MB)",
                                            action: .cleanup) == .cleaning,
               "Homebrew progress parser detects cleanup removals")
        suite.expect(HomebrewProgressParser.phase(in: "Pruning 3 days from /Users/test/Library/Caches/Homebrew",
                                            action: .cleanup) == .cleaning,
               "Homebrew progress parser detects cache pruning")

        let executedCleanup = HomebrewCleanupParser.parse("""
        \u{001B}[32mRemoving: /Users/test/Library/Caches/Homebrew/downloads/a.incomplete... (42MB)\u{001B}[0m
        Removing: /Users/test/Library/Caches/Homebrew/b--1.0.tar.gz... (8MB)
        ==> Autoremoving 2 unneeded formulae:
        ==> This operation has freed approximately 148.5MB of disk space.
        """)
        suite.expect(executedCleanup.freedSizeText == "148.5 MB"
                && executedCleanup.removedCount == 4
                && !executedCleanup.isEmpty,
               "Homebrew cleanup parser extracts freed disk space and removed item count from cleanup output")

        let dryRunCleanup = HomebrewCleanupParser.parse("""
        Would remove: /Users/test/Library/Caches/Homebrew/downloads/stale.incomplete (24.2MB)
        ==> This operation would free approximately 24.2MB of disk space.
        """)
        suite.expect(dryRunCleanup.freedSizeText == "24.2 MB"
                && dryRunCleanup.removedCount == 1
                && !dryRunCleanup.isEmpty,
               "Homebrew cleanup parser extracts estimated space from dry-run output")

        let emptyCleanup = HomebrewCleanupParser.parse("")
        suite.expect(emptyCleanup.freedSizeText == nil
                && emptyCleanup.removedCount == 0
                && emptyCleanup.isEmpty,
               "Homebrew cleanup parser treats empty output as nothing to clean")

        let panelHomebrewSource = repository.moduleSource(at: "Sources/Lattice/UI/MenuPanel/PanelHomebrewView.swift")
        let panelHomebrewSurfacesSource = repository.moduleSource(at: "Sources/Lattice/UI/MenuPanel/PanelHomebrewView+Surfaces.swift")
        let hostedUtilitySource = repository.moduleSource(at: "Sources/Lattice/UI/LatticeHub/LatticeHubHostedUtility.swift")
        let homebrewTabSource = repository.moduleSource(at: "Sources/Lattice/UI/Settings/HomebrewTab.swift")
        let operationStatusSource = repository.moduleSource(at: "Sources/Lattice/UI/HomebrewOperationStatusView.swift")
        let updatesPickerSource = repository.moduleSource(at: "Sources/Lattice/UI/AppUpdates/AppUpdatesListView+Picker.swift")
        let updatesCompactSource = repository.moduleSource(at: "Sources/Lattice/UI/AppUpdates/AppUpdatesListView+Compact.swift")
        suite.expect(panelHomebrewSurfacesSource.contains("var islandBody: some View")
                && panelHomebrewSurfacesSource.contains("var hubBody: some View")
                && panelHomebrewSurfacesSource.contains("islandUpdatesCard")
                && panelHomebrewSurfacesSource.contains("islandCleanupCard")
                && panelHomebrewSurfacesSource.contains("NotchControlSurface")
                && panelHomebrewSource.contains("if inNotch"),
               "PanelHomebrewView separates Dynamic Island package updates and cache cleanup into stacked full-width modules alongside its floating hub layout")
        suite.expect(panelHomebrewSource.contains("homebrew.cleanup")
                && panelHomebrewSource.contains("homebrew.upgradeAll")
                && panelHomebrewSurfacesSource.contains(".hubScrollEdgeFade")
                && panelHomebrewSurfacesSource.contains("minHeight: 70"),
               "PanelHomebrewView exposes cleanup, update all, 70pt empty online state, and edge-faded hub scrolling")
        suite.expect(homebrewTabSource.contains("cleanupButton")
                && homebrewTabSource.contains("homebrew.cleanup")
                && homebrewTabSource.contains("hidesEmptyInstalledSection")
                && homebrewTabSource.contains("minHeight: 70"),
               "HomebrewTab compounds cache cleanup into one top card, hides empty local results for online searches, and sizes online empty state to 70pt")
        suite.expect(!homebrewTabSource.contains("sparkles")
                && !panelHomebrewSurfacesSource.contains("sparkles"),
               "Homebrew cleanup controls omit the sparkles icon across Settings, Dynamic Island, and floating Hub")
        suite.expect(homebrewTabSource.contains("showsCleanupButton")
                && !homebrewTabSource.contains("ellipsis.circle")
                && panelHomebrewSurfacesSource.contains("showsCleanupButton")
                && !panelHomebrewSurfacesSource.contains("ellipsis.circle")
                && !panelHomebrewSurfacesSource.contains("islandOutdatedMoreMenu")
                && homebrewTabSource.contains("HomebrewCompactOperationFooter")
                && panelHomebrewSurfacesSource.contains("HomebrewCompactOperationFooter")
                && operationStatusSource.contains("setOperationDetailsExpanded"),
               "Clean Up sits directly beside Update All without an overflow menu, hides when clean, and Settings shares the auto-dismissing compact operation footer")
        suite.expect(HomebrewTabStrings.enUS.upgrading == "Updating…"
                && !repository.moduleSource(at: "Sources/Lattice/Core/HomebrewTabStrings.swift").contains("Upgrading"),
               "Homebrew UI strings consistently use Update/Updating terminology rather than mixing Upgrade")
        suite.expect(operationStatusSource.contains("case .cancelled: return \"xmark.octagon.fill\"")
                && panelHomebrewSurfacesSource.contains("case .cancelled: return \"xmark.octagon.fill\"")
                && operationStatusSource.contains("case .cancelled: return .red")
                && panelHomebrewSurfacesSource.contains("case .cancelled: return .red"),
               "Cancelled Homebrew operations use a red octagon icon rather than a close button X")
        suite.expect(panelHomebrewSource.contains("case all, cask, formula, outdated, orphans")
                && panelHomebrewSource.contains("filterCount($0) > 0")
                && homebrewTabSource.contains("filterCount($0) > 0"),
               "Floating window and Settings share All/Casks/Formulas/Outdated/Orphans filter ordering and omit zero-count categories")
        let uninstallerPanelSource = repository.moduleSource(at: "Sources/Lattice/UI/MenuPanel/PanelUninstallerView.swift")
        let hubPresentationSource = repository.moduleSource(at: "Sources/Lattice/Services/LatticeHub/LatticeHubPresentation.swift")
        let notchServiceSource = repository.moduleSource(at: "Sources/Lattice/Services/Notch/NotchService.swift")
        let appManagerPanelSource = repository.moduleSource(at: "Sources/Lattice/UI/MenuPanel/PanelAppManagerView.swift")
        suite.expect(uninstallerPanelSource.contains("uninstaller.reset()")
                && hubPresentationSource.contains("resetUninstallerIfSelected()")
                && notchServiceSource.contains("resetUninstallerIfSelected()")
                && appManagerPanelSource.contains("AppUninstaller.shared.reset()"),
               "Exiting or closing an inspected uninstaller panel resets to the app chooser for the next open")
        suite.expect(!updatesPickerSource.contains("arrow.up.right.square")
                && updatesPickerSource.contains("text.openAppUpdates")
                && !panelHomebrewSurfacesSource.contains("arrow.up.right.square")
                && panelHomebrewSurfacesSource.contains("strings.openHomebrew")
                && updatesCompactSource.contains("VStack(alignment: .leading, spacing: 0)")
                && updatesCompactSource.contains(".contentMargins(.vertical, HubScrollEdge.inset"),
               "Updates and Homebrew floating/island views replace the boxed arrow with secondary Open buttons while preserving scroll soft-edge fade")
        suite.expect(HomebrewTabStrings.enUS.cleanupTitle == "Homebrew Cache"
                && !panelHomebrewSurfacesSource.contains("islandCleanupSubtitle")
                && !panelHomebrewSurfacesSource.contains(".help(strings.cleanupDescription)")
                && !panelHomebrewSurfacesSource.contains("Circle()\n                        .fill(Color.green")
                && !panelHomebrewSurfacesSource.contains("Text(summaryLine)")
                && !homebrewTabSource.contains("strings.summaryFormat")
                && !homebrewTabSource.contains("ProgressView().controlSize(.mini)\n            }")
                && !panelHomebrewSurfacesSource.contains("if homebrew.isCheckingCleanup")
                && homebrewTabSource.contains(".padding(.vertical, 5.5)")
                && panelHomebrewSource.contains(".padding(.vertical, 3.5)"),
               "DI/Floating/Settings Homebrew views match simplified labels, centered badge-free checkmark, no cleanup spinner, and matching Updating button heights")
        let hubMonitorsSource = repository.moduleSource(at: "Sources/Lattice/Services/LatticeHub/LatticeHubMonitors.swift")
        suite.expect(updatesCompactSource.contains("if updates.isChecking")
                && updatesCompactSource.contains("compactHeader\n                    AppManagerListSkeleton")
                && updatesPickerSource.contains("if isChecking && count == 0")
                && !hubMonitorsSource.contains("didResignKeyNotification")
                && hubMonitorsSource.contains("shouldDismissWhenOtherWindowBecomesKey")
                && !uninstallerPanelSource.contains(".defaultFocus("),
               "Floating App Updates skeleton retains its heading and switching to Uninstaller in the floating window never spurs key-loss dismissal")
        suite.expect(hostedUtilitySource.contains("if item == .appManager {")
                && !hostedUtilitySource.contains("appManagerPanel.selectedTab != .homebrew"),
               "LatticeHubHostedUtility lets all App Manager tabs including Homebrew manage their viewport directly")
        suite.expect(HomebrewProgressParser.visibleError(from: "$ brew install x\nError: Cask failed")
               == "Error: Cask failed",
               "Homebrew progress parser hides command lines from visible errors")

        let homebrewJSON = """
        {
          "formulae": [
            {
              "name": "sample-formula",
              "full_name": "sample-formula",
              "desc": "Sample formula",
              "homepage": "https://example.com/sample-formula",
              "versions": { "stable": "1.8.1" },
              "installed": [{ "version": "1.8.1" }]
            },
            {
              "name": "tapped-formula",
              "full_name": "example/tap/tapped-formula",
              "desc": "Formula from a third-party tap",
              "homepage": "https://example.com/tapped-formula",
              "versions": { "stable": "2.0.0" },
              "installed": [{ "version": "1.0.0" }]
            }
          ],
          "casks": [
            {
              "token": "sample-tool",
              "name": ["Sample Tool"],
              "desc": "Sample cask",
              "homepage": "https://example.com/sample-tool",
              "version": "1.108.1",
              "installed": "1.107.0"
            },
            {
              "token": "tapped-tool",
              "full_token": "example/tap/tapped-tool",
              "name": ["Tapped Tool"],
              "desc": "Cask from a third-party tap",
              "homepage": "https://example.com/tapped-tool",
              "version": "2.0.0",
              "installed": "1.0.0"
            }
          ]
        }
        """
        let homebrewPackages = (try? HomebrewParser.parseInfoJSON(Data(homebrewJSON.utf8))) ?? []
        suite.expect(homebrewPackages.count == 4, "Homebrew JSON parser keeps formulae and casks")
        suite.expect(homebrewPackages.first?.kind == .cask,
               "Homebrew JSON parser sorts casks before formulae")
        suite.expect(homebrewPackages.first(where: { $0.name == "sample-formula" })?.installedVersion == "1.8.1",
               "Homebrew parser reads installed formula version")
        let tappedFormula = homebrewPackages.first { $0.name == "example/tap/tapped-formula" }
        suite.expect(tappedFormula?.displayName == "example/tap/tapped-formula",
               "Homebrew parser keeps the canonical name for a formula from a tap")
        suite.expect(homebrewPackages.first(where: { $0.name == "sample-tool" })?.displayName == "Sample Tool",
               "Homebrew parser reads cask display name")
        let tappedCask = homebrewPackages.first { $0.name == "tapped-tool" }
        suite.expect(tappedCask != nil,
               "Homebrew parser identifies a cask from a tap by its short token")
        suite.expect(tappedCask?.displayName == "Tapped Tool",
               "Homebrew parser keeps the human-readable name for a cask from a tap")
        let cleanCommandPackages = (try? HomebrewParser.parseInfoCommandOutput(homebrewJSON)) ?? []
        suite.expect(cleanCommandPackages.count == 4,
               "Homebrew command output parser keeps clean JSON")
        let noisyHomebrewOutput = """
        Warning: Skipping some beta metadata
        {"notice": "not package data"}
        \(homebrewJSON)
        Warning: A newer Homebrew beta changed an optional field
        """
        let noisyCommandPackages = (try? HomebrewParser.parseInfoCommandOutput(noisyHomebrewOutput)) ?? []
        suite.expect(noisyCommandPackages.count == 4,
               "Homebrew command output parser accepts warnings around JSON")
        suite.expect(noisyCommandPackages.first(where: { $0.name == "sample-tool" })?.installedVersion == "1.107.0",
               "Homebrew command output parser keeps package data from noisy output")
        suite.expect((try? HomebrewParser.parseInfoCommandOutput("Warning: no JSON here")) == nil,
               "Homebrew command output parser rejects output without valid JSON")
        let outdatedJSON = """
        {
          "formulae": [
            {
              "name": "fmt",
              "installed_versions": ["12.1.0"],
              "current_version": "12.2.0",
              "pinned": false
            },
            {
              "name": "example/tap/tapped-formula",
              "installed_versions": ["1.0.0"],
              "current_version": "2.0.0",
              "pinned": false
            }
          ],
          "casks": [
            {
              "name": "sample-tool",
              "installed_versions": ["1.107.0"],
              "current_version": "1.108.1",
              "pinned": true
            },
            {
              "name": "tapped-tool",
              "installed_versions": ["1.0.0"],
              "current_version": "2.0.0",
              "pinned": false
            }
          ]
        }
        """
        let outdatedPackages = (try? HomebrewParser.parseOutdatedJSON(Data(outdatedJSON.utf8))) ?? [:]
        suite.expect(outdatedPackages.count == 4,
               "Homebrew outdated parser keeps formulae and casks")
        suite.expect(outdatedPackages["formula:fmt"]?.versionSummary == "12.1.0 -> 12.2.0",
               "Homebrew outdated parser renders installed to current version")
        suite.expect(outdatedPackages["cask:sample-tool"]?.isPinned == true,
               "Homebrew outdated parser reads pinned status")
        suite.expect(tappedFormula.flatMap { outdatedPackages[$0.id] }?.currentVersion == "2.0.0",
               "Homebrew installed and outdated data use the same ID for tapped formulae")
        suite.expect(tappedCask?.id == "cask:tapped-tool",
               "Homebrew installed cask data stays on the short token brew outdated reports")
        suite.expect(tappedCask.flatMap { outdatedPackages[$0.id] }?.currentVersion == "2.0.0",
               "Homebrew installed and outdated data use the same short-token ID for tapped casks")
        let noisyOutdatedOutput = """
        Warning: Homebrew updated metadata
        {"notice": "not outdated data"}
        \(outdatedJSON)
        """
        let noisyOutdatedPackages = (try? HomebrewParser.parseOutdatedCommandOutput(noisyOutdatedOutput)) ?? [:]
        suite.expect(noisyOutdatedPackages["formula:fmt"]?.currentVersion == "12.2.0",
               "Homebrew outdated command output parser accepts warnings around JSON")
        let orderingPackages = [
            HomebrewPackage(kind: .cask, name: "alpha-tool", displayName: "Alpha Tool",
                            desc: nil, installedVersion: "1.0", stableVersion: nil, homepage: nil),
            HomebrewPackage(kind: .cask, name: "beta-tool", displayName: "Beta Tool",
                            desc: nil, installedVersion: "1.0", stableVersion: nil, homepage: nil,
                            update: HomebrewPackageUpdate(kind: .cask, name: "beta-tool",
                                                          installedVersions: ["1.0"],
                                                          currentVersion: "2.0", isPinned: false)),
            HomebrewPackage(kind: .formula, name: "gamma-tool", displayName: "Gamma Tool",
                            desc: nil, installedVersion: "1.0", stableVersion: nil, homepage: nil,
                            update: HomebrewPackageUpdate(kind: .formula, name: "gamma-tool",
                                                          installedVersions: ["1.0"],
                                                          currentVersion: "2.0", isPinned: false)),
            HomebrewPackage(kind: .formula, name: "delta-tool", displayName: "Delta Tool",
                            desc: nil, installedVersion: "1.0", stableVersion: nil, homepage: nil)
        ]
        suite.expect(HomebrewPackageOrdering.updatesFirst(orderingPackages).map(\.name)
               == ["beta-tool", "gamma-tool", "alpha-tool", "delta-tool"],
               "Homebrew installed packages keep all pending updates first without reordering either group")
        let dependencyJSON = """
        {
          "formulae": [
            { "name": "app-a", "full_name": "app-a",
              "installed": [{ "version": "1", "installed_on_request": true,
                              "runtime_dependencies": [{ "full_name": "shared-lib" }, { "full_name": "deep-lib" }] }] },
            { "name": "app-b", "full_name": "example/tap/app-b",
              "installed": [{ "version": "1", "installed_on_request": true,
                              "runtime_dependencies": [{ "full_name": "shared-lib" }, { "full_name": "example/tap/tap-lib" }] }] },
            { "name": "shared-lib", "full_name": "shared-lib",
              "installed": [{ "version": "2", "installed_on_request": false,
                              "runtime_dependencies": [{ "full_name": "deep-lib" }] }] },
            { "name": "deep-lib", "full_name": "deep-lib",
              "installed": [{ "version": "3", "installed_on_request": false, "runtime_dependencies": [] }] },
            { "name": "tap-lib", "full_name": "example/tap/tap-lib",
              "installed": [{ "version": "4", "installed_on_request": false, "runtime_dependencies": [] }] },
            { "name": "cask-lib", "full_name": "cask-lib",
              "installed": [{ "version": "5", "installed_on_request": false, "runtime_dependencies": [] }] },
            { "name": "orphan-lib", "full_name": "orphan-lib",
              "installed": [{ "version": "6", "installed_on_request": false, "runtime_dependencies": [] }] }
          ],
          "casks": [
            { "token": "cask-app", "name": ["Cask App"], "installed": "1",
              "depends_on": { "formula": ["cask-lib"] } }
          ]
        }
        """
        let dependencyPackages = (try? HomebrewParser.parseInfoJSON(Data(dependencyJSON.utf8))) ?? []
        let folded = HomebrewDependencyGraph.fold(dependencyPackages, installed: dependencyPackages)
        let flat = HomebrewDependencyGraph.display(dependencyPackages,
                                                   installed: dependencyPackages,
                                                   groupDependencies: false)
        suite.expect(flat.rows.map(\.id) == dependencyPackages.map(\.id)
                     && flat.rows.count == dependencyPackages.count
                     && flat.dependencies.isEmpty
                     && flat.orphans.isEmpty,
                     "Homebrew flat mode retains every installed row in its incoming order and shows no nested duplicates or orphans")
        let grouped = HomebrewDependencyGraph.display(dependencyPackages,
                                                      installed: dependencyPackages,
                                                      groupDependencies: true)
        suite.expect(grouped.rows.map(\.id) == folded.rows.map(\.id)
                     && Set(grouped.dependencies.keys) == Set(folded.dependencies.keys)
                     && grouped.orphans.map(\.id) == folded.orphans.map(\.id),
                     "Homebrew grouped mode preserves the existing dependency layout")
        suite.expect(folded.rows.map(\.name) == ["cask-app", "app-a", "example/tap/app-b"]
                     && folded.orphans.map(\.name) == ["orphan-lib"],
                     "Homebrew keeps requested packages as rows and lists a dependency nothing needs as an orphan, found \(folded.rows.map(\.name)) and \(folded.orphans.map(\.name))")
        suite.expect(folded.dependencies["formula:app-a"]?.map(\.name) == ["deep-lib", "shared-lib"],
                     "Homebrew lists direct and transitive dependencies under a requested formula")
        suite.expect(folded.dependencies["formula:example/tap/app-b"]?.map(\.name)
                     == ["deep-lib", "example/tap/tap-lib", "shared-lib"],
                     "Homebrew lists a shared dependency under each parent and resolves tapped names")
        suite.expect(folded.dependencies["cask:cask-app"]?.map(\.name) == ["cask-lib"],
                     "Homebrew lists a cask's formula dependencies under the cask")
        let withUpdate = HomebrewPackageOrdering.updatesFirst(dependencyPackages.map { package in
            var package = package
            if package.name == "shared-lib" {
                package.update = HomebrewPackageUpdate(kind: .formula, name: "shared-lib",
                                                       installedVersions: ["2"], currentVersion: "3", isPinned: false)
            }
            return package
        })
        let updateFolded = HomebrewDependencyGraph.fold(withUpdate, installed: withUpdate)
        let flatWithUpdate = HomebrewDependencyGraph.display(withUpdate,
                                                             installed: withUpdate,
                                                             groupDependencies: false)
        suite.expect(flatWithUpdate.rows.map(\.id) == withUpdate.map(\.id)
                     && flatWithUpdate.rows.first?.name == "shared-lib",
                     "Homebrew flat mode keeps update-first ordering and includes dependencies as top-level rows")
        suite.expect(updateFolded.rows.map(\.name) == ["app-a", "example/tap/app-b", "cask-app"]
                     && updateFolded.dependencies["formula:app-a"]?.map(\.name) == ["deep-lib", "shared-lib"],
                     "Homebrew keeps a dependency with an update under its parents and moves those parents up, found \(updateFolded.rows.map(\.name))")
        let orphanUpdate = HomebrewPackageOrdering.updatesFirst(dependencyPackages.map { package in
            var package = package
            if package.name == "orphan-lib" {
                package.update = HomebrewPackageUpdate(kind: .formula, name: "orphan-lib",
                                                       installedVersions: ["6"], currentVersion: "7", isPinned: false)
            }
            return package
        })
        let orphanUpdateFolded = HomebrewDependencyGraph.fold(orphanUpdate, installed: orphanUpdate)
        suite.expect(orphanUpdateFolded.orphans.map(\.name) == ["orphan-lib"]
                     && !orphanUpdateFolded.rows.contains { $0.name == "orphan-lib" },
                     "Homebrew keeps an orphan with an update in the unneeded group, found \(orphanUpdateFolded.rows.map(\.name))")
        let formulaOnly = dependencyPackages.filter { $0.kind == .formula }
        let flatFormulaOnly = HomebrewDependencyGraph.display(formulaOnly,
                                                              installed: dependencyPackages,
                                                              groupDependencies: false)
        suite.expect(flatFormulaOnly.rows.count == formulaOnly.count
                     && flatFormulaOnly.rows.allSatisfy { $0.kind == .formula },
                     "Homebrew flat mode keeps the active filter and its displayed count")
        let formulaOnlyFolded = HomebrewDependencyGraph.fold(formulaOnly, installed: dependencyPackages)
        suite.expect(formulaOnlyFolded.rows.map(\.name).contains("cask-lib")
                     && formulaOnlyFolded.orphans.map(\.name) == ["orphan-lib"],
                     "Homebrew shows a cask's dependency as a row, not an orphan, when the filter hides the cask")
        let oldBrewPackages = (try? HomebrewParser.parseInfoJSON(Data(dependencyJSON
            .replacingOccurrences(of: "\"installed_on_request\": true,", with: "")
            .replacingOccurrences(of: "\"installed_on_request\": false,", with: "").utf8))) ?? []
        let oldBrewFolded = HomebrewDependencyGraph.fold(oldBrewPackages, installed: oldBrewPackages)
        suite.expect(oldBrewFolded.rows.count == 8 && oldBrewFolded.dependencies.isEmpty && oldBrewFolded.orphans.isEmpty,
                     "Homebrew keeps the flat list when brew does not report installed_on_request, found \(oldBrewFolded.rows.count)")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.homebrewGroupDependencies] as? Bool == true
                     && SettingsBackupSupport.exportKeys().contains(DefaultsKey.homebrewGroupDependencies),
                     "Homebrew grouping remains the default and the alternative layout travels with settings backups")
        let searchPackages = HomebrewParser.parseSearchOutput("sample-formula\nbad token\nsample-filter\nsample-tool\n",
                                                              kind: .formula,
                                                              installed: homebrewPackages)
        suite.expect(searchPackages.map(\.name) == ["sample-formula", "sample-filter", "sample-tool"],
               "Homebrew search parser keeps valid one-token results")
        let analyticsJSON = """
        {
          "category": "formula_install_on_request",
          "formulae": {
            "sample-formula": [
              { "formula": "sample-formula", "count": "21,557" },
              { "formula": "sample-formula --HEAD", "count": "30" }
            ],
            "sample-filter": [
              { "formula": "sample-filter", "count": "42,001" }
            ]
          }
        }
        """
        let popularity = (try? HomebrewAnalytics.parse(Data(analyticsJSON.utf8), kind: .formula)) ?? [:]
        suite.expect(popularity["sample-formula"]?.count == 21_557,
               "Homebrew analytics parser prefers the exact formula count")
        suite.expect(popularity["sample-filter"]?.rank == 1,
               "Homebrew analytics parser ranks by count")
        let rankedPackages = HomebrewAnalytics.enrichAndSort(searchPackages, popularity: popularity)
        suite.expect(rankedPackages.map(\.name) == ["sample-filter", "sample-formula", "sample-tool"],
               "Homebrew search results sort by popularity first")
        suite.expect(rankedPackages.first?.popularity?.compactCount == "42K",
               "Homebrew search results keep compact popularity")
        var newlyInstalled = rankedPackages[0]
        newlyInstalled.installedVersion = "2.0"
        let afterInstall = HomebrewSearchResults.reconciled(rankedPackages, installed: [newlyInstalled])
        suite.expect(afterInstall.first?.isInstalled == true
                     && afterInstall.first?.popularity == rankedPackages.first?.popularity,
                     "Homebrew search shows an installed package without losing its popularity")
        let afterUninstall = HomebrewSearchResults.reconciled(afterInstall, installed: [])
        suite.expect(afterUninstall.first?.isInstalled == false
                     && afterUninstall.map(\.id) == rankedPackages.map(\.id),
                     "Homebrew search returns to an installable result after uninstall")

        // MARK: Repository-wide source contracts

        // Reading a file is not a drawing step. The watermark logo was being
        // decoded inside the preview's body, so every frame of an opacity
        // drag re-read it from disk; it is loaded once per chosen file now,
        // which is what a task is for.
        let uiPrefix = "Sources/Lattice/UI/"
        let allUIFiles = repository.swiftPaths.filter { $0.hasPrefix(uiPrefix) }
        var decodingInBody: [String] = []
        for path in allUIFiles {
            let lines = repository.lines(at: path)
            for (index, line) in lines.enumerated() {
                let reads = line.contains("NSImage(contentsOfFile:")
                    || line.contains("Data(contentsOf:")
                guard reads else { continue }
                let around = lines[max(0, index - 6)...min(lines.count - 1, index + 2)]
                if !around.contains(where: { $0.contains(".task(") || $0.contains("func ")
                                             || $0.contains("Task {") }) {
                    decodingInBody.append("\(path):\(index + 1)")
                }
            }
        }
        suite.expect(decodingInBody.isEmpty,
               "a view reads a file once, never while drawing (\(decodingInBody.joined(separator: ", ")))")

        // An unpinned borderless Menu claims the free width of its row on
        // macOS 15 and starves whatever shares that row (issue #569), so the
        // rule is checked for every borderless menu in the app rather than for
        // the one this fix touches.
        var unpinnedBorderlessMenus: [String] = []
        let uiFiles = allUIFiles.filter { !$0.contains(" 2") }
        for path in uiFiles {
            let file = String(path.dropFirst(uiPrefix.count))
            let lines = repository.lines(at: path)
            for (index, line) in lines.enumerated()
            where line.contains(".menuStyle(.borderlessButton)") {
                // Read to the end of the menu's own modifier chain: the next
                // line that is neither a modifier nor a comment belongs to
                // something else.
                var pinned = false
                var cursor = index + 1
                while cursor < lines.count {
                    let text = lines[cursor].trimmingCharacters(in: .whitespaces)
                    guard text.hasPrefix(".") || text.hasPrefix("//") else { break }
                    if text.hasPrefix(".fixedSize()") { pinned = true; break }
                    cursor += 1
                }
                if !pinned { unpinnedBorderlessMenus.append("\(file):\(index + 1)") }
            }
        }
        suite.expect(!uiFiles.isEmpty && unpinnedBorderlessMenus.isEmpty,
               "every borderless menu keeps its own size, across \(uiFiles.count) "
               + "scanned files: \(unpinnedBorderlessMenus)")

        // `waitUntilAllOperationsAreFinished` has no deadline, and the window
        // walk that used it runs on the main thread while its operations run on
        // the shared dispatch pool. Once unrelated work had taken every worker
        // in that pool, not one operation started and the wait never returned,
        // taking the whole app with it (issue #971).
        let appPrefix = "Sources/Lattice/"
        let appSources = repository.swiftPaths.filter {
            $0.hasPrefix(appPrefix) && !$0.contains(" 2")
        }
        var unboundedOperationWaits: [String] = []
        for path in appSources {
            let file = String(path.dropFirst(appPrefix.count))
            for (index, line) in repository.lines(at: path).enumerated()
            where line.contains("waitUntilAllOperationsAreFinished") {
                unboundedOperationWaits.append("\(file):\(index + 1)")
            }
        }
        suite.expect(!appSources.isEmpty && unboundedOperationWaits.isEmpty,
               "no operation queue is waited on without a deadline: \(unboundedOperationWaits)")

        // Asking an application element for its role switches a Chromium app's
        // renderers into full accessibility mode for the rest of the process's
        // life. Both scans report real line numbers, so comments are excluded
        // in the predicate rather than removed from the source.
        func isCommentLine(_ line: String) -> Bool {
            line.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        var applicationRoleReads: [String] = []
        for path in appSources {
            let file = String(path.dropFirst(appPrefix.count))
            let lines = repository.lines(at: path)
            var applicationElements: Set<String> = []
            for line in lines where line.contains("AXUIElementCreateApplication(") {
                let assigned = (line.components(separatedBy: "=").first ?? "")
                    .trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: " ")
                guard assigned.count == 2, assigned[0] == "let" || assigned[0] == "var" else { continue }
                applicationElements.insert(assigned[1])
            }
            for (index, line) in lines.enumerated()
            where line.contains("kAXRoleAttribute")
                && !isCommentLine(line)
                && applicationElements.contains(where: { line.contains("(\($0), ") }) {
                applicationRoleReads.append("\(file):\(index + 1)")
            }
        }
        suite.expect(!appSources.isEmpty && applicationRoleReads.isEmpty,
               "no application element is ever asked for its role: \(applicationRoleReads)")

        // The snippet probe asks whatever app is in front while typing waits,
        // so its questions share one deadline, and a spent one stops them: a
        // zero timeout means the system default, which is seconds.
        let readerLines = repository.lines(at: appPrefix + "Services/SelectedTextReader.swift")
            .filter { !isCommentLine($0) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let focusedTextProbe = readerLines
            .drop(while: { !$0.hasPrefix("func text(in range: NSRange)") })
            .prefix(while: { !$0.hasPrefix("private static func limit(") })
        suite.expect(readerLines.contains("guard left > 0 else { return false }")
               && focusedTextProbe.filter { $0.contains("limit(") }.count == 5
               && focusedTextProbe.filter { $0.contains("copyElement(") || $0.contains("copyValue(")
                   || $0.contains("copyString(") }.count == 5
               && focusedTextProbe.contains("guard textLength <= wholeValueLimit,")
               && !focusedTextProbe.contains(where: {
                   $0.contains("kAXRoleAttribute") || $0.contains("AXUIElementSetMessagingTimeout")
               }),
               "the focused text probe asks every question within one deadline, never a role, and copies only a short value whole")

        // A walk up kAXParent reaches an application element without naming it,
        // so every such walk must stop before asking that parent for its role.
        var unguardedParentWalks: [String] = []
        for path in appSources {
            let file = String(path.dropFirst(appPrefix.count))
            let lines = repository.lines(at: path)
            for (index, line) in lines.enumerated()
            where line.contains("role(of: parent)") && !isCommentLine(line) {
                let guarded = lines[max(0, index - 3)..<index]
                    .contains { $0.contains("isApplicationElement(parent)") && !isCommentLine($0) }
                if !guarded { unguardedParentWalks.append("\(file):\(index + 1)") }
            }
        }
        suite.expect(!appSources.isEmpty && unguardedParentWalks.isEmpty,
               "a walk up the parent chain stops at the application element: \(unguardedParentWalks)")

        // Production availability writers cannot bypass the hardware gate.
        // The layout-only host is compiled out of release builds and refuses
        // real app identities before writing its isolated preview preferences.
        var availabilityWriters: Set<String> = []
        for path in repository.swiftPaths {
            if path.contains("/Support/") && path.hasSuffix("Probe.swift") { continue }
            let writes = repository.lines(at: path).contains {
                $0.contains(".set(") && $0.contains("availabilityKey")
            }
            if writes { availabilityWriters.insert((path as NSString).lastPathComponent) }
        }
        suite.expect(availabilityWriters == ["FeatureRuntime.swift",
                                       "Defaults.swift"],
               "feature availability is written only where the hardware gate runs, "
               + "found \(availabilityWriters.sorted())")
        let preview = repository.source(at: "Sources/Lattice/Support/SettingsPresentationProbe.swift")
        suite.expect(preview.hasPrefix("#if LATTICE_DEVELOPMENT")
                     && preview.contains("hasPrefix(\"io.github.sam32j.lattice.tests.\") == true")
                     && preview.contains("exit(2)"),
                     "the layout-only preview refuses production identities and never ships in release builds")

        // A saved shelf may only be read through the loader that distinguishes
        // an unreadable or partial store from a valid empty one.
        let rawShelfStoreDecoders = repository.swiftPaths.compactMap { path in
            repository.source(at: path).contains("decode([ShelfPersistedItem]")
                ? (path as NSString).lastPathComponent : nil
        }
        suite.expect(!repository.swiftPaths.isEmpty && rawShelfStoreDecoders.isEmpty,
               "the saved shelf is read only through ShelfPersistenceSupport.load, "
               + "found a bare decode in \(rawShelfStoreDecoders.sorted()) "
               + "across \(repository.swiftPaths.count) scanned files")

        var bareActivationYields: [String] = []
        for path in repository.swiftPaths
        where (path as NSString).lastPathComponent != "ActivationHandoff.swift"
            && repository.source(at: path).contains("yieldActivation") {
            bareActivationYields.append((path as NSString).lastPathComponent)
        }
        suite.expect(!repository.swiftPaths.isEmpty && bareActivationYields.isEmpty,
               "activation is yielded only through ActivationHandoff, "
               + "found a bare yield in \(bareActivationYields.sorted()) "
               + "across \(repository.swiftPaths.count) scanned files")

        // Dropping the last Swift reference does not deregister an event tap;
        // every literal tap creation needs a matching invalidation or removal.
        var tapOwnersWithoutInvalidate: [String] = []
        var tapOwners = 0
        for path in appSources {
            let code = repository.lines(at: path)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            let taps = code.components(separatedBy: "InputEventTap.create").count - 1
            guard taps > 0 else { continue }
            tapOwners += 1
            let invalidations = code.components(separatedBy: "CFMachPortInvalidate").count - 1
                + (code.components(separatedBy: "PointerTapRunLoop.remove(").count - 1)
            if invalidations < taps {
                let file = String(path.dropFirst(appPrefix.count))
                tapOwnersWithoutInvalidate.append("\(file) (\(taps) taps, \(invalidations) invalidated)")
            }
        }
        suite.expect(tapOwners > 0 && tapOwnersWithoutInvalidate.isEmpty,
               "every event tap owner invalidates its port on teardown, across "
               + "\(tapOwners) scanned owners: \(tapOwnersWithoutInvalidate)")

        // MARK: Localization source contracts

        // Visible localization source uses typographic apostrophes rather than
        // typewriter marks.
        let localizationSourcePaths = repository.swiftPaths.filter { path in
            let folder = (path as NSString).deletingLastPathComponent
            let name = (path as NSString).lastPathComponent
            return (folder == "Sources/Lattice/Core"
                    || folder == "Sources/Lattice/Core/Localizations")
                && (name.hasSuffix("Strings.swift") || name.hasPrefix("Strings+")
                    || name == "Localization.swift")
        }
        var typewriterMarks: [String] = []
        for path in localizationSourcePaths {
            for (index, line) in repository.lines(at: path).enumerated() {
                guard !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") else { continue }
                guard let opening = line.firstIndex(of: "\""),
                      let closing = line.lastIndex(of: "\""), opening < closing else { continue }
                if line[opening..<closing].contains("'") {
                    typewriterMarks.append("\(path):\(index + 1)")
                }
            }
        }
        suite.expect(typewriterMarks.isEmpty,
               "visible text curls its apostrophes (\(typewriterMarks.prefix(6).joined(separator: ", ")))")

        // French double punctuation and guillemets use non-breaking spaces.
        func frenchLines(_ path: String) -> ArraySlice<String> {
            let lines = repository.lines(at: path)
            guard !path.hasSuffix("Strings+French.swift") else { return lines[...] }
            guard let start = lines.firstIndex(where: {
                $0.trimmingCharacters(in: .whitespaces).hasPrefix("static let fr = ")
            }) else { return [][...] }
            let end = lines[(start + 1)...].firstIndex {
                $0.trimmingCharacters(in: .whitespaces).hasPrefix("static let ")
            } ?? lines.endIndex
            return lines[start..<end]
        }
        let frenchSources = repository.swiftPaths.filter { path in
            path == "Sources/Lattice/Core/Localizations/Strings+French.swift"
                || ((path as NSString).deletingLastPathComponent == "Sources/Lattice/Core"
                    && path.hasSuffix("Strings.swift"))
        }
        var breakingFrench: [String] = []
        for path in frenchSources {
            for line in frenchLines(path) {
                guard !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") else { continue }
                guard let opening = line.firstIndex(of: "\""),
                      let closing = line.lastIndex(of: "\""), opening < closing else { continue }
                let body = String(line[line.index(after: opening)..<closing])
                let breaks = [" ;", " :", " !", " ?", " \u{00BB}", "\u{00AB} "]
                if breaks.contains(where: { body.contains($0) }) {
                    breakingFrench.append((path as NSString).lastPathComponent)
                }
            }
        }
        suite.expect(breakingFrench.isEmpty,
               "French keeps its punctuation on the line it belongs to (\(Set(breakingFrench).sorted().prefix(4).joined(separator: ", ")))")

        let themeSource = repository.source(at: "Sources/Lattice/UI/Theme.swift")
        let raisedReads = themeSource
            .components(separatedBy: "accessibilityDisplayShouldIncreaseContrast").count - 1
        suite.expect(raisedReads == 2,
               "both panel outlines answer raised contrast, and nothing else pretends to")

        // Every formatted decimal explicitly chooses its locale. Long calls
        // may put that locale on either of the next two lines.
        var regionlessDecimals: [String] = []
        for path in repository.swiftPaths {
            let lines = repository.lines(at: path)
            for (index, line) in lines.enumerated() {
                let statement = lines[index...min(index + 2, lines.count - 1)].joined()
                guard line.contains("String(format:"), !statement.contains("locale:") else { continue }
                let piece = line.components(separatedBy: "String(format:").dropFirst().first ?? ""
                let format = piece.components(separatedBy: "\"").dropFirst().first ?? ""
                if format.contains("f") && format.contains("%") {
                    regionlessDecimals.append("\(path):\(index + 1)")
                }
            }
        }
        suite.expect(regionlessDecimals.isEmpty,
               "a decimal on screen names its region (\(regionlessDecimals.joined(separator: ", ")))")

        // Purgeable space is queried only for writable volumes.
        let samplerCode = repository.lines(
            at: "Sources/Lattice/Services/Metrics/DiskSampler.swift")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        suite.expect(!samplerCode.isEmpty, "the disk sampler reads back for its shape check")
        let bulkKeys = samplerCode.components(separatedBy: "let keys: Set<URLResourceKey>")
            .dropFirst().first?.components(separatedBy: "]").first ?? ""
        suite.expect(!bulkKeys.contains("volumeAvailableCapacityForImportantUsageKey")
                && bulkKeys.contains("volumeIsReadOnlyKey"),
               "the bulk volume fetch asks nothing that only a writable volume can answer")
        suite.expect(samplerCode.contains("guard !isReadOnly,"),
               "purgeable space is read only where there is something to purge")

        // Only localized fields that reach String(format:) need matching
        // placeholders in every language.
        var formatFields: Set<String> = []
        for path in repository.swiftPaths {
            for piece in repository.source(at: path).components(separatedBy: "String(format:").dropFirst() {
                let head = piece.prefix(120)
                guard let comma = head.firstIndex(of: ",") else { continue }
                let expression = head[head.startIndex..<comma]
                guard let dot = expression.lastIndex(of: ".") else { continue }
                let name = expression[expression.index(after: dot)...]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty, name.allSatisfy({ $0.isLetter || $0.isNumber }) {
                    formatFields.insert(name)
                }
            }
        }
        suite.expect(formatFields.count > 10, "the format fields were found to compare (\(formatFields.count))")
        var mismatched: [String] = []
        for (language, strings) in LocalizationTests.languages where language != .enUS {
            let mine = Mirror(reflecting: strings).children
            let base = Mirror(reflecting: Strings.enUS).children
            for (left, right) in zip(base, mine) {
                guard let label = left.label, formatFields.contains(label),
                      let english = left.value as? String,
                      let other = right.value as? String else { continue }
                if TestFormat.parse(english) == nil
                    || TestFormat.parse(english)?.arguments != TestFormat.parse(other)?.arguments {
                    mismatched.append("\(label)/\(language.rawValue)")
                }
            }
        }
        suite.expect(mismatched.isEmpty,
               "every language fills a format the same way (\(mismatched.prefix(5).joined(separator: ", ")))")

        // Every literal SF Symbol name resolves on the test system.
        var symbolNames: Set<String> = []
        for path in repository.swiftPaths {
            for piece in repository.source(at: path).components(separatedBy: "systemName: \"").dropFirst() {
                guard let end = piece.firstIndex(of: "\"") else { continue }
                let name = String(piece[piece.startIndex..<end])
                if !name.isEmpty, !name.contains("\\") { symbolNames.insert(name) }
            }
        }
        suite.expect(symbolNames.count > 80, "the symbol names were found (\(symbolNames.count))")
        var missingSymbols: [String] = []
        for name in symbolNames.sorted()
        where NSImage(systemSymbolName: name, accessibilityDescription: nil) == nil {
            missingSymbols.append(name)
        }
        suite.expect(missingSymbols.isEmpty,
               "every symbol the app draws exists (\(missingSymbols.joined(separator: ", ")))")

        // Every literal resource name requested by Swift is shipped or staged
        // by the build.
        var namedResources: Set<String> = []
        for path in repository.swiftPaths {
            let text = repository.source(at: path)
            for marker in ["url(forResource: \"", "path(forResource: \"", "NSImage(named: \""] {
                for piece in text.components(separatedBy: marker).dropFirst() {
                    guard let end = piece.firstIndex(of: "\"") else { continue }
                    let name = String(piece[piece.startIndex..<end])
                    if !name.isEmpty, !name.contains("\\") { namedResources.insert(name) }
                }
            }
        }
        suite.expect(namedResources.count >= 5, "the named resources were found (\(namedResources.count))")
        var shippedNames: Set<String> = []
        for path in (try? FileManager.default.subpathsOfDirectory(atPath: "Resources")) ?? [] {
            let file = (path as NSString).lastPathComponent
            shippedNames.insert((file as NSString).deletingPathExtension)
            shippedNames.insert(file)
        }
        suite.expect(!buildScript.isEmpty, "the build script reads back for its resource names")
        for word in buildScript.components(separatedBy: CharacterSet(charactersIn: " \n\t\"'()")) {
            let file = (word as NSString).lastPathComponent
            guard !file.isEmpty else { continue }
            shippedNames.insert((file as NSString).deletingPathExtension)
            shippedNames.insert(file)
        }
        shippedNames.insert("CHANGELOG")
        let absentResources = namedResources.filter { !shippedNames.contains($0) }.sorted()
        suite.expect(absentResources.isEmpty,
               "every file the app asks for by name is in the bundle (\(absentResources.joined(separator: ", ")))")

        // Embedded Finder scripts are compiled only when they run, so verify
        // that every multiline tell/repeat block balances here.
        var unbalancedScripts: [String] = []
        for path in repository.swiftPaths {
            let text = repository.source(at: path)
            for chunk in text.components(separatedBy: "\"\"\"").enumerated()
            where chunk.offset % 2 == 1 && chunk.element.contains("tell application") {
                let body = chunk.element.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                func opens(_ word: String, closing: String, inline: (String) -> Bool) -> Bool {
                    let started = body.filter { $0.hasPrefix(word + " ") && !inline($0) }.count
                    let ended = body.filter { $0 == closing }.count
                    return started != ended
                }
                let name = (path as NSString).lastPathComponent
                if opens("tell", closing: "end tell", inline: { $0.contains(" to ") }) {
                    unbalancedScripts.append("\(name):tell")
                }
                if opens("repeat", closing: "end repeat", inline: { _ in false }) {
                    unbalancedScripts.append("\(name):repeat")
                }
            }
        }
        suite.expect(unbalancedScripts.isEmpty,
               "every embedded script closes what it opens (\(unbalancedScripts.joined(separator: ", ")))")

        // Absolute command-line tool paths embedded in Swift must exist.
        var toolPaths: Set<String> = []
        for path in repository.swiftPaths {
            for piece in repository.source(at: path).components(separatedBy: "\"/").dropFirst() {
                guard let end = piece.firstIndex(of: "\"") else { continue }
                let candidate = "/" + piece[piece.startIndex..<end]
                guard candidate.hasPrefix("/bin/") || candidate.hasPrefix("/usr/bin/")
                        || candidate.hasPrefix("/usr/sbin/") else { continue }
                guard !candidate.contains(" "), !candidate.contains("\\") else { continue }
                toolPaths.insert(candidate)
            }
        }
        suite.expect(toolPaths.count >= 15, "the system tools were found (\(toolPaths.count))")
        let missingTools = toolPaths.sorted().filter {
            !FileManager.default.fileExists(atPath: $0)
        }
        suite.expect(missingTools.isEmpty,
               "every system tool the app runs is where it expects (\(missingTools.joined(separator: ", ")))")

        // User-file stores delete only paths whose ownership is established in
        // the local scope immediately before removal.
        var ungardedDeletes: [String] = []
        let ownershipGuards = ["isShelfOwnedFile", "discardablePaths", "ownedPayloadURLs",
                               "isRegularFile", "tempDir", "legacyDir", "root", "uuidString",
                               "storeRoot", "contentsOfDirectory"]
        for path in ["Sources/Lattice/Services/Shelf/ShelfService.swift",
                     "Sources/Lattice/Services/QuickTools/RecentCaptureService.swift",
                     "Sources/Lattice/Services/QuickTools/RecentCaptureStore.swift"] {
            let lines = repository.lines(at: path)
            suite.expect(!lines.isEmpty, "the store source reads back for its deletion check")
            for (index, line) in lines.enumerated() where line.contains("removeItem(at:") {
                let scope = lines[max(0, index - 10)...index].joined(separator: "\n")
                if !ownershipGuards.contains(where: scope.contains) {
                    ungardedDeletes.append("\((path as NSString).lastPathComponent):\(index + 1)")
                }
            }
        }
        suite.expect(ungardedDeletes.isEmpty,
               "a file is deleted only after the app checks it owns it (\(ungardedDeletes.joined(separator: ", ")))")

        // MARK: Result

        // MARK: Every temp dir build.sh stages in is swept when the script ends
        // `mktemp -d` lands outside the repo, so a dir the script does not
        // remove survives the run — a successful one as much as a failed one.
        // The sweep is therefore a trap, and a staging dir added later leaks on
        // every build until it is named in cleanup(). The names are read out of
        // the script so the two cannot drift apart.
        // The trap has to be installed before the first dir exists: a failure
        // between `mktemp -d` and a later `trap` leaks exactly as before.
        let sweepInstalled = buildScript.range(of: "trap cleanup EXIT")?.lowerBound
        let firstStaged = buildScript.range(of: "mktemp -d")?.lowerBound
        suite.expect(sweepInstalled != nil && firstStaged != nil && sweepInstalled! < firstStaged!,
               "build.sh installs the temp dir sweep before it stages the first dir")
        // zsh runs the EXIT trap on HUP but not on INT or TERM, so the signals
        // have to reach it through `exit` or Ctrl-C leaks the staged bundle.
        let signalsRouted = buildScript.range(of: "trap 'exit 1' INT TERM HUP")?.lowerBound
        suite.expect(signalsRouted != nil && firstStaged != nil && signalsRouted! < firstStaged!,
               "build.sh routes interrupts through the sweep before it stages the first dir")
        let cleanupBody = buildScript.components(separatedBy: "cleanup() {")
            .dropFirst().first?.components(separatedBy: "\n}").first ?? ""
        let stagedTempDirs = buildScript.components(separatedBy: "=\"$(mktemp -d)\"")
            .dropLast()
            .compactMap {
                $0.split(whereSeparator: { $0.isNewline || $0 == " " || $0 == "\t" })
                    .last.map(String.init)
            }
        suite.expect(!stagedTempDirs.isEmpty, "the staged temp dirs read back out of build.sh")
        // A dir reached through a path suffix — `X="$(mktemp -d)/name"` — puts
        // the parent in no variable at all, which is how the bundle staging dir
        // leaked. Every call has to be captured whole to be sweepable.
        suite.expect(buildScript.components(separatedBy: "mktemp -d").count - 1 == stagedTempDirs.count,
               "every mktemp -d in build.sh is a whole capture — no path suffix, no other spelling")
        for variable in Set(stagedTempDirs) {
            suite.expect(cleanupBody.contains("\"$\(variable)\""),
                   "temp dir \(variable) is swept by build.sh cleanup()")
            // The sweep runs under `set -u` before the dir is staged: an entry
            // whose variable is not empty first aborts cleanup() at that line,
            // leaving everything listed below it unswept and the exit status
            // untouched. The empty assignment is the third line of the pattern.
            // The leading newline keeps ICON_TMP off STAGE_ICON_TMP.
            let initialized = buildScript.range(of: "\n\(variable)=\"\"")?.lowerBound
            suite.expect(initialized != nil && sweepInstalled != nil && initialized! < sweepInstalled!,
                   "temp dir \(variable) is empty before the sweep is installed")
        }

        // Lattice signing is explicitly configured; it never provisions the upstream identity.
        let buildScriptCode = buildScript.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
        // The setup script must run against the stock /usr/bin/openssl, which
        // is LibreSSL: it rejects OpenSSL 3's -legacy flag outright, and the
        // script once died on exactly that with its stderr discarded. The
        // portable spelling names the PBE algorithms instead of the flag.
        let signingSetup = (try? String(contentsOfFile: "Tools/setup-signing.sh",
                                         encoding: .utf8)) ?? ""
        suite.expect(!signingSetup.isEmpty, "the signing setup script reads back for its shape check")
        let signingSetupCode = signingSetup.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
            .joined(separator: "\n")
        suite.expect(!signingSetupCode.contains("-legacy"),
               "setup-signing.sh avoids the -legacy flag the stock LibreSSL openssl rejects")

        // MARK: The stable identity is judged by whether codesign can sign with it
        // A find-identity listing names certificates codesign then rejects, and
        // -v excludes every self-signed one, so neither spelling may decide.
        for (script, code, identity) in [("build.sh", buildScriptCode, "$LEGACY_IDENTITY"),
                                         ("Tools/setup-signing.sh", signingSetupCode.components(separatedBy: "\n"),
                                          "$IDENTITY")] {
            suite.expect(!code.contains { $0.contains("find-identity") && $0.contains(identity) },
                   "\(script) never decides the stable identity by a find-identity listing")
            suite.expect(code.contains { $0.contains("cp /bin/echo") }
                    && code.contains { $0.contains("--sign \"\(identity)\" \"$probe\"") },
                   "\(script) asks codesign to sign a throwaway copy of /bin/echo with the stable identity")
        }

        // MARK: Uninstallation paths stay aligned across SelfUninstall and Tools/uninstall.sh
        let selfUninstallSource = repository.source(
            at: "Sources/Lattice/Services/SelfUninstall.swift")
        let uninstallScriptSource = (try? String(contentsOfFile: "Tools/uninstall.sh",
                                                encoding: .utf8)) ?? ""
        suite.expect(!selfUninstallSource.isEmpty && !uninstallScriptSource.isEmpty,
               "uninstall sources read back for uninstallation alignment check")
        suite.expect(selfUninstallSource.contains("CleaningModeManager.shared.deactivateForSystemTeardown()"),
               "permission reset removes the cleaning input tap synchronously")
        let queryHabitSupportSource = repository.source(
            at: "Sources/Lattice/Services/CommandBar/CommandBarSupport.swift")
        let queryHabitServiceSource = repository.source(
            at: "Sources/Lattice/Services/CommandBar/CommandBarService.swift")
        suite.expect(!queryHabitSupportSource.isEmpty
                && !queryHabitServiceSource.isEmpty
                && !queryHabitSupportSource.contains("SecItem")
                && !queryHabitSupportSource.contains("import Security")
                && !selfUninstallSource.contains("removeInstallationKey")
                && !uninstallScriptSource.contains("delete-generic-password")
                && queryHabitServiceSource.contains("DefaultsKey.commandBarQueryHabits"),
               "query learning persists locally without Keychain access")
        let requiredSubpaths = ["Library/Application Support", "Library/Caches", "Library/HTTPStorages"]
        for subpath in requiredSubpaths {
            suite.expect(selfUninstallSource.contains(subpath) && uninstallScriptSource.contains(subpath),
                   "both in-app and script uninstall sweep \(subpath)")
        }
        suite.expect(uninstallScriptSource.contains("Library/Preferences/ByHost"),
               "script uninstall sweeps ByHost preferences")
        // zsh passes a plain string to a command as one word, so the script
        // keeps the closed-lid rule names in an array. They must be the files
        // the current app variant owns, without removing the other variant.
        func sudoersRuleFiles(_ text: String) -> Set<String> {
            Set(text.components(separatedBy: CharacterSet(charactersIn: " \n\t\"(),"))
                .filter { $0.hasPrefix("/etc/sudoers.d/") })
        }
        let scriptRuleFiles = sudoersRuleFiles(uninstallScriptSource.components(separatedBy: "\n")
            .first { $0.hasPrefix("RULES=(") } ?? "")
        suite.expect(scriptRuleFiles == [Sudoers.rulePath],
               "script uninstall looks for the same closed-lid rule files as the app: \(scriptRuleFiles.sorted())")
        // Restoring sleep used to be fired and forgotten at both exits. A
        // failure there leaves `pmset disablesleep 1` set system-wide, and
        // removal deletes the flag that launch-time recovery reads before it
        // reads the setting, so nothing repairs it afterwards — a reinstall
        // included.
        let uninstallerSource = repository.source(
            at: "Sources/Lattice/Support/Uninstaller.swift")
        suite.expect(!uninstallerSource.isEmpty,
               "uninstaller entry point reads back for the sleep restore check")
        suite.expect(!selfUninstallSource.contains("_ = Sudoers.pmsetDisableSleep")
                && !uninstallerSource.contains("_ = Sudoers.pmsetDisableSleep"),
               "neither uninstall path discards the result of restoring sleep")
        suite.expect(selfUninstallSource.contains("SpacesOrderHold.restoreForRemoval(), restoreSleepBeforeRemoval()")
                && selfUninstallSource.contains("restoreSleepBeforeRemoval() -> Bool")
                && selfUninstallSource.contains("guard detachFanControl() else")
                && selfUninstallSource.contains("FanControlService.restoreAndUnregisterForRemoval()")
                && selfUninstallSource.contains("adminPromptRecover")
                && selfUninstallSource.contains("verification.status == 0"),
               "in-app uninstall aborts unless fans and normal sleep are restored before removal")
        suite.expect(uninstallerSource.contains("SpacesOrderHold.restoreForRemoval()"),
               "script uninstall puts back the Space rearranging setting before the preferences are deleted")
        suite.expect(uninstallScriptSource.contains("SleepDisabled"),
               "script uninstall reads the sleep setting back for itself")
        suite.expect(uninstallScriptSource.contains("spaces_read_domain \"$BUNDLE\"")
                && uninstallScriptSource.contains("spaces_recovery_value \"$spaces_snapshot\" \(DefaultsKey.spacesOrderRestore)")
                && uninstallScriptSource.contains("spaces_recovery_value \"$spaces_snapshot\" \(DefaultsKey.spacesOrderRestartPending)")
                && uninstallScriptSource.contains("spaces_read_domain com.apple.dock")
                && uninstallScriptSource.contains("spaces_stuck == 0")
                && uninstallScriptSource.contains("spaces_unloaded == 0")
                && uninstallScriptSource.contains("spaces_unknown == 0")
                && !uninstallScriptSource.contains("defaults write com.apple.dock")
                && !uninstallScriptSource.contains("killall"),
               "script uninstall reads Space rearranging back for itself and never changes it")
        let brightnessSource = repository.source(
            at: "Sources/Lattice/Services/Display/BrightnessService.swift")
        let brightnessTapMethod = brightnessSource
            .components(separatedBy: "    func suspendInputTaps()").dropFirst().first?
            .components(separatedBy: "    private func installFunctionKeyTap").first ?? ""
        let brightnessTapCode = brightnessTapMethod.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        suite.expect(selfUninstallSource.contains("TextSnippetService.shared.suspend()")
                && selfUninstallSource.contains("QuitProtectionService.shared.suspend()")
                && selfUninstallSource.contains("BrightnessService.shared.suspendInputTaps()")
                && selfUninstallSource.contains("BrightnessService.shared.resumeInputTaps()")
                && brightnessTapCode.contains("inputTapsSuspended = true")
                && brightnessTapCode.contains("removeKeyTap()")
                && brightnessTapCode.contains("removeFunctionKeyTap()")
                && !brightnessTapCode.contains("restoreManagedDisplays")
                && !brightnessTapCode.contains("restoreAllGamma"),
               "the permission teardown stops every persistent keyboard tap")
        let quitProtectionSource = repository.source(
            at: "Sources/Lattice/Services/QuitProtection/QuitProtectionService.swift")
        suite.expect(quitProtectionSource.contains("func suspend()"),
               "quit protection exposes the teardown the permission reset calls")

        // MARK: Secure input

        // The session records the app that was active when secure input
        // turned on, not the process holding it, and Settings makes
        // Lattice that app.
        let secureInputOwnPid: pid_t = 77
        suite.expect(SecureInputSupport.holder(isEnabled: false,
                                         read: .noHolder,
                                         ownPid: secureInputOwnPid,
                                         runningApp: { _ in nil },
                                         isProcessAlive: { _ in true }) == .off,
               "secure input off with no recorded app is off")
        var secureInputNameLookups = 0
        let secureInputOffWithPid = SecureInputSupport.holder(
            isEnabled: false,
            read: .holder(4242),
            ownPid: secureInputOwnPid,
            runningApp: { pid in
                secureInputNameLookups += 1
                return ("SomeBrowser", pid)
            },
            isProcessAlive: { _ in true })
        suite.expect(secureInputOffWithPid == .off,
               "secure input off stays off even with a pid still recorded")
        suite.expect(SecureInputSupport.holder(isEnabled: false,
                                         read: .unavailable,
                                         ownPid: secureInputOwnPid,
                                         runningApp: { _ in nil },
                                         isProcessAlive: { _ in true }) == .off,
               "secure input off stays off when the session cannot be read")
        suite.expect(secureInputNameLookups == 0,
               "the name lookup is skipped when secure input is off")

        suite.expect(SecureInputSupport.holder(isEnabled: true,
                                         read: .holder(999),
                                         ownPid: secureInputOwnPid,
                                         runningApp: { pid in
                                             pid == 999 ? ("SomeBrowser", 4242) : nil
                                         },
                                         isProcessAlive: { _ in true })
                   == .app(name: "SomeBrowser", pid: 4242),
               "a helper pid is attributed to the app responsible for it")
        suite.expect(SecureInputSupport.holder(isEnabled: true,
                                         read: .holder(4242),
                                         ownPid: secureInputOwnPid,
                                         runningApp: { _ in nil },
                                         isProcessAlive: { _ in true }) == .unknown,
               "a running process that is no regular app is never sent to log out")
        suite.expect(SecureInputSupport.holder(isEnabled: true,
                                         read: .holder(4242),
                                         ownPid: secureInputOwnPid,
                                         runningApp: { _ in nil },
                                         isProcessAlive: { _ in false }) == .unattributed,
               "once the recorded app has quit, a new login session is the fallback")
        suite.expect(SecureInputSupport.holder(isEnabled: true,
                                         read: .noHolder,
                                         ownPid: secureInputOwnPid,
                                         runningApp: { _ in nil },
                                         isProcessAlive: { _ in true }) == .unattributed,
               "secure input on with no recorded app is unattributed")
        suite.expect(SecureInputSupport.holder(isEnabled: true,
                                         read: .holder(0),
                                         ownPid: secureInputOwnPid,
                                         runningApp: { pid in ("SomeBrowser", pid) },
                                         isProcessAlive: { _ in true }) == .unattributed,
               "a zero pid is not an attribution")
        suite.expect(SecureInputSupport.holder(isEnabled: true,
                                         read: .holder(4242),
                                         ownPid: secureInputOwnPid,
                                         runningApp: { pid in ("", pid) },
                                         isProcessAlive: { _ in false }) == .unattributed,
               "an empty app name is not an attribution")

        var secureInputOwnLivenessChecks = 0
        suite.expect(SecureInputSupport.holder(isEnabled: true,
                                         read: .holder(secureInputOwnPid),
                                         ownPid: secureInputOwnPid,
                                         runningApp: { pid in ("Lattice", pid) },
                                         isProcessAlive: { _ in
                                             secureInputOwnLivenessChecks += 1
                                             return true
                                         }) == .unknown,
               "Lattice recorded as the active app is never named as holding secure input")
        suite.expect(secureInputOwnLivenessChecks == 0,
               "naming Lattice is refused before any liveness check")
        suite.expect(SecureInputSupport.holder(isEnabled: true,
                                         read: .holder(5555),
                                         ownPid: secureInputOwnPid,
                                         runningApp: { _ in ("Lattice", secureInputOwnPid) },
                                         isProcessAlive: { _ in true }) == .unknown,
               "a recorded helper owned by Lattice is not named either")
        suite.expect(SecureInputSupport.holder(isEnabled: true,
                                         read: .holder(secureInputOwnPid),
                                         ownPid: secureInputOwnPid,
                                         runningApp: { _ in nil },
                                         isProcessAlive: { _ in true }) == .unknown,
               "Lattice recorded while it is not a regular app is never sent to log out")
        suite.expect(SecureInputSupport.holder(isEnabled: true,
                                         read: .holder(4242),
                                         ownPid: secureInputOwnPid,
                                         runningApp: { pid in ("Lattice", pid) },
                                         isProcessAlive: { _ in true })
                   == .app(name: "Lattice", pid: 4242),
               "another copy of the app is told apart from this one by pid, not by name")
        // The rule above protects the row only if the monitor passes this
        // process, and the harness does not compile `SecureInputMonitor`.
        let secureInputMonitorCode = ((try? String(
            contentsOfFile: "Sources/Lattice/Core/SecureInputMonitor.swift", encoding: .utf8)) ?? "")
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        suite.expect(secureInputMonitorCode.contains("ownPid: getpid(),"),
               "the secure input monitor passes its own pid, so the row never names Lattice")

        var secureInputUnavailableLookups = 0
        var secureInputUnavailableLivenessChecks = 0
        let secureInputUnavailable = SecureInputSupport.holder(
            isEnabled: true,
            read: .unavailable,
            ownPid: secureInputOwnPid,
            runningApp: { pid in
                secureInputUnavailableLookups += 1
                return ("SomeBrowser", pid)
            },
            isProcessAlive: { _ in
                secureInputUnavailableLivenessChecks += 1
                return true
            })
        suite.expect(secureInputUnavailable == .unknown,
               "a session that cannot be read reports an unknown holder")
        suite.expect(secureInputUnavailableLookups == 0 && secureInputUnavailableLivenessChecks == 0,
               "a session that cannot be read costs no name lookup and no liveness check")

        suite.expect(!SecureInputSupport.shouldPoll(observingSurfaceCount: 0, windowIsOpen: true),
               "secure input keeps no timer without a visible surface")
        suite.expect(SecureInputSupport.shouldPoll(observingSurfaceCount: 1, windowIsOpen: true)
                   && SecureInputSupport.shouldPoll(observingSurfaceCount: 3, windowIsOpen: true),
               "a visible surface polls secure input while the window is open")
        suite.expect(SecureInputSupport.shouldPoll(observingSurfaceCount: 1, windowIsOpen: true)
                   == SecureInputSupport.shouldPoll(observingSurfaceCount: 2, windowIsOpen: true),
               "repeating a demand does not change whether secure input polls")
        suite.expect(!SecureInputSupport.shouldPoll(observingSurfaceCount: 1, windowIsOpen: false),
               "a demand left over from before the window closed does not poll on its own")
        suite.expect(!SecureInputSupport.shouldPoll(observingSurfaceCount: 0, windowIsOpen: false),
               "neither gate alone is enough")

    }
}
