import Foundation

enum PermissionRevocationTrackerTests {
    static func run(_ suite: TestSuite) {
        let domain = "io.github.sam32j.lattice.tests.grant-history.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        var tracker = PermissionRevocationTracker(defaults: defaults)
        suite.expect(tracker.update([.camera: .unverified, .accessibility: .unverified]).isEmpty,
                     "never-requested permissions are not revoked on first launch")
        suite.expect(tracker.update([.camera: .denied]) == [.camera: false],
                     "an explicit system denial disables saved activation even at startup")
        suite.expect(tracker.update([.accessibility: .granted, .bluetooth: .granted]).isEmpty,
                     "observing grants never enables features")
        var restarted = PermissionRevocationTracker(defaults: defaults)
        suite.expect(restarted.update([.accessibility: .unverified]) == [.accessibility: false],
                     "a grant lost while the app was closed is remembered and revoked on restart")
        suite.expect(restarted.update([.bluetooth: .unverified]) == [.bluetooth: false],
                     "an omitted capability retains its grant history until independently checked")
        suite.expect(restarted.update([.accessibility: .unverified, .bluetooth: .unverified]).isEmpty,
                     "unchanged missing access does not repeatedly revoke the same grant")
        suite.expect(!SettingsBackupSupport.exportKeys().contains("permissionRevocationObservedGrants"),
                     "portable backups cannot import grant history from another Mac")
    }
}
