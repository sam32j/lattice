import Foundation

enum CleanerPrivacyEnumerationTests {
    private final class InspectingManager: FileManager, @unchecked Sendable {
        var prefetchedKeys: [[URLResourceKey]] = []
        override func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?,
            options mask: DirectoryEnumerationOptions = []) throws -> [URL] {
            prefetchedKeys.append(keys ?? [])
            return try super.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: mask)
        }
    }

    static func run(_ suite: TestSuite) {
        let manager = InspectingManager()
        let root = manager.temporaryDirectory.appendingPathComponent("lattice-cleaner-privacy-\(UUID())")
        do {
            try manager.createDirectory(at: root.appendingPathComponent("com.apple.Music"), withIntermediateDirectories: true)
            defer { try? manager.removeItem(at: root) }
            try Data(repeating: 1, count: 64).write(to: root.appendingPathComponent("com.apple.Music/library.data"))
            var results: [CleanerEligibilityTests.Item] = []
            CleanerEligibilityTests.appendLeftovers(in: root.path, usesContainerMetadata: true,
                installed: [], fm: manager, into: &results)
            let size = CleanerEligibilityTests.directorySize(of: root, fm: manager)
            suite.expect(!manager.prefetchedKeys.isEmpty && manager.prefetchedKeys.allSatisfy(\.isEmpty)
                         && results.isEmpty && size == 0,
                         "enumeration never prefetches protected entries' properties before privacy exclusions run")
        } catch { suite.expect(false, "isolated privacy enumeration fixture failed: \(error)") }
    }
}
