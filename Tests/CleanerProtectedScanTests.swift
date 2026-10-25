import Foundation

enum CleanerProtectedScanTests {
    static func run(_ suite: TestSuite) {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("lattice-protected-scans-\(UUID())")
        let previous = CleanerEligibilityTests.fixtureRoot
        CleanerEligibilityTests.fixtureRoot = root
        defer { CleanerEligibilityTests.fixtureRoot = previous; try? fm.removeItem(at: root) }
        do {
            for path in ["Library/Application Support/com.vendor.Orphan", "Library/Logs/com.vendor.Logs", "Library/Logs/DiagnosticReports"] {
                let candidate = root.appendingPathComponent(path)
                try fm.createDirectory(at: candidate, withIntermediateDirectories: true)
                try Data(repeating: 1, count: 8192).write(to: candidate.appendingPathComponent("eligible.bin"))
                func offered() -> Bool {
                    let items: [CleanerEligibilityTests.Item]
                    if path.contains("Application Support") {
                        var found: [CleanerEligibilityTests.Item] = []
                        CleanerEligibilityTests.appendLeftovers(in: candidate.deletingLastPathComponent().path,
                            usesContainerMetadata: false, installed: [], fm: fm, into: &found)
                        items = found
                    } else { items = CleanerEligibilityTests.scanLogs(excluding: []) }
                    return items.contains { $0.url.standardizedFileURL.path == candidate.standardizedFileURL.path }
                }
                suite.expect(offered(), "ordinary leftover/log roots remain eligible: \(path)")
                for name in ["Library.photoslibrary", "Saved.musiclibrary", "com.apple.Music"] {
                    let child = candidate.appendingPathComponent("nested/\(name)")
                    try fm.createDirectory(at: child, withIntermediateDirectories: true)
                    try Data([1]).write(to: child.appendingPathComponent("protected.data"))
                    suite.expect(!offered(), "protected descendants exclude the whole offered root: \(path), \(name)")
                    try fm.removeItem(at: child)
                }
            }
        } catch { suite.expect(false, "protected scan fixture failed: \(error)") }
    }
}
