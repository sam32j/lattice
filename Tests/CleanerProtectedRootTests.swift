import Foundation

enum CleanerProtectedRootTests {
    static func run(_ suite: TestSuite) {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("lattice-cleaner-protected-\(UUID())")
        let previous = CleanerEligibilityTests.fixtureRoot
        CleanerEligibilityTests.fixtureRoot = root
        defer {
            CleanerEligibilityTests.fixtureRoot = previous
            try? fm.removeItem(at: root)
        }
        do {
            let cache = root.appendingPathComponent("Library/Caches/com.vendor.Cache")
            try fm.createDirectory(at: cache, withIntermediateDirectories: true)
            try Data(repeating: 1, count: 8192).write(to: cache.appendingPathComponent("eligible.bin"))
            suite.expect(CleanerEligibilityTests.scanCaches(excluding: []).contains { $0.url.standardizedFileURL.path == cache.standardizedFileURL.path },
                         "ordinary cache roots remain eligible")
            for name in ["com.apple.Music", "Library.photoslibrary", "Saved.musiclibrary"] {
                let child = cache.appendingPathComponent("nested/\(name)")
                try fm.createDirectory(at: child, withIntermediateDirectories: true)
                try Data([1]).write(to: child.appendingPathComponent("protected.data"))
                suite.expect(!CleanerEligibilityTests.scanCaches(excluding: []).contains { $0.url.standardizedFileURL.path == cache.standardizedFileURL.path },
                             "a cache root containing protected descendants is never offered for whole-root removal")
                let candidate = CleanerEligibilityTests.Item(url: cache, category: .caches, detail: "com.vendor.Cache")
                suite.expect(!CleanerEligibilityTests.canRemove(candidate),
                             "the final removal guard rechecks protected descendants independently of scanning")
                try fm.removeItem(at: child)
            }
        } catch { suite.expect(false, "isolated protected-root fixture failed: \(error)") }
    }
}
