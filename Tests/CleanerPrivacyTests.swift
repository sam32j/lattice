import Foundation

enum CleanerPrivacyTests {
    static func run(_ suite: TestSuite) {
        CleanerPrivacyEnumerationTests.run(suite)
        CleanerProtectedRootTests.run(suite)
        CleanerProtectedScanTests.run(suite)
        var reads = 0
        let owner = CleanerOwnership.owner(at: URL(fileURLWithPath: "/fixture/com.apple.Music"),
            usesContainerMetadata: true, readMetadata: { _ in reads += 1; return "com.vendor.example" })
        suite.expect(owner == nil && reads == 0,
                     "protected Apple container ownership is rejected before any metadata read")
        suite.expect(CleanerPolicy.isExcludedCacheEntry("com.apple.AMPArtworkAgent"),
                     "cleanup never traverses Apple's media caches to calculate disposable bytes")
        suite.expect(CleanerScanPrivacy.mayInspect(".cache-data"),
                     "privacy exclusions do not skip ordinary hidden data inside an eligible cache")
    }
}
