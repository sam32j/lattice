import Foundation

enum PR12DestinationTests {
    static func run(_ suite: TestSuite) {
        let domain = "vorss.tests.pr12-destinations.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        for destination in [IslandDestination.clipboard, .files, .scratchpad, .cameraPreview, .launcherGrid] {
            destination.setShown(true, in: defaults)
            suite.expect(destination.isShown(in: defaults), "page-owned destinations enable their route and module")
            destination.setShown(false, in: defaults)
            suite.expect(!destination.isShown(in: defaults), "page-owned destinations disable their route and module")
        }
    }
}
